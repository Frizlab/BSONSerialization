import XCTest

import BSONSerializationTests

var tests = [XCTestCaseEntry]()
tests += BSONSerializationTests.__allTests()

XCTMain(tests)
