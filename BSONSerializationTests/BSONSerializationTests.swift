/*
 * BSONSerializationTests.swift
 * BSONSerializationTests
 *
 * Created by François Lamboley on 1/17/16.
 * Copyright © 2016 frizlab. All rights reserved.
 */

import XCTest
@testable import BSONSerialization



class BSONSerializationTests: XCTestCase {
	
	override func setUp() {
		super.setUp()
		
		/* Setup code goes here. */
	}
	
	override func tearDown() {
		/* Teardown code goes here. */
		
		super.tearDown()
	}
	
	func testEmptyBSON() {
		let data = NSData(base64EncodedString: "BQAAAAA=", options: [])!
		do {
			let r = try BSONSerialization.BSONObjectWithData(data, options: []) as NSDictionary
			let e = [String: AnyObject]() as NSDictionary
			XCTAssertEqual(r, e)
		} catch {
			XCTFail("\(error)")
		}
	}
	
	func testKeyAbcValDef() {
		let data = NSData(base64EncodedString: "EgAAAAJhYmMABAAAAGRlZgAA", options: [])!
		do {
			let r = try BSONSerialization.BSONObjectWithData(data, options: []) as NSDictionary
			let e = ["abc": "def"] as NSDictionary
			XCTAssertEqual(r, e)
		} catch {
			XCTFail("\(error)")
		}
	}
	
	func testPerformanceExample() {
		/* This is an example of a performance test case. */
		self.measureBlock {
			/* Put the code you want to measure the time of here. */
		}
	}
	
}
