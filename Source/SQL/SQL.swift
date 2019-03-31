import Foundation

extension SQL {
    /// The type of data in a column.
    internal enum DataType: String {
        case text = "TEXT"
        case numeric = "NUMERIC"
        case integer = "INTEGER"
        case real = "REAL"
        case blob = "BLOB"
    }
}

extension SQL.DataType {
    internal var sql: SQL {
        return SQL(rawValue)
    }
}

extension String {
    // swiftlint:disable:next force_try
    static let PlaceholderRegex = try! NSRegularExpression(
        pattern: "(\\?) | '[^']*' | --[^\\n]* | /\\* (?:(?!\\*/).)* \\*/",
        options: [ .allowCommentsAndWhitespace, .dotMatchesLineSeparators ]
    )

    internal var placeholders: IndexSet {
        let range = NSRange(location: 0, length: count)
        let matches = String.PlaceholderRegex.matches(in: self, range: range)
        var result = IndexSet()
        for match in matches {
            let location = match.range(at: 1).location
            if location != NSNotFound {
                result.insert(location)
            }
        }
        return result
    }
}

/// A SQL statement with placeholders for sanitized values.
public struct SQL: Hashable {
    /// The SQL statement.
    public private(set) var sql: String

    /// The parameters to the SQL statement.
    internal private(set) var parameters: [SQL.Value]

    internal init(_ sql: String, parameters: [SQL.Value]) {
        precondition(sql.placeholders.count == parameters.count)
        self.sql = sql
        self.parameters = parameters
    }

    internal init(_ sql: String, parameters: SQL.Value...) {
        self.init(sql, parameters: parameters)
    }

    public init() {
        self.init("")
    }

    /// A textual representation of self, suitable for debugging.
    public var debugDescription: String {
        var result = sql
        var offset = 0
        for (index, parameter) in zip(sql.placeholders, parameters) {
            let replacement = parameter.description
            let adjusted = result.index(result.startIndex, offsetBy: index + offset)
            result.replaceSubrange(adjusted...adjusted, with: replacement)

            offset += replacement.count - 1
        }
        return String(result)
    }

    /// Append the given statement to the statement.
    internal mutating func append(_ sql: String, parameters: [SQL.Value]) {
        self.sql += sql
        self.parameters += parameters
    }

    /// Append the given statement to the statement.
    internal mutating func append(_ sql: String, parameters: SQL.Value...) {
        append(sql, parameters: parameters)
    }

    /// Append the given statement to the statement.
    internal mutating func append(_ sql: SQL) {
        append(sql.sql, parameters: sql.parameters)
    }

    /// Create a new SQL statement by appending a SQL statement
    internal func appending(_ sql: String, parameters: [SQL.Value]) -> SQL {
        return SQL(self.sql + sql, parameters: self.parameters + parameters)
    }

    /// Create a new SQL statement by appending a SQL statement
    internal func appending(_ sql: String, parameters: SQL.Value...) -> SQL {
        return appending(sql, parameters: parameters)
    }

    /// Create a new SQL statement by appending a SQL statement
    internal func appending(_ sql: SQL) -> SQL {
        return appending(sql.sql, parameters: sql.parameters)
    }

    /// Returns a version of the statement that's surrounded by paretheses.
    internal var parenthesized: SQL {
        return "(" + self + ")"
    }
}

/// Create a new SQL statement by appending a SQL statement
internal func + (lhs: SQL, rhs: SQL) -> SQL {
    return lhs.appending(rhs)
}

/// Create a new SQL statement by appending a SQL statement
internal func + (lhs: SQL, rhs: String) -> SQL {
    return lhs.appending(rhs)
}

/// Create a new SQL statement by appending a SQL statement
internal func + (lhs: String, rhs: SQL) -> SQL {
    return SQL(lhs).appending(rhs)
}

internal func += (lhs: inout SQL, rhs: SQL) {
    lhs.append(rhs)
}

internal func += (lhs: inout SQL, rhs: String) {
    lhs.append(rhs)
}

extension Sequence where Iterator.Element == SQL {
    internal func joined(separator: String) -> SQL {
        var result: SQL?
        for sql in self {
            if let accumulated = result {
                result = accumulated + separator + sql
            } else {
                result = sql
            }
        }
        return result ?? SQL()
    }
}
