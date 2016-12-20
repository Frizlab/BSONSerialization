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
	
	func testDecodeEmptyBSONFromData() {
		do {
			let data = Data(hexEncoded: "05 00 00 00 00")!
			let r = try BSONSerialization.BSONObject(data: data, options: []) as NSDictionary
			let e = [String: Any]() as NSDictionary
			XCTAssertEqual(r, e)
		} catch {
			XCTFail("\(error)")
		}
	}
	
	func testDecodeKeyAbcValDefFromData() {
		do {
			let data = Data(hexEncoded: "12 00 00 00 02 61 62 63 00 04 00 00 00 64 65 66 00 00")!
			let r = try BSONSerialization.BSONObject(data: data, options: []) as NSDictionary
			let e = ["abc": "def"] as NSDictionary
			XCTAssertEqual(r, e)
		} catch {
			XCTFail("\(error)")
		}
	}
	
	func testSimpleEmbeddedDocFromData() {
		do {
			let data = Data(hexEncoded: "1C 00 00 00 03 64 6F 63 00 12 00 00 00 02 61 62 63 00 04 00 00 00 64 65 66 00 00 00")!
			let r = try BSONSerialization.BSONObject(data: data, options: []) as NSDictionary
			let e = ["doc": ["abc": "def"]] as NSDictionary
			XCTAssertEqual(r, e)
		} catch {
			XCTFail("\(error)")
		}
	}
	
	func testPerformanceDecode4242EmptyDictionaryFromData() {
		let data = Data(hexEncoded: "05 00 00 00 00")!
		self.measure {
			for _ in 0..<4242 {
				do {
					_ = try BSONSerialization.BSONObject(data: data, options: []) as NSDictionary
				} catch {
					XCTFail("\(error)")
				}
			}
		}
	}
	
	
	func testDecodeEmptyBSONFromStream() {
		do {
			let stream = Data(hexEncoded: "05 00 00 00 00")!.asStream()!
			CFReadStreamOpen(stream); defer {CFReadStreamClose(stream)}
			
			let r = try BSONSerialization.BSONObject(stream: stream, options: []) as NSDictionary
			let e = [String: Any]() as NSDictionary
			XCTAssertEqual(r, e)
		} catch {
			XCTFail("\(error)")
		}
	}
	
	func testSimpleEmbeddedDocFromStream() {
		do {
			let stream = Data(hexEncoded: "1C 00 00 00 03 64 6F 63 00 12 00 00 00 02 61 62 63 00 04 00 00 00 64 65 66 00 00 00")!.asStream()!
			CFReadStreamOpen(stream); defer {CFReadStreamClose(stream)}
			
			let r = try BSONSerialization.BSONObject(stream: stream, options: []) as NSDictionary
			let e = ["doc": ["abc": "def"]] as NSDictionary
			XCTAssertEqual(r, e)
		} catch {
			XCTFail("\(error)")
		}
	}
	
	
//	func testEncodeEmptyBSONToData() {
//		do {
//			let ref = "05 00 00 00 00"
//			let res = try BSONSerialization.data(withBSONObject: [:], options: []).hexEncodedString()
//			XCTAssertEqual(ref, res)
//		} catch {
//			XCTFail("\(error)")
//		}
//	}
	
}
