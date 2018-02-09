@testable import PersistDB
import XCTest

class ValueSetInitTests: XCTestCase {
    func testMultipleAssignmentsWithSameKeyPath() {
        let valueSet: ValueSet<Book> = [
            \.title == "foo",
            \.title == "bar",
        ]

        XCTAssertEqual(valueSet, [\Book.title == "bar"])
    }
}

class ValueSetUpdateTests: XCTestCase {
    func testReplacedValue() {
        let old: ValueSet = [\Author.born == 1900 ]
        let new: ValueSet = [\Author.born == 2000 ]
        XCTAssertEqual(old.update(with: new), new)
    }

    func testNewValue() {
        let old = ValueSet<Author>()
        let new: ValueSet = [\Author.died == 2000 ]
        XCTAssertEqual(old.update(with: new), new)
    }

    func testUnreplacedValue() {
        let old: ValueSet = [\Author.died == 2000 ]
        let new = ValueSet<Author>()
        XCTAssertEqual(old.update(with: new), old)
    }
}

class ValueSetSufficientForInsertTests: XCTestCase {
    func testEveryPropertySet() {
        let assignments: [Assignment<Author>] = [
            \.id == Author.ID(1),
            \.name == "Some Gal",
            \.givenName == "Someantha Gal",
            \.born == 1930,
            \.died == nil,
        ]
        XCTAssertTrue(ValueSet(assignments).sufficientForInsert)
    }

    func testWithoutOptionalProperties() {
        let assignments: [Assignment<Author>] = [
            \.id == Author.ID(1),
            \.name == "Some Gal",
            \.givenName == "Someantha Gal",
            \.born == 1930,
        ]
        XCTAssertTrue(ValueSet(assignments).sufficientForInsert)
    }

    func testMissingProperties() {
        let valueSet: ValueSet<Author> = [
            \.id == Author.ID(1),
            \.born == 1930,
        ]
        XCTAssertFalse(valueSet.sufficientForInsert)
    }
}
