/*
 * BSONClasses.swift
 * BSONSerialization
 *
 * Created by François Lamboley on 23/12/2016.
 * Copyright © 2016 frizlab. All rights reserved.
 */

import Foundation


struct Double128 : Equatable /*, AbsoluteValuable, BinaryFloatingPoint, ExpressibleByIntegerLiteral, Hashable, LosslessStringConvertible, CustomDebugStringConvertible, CustomStringConvertible, Strideable*/ {
	
	let data: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)
	
	static func ==(lhs: Double128, rhs: Double128) -> Bool {
		return (
			lhs.data.0  == rhs.data.0  && lhs.data.1  == rhs.data.1  && lhs.data.2  == rhs.data.2  && lhs.data.3  == rhs.data.3  &&
			lhs.data.4  == rhs.data.4  && lhs.data.5  == rhs.data.5  && lhs.data.6  == rhs.data.6  && lhs.data.7  == rhs.data.7  &&
			lhs.data.8  == rhs.data.8  && lhs.data.9  == rhs.data.9  && lhs.data.10 == rhs.data.10 && lhs.data.11 == rhs.data.11 &&
			lhs.data.12 == rhs.data.12 && lhs.data.13 == rhs.data.13 && lhs.data.14 == rhs.data.14 && lhs.data.15 == rhs.data.15
		)
	}
	
}


struct MongoTimestamp : Equatable {
	
	let increment: (UInt8, UInt8, UInt8, UInt8)
	let timestamp: (UInt8, UInt8, UInt8, UInt8)
	
	init(incrementData: Data, timestampData: Data) {
		assert(incrementData.count == 4)
		assert(timestampData.count == 4)
		increment = (incrementData[0], incrementData[1], incrementData[2], incrementData[3])
		timestamp = (timestampData[0], timestampData[1], timestampData[2], timestampData[3])
	}
	
	static func ==(lhs: MongoTimestamp, rhs: MongoTimestamp) -> Bool {
		return (
			lhs.increment.0 == rhs.increment.0 && lhs.increment.1 == rhs.increment.1 && lhs.increment.2 == rhs.increment.2 && lhs.increment.3 == rhs.increment.3 &&
			lhs.timestamp.0 == rhs.timestamp.0 && lhs.timestamp.1 == rhs.timestamp.1 && lhs.timestamp.2 == rhs.timestamp.2 && lhs.timestamp.3 == rhs.timestamp.3
		)
	}
	
}


struct MongoBinary : Equatable {
	
	enum BinarySubtype : UInt8 {
		case genericBinary = 0x00
		case function      = 0x01
		case uuid          = 0x04
		case md5           = 0x05
		
		/* Start of user-defined subtypes (up to 0xFF). */
		case userDefined   = 0x80
		
		case uuidOld       = 0x03
		case binaryOld     = 0x02
	}
	
	let binaryTypeAsInt: UInt8
	let data: Data
	
	static func ==(lhs: MongoBinary, rhs: MongoBinary) -> Bool {
		return lhs.binaryTypeAsInt == rhs.binaryTypeAsInt && lhs.data == rhs.data
	}
	
	var binaryType: BinarySubtype? {
		if let t = BinarySubtype(rawValue: binaryTypeAsInt) {return t}
		if binaryTypeAsInt >= BinarySubtype.userDefined.rawValue {return BinarySubtype.userDefined}
		return nil
	}
	
}


struct MongoObjectId : Equatable {
	
	let data: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)
	
	static func ==(lhs: MongoObjectId, rhs: MongoObjectId) -> Bool {
		return (
			lhs.data.0  == rhs.data.0  && lhs.data.1  == rhs.data.1  && lhs.data.2  == rhs.data.2  && lhs.data.3  == rhs.data.3  &&
			lhs.data.4  == rhs.data.4  && lhs.data.5  == rhs.data.5  && lhs.data.6  == rhs.data.6  && lhs.data.7  == rhs.data.7  &&
			lhs.data.8  == rhs.data.8  && lhs.data.9  == rhs.data.9  && lhs.data.10 == rhs.data.10 && lhs.data.11 == rhs.data.11
		)
	}
	
}


struct Javascript : Equatable {
	
	let javascript: String
	
	static func ==(lhs: Javascript, rhs: Javascript) -> Bool {
		return lhs.javascript == rhs.javascript
	}
	
}


struct JavascriptWithScope : Equatable {
	
	let javascript: String
	let scope: BSONDoc
	
	static func ==(lhs: JavascriptWithScope, rhs: JavascriptWithScope) -> Bool {
		return lhs.javascript == rhs.javascript && ((try? areBSONDocEqual(lhs.scope, rhs.scope)) ?? false)
	}
	
}


struct MinKey : Comparable {
	
	static func ==(lhs: MinKey, rhs: MinKey) -> Bool {return true}
	static func ==(lhs: MinKey, rhs: Any?) -> Bool {return false}
	static func ==(lhs: Any?, rhs: MinKey) -> Bool {return false}
	
	static func <(lhs: MinKey, rhs: MinKey) -> Bool {return false}
	static func <(lhs: MinKey, rhs: Any?) -> Bool {return true}
	static func <(lhs: Any?, rhs: MinKey) -> Bool {return false}
	
}


struct MaxKey : Comparable {
	
	static func ==(lhs: MaxKey, rhs: MaxKey) -> Bool {return true}
	static func ==(lhs: MaxKey, rhs: Any?) -> Bool {return false}
	static func ==(lhs: Any?, rhs: MaxKey) -> Bool {return false}
	
	static func <(lhs: MaxKey, rhs: MaxKey) -> Bool {return false}
	static func <(lhs: MaxKey, rhs: Any?) -> Bool {return false}
	static func <(lhs: Any?, rhs: MaxKey) -> Bool {return true}
	
}


struct MongoDBPointer : Equatable {
	
	let stringPart: String
	let bytesPart: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)
	
	init(stringPart str: String, bytesPartData: Data) {
		assert(bytesPartData.count == 12)
		stringPart = str
		bytesPart = (
			bytesPartData[0],  bytesPartData[1],  bytesPartData[2],  bytesPartData[3],
			bytesPartData[4],  bytesPartData[5],  bytesPartData[6],  bytesPartData[7],
			bytesPartData[8],  bytesPartData[9],  bytesPartData[10], bytesPartData[11]
		)
	}
	
	static func ==(lhs: MongoDBPointer, rhs: MongoDBPointer) -> Bool {
		return (
			lhs.stringPart == rhs.stringPart &&
			lhs.bytesPart.0  == rhs.bytesPart.0  && lhs.bytesPart.1  == rhs.bytesPart.1  && lhs.bytesPart.2  == rhs.bytesPart.2  && lhs.bytesPart.3  == rhs.bytesPart.3  &&
			lhs.bytesPart.4  == rhs.bytesPart.4  && lhs.bytesPart.5  == rhs.bytesPart.5  && lhs.bytesPart.6  == rhs.bytesPart.6  && lhs.bytesPart.7  == rhs.bytesPart.7  &&
			lhs.bytesPart.8  == rhs.bytesPart.8  && lhs.bytesPart.9  == rhs.bytesPart.9  && lhs.bytesPart.10 == rhs.bytesPart.10 && lhs.bytesPart.11 == rhs.bytesPart.11
		)
	}
	
}


/** Check both given BSONDoc for equality. Throws if the docs are not valid BSON
docs! */
func areBSONDocEqual(_ doc1: BSONDoc, _ doc2: BSONDoc) throws -> Bool {
	/* TODO: Faster implementation of this... */
	let data1 = try BSONSerialization.data(withBSONObject: doc1, options: .skipSizes)
	let data2 = try BSONSerialization.data(withBSONObject: doc2, options: .skipSizes)
	return data1 == data2
}
