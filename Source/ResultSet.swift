import Differ
import Schemata

/// An ordered set of results from a query.
///
/// Result sets that haven't been grouped use `None` as `Key`.
public struct ResultSet<Key: Hashable, Projection: PersistDB.ModelProjection>: Hashable {
    /// The groups in the result set.
    public private(set) var groups: [Group<Key, Projection>]

    /// All the values from all the groups in the set.
    public private(set) var values: [Projection]

    /// Whether the result set has been grouped by some key.
    public let isGrouped: Bool

    /// Create an empty result set.
    public init() {
        self.init([])
    }

    fileprivate init(_ groups: [Group<Key, Projection>], isGrouped: Bool) {
        let values = groups.flatMap { $0.values }
        precondition(Set(groups.map { $0.key }).count == groups.count)
        precondition(Set(values).count == values.count)

        self.groups = groups
        self.values = values
        self.isGrouped = isGrouped
    }

    /// Create a result set with the given groups.
    public init(_ groups: [Group<Key, Projection>]) {
        self.init(groups, isGrouped: Key.self != None.self)
    }
}

extension ResultSet {
    /// All the keys from all the groups.
    public var keys: [Key] {
        return groups.map { $0.key }
    }

    /// Return a new result set where the group keys have been transformed.
    ///
    /// - important: The keys **must** remain unique.
    public func mapKeys<T>(_ transform: (Key) -> T) -> ResultSet<T, Projection> {
        let groups = self.groups.map { Group(key: transform($0.key), values: $0.values) }
        return ResultSet<T, Projection>(groups, isGrouped: isGrouped)
    }
}

extension ResultSet where Key == None {
    /// Create a ungrouped result set with the given projections.
    public init(_ projections: [Projection]) {
        self.init([ Group(key: .none, values: projections) ])
    }
}

extension ResultSet: Collection {
    public var startIndex: Int {
        return values.startIndex
    }

    public var endIndex: Int {
        return values.endIndex
    }

    public subscript(_ i: Int) -> Projection {
        return values[i]
    }

    public func index(after i: Int) -> Int {
        return values.index(after: i)
    }
}

private func diff<K, P>(
    from old: ResultSet<K, P>,
    to new: ResultSet<K, P>
) -> ResultSet<K, P>.Diff {
    var diff = ResultSet<K, P>.Diff()

    func indicesByID(in resultSet: ResultSet<K, P>) -> [P.Model.ID: (Int, Int)] {
        var result: [P.Model.ID: (Int, Int)] = [:]
        for (g, group) in resultSet.groups.enumerated() {
            for (v, value) in group.values.enumerated() {
                result[value.id] = (g, v)
            }
        }
        return result
    }

    let oldIndicesByID = indicesByID(in: old)
    let newIndicesByID = indicesByID(in: new)

    // 1. Diff the group keys by themselves.
    //
    // This generates all `deleteGroup`, `insertGroup`, and `moveGroup`s.
    let groupsDiff = old.keys.extendedDiff(new.keys)
    let groupDeltas = groupsDiff
        .elements
        .map { element -> ResultSet<K, P>.Diff.Delta in
            switch element {
            case let .insert(index):
                return .insertGroup(index)
            case let .delete(index):
                return .deleteGroup(index)
            case let .move(from, to):
                return .moveGroup(from, to)
            }
        }
    diff.deltas.formUnion(groupDeltas)

    // 2. Diff the IDs to find inserts, deletes, and moves
    var oldGroups = old.groups
    for case let .move(from, to) in groupsDiff.patch(from: old.keys, to: new.keys) {
        let group = oldGroups.remove(at: from)
        oldGroups.insert(group, at: to)
    }
    let oldIDs = oldGroups.flatMap { $0.values }.map { $0.id }
    let newIDs = new.values.map { $0.id }
    let valueElements = oldIDs.extendedDiff(newIDs).elements
    let valueDeltas = valueElements.compactMap { element -> ResultSet<K, P>.Diff.Delta? in
        switch element {
        case let .insert(index):
            let id = new[index].id
            let new = newIndicesByID[id]!
            return .insertValue(new.0, new.1)
        case let .delete(index):
            let id = old[index].id
            let old = oldIndicesByID[id]!
            return .deleteValue(old.0, old.1)
        case let .move(from, _):
            let id = old[from].id
            let old = oldIndicesByID[id]!
            let new = newIndicesByID[id]!
            return .moveValue(old.0, old.1, new.0, new.1)
        }
    }
    diff.deltas.formUnion(valueDeltas)

    // 3. Find updated values and values that shifted group boundaries
    let updated = new
        .compactMap { newValue -> ResultSet<K, P>.Diff.Delta? in
            guard let oldIndex = oldIndicesByID[newValue.id] else { return nil }
            let newIndex = newIndicesByID[newValue.id]!
            let oldValue = old.groups[oldIndex.0].values[oldIndex.1]
            if oldValue != newValue {
                return .updateValue(newIndex.0, newIndex.1)
            }
            if old.groups[oldIndex.0].key != new.groups[newIndex.0].key {
                return .moveValue(oldIndex.0, oldIndex.1, newIndex.0, newIndex.1)
            }
            return nil
        }
    diff.deltas.formUnion(updated)

    return diff
}

extension ResultSet {
    /// The difference between two result sets.
    public struct Diff: Hashable {
        /// A change within a diff.
        public enum Delta: Hashable {
            /// The group at the given index in the old set was deleted.
            ///
            /// Values within the group are assumed to be deleted unless in a `.updateValue`.
            case deleteGroup(Int)
            /// The group at the given index in the new set was inserted.
            case insertGroup(Int)
            /// The group was moved from the given index in the old set to the given index in the
            /// new set.
            case moveGroup(Int, Int)
            /// The value at the given group and value indices in the old set was deleted.
            case deleteValue(Int, Int)
            /// The value at the given group and value indices in the new set was inserted.
            case insertValue(Int, Int)
            /// The value was moved from the given group and value indices in the old set to the
            /// given group and value indices in the new set.
            case moveValue(Int, Int, Int, Int)
            /// The values at the given group and value indices in the new set was updated, but
            /// not moved.
            case updateValue(Int, Int)
        }

        /// The changes that make up the diff.
        public var deltas: Set<Delta>

        /// Create an empty diff.
        public init() {
            deltas = []
        }

        /// Create a diff with the given deltas.
        public init(_ deltas: Set<Delta>) {
            self.deltas = deltas
        }
    }

    /// Calculate the diff from `resultSet` to `self`.
    public func diff(from resultSet: ResultSet) -> Diff {
        return PersistDB.diff(from: resultSet, to: self)
    }
}
