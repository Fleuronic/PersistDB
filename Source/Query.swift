import Foundation
import Schemata

/// A value representing a query of a model type.
public struct Query<Key: ModelValue, Model: PersistDB.Model>: Hashable {
    /// The predicates used to filter results.
    public var predicates: [Predicate<Model>]

    /// The orderings used to order results.
    ///
    /// - note: Results are sorted by the first ordering first. Subsequent ordering are used
    ///         to break ties.
    public var order: [Ordering<Model>]

    /// The grouping that's used by this query.
    public var groupedBy: Grouping<Model, Key>

    public init(
        predicates: [Predicate<Model>],
        order: [Ordering<Model>],
        groupedBy: Grouping<Model, Key>
    ) {
        self.predicates = predicates
        self.order = order
        self.groupedBy = groupedBy
    }
}

extension Query where Key == None {
    /// Creates a query that returns all instances of `Model` in the store.
    public init() {
        predicates = []
        order = []
        groupedBy = .none
    }
}

extension Query {
    /// Returns a query that is filtered by the given predicate.
    public func filter(_ predicate: Predicate<Model>) -> Query {
        var result = self
        result.predicates.append(predicate)
        return result
    }

    /// Returns a query that is grouped by the given keypath.
    public func group<Value>(
        by keyPath: KeyPath<Model, Value>,
        ascending: Bool = true
    ) -> Query<Value, Model> {
        return group(by: Expression(AnyExpression(keyPath)), ascending: ascending)
    }

    /// Returns a query that is grouped by the given expression.
    public func group<Value>(
        by expression: Expression<Model, Value>,
        ascending: Bool = true
    ) -> Query<Value, Model> {
        return Query<Value, Model>(
            predicates: predicates,
            order: order,
            groupedBy: Grouping(expression, ascending: ascending)
        )
    }

    /// Returns a query that is sorted by the given keypath.
    ///
    /// - important: Orderings are inserted into the beginning of the array.
    ///              `.sort(by: \.a, ascending: true).sort(by: \.b, ascending: true)` will sort by
    ///              `b` and use `a` to break ties.
    public func sort<Value>(by keyPath: KeyPath<Model, Value>, ascending: Bool = true) -> Query {
        var result = self
        let descriptor = Ordering(keyPath, ascending: ascending)
        result.order.insert(descriptor, at: 0)
        return result
    }

    /// Returns a query that is sorted by the given expression.
    ///
    /// - important: Orderings are inserted into the beginning of the array.
    ///              `.sort(by: \.a, ascending: true).sort(by: \.b, ascending: true)` will sort by
    ///              `b` and use `a` to break ties.
    public func sort<Value>(
        by expression: Expression<Model, Value>,
        ascending: Bool = true
    ) -> Query {
        var result = self
        let descriptor = Ordering<Model>(expression.expression, ascending: ascending)
        result.order.insert(descriptor, at: 0)
        return result
    }
}

extension Query {
    public var count: Aggregate<Model, Int> {
        return Aggregate(
            expression: .function(.count, [ AnyExpression(Model.idKeyPath) ]),
            predicates: predicates
        )
    }
}
