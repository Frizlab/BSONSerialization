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
	
	func testDecodeEmptyBSON() {
		do {
			let data = Data(base64Encoded: "BQAAAAA=", options: [])!
			let r = try BSONSerialization.BSONObject(data: data, options: []) as NSDictionary
			let e = [String: Any]() as NSDictionary
			XCTAssertEqual(r, e)
		} catch {
			XCTFail("\(error)")
		}
	}
	
	func testEncodeEmptyBSON() {
		do {
			let ref = "BQAAAAA="
			let res = try BSONSerialization.data(withBSONObject: [:], options: []).base64EncodedString()
			XCTAssertEqual(ref, res)
		} catch {
			XCTFail("\(error)")
		}
	}
	
	func testDecodeKeyAbcValDef() {
		do {
			let data = Data(base64Encoded: "EgAAAAJhYmMABAAAAGRlZgAA", options: [])!
			let r = try BSONSerialization.BSONObject(data: data, options: []) as NSDictionary
			let e = ["abc": "def"] as NSDictionary
			XCTAssertEqual(r, e)
		} catch {
			XCTFail("\(error)")
		}
	}
	
	func testPerformanceDecode4242EmptyDictionary() {
		self.measure {
			for _ in 0..<4242 {
				do {
					let data = Data(base64Encoded: "BQAAAAA=", options: [])!
					_ = try BSONSerialization.BSONObject(data: data, options: []) as NSDictionary
				} catch {
					XCTFail("\(error)")
				}
			}
		}
	}
	
}
