/*
 * BSONClasses.swift
 * BSONSerialization
 *
 * Created by François Lamboley on 2016/12/23.
 * Copyright © 2016 frizlab. All rights reserved.
 */

import Foundation



public struct Double128 : Equatable /*, AbsoluteValuable, BinaryFloatingPoint, ExpressibleByIntegerLiteral, Hashable, LosslessStringConvertible, CustomDebugStringConvertible, CustomStringConvertible, Strideable*/ {
	
	public let data: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)
	
	public init(data d: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)) {
		data = d
	}
	
	public static func ==(lhs: Double128, rhs: Double128) -> Bool {
		return (
			lhs.data.0  == rhs.data.0  && lhs.data.1  == rhs.data.1  && lhs.data.2  == rhs.data.2  && lhs.data.3  == rhs.data.3  &&
			lhs.data.4  == rhs.data.4  && lhs.data.5  == rhs.data.5  && lhs.data.6  == rhs.data.6  && lhs.data.7  == rhs.data.7  &&
			lhs.data.8  == rhs.data.8  && lhs.data.9  == rhs.data.9  && lhs.data.10 == rhs.data.10 && lhs.data.11 == rhs.data.11 &&
			lhs.data.12 == rhs.data.12 && lhs.data.13 == rhs.data.13 && lhs.data.14 == rhs.data.14 && lhs.data.15 == rhs.data.15
		)
	}
	
}


public struct MongoTimestamp : Equatable {
	
	public let increment: (UInt8, UInt8, UInt8, UInt8)
	public let timestamp: (UInt8, UInt8, UInt8, UInt8)
	
	public init(incrementData: Data, timestampData: Data) {
		assert(incrementData.count == 4)
		assert(timestampData.count == 4)
		increment = (incrementData[0], incrementData[1], incrementData[2], incrementData[3])
		timestamp = (timestampData[0], timestampData[1], timestampData[2], timestampData[3])
	}
	
	public static func ==(lhs: MongoTimestamp, rhs: MongoTimestamp) -> Bool {
		return (
			lhs.increment.0 == rhs.increment.0 && lhs.increment.1 == rhs.increment.1 && lhs.increment.2 == rhs.increment.2 && lhs.increment.3 == rhs.increment.3 &&
			lhs.timestamp.0 == rhs.timestamp.0 && lhs.timestamp.1 == rhs.timestamp.1 && lhs.timestamp.2 == rhs.timestamp.2 && lhs.timestamp.3 == rhs.timestamp.3
		)
	}
	
}


public struct MongoBinary : Equatable {
	
	public enum BinarySubtype : UInt8 {
		case genericBinary = 0x00
		case function      = 0x01
		case uuid          = 0x04
		case md5           = 0x05
//		case ciphertext    = 0x06 /* Not merged yet in specs */
		
		/* Start of user-defined subtypes (up to 0xFF). */
		case userDefined   = 0x80
		
		case uuidOld       = 0x03
		case binaryOld     = 0x02
	}
	
	public let binaryTypeAsInt: UInt8
	public let data: Data
	
	public init(binaryTypeAsInt bti: UInt8, data d: Data) {
		binaryTypeAsInt = bti
		data = d
	}
	
	public static func ==(lhs: MongoBinary, rhs: MongoBinary) -> Bool {
		return lhs.binaryTypeAsInt == rhs.binaryTypeAsInt && lhs.data == rhs.data
	}
	
	public var binaryType: BinarySubtype? {
		if let t = BinarySubtype(rawValue: binaryTypeAsInt) {return t}
		if binaryTypeAsInt >= BinarySubtype.userDefined.rawValue {return BinarySubtype.userDefined}
		return nil
	}
	
}


public struct MongoObjectId : Equatable {
	
	public let data: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)
	
	public init(data d: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)) {
		data = d
	}
	
	public static func ==(lhs: MongoObjectId, rhs: MongoObjectId) -> Bool {
		return (
			lhs.data.0  == rhs.data.0  && lhs.data.1  == rhs.data.1  && lhs.data.2  == rhs.data.2  && lhs.data.3  == rhs.data.3  &&
			lhs.data.4  == rhs.data.4  && lhs.data.5  == rhs.data.5  && lhs.data.6  == rhs.data.6  && lhs.data.7  == rhs.data.7  &&
			lhs.data.8  == rhs.data.8  && lhs.data.9  == rhs.data.9  && lhs.data.10 == rhs.data.10 && lhs.data.11 == rhs.data.11
		)
	}
	
}


public struct Javascript : Equatable {
	
	public let javascript: String
	
	public init(javascript js: String) {
		javascript = js
	}
	
	public static func ==(lhs: Javascript, rhs: Javascript) -> Bool {
		return lhs.javascript == rhs.javascript
	}
	
}


public struct JavascriptWithScope : Equatable {
	
	public let javascript: String
	public let scope: BSONDoc
	
	public init(javascript js: String, scope s: BSONDoc) {
		javascript = js
		scope = s
	}
	
	public static func ==(lhs: JavascriptWithScope, rhs: JavascriptWithScope) -> Bool {
		return lhs.javascript == rhs.javascript && ((try? areBSONDocEqual(lhs.scope, rhs.scope)) ?? false)
	}
	
}


public struct MinKey : Comparable {
	
	public init() {
	}
	
	public static func ==(lhs: MinKey, rhs: MinKey) -> Bool {return true}
	public static func ==(lhs: MinKey, rhs: Any?) -> Bool {return false}
	public static func ==(lhs: Any?, rhs: MinKey) -> Bool {return false}
	
	public static func <(lhs: MinKey, rhs: MinKey) -> Bool {return false}
	public static func <(lhs: MinKey, rhs: Any?) -> Bool {return true}
	public static func <(lhs: Any?, rhs: MinKey) -> Bool {return false}
	
}


public struct MaxKey : Comparable {
	
	public init() {
	}
	
	public static func ==(lhs: MaxKey, rhs: MaxKey) -> Bool {return true}
	public static func ==(lhs: MaxKey, rhs: Any?) -> Bool {return false}
	public static func ==(lhs: Any?, rhs: MaxKey) -> Bool {return false}
	
	public static func <(lhs: MaxKey, rhs: MaxKey) -> Bool {return false}
	public static func <(lhs: MaxKey, rhs: Any?) -> Bool {return false}
	public static func <(lhs: Any?, rhs: MaxKey) -> Bool {return true}
	
}


public struct MongoDBPointer : Equatable {
	
	public let stringPart: String
	public let bytesPart: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)
	
	public init(stringPart str: String, bytesPartData: Data) {
		assert(bytesPartData.count == 12)
		stringPart = str
		bytesPart = (
			bytesPartData[0],  bytesPartData[1],  bytesPartData[2],  bytesPartData[3],
			bytesPartData[4],  bytesPartData[5],  bytesPartData[6],  bytesPartData[7],
			bytesPartData[8],  bytesPartData[9],  bytesPartData[10], bytesPartData[11]
		)
	}
	
	public static func ==(lhs: MongoDBPointer, rhs: MongoDBPointer) -> Bool {
		return (
			lhs.stringPart == rhs.stringPart &&
			lhs.bytesPart.0  == rhs.bytesPart.0  && lhs.bytesPart.1  == rhs.bytesPart.1  && lhs.bytesPart.2  == rhs.bytesPart.2  && lhs.bytesPart.3  == rhs.bytesPart.3  &&
			lhs.bytesPart.4  == rhs.bytesPart.4  && lhs.bytesPart.5  == rhs.bytesPart.5  && lhs.bytesPart.6  == rhs.bytesPart.6  && lhs.bytesPart.7  == rhs.bytesPart.7  &&
			lhs.bytesPart.8  == rhs.bytesPart.8  && lhs.bytesPart.9  == rhs.bytesPart.9  && lhs.bytesPart.10 == rhs.bytesPart.10 && lhs.bytesPart.11 == rhs.bytesPart.11
		)
	}
	
}


/**
 Check both given BSONDoc for equality.
 Throws if the docs are not valid BSON docs! */
public func areBSONDocEqual(_ doc1: BSONDoc, _ doc2: BSONDoc) throws -> Bool {
	guard doc1.count == doc2.count else {return false}
	for (key, val1) in doc1 {
		guard let val2 = doc2[key] else {return false}
		guard try areBSONEntitiesEqual(val1, val2) else {return false}
	}
	return true
}

private func areBSONEntitiesEqual(_ entity1: Any?, _ entity2: Any?) throws -> Bool {
	let entity1 = BSONSerialization.normalized(BSONEntity: entity1)
	let entity2 = BSONSerialization.normalized(BSONEntity: entity2)
	switch entity1 {
		case nil:             guard entity2          == nil else {return false}
		case let val as Bool: guard entity2 as? Bool == val else {return false}
			
		case let val1 as Int32:
			guard entity2 as? Int32 == val1 else {
				if MemoryLayout<Int>.size == MemoryLayout<Int32>.size, let val2 = entity2 as? Int, val1 == Int32(val2) {return true}
				return false
			}
			
		case let val1 as Int64:
			guard entity2 as? Int64 == val1 else {
				if MemoryLayout<Int>.size == MemoryLayout<Int64>.size, let val2 = entity2 as? Int, val1 == Int64(val2) {return true}
				return false
			}
			
		case let val1 as Int:
			guard entity2 as? Int == val1 else {
				if MemoryLayout<Int>.size == MemoryLayout<Int32>.size, let val2 = entity2 as? Int32, val1 == Int(val2) {return true}
				if MemoryLayout<Int>.size == MemoryLayout<Int64>.size, let val2 = entity2 as? Int64, val1 == Int(val2) {return true}
				return false
			}
			
		case let val as Double:    guard entity2 as? Double    == val else {return false}
		case let val as Double128: guard entity2 as? Double128 == val else {return false}
		case let val as Date:      guard entity2 as? Date      == val else {return false}
		case let str as String:    guard entity2 as? String    == str else {return false}
		case let regexp1 as NSRegularExpression:
			guard let regexp2 = entity2 as? NSRegularExpression else {return false}
			guard regexp1.pattern == regexp2.pattern && regexp1.options == regexp2.options else {return false}
			
		case let subObj1 as BSONDoc:
			guard let subObj2 = entity2 as? BSONDoc else {return false}
			guard try areBSONDocEqual(subObj1, subObj2) else {return false}
			
		case let array1 as [Any?]:
			guard let array2 = entity2 as? [Any?], array1.count == array2.count else {return false}
			for (subval1, subval2) in zip(array1, array2) {
				guard try areBSONEntitiesEqual(subval1, subval2) else {return false}
			}
			
		case let val as MongoTimestamp:      guard entity2 as? MongoTimestamp      == val else {return false}
		case let bin as MongoBinary:         guard entity2 as? MongoBinary         == bin else {return false}
		case let val as MongoObjectId:       guard entity2 as? MongoObjectId       == val else {return false}
		case let js  as Javascript:          guard entity2 as? Javascript          == js  else {return false}
		case let sjs as JavascriptWithScope: guard entity2 as? JavascriptWithScope == sjs else {return false}
			
		case _ as MinKey: guard entity2 is MinKey else {return false}
		case _ as MaxKey: guard entity2 is MaxKey else {return false}
			
		case let dbPointer as MongoDBPointer: guard entity2 as? MongoDBPointer == dbPointer else {return false}
			
		default:
			throw Err.invalidBSONObject(invalidElement: entity1! /* nil case already processed above */)
	}
	
	return true
}
