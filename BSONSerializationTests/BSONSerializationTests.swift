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
		do {
			let ref = [5]
			let res = try BSONSerialization.sizesOfBSONObject([:])
			XCTAssertEqual(res, ref)
		} catch {
			XCTFail("\(error)")
		}
	}
	
	func testSizeSimpleEmbeddedBSON() {
		do {
			let ref = [18, 28]
			let res = try BSONSerialization.sizesOfBSONObject(["doc": ["abc": "def"]])
			XCTAssertEqual(res, ref)
		} catch {
			XCTFail("\(error)")
		}
	}
	
	func testSizeEmbeddedArrayBSON() {
		do {
			let ref = [38, 48]
			let res = try BSONSerialization.sizesOfBSONObject(["col": ["abc", "def", "ghi"]])
			XCTAssertEqual(res, ref)
		} catch {
			XCTFail("\(error)")
		}
	}
	
	func testSizeEmbeddedBSONsInArrayBSON() {
		do {
			let ref = [14, 18, 43, 50]
			let res = try BSONSerialization.sizesOfBSONObject(["": [["abc": "def"], ["g": "h"]]])
			XCTAssertEqual(res, ref)
		} catch {
			XCTFail("\(error)")
		}
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
	
	func testEncodeSimpleBSONToData() {
		do {
			let ref = "12 00 00 00 02 61 62 63 00 04 00 00 00 64 65 66 00 00"
			let res = try BSONSerialization.data(withBSONObject: ["abc": "def"], options: []).hexEncodedString()
			XCTAssertEqual(res, ref)
		} catch {
			XCTFail("\(error)")
		}
	}
	
	func testEncodeSimpleEmbeddedBSONToData() {
		do {
			let ref = "1C 00 00 00 03 64 6F 63 00 12 00 00 00 02 61 62 63 00 04 00 00 00 64 65 66 00 00 00"
			let res = try BSONSerialization.data(withBSONObject: ["doc": ["abc": "def"]], options: []).hexEncodedString()
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
	
	func testEncodeSimpleEmbeddedBSONToStream() {
		do {
			let ref = "1C 00 00 00 03 64 6F 63 00 12 00 00 00 02 61 62 63 00 04 00 00 00 64 65 66 00 00 00"
			let res = try dataFromWriteStream { _ = try BSONSerialization.write(BSONObject: ["doc": ["abc": "def"]], toStream: $0, options: []) }.hexEncodedString()
			XCTAssertEqual(res, ref)
		} catch {
			XCTFail("\(error)")
		}
	}
	
	
	func testEncodeDecodeEmptyBSONUsingData() {
		do {
			let ref: BSONDoc = [:]
			let encoded = try BSONSerialization.data(withBSONObject: ref, options: [])
			let decoded = try BSONSerialization.BSONObject(data: encoded, options: [])
			XCTAssertEqual(decoded as NSDictionary, ref as NSDictionary)
		} catch {
			XCTFail("\(error)")
		}
	}
	
	func testEncodeDecodeSimpleOneEmptyKeyBSONUsingData() {
		do {
			let ref: BSONDoc = ["": "def"]
			let encoded = try BSONSerialization.data(withBSONObject: ref, options: [])
			let decoded = try BSONSerialization.BSONObject(data: encoded, options: [])
			XCTAssertEqual(decoded as NSDictionary, ref as NSDictionary)
		} catch {
			XCTFail("\(error)")
		}
	}
	
	func testEncodeDecodeSimpleOneEmptyValBSONUsingData() {
		do {
			let ref: BSONDoc = ["abc": ""]
			let encoded = try BSONSerialization.data(withBSONObject: ref, options: [])
			let decoded = try BSONSerialization.BSONObject(data: encoded, options: [])
			XCTAssertEqual(decoded as NSDictionary, ref as NSDictionary)
		} catch {
			XCTFail("\(error)")
		}
	}
	
	func testEncodeDecodeSimpleOneEmptyKeyAndValBSONUsingData() {
		do {
			let ref: BSONDoc = ["": ""]
			let encoded = try BSONSerialization.data(withBSONObject: ref, options: [])
			let decoded = try BSONSerialization.BSONObject(data: encoded, options: [])
			XCTAssertEqual(decoded as NSDictionary, ref as NSDictionary)
		} catch {
			XCTFail("\(error)")
		}
	}
	
	func testEncodeDecodeSimpleOneKeyBSONUsingData() {
		do {
			let ref: BSONDoc = ["abc": "def"]
			let encoded = try BSONSerialization.data(withBSONObject: ref, options: [])
			let decoded = try BSONSerialization.BSONObject(data: encoded, options: [])
			XCTAssertEqual(decoded as NSDictionary, ref as NSDictionary)
		} catch {
			XCTFail("\(error)")
		}
	}
	
	func testEncodeDecodeSimpleTwoKeysBSONUsingData() {
		do {
			let ref: BSONDoc = ["abc": "def", "ghi": "jkl"]
			let encoded = try BSONSerialization.data(withBSONObject: ref, options: [])
			let decoded = try BSONSerialization.BSONObject(data: encoded, options: [])
			XCTAssertEqual(decoded as NSDictionary, ref as NSDictionary)
		} catch {
			XCTFail("\(error)")
		}
	}
	
	func testEncodeDecodeSimpleNilValBSONUsingData() {
		do {
			let ref: BSONDoc = ["key": nil]
			let encoded = try BSONSerialization.data(withBSONObject: ref, options: [])
			let decoded = try BSONSerialization.BSONObject(data: encoded, options: [])
			XCTAssertEqual(decoded as NSDictionary, ref as NSDictionary)
		} catch {
			XCTFail("\(error)")
		}
	}
	
	func testEncodeDecodeSimpleBoolValBSONUsingData() {
		do {
			let ref: BSONDoc = ["key": true]
			let encoded = try BSONSerialization.data(withBSONObject: ref, options: [])
			let decoded = try BSONSerialization.BSONObject(data: encoded, options: [])
			XCTAssertEqual(decoded as NSDictionary, ref as NSDictionary)
		} catch {
			XCTFail("\(error)")
		}
	}
	
	func testEncodeDecodeSimpleIntValBSONUsingData() {
		do {
			let ref: BSONDoc = ["key": 42]
			let encoded = try BSONSerialization.data(withBSONObject: ref, options: [])
			let decoded = try BSONSerialization.BSONObject(data: encoded, options: [])
			XCTAssertEqual(decoded as NSDictionary, ref as NSDictionary)
		} catch {
			XCTFail("\(error)")
		}
	}
	
	func testEncodeDecodeSimpleInt32ValBSONUsingData() {
		do {
			let ref: BSONDoc = ["key": Int32(42)]
			let encoded = try BSONSerialization.data(withBSONObject: ref, options: [])
			let decoded = try BSONSerialization.BSONObject(data: encoded, options: [])
			XCTAssertEqual(decoded as NSDictionary, ref as NSDictionary)
		} catch {
			XCTFail("\(error)")
		}
	}
	
	func testEncodeDecodeSimpleInt64ValBSONUsingData() {
		do {
			let ref: BSONDoc = ["key": Int64(42)]
			let encoded = try BSONSerialization.data(withBSONObject: ref, options: [])
			let decoded = try BSONSerialization.BSONObject(data: encoded, options: [])
			XCTAssertEqual(decoded as NSDictionary, ref as NSDictionary)
		} catch {
			XCTFail("\(error)")
		}
	}
	
	func testEncodeDecodeSimpleDouble64ValBSONUsingData() {
		do {
			let ref: BSONDoc = ["key": Double(42)]
			let encoded = try BSONSerialization.data(withBSONObject: ref, options: [])
			let decoded = try BSONSerialization.BSONObject(data: encoded, options: [])
			XCTAssertEqual(decoded as NSDictionary, ref as NSDictionary)
		} catch {
			XCTFail("\(error)")
		}
	}
	
	func testEncodeDecodeSimpleDouble128ValBSONUsingData() {
		do {
			let ref: BSONDoc = ["key": Double128(data: (1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0) /* No idea if this is a valid Double128... */)]
			let encoded = try BSONSerialization.data(withBSONObject: ref, options: [])
			let decoded = try BSONSerialization.BSONObject(data: encoded, options: [])
			XCTAssertEqual(decoded as NSDictionary, ref as NSDictionary)
		} catch {
			XCTFail("\(error)")
		}
	}
	
	func testEncodeDecodeSimpleDateValBSONUsingData() {
		do {
			let ref: BSONDoc = ["key": Date()]
			let encoded = try BSONSerialization.data(withBSONObject: ref, options: [])
			let decoded = try BSONSerialization.BSONObject(data: encoded, options: [])
			XCTAssertEqual(decoded as NSDictionary, ref as NSDictionary)
		} catch {
			XCTFail("\(error)")
		}
	}
	
	func testEncodeDecodeSimpleRegexValBSONUsingData() {
		do {
			let ref: BSONDoc = ["key": try! NSRegularExpression(pattern: ".*", options: [])]
			let encoded = try BSONSerialization.data(withBSONObject: ref, options: [])
			let decoded = try BSONSerialization.BSONObject(data: encoded, options: [])
			XCTAssertEqual(decoded as NSDictionary, ref as NSDictionary)
		} catch {
			XCTFail("\(error)")
		}
	}
	
	func testEncodeDecodeSimpleEmbeddedDocValBSONUsingData() {
		do {
			let ref: BSONDoc = ["key": ["abc": "def"]]
			let encoded = try BSONSerialization.data(withBSONObject: ref, options: [])
			let decoded = try BSONSerialization.BSONObject(data: encoded, options: [])
			XCTAssertEqual(decoded as NSDictionary, ref as NSDictionary)
		} catch {
			XCTFail("\(error)")
		}
	}
	
	func testEncodeDecodeSimpleArrayValBSONUsingData() {
		do {
			let ref: BSONDoc = ["key": ["abc", "def"]]
			let encoded = try BSONSerialization.data(withBSONObject: ref, options: [])
			let decoded = try BSONSerialization.BSONObject(data: encoded, options: [])
			XCTAssertEqual(decoded as NSDictionary, ref as NSDictionary)
		} catch {
			XCTFail("\(error)")
		}
	}
	
	func testEncodeDecodeSimpleBSONTimeStampValBSONUsingData() {
		do {
			let ref: BSONDoc = ["key": MongoTimestamp(incrementData: Data([0, 1, 2, 3]), timestampData: Data([4, 5, 6, 7]))]
			let encoded = try BSONSerialization.data(withBSONObject: ref, options: [])
			let decoded = try BSONSerialization.BSONObject(data: encoded, options: [])
			XCTAssertEqual(decoded as NSDictionary, ref as NSDictionary)
		} catch {
			XCTFail("\(error)")
		}
	}
	
	func testEncodeDecodeSimpleBSONBinaryValBSONUsingData() {
		do {
			let ref: BSONDoc = ["key": MongoBinary(binaryTypeAsInt: MongoBinary.BinarySubtype.genericBinary.rawValue, data: Data([0, 1, 2, 3, 4, 5]))]
			let encoded = try BSONSerialization.data(withBSONObject: ref, options: [])
			let decoded = try BSONSerialization.BSONObject(data: encoded, options: [])
			XCTAssertEqual(decoded as NSDictionary, ref as NSDictionary)
		} catch {
			XCTFail("\(error)")
		}
	}
	
	func testEncodeDecodeSimpleBSONObjectIdValBSONUsingData() {
		do {
			let ref: BSONDoc = ["key": MongoObjectId(data: (1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))]
			let encoded = try BSONSerialization.data(withBSONObject: ref, options: [])
			let decoded = try BSONSerialization.BSONObject(data: encoded, options: [])
			XCTAssertEqual(decoded as NSDictionary, ref as NSDictionary)
		} catch {
			XCTFail("\(error)")
		}
	}
	
	func testEncodeDecodeSimpleJSValBSONUsingData() {
		do {
			let ref: BSONDoc = ["key": Javascript(javascript: "console.log(\"hello world\");" /* Not sure if valid JS, but we do not care... */)]
			let encoded = try BSONSerialization.data(withBSONObject: ref, options: [])
			let decoded = try BSONSerialization.BSONObject(data: encoded, options: [])
			XCTAssertEqual(decoded as NSDictionary, ref as NSDictionary)
		} catch {
			XCTFail("\(error)")
		}
	}
	
	func testEncodeDecodeSimpleJSWithScopeValSimpleScopeBSONUsingData() {
		do {
			let ref: BSONDoc = ["key": JavascriptWithScope(javascript: "console.log(\"hello world\");", scope: ["abc": "def"])]
			let encoded = try BSONSerialization.data(withBSONObject: ref, options: [])
			let decoded = try BSONSerialization.BSONObject(data: encoded, options: [])
			XCTAssertEqual(decoded as NSDictionary, ref as NSDictionary)
		} catch {
			XCTFail("\(error)")
		}
	}
	
	func testEncodeDecodeSimpleMinKeyValBSONUsingData() {
		do {
			let ref: BSONDoc = ["key": MinKey()]
			let encoded = try BSONSerialization.data(withBSONObject: ref, options: [])
			let decoded = try BSONSerialization.BSONObject(data: encoded, options: [])
			XCTAssertEqual(decoded as NSDictionary, ref as NSDictionary)
		} catch {
			XCTFail("\(error)")
		}
	}
	
	func testEncodeDecodeSimpleMaxKeyValBSONUsingData() {
		do {
			let ref: BSONDoc = ["key": MaxKey()]
			let encoded = try BSONSerialization.data(withBSONObject: ref, options: [])
			let decoded = try BSONSerialization.BSONObject(data: encoded, options: [])
			XCTAssertEqual(decoded as NSDictionary, ref as NSDictionary)
		} catch {
			XCTFail("\(error)")
		}
	}
	
	func testEncodeDecodeSimpleMongoDBPointerKeyValBSONUsingData() {
		do {
			let ref: BSONDoc = ["key": MongoDBPointer(stringPart: "StringPart!", bytesPartData: Data([1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]))]
			let encoded = try BSONSerialization.data(withBSONObject: ref, options: [])
			let decoded = try BSONSerialization.BSONObject(data: encoded, options: [])
			XCTAssertEqual(decoded as NSDictionary, ref as NSDictionary)
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
