import XCTest

import PerfectNIOCompatTests

var tests = [XCTestCaseEntry]()
tests += PerfectNIOCompatTests.allTests()
XCTMain(tests)