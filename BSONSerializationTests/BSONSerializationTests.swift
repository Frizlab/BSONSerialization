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
	
	func testSimpleArrayFromData() {
		do {
			let data = Data(hexEncoded: "30 00 00 00 04 63 6F 6C 00 26 00 00 00 02 30 00 04 00 00 00 61 62 63 00 02 31 00 04 00 00 00 64 65 66 00 02 32 00 04 00 00 00 67 68 69 00 00 00")!
			let r = try BSONSerialization.BSONObject(data: data, options: []) as NSDictionary
			let e = ["col": ["abc", "def", "ghi"]] as NSDictionary
			XCTAssertEqual(r, e)
		} catch {
			XCTFail("\(error)")
		}
	}
	
	func testInvalidFirstKeySimpleArrayFromData() {
		do {
			let data = Data(hexEncoded: "30 00 00 00 04 63 6F 6C 00 26 00 00 00 02 31 00 04 00 00 00 61 62 63 00 02 32 00 04 00 00 00 64 65 66 00 02 33 00 04 00 00 00 67 68 69 00 00 00")!
			_ = try BSONSerialization.BSONObject(data: data, options: []) as NSDictionary
			XCTFail("Decoding should have failed.")
		} catch {
			switch error {
			case BSONSerialization.BSONSerializationError.invalidArrayKey(currentKey: let key, previousKey: let prevKey) where key == "1" && prevKey == nil: (/*Success*/)
			default: XCTFail("Invalid error thrown \(error)")
			}
		}
	}
	
	func testInvalidSecondKeySimpleArrayFromData() {
		do {
			let data = Data(hexEncoded: "30 00 00 00 04 63 6F 6C 00 26 00 00 00 02 30 00 04 00 00 00 61 62 63 00 02 32 00 04 00 00 00 64 65 66 00 02 33 00 04 00 00 00 67 68 69 00 00 00")!
			_ = try BSONSerialization.BSONObject(data: data, options: []) as NSDictionary
			XCTFail("Decoding should have failed.")
		} catch {
			switch error {
			case BSONSerialization.BSONSerializationError.invalidArrayKey(currentKey: let key, previousKey: let prevKey) where key == "2" && prevKey == "0": (/*Success*/)
			default: XCTFail("Invalid error thrown \(error)")
			}
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
	
	
	func testSizeEmptyBSON() {
		let ref = [5]
		guard let res = BSONSerialization.sizesOfBSONObject([:]) else {XCTFail("Cannot compute size of object"); return}
		XCTAssertEqual(res, ref)
	}
	
	
	func testSizeSimpleEmbeddedBSON() {
		let ref = [28, 18]
		guard let res = BSONSerialization.sizesOfBSONObject(["doc": ["abc": "def"]]) else {XCTFail("Cannot compute size of object"); return}
		XCTAssertEqual(res, ref)
	}
	
	
	func testSizeEmbeddedArrayBSON() {
		let ref = [48, 38]
		guard let res = BSONSerialization.sizesOfBSONObject(["col": ["abc", "def", "ghi"]]) else {XCTFail("Cannot compute size of object"); return}
		XCTAssertEqual(res, ref)
	}
	
	
	func testEncodeEmptyBSONToData() {
		do {
			let ref = "05 00 00 00 00"
			let res = try BSONSerialization.data(withBSONObject: [:], options: []).hexEncodedString()
			XCTAssertEqual(res, ref)
		} catch {
			XCTFail("\(error)")
		}
	}
	
	
	func testEncodeEmptyBSONToStream() {
		do {
			let ref = "05 00 00 00 00"
			let res = try dataFromWriteStream { _ = try BSONSerialization.write(BSONObject: [:], toStream: $0, options: []) }.hexEncodedString()
			XCTAssertEqual(res, ref)
		} catch {
			XCTFail("\(error)")
		}
	}
	
	
	private func dataFromWriteStream(writeBlock: (_ writeStream: OutputStream) throws -> Void) rethrows -> Data {
		let stream = CFWriteStreamCreateWithAllocatedBuffers(kCFAllocatorDefault, kCFAllocatorDefault)!
		guard CFWriteStreamOpen(stream) else {fatalError("Cannot open write stream")}
		defer {CFWriteStreamClose(stream)}
		
		try writeBlock(stream)
		
		return CFWriteStreamCopyProperty(stream, .dataWritten) as AnyObject as! Data
	}
	
}
