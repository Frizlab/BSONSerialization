/*
 * BSONSerialization.swift
 * BSONSerialization
 *
 * Created by François Lamboley on 1/17/16.
 * Copyright © 2016 frizlab. All rights reserved.
 */

import Foundation



typealias BSONDoc = [String: Any?]

struct BSONReadingOptions : OptionSet {
	let rawValue: Int
	/* Empty. We just create the enum in case we want to add something to it later. */
}


struct BSONWritingOptions : OptionSet {
	let rawValue: Int
	
	static let skipSizes = BSONWritingOptions(rawValue: 1 << 0)
}


class BSONSerialization {
	
	struct Double128/* : AbsoluteValuable, BinaryFloatingPoint, ExpressibleByIntegerLiteral, Hashable, LosslessStringConvertible, CustomDebugStringConvertible, CustomStringConvertible, Strideable*/ {
		
		let data: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)
		
	}
	
	struct MongoTimestamp {
		
		let increment: (UInt8, UInt8, UInt8, UInt8)
		let timestamp: (UInt8, UInt8, UInt8, UInt8)
		
		init(incrementData: Data, timestampData: Data) {
			assert(incrementData.count == 4)
			assert(timestampData.count == 4)
			increment = (incrementData[0], incrementData[1], incrementData[2], incrementData[3])
			timestamp = (timestampData[0], timestampData[1], timestampData[2], timestampData[3])
		}
		
	}
	
	struct MongoBinary {
		
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
		
		var binaryType: BinarySubtype? {
			if let t = BinarySubtype(rawValue: binaryTypeAsInt) {return t}
			if binaryTypeAsInt >= BinarySubtype.userDefined.rawValue {return BinarySubtype.userDefined}
			return nil
		}
		
	}
	
	struct MongoObjectId {
		
		let data: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)
		
	}
	
	struct Javascript {
		
		let javascript: String
		
	}
	
	struct JavascriptWithScope {
		
		let javascript: String
		let scope: BSONDoc
		
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
	
	struct MongoDBPointer {
		
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
		
	}
	
	/** The BSON Serialization errors enum. */
	enum BSONSerializationError : Error {
		/** The given data/stream contains too few bytes to be a valid bson doc. */
		case dataTooSmall
		/** The given data size is not the one declared by the bson doc. */
		case dataLengthDoNotMatch
		
		/** The stream ended before the end of the bson doc was reached. */
		case earlyStreamEnding
		
		/** The length of the bson doc is invalid. */
		case invalidLength
		/** An invalid element was found. The element is given in argument to this
		enum case. */
		case invalidElementType(UInt8)
		
		/** Found an invalid bool value (given in arg). */
		case invalidBooleanValue(UInt8)
		
		/** Asked to read an invalid string for the required encoding. The
		original data that has been tried to be parsed is given in arg of this
		error. */
		case invalidString(Data)
		/** Invalid end of BSON string found. Expected NULL (0), but found the
		bytes given in argument to this enum case (if nil, no data can be read
		after the string). */
		case invalidEndOfString(UInt8?)
		
		/**
		An invalid key was found in an array: Keys must be integers, sorted in
		ascending order from 0 to n-1 (where n = number of elements in the array).
		
		- Note: Not so sure the increments from one element to the next should
		necessarily be of one… The doc is pretty vague on the subject. It says:
		“[…] with integer values for the keys, starting with 0 and continuing
		sequentially. […] The keys must be in ascending numerical order.” */
		case invalidArrayKey(currentKey: String, previousKey: String?)
		
		/** Found an invalid regular expression options value (the complete
		options and the faulty character are given in arg). */
		case invalidRegularExpressionOptions(options: String, invalidCharacter: Character)
		/** Found an invalid regular expression value (the regular expression and
		the parsing error are given in arg). */
		case invalidRegularExpression(pattern: String, error: Error)
		
		/** The JS with scope element gives the raw data length in its definition.
		If the given length does not match the decoded length, this error is
		thrown. The expected and actual length are given in the error. */
		case invalidJSWithScopeLength(expected: Int, actual: Int)
		
		/** An error occurred writing the stream. */
		case cannotWriteToStream(streamError: Error?)
		
		/** An invalid BSON object was given to be serialized. The invalid element
		is passed in argument to this error. */
		case invalidBSONObject(invalidElement: Any)
		/** One of the key cannot be serialized in an unambiguous way. Said key is
		given in arg of the error. */
		case unserializableKey(String)
		
		/** Cannot allocate memory (either with `malloc` or `UnsafePointer.alloc()`). */
		case cannotAllocateMemory(Int)
		/** An internal error occurred rendering the serialization impossible. */
		case internalError
	}
	
	/** The recognized BSON element types. */
	private enum BSONElementType : UInt8 {
		/** The end of the document. Parsing ends when this element is found. */
		case endOfDocument       = 0x00
		
		/** `nil` */
		case null                = 0x0A
		/** `Bool`. Raw value is a single byte, containing `'\0'` (`false`) or
		`'\1'` (`true`). */
		case boolean             = 0x08
		/** `Int32`. 4 bytes (32-bit signed integer, two’s complement). */
		case int32Bits           = 0x10
		/** `Int64`. 8 bytes (64-bit signed integer, two’s complement). */
		case int64Bits           = 0x12
		/** `Double`. 8 bytes (64-bit IEEE 754-2008 binary floating point). */
		case double64Bits        = 0x01
		/** `.Double128`. 16 bytes (128-bit IEEE 754-2008 decimal floating point).
		Currently Double128 is a struct containing a Data of length 16 bytes. */
		case double128Bits       = 0x13
		/** `Date`. Raw value is the number of milliseconds since the Epoch in UTC
		in an Int64. */
		case utcDateTime         = 0x09
		/** `NSRegularExpression`. Raw value is two cstring: Regexp pattern first,
		then regexp options. */
		case regularExpression   = 0x0B
		
		/** `String`. Raw value is an Int32 representing the length of the string
		+ 1, then the actual bytes of the string, then a single 0 byte. */
		case utf8String          = 0x02
		
		/** `BSONDoc`. Raw value is an embedded BSON document */
		case dictionary          = 0x03
		/** `[Any?]`. Raw value is an embedded BSON document; keys are "0", "1",
		etc. and must be ordered in numerical order. */
		case array               = 0x04
		
		/** `.MongoTimestamp`. Special internal type used by MongoDB replication
		and sharding. First 4 bytes are an increment, second 4 are a timestamp. */
		case timestamp           = 0x11
		/** `.MongoBinary`. Raw value is an Int32, followed by a subtype (1 byte)
		then the actual bytes. */
		case binary              = 0x05
		/** `.MongoObjectId`. 12 bytes, used by MongoDB. */
		case objectId            = 0x07
		/** `Javascript`. (Basically a container for a `String`.) */
		case javascript          = 0x0D
		/**
		`.JavascriptWithScope`. Raw value is an Int32 representing the length of
		the whole raw value, then a string, then an embedded BSON doc.
		
		The document is a mapping from identifiers to values, representing the
		scope in which the string should be evaluated.*/
		case javascriptWithScope = 0x0F
		
		/** `.MinKey` Special type which compares lower than all other possible
		BSON element values. */
		case minKey              = 0xFF
		/** `.MaxKey` Special type which compares higher than all other possible
		BSON element values. */
		case maxKey              = 0x7F
		
		/** `nil`. Undefined value. Deprecated. */
		case undefined           = 0x06
		/** `.MongoDBPointer`. Deprecated. Raw value is a string followed by 12
		bytes. */
		case dbPointer           = 0x0C
		/** Value is `String`. Deprecated. */
		case symbol              = 0x0E
	}
	
	/**
	Serialize the given data into a dictionary with String keys, object values.
	
	- Parameter data: The data to parse. Must be exactly an entire BSON doc.
	- Parameter options: Some options to customize the parsing. See `BSONReadingOptions`.
	- Throws: `BSONSerializationError` in case of error.
	- Returns: The serialized BSON data.
	*/
	class func BSONObject(data: Data, options opt: BSONReadingOptions) throws -> BSONDoc {
		let bufferedData = BufferedData(data: data)
		return try BSONObject(bufferStream: bufferedData, options: opt)
	}
	
	/**
	Serialize the given stream into a dictionary with String keys, object values.
	
	Exactly the size of the BSON document will be read from the stream. If an
	error occurs while reading the BSON document, you are guaranteed that less
	than the size of the BSON doc is read. If the size of the BSON declared in
	the stream is invalid, the read bytes count is undetermined.
	
	- Parameter stream: The stream to parse. Must already be opened and configured.
	- Parameter options: Some options to customize the parsing. See `BSONReadingOptions`.
	- Throws: `BSONSerializationError` in case of error.
	- Returns: The serialized BSON data.
	*/
	class func BSONObject(stream: InputStream, options opt: BSONReadingOptions) throws -> BSONDoc {
		let bufferedInputStream = BufferedInputStream(stream: stream, bufferSize: 1024*1024, streamReadSizeLimit: nil)
		return try BSONObject(bufferStream: bufferedInputStream, options: opt)
	}
	
	/* Note: Whenever we can, I'd like to have a non-escaping optional closure... */
	class func BSONObject(bufferStream: BufferStream, options opt: BSONReadingOptions, initialReadPosition: Int = 0, decodeCallback: (_ key: String, _ val: Any?) throws -> Void = {_,_ in}) throws -> BSONDoc {
		precondition(MemoryLayout<Int32>.size <= MemoryLayout<Int>.size, "I currently need Int32 to be lower or equal in size than Int")
		precondition(MemoryLayout<Double>.size == 8, "I currently need Double to be 64 bits")
		
		/* TODO: Handle endianness! */
		
		let length32: Int32 = try bufferStream.readType()
		guard length32 >= 5 else {throw BSONSerializationError.dataTooSmall}
		
		let length = Int(length32)
		let previousStreamReadSizeLimit: Int?
		if let bufferedInputStream = bufferStream as? BufferedInputStream {previousStreamReadSizeLimit = bufferedInputStream.streamReadSizeLimit; bufferedInputStream.streamReadSizeLimit = initialReadPosition + length}
		else                                                              {previousStreamReadSizeLimit = nil}
		defer {if let bufferedInputStream = bufferStream as? BufferedInputStream {bufferedInputStream.streamReadSizeLimit = previousStreamReadSizeLimit}}
		
		var ret = [String: Any]()
		
		var isAtEnd = false
		while !isAtEnd {
			guard bufferStream.currentReadPosition - initialReadPosition <= length else {throw BSONSerializationError.invalidLength}
			
			let currentElementType: UInt8 = try bufferStream.readType()
			guard currentElementType != BSONElementType.endOfDocument.rawValue else {
				isAtEnd = true
				break
			}
			
			let key = try bufferStream.readCString(encoding: .utf8)
			switch BSONElementType(rawValue: currentElementType) {
			case .null?:
				try decodeCallback(key, nil)
				ret[key] = nil
				
			case .boolean?:
				let valAsInt8 = try bufferStream.readData(size: 1, alwaysCopyBytes: false).first!
				switch valAsInt8 {
				case 1: try decodeCallback(key, true);  ret[key] = true
				case 0: try decodeCallback(key, false); ret[key] = false
				default: throw BSONSerializationError.invalidBooleanValue(valAsInt8)
				}
				
			case .int32Bits?:
				let val: Int32 = try bufferStream.readType()
				try decodeCallback(key, val)
				ret[key] = val
				
			case .int64Bits?:
				let val: Int64 = try bufferStream.readType()
				try decodeCallback(key, val)
				ret[key] = val
				
			case .double64Bits?:
				let val: Double = try bufferStream.readType()
				try decodeCallback(key, val)
				ret[key] = val
				
			case .double128Bits?:
				/* Note: We assume Swift will **always** represent tuples the way it
				 *       currently does and struct won't have any padding... */
				let val: Double128 = try bufferStream.readType()
				try decodeCallback(key, val)
				ret[key] = val
				
			case .utcDateTime?:
				let timestamp: Int64 = try bufferStream.readType()
				let val = Date(timeIntervalSince1970: TimeInterval(timestamp))
				try decodeCallback(key, val)
				ret[key] = val
				
			case .regularExpression?:
				let pattern = try bufferStream.readCString(encoding: .utf8)
				let options = try bufferStream.readCString(encoding: .utf8)
				var foundationOptions: NSRegularExpression.Options = [.anchorsMatchLines]
				for c in options.characters {
					switch c {
					case "i": foundationOptions.insert(.caseInsensitive) /* Case insensitive matching */
					case "m": foundationOptions.remove(.anchorsMatchLines) /* Multiline matching. Not sure if what we've set corresponds exactly to the MongoDB implementation's... */
					case "x": (/* Verbose Mode. (Unsupported...) */)
					case "l": (/* Make \w, \W, etc. locale dependent. (Unsupported, or most likely default unremovable behaviour...) */)
					case "s": foundationOptions.insert(.dotMatchesLineSeparators) /* Dotall mode ('.' matches everything). Not sure if this option is enough */
					case "u": foundationOptions.insert(.useUnicodeWordBoundaries) /* Make \w, \W, etc. match unicode */
					default: throw BSONSerializationError.invalidRegularExpressionOptions(options: options, invalidCharacter: c)
					}
				}
				do    {let val = try NSRegularExpression(pattern: pattern, options: foundationOptions); try decodeCallback(key, val); ret[key] = val}
				catch {throw BSONSerializationError.invalidRegularExpression(pattern: pattern, error: error)}
				
			case .utf8String?:
				let val = try bufferStream.readBSONString(encoding: .utf8)
				try decodeCallback(key, val)
				ret[key] = val
				
			case .dictionary?:
				let val = try BSONObject(bufferStream: bufferStream, options: opt, initialReadPosition: bufferStream.currentReadPosition)
				try decodeCallback(key, val)
				ret[key] = val
				
			case .array?:
				var val = [Any?]()
				var prevKey: String? = nil
				_ = try BSONObject(bufferStream: bufferStream, options: opt, initialReadPosition: bufferStream.currentReadPosition, decodeCallback: { subkey, subval in
					guard String(val.count) == subkey else {throw BSONSerializationError.invalidArrayKey(currentKey: subkey, previousKey: prevKey)}
					val.append(subval)
					prevKey = subkey
				})
				try decodeCallback(key, val)
				ret[key] = val
				
			case .timestamp?:
				let increment = try bufferStream.readData(size: 4, alwaysCopyBytes: true)
				let timestamp = try bufferStream.readData(size: 4, alwaysCopyBytes: true)
				let val = MongoTimestamp(incrementData: increment, timestampData: timestamp)
				try decodeCallback(key, val)
				ret[key] = val
				
			case .binary?:
				let size: Int32 = try bufferStream.readType()
				let subtypeInt: UInt8 = try bufferStream.readType()
				let data = try bufferStream.readData(size: Int(size), alwaysCopyBytes: true)
				let val = MongoBinary(binaryTypeAsInt: subtypeInt, data: data)
				try decodeCallback(key, val)
				ret[key] = val
				
			case .objectId?:
				/* Note: We assume Swift will **always** represent tuples the way it
				 *       currently does and struct won't have any padding... */
				let val: MongoObjectId = try bufferStream.readType()
				try decodeCallback(key, val)
				ret[key] = val
				
			case .javascript?:
				let val = Javascript(javascript: try bufferStream.readBSONString(encoding: .utf8))
				try decodeCallback(key, val)
				ret[key] = val
				
			case .javascriptWithScope?:
				let valStartPosition = bufferStream.currentReadPosition
				
				let valSize: Int32 = try bufferStream.readType()
				let jsCode = try bufferStream.readBSONString(encoding: .utf8)
				let scope = try BSONSerialization.BSONObject(bufferStream: bufferStream, options: opt, initialReadPosition: bufferStream.currentReadPosition)
				guard bufferStream.currentReadPosition - valStartPosition == Int(valSize) else {throw BSONSerializationError.invalidJSWithScopeLength(expected: Int(valSize), actual: bufferStream.currentReadPosition - valStartPosition)}
				let val = JavascriptWithScope(javascript: jsCode, scope: scope)
				try decodeCallback(key, val)
				ret[key] = val
				
			case .minKey?:
				let val = MinKey()
				try decodeCallback(key, val)
				ret[key] = val
				
			case .maxKey?:
				let val = MaxKey()
				try decodeCallback(key, val)
				ret[key] = val
				
			case .undefined?:
				try decodeCallback(key, nil)
				ret[key] = nil
				
			case .dbPointer?:
				let stringPart = try bufferStream.readBSONString(encoding: .utf8)
				let bytesPartData = try bufferStream.readData(size: 12, alwaysCopyBytes: true)
				let val = MongoDBPointer(stringPart: stringPart, bytesPartData: bytesPartData)
				try decodeCallback(key, val)
				ret[key] = val
				
			case .symbol?:
				let val = try bufferStream.readBSONString(encoding: .utf8)
				try decodeCallback(key, val)
				ret[key] = val
				
			case nil: throw BSONSerializationError.invalidElementType(currentElementType)
			case .endOfDocument?: fatalError() /* Guarded before the switch */
			}
		}
		guard bufferStream.currentReadPosition - initialReadPosition == length else {throw BSONSerializationError.invalidLength}
		return ret
	}
	
	class func data(withBSONObject BSONObject: BSONDoc, options opt: BSONWritingOptions) throws -> Data {
		guard let stream = CFWriteStreamCreateWithAllocatedBuffers(kCFAllocatorDefault, kCFAllocatorDefault) else {
			throw BSONSerializationError.internalError
		}
		guard CFWriteStreamOpen(stream) else {
			throw BSONSerializationError.internalError
		}
		defer {CFWriteStreamClose(stream)}
		
		var sizes = [Int: Int32]()
		_ = try write(BSONObject: BSONObject, toStream: stream, options: opt.union([.skipSizes]), sizeFoundCallback: { offset, size in
			assert(sizes[offset] == nil)
			sizes[offset] = size
		})
		
		guard var data = CFWriteStreamCopyProperty(stream, .dataWritten) as AnyObject as? Data else {
			throw BSONSerializationError.internalError
		}
		
		if !opt.contains(.skipSizes) {
			data.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<UInt8>) -> Void in
				for (offset, size) in sizes {
					unsafeBitCast(bytes.advanced(by: offset), to: UnsafeMutablePointer<Int32>.self).pointee = size
				}
			}
		}
		
		return data
	}
	
	/** Write BSON object to a write stream.
	
	- Parameter sizeFoundCallback: Only called when options contain `.skipSizes`.
	- Returns: The number of bytes written. */
	class func write(BSONObject: BSONDoc, toStream stream: OutputStream, options opt: BSONWritingOptions, initialWritePosition: Int = 0, sizeFoundCallback: (_ offset: Int, _ size: Int32) -> Void = {_,_ in}) throws -> Int {
		let skipSizes = opt.contains(.skipSizes)
		
		var zero: Int8 = 0
		
		var sizes: [Int]?
		var docSize: Int32
		var currentRelativeWritePosition = 0
		
		if skipSizes {sizes = nil;                               docSize = 0}
		else         {sizes = try sizesOfBSONObject(BSONObject); docSize = Int32(sizes!.popLast()!/* If nil, this is an internal error */)}
		
		/* Writing doc size to the doc (if size is skipped, set to 0) */
		currentRelativeWritePosition += try write(value: &docSize, toStream: stream)
		
		/* Writing key values to the doc */
		for (key, val) in BSONObject {
			currentRelativeWritePosition += try write(BSONEntity: val, withKey: key, toStream: stream, options: opt, initialWritePosition: currentRelativeWritePosition, sizes: &sizes, sizeFoundCallback: sizeFoundCallback)
		}
		
		/* Writing final 0 */
		currentRelativeWritePosition += try write(value: &zero, toStream: stream)
		
		/* If skipping sizes, we have to call the callback for size found (the doc
		 * is written entirely, we now know its size! */
		if skipSizes {sizeFoundCallback(initialWritePosition, Int32(currentRelativeWritePosition - initialWritePosition))}
		
		/* The current write position is indeed the number of bytes written... */
		return currentRelativeWritePosition
	}
	
	class func sizesOfBSONObject(_ obj: BSONDoc) throws -> [Int] {
		precondition(MemoryLayout<Double>.size == 8, "I currently need Double to be 64 bits")
		precondition(MemoryLayout<Int>.size <= MemoryLayout<Int64>.size, "I currently need Int to be lower or equal in size than Int64")
		
		var curSize = 4 /* Size of the BSON Doc */
		var sizes = [Int]()
		for (key, val) in obj {
			let sizesInfo = try sizesForBSONEntity(val, withKey: key)
			sizes.insert(contentsOf: sizesInfo.1, at: 0)
			curSize += sizesInfo.0
		}
		curSize += 1 /* The zero-terminator for BSON docs */
		sizes.append(curSize)
		return sizes
	}
	
	class func isValidBSONObject(_ obj: BSONDoc) -> Bool {
		return (try? sizesOfBSONObject(obj)) != nil
	}
	
	private class func sizesForBSONEntity(_ entity: Any?, withKey key: String) throws -> (Int /* Size for whole entity with key */, [Int] /* Subsizes (often empty) */) {
		var subSizes = [Int]()
		
		var size = 1 /* Type of the element */
		size += key.utf8.count + 1 /* Size of the encoded key */
		
		switch entity {
		case nil: (/*nop; this value does not have anything to write*/)
		case _ as Bool:                        size += 1
		case _ as Int32, _ as Int64, _ as Int: size += MemoryLayout.size(ofValue: entity!)
		case _ as Double:                      size += 8  /* 64  bits is 8  bytes */
		case _ as Double128:                   size += 16 /* 128 bits is 16 bytes */
		case _ as Date:                        size += 8  /* Encoded as an Int64 */
			
		case _ as NSRegularExpression: fatalError("Not Implemented (TODO)")
			
		case let str as String: size += sizeOfBSONEncodedString(str)
			
		case let subObj as BSONDoc:
			let s = try sizesOfBSONObject(subObj)
			size += s.last!
			subSizes = s
			
		case let array as [Any?]:
			var arraySize = 4 /* The size of the BSON doc (an array is a BSON doc) */
			for (i, elt) in array.enumerated().reversed() {
				let sizesInfo = try sizesForBSONEntity(elt, withKey: String(i))
				subSizes.append(contentsOf: sizesInfo.1)
				arraySize += sizesInfo.0
			}
			arraySize += 1 /* The zero terminator for a BSON doc */
			subSizes.append(arraySize)
			size += arraySize
			
		case     _   as MongoTimestamp: size += 8
		case let bin as MongoBinary:    size += 4 /* Size of the data */ + 1 /* Binary subtype */ + bin.data.count
		case     _   as MongoObjectId:  size += 12
		case let js  as Javascript:     size += sizeOfBSONEncodedString(js.javascript)
			
		case let sjs as JavascriptWithScope:
			var jsWithScopeSize = 4 /* Size of the whole jsWithScope entry */
			jsWithScopeSize += sizeOfBSONEncodedString(sjs.javascript)
			let s = try sizesOfBSONObject(sjs.scope)
			jsWithScopeSize += s.last!
			size += jsWithScopeSize
			
			subSizes = s
			subSizes.append(jsWithScopeSize)
			
		case _ as MinKey: (/*nop; this value does not have anything to write*/)
		case _ as MaxKey: (/*nop; this value does not have anything to write*/)
			
		case let dbPointer as MongoDBPointer:
			size += sizeOfBSONEncodedString(dbPointer.stringPart)
			size += 12
			
		default:
			throw BSONSerializationError.invalidBSONObject(invalidElement: entity! /* nil case already processed above */)
		}
		
		return (size, subSizes)
	}
	
	private class func sizeOfBSONEncodedString(_ str: String) -> Int {
		return 4 /* length of the string is represented as an Int32 */ + str.utf8.count + 1 /* The '\0' terminator */
	}
	
	/** Writes the given entity to the stream.
	
	- Note: The .skipSizes option is ignored (determined by whether the sizes
	argument is `nil`.
	
	- Note: When possible, `sizeFoundCallback` should be optional (cannot be a
	non-escaped closure in current Swift state). */
	private class func write(BSONEntity entity: Any?, withKey key: String, toStream stream: OutputStream, options opt: BSONWritingOptions, initialWritePosition: Int = 0, sizes: inout [Int]?, sizeFoundCallback: (_ offset: Int, _ size: Int32) -> Void = {_,_ in}) throws -> Int {
		precondition(MemoryLayout<Double>.size == 8, "I currently need Double to be 64 bits")
		
		var size = 0
		
		switch entity {
		case nil:
			size += try write(elementType: .null, toStream: stream)
			size += try write(CEncodedString: key, toStream: stream)
			
		case let val as Bool:
			size += try write(elementType: .boolean, toStream: stream)
			size += try write(CEncodedString: key, toStream: stream)
			
			var bsonVal = Int8(val ? 1 : 0)
			size += try write(value: &bsonVal, toStream: stream)
			
		case var val as Int32:
			size += try write(elementType: .int32Bits, toStream: stream)
			size += try write(CEncodedString: key, toStream: stream)
			size += try write(value: &val, toStream: stream)
			
		case var val as Int64:
			size += try write(elementType: .int64Bits, toStream: stream)
			size += try write(CEncodedString: key, toStream: stream)
			size += try write(value: &val, toStream: stream)
			
		case var val as Int where MemoryLayout<Int>.size == MemoryLayout<Int64>.size:
			size += try write(elementType: .int64Bits, toStream: stream)
			size += try write(CEncodedString: key, toStream: stream)
			size += try write(value: &val, toStream: stream)
			
		case var val as Int where MemoryLayout<Int>.size == MemoryLayout<Int32>.size:
			size += try write(elementType: .int32Bits, toStream: stream)
			size += try write(CEncodedString: key, toStream: stream)
			size += try write(value: &val, toStream: stream)
			
		case var val as Double:
			size += try write(elementType: .double64Bits, toStream: stream)
			size += try write(CEncodedString: key, toStream: stream)
			size += try write(value: &val, toStream: stream)
			
		case var val as Double128:
			size += try write(elementType: .double128Bits, toStream: stream)
			size += try write(CEncodedString: key, toStream: stream)
			size += try write(value: &val, toStream: stream)
			
		case let val as Date:
			size += try write(elementType: .utcDateTime, toStream: stream)
			size += try write(CEncodedString: key, toStream: stream)
			
			var timestamp = Int64(val.timeIntervalSince1970)
			size += try write(value: &timestamp, toStream: stream)
			
//		case _ as NSRegularExpression: fatalError("Not Implemented (TODO)")
			
		case let str as String:
			size += try write(elementType: .utf8String, toStream: stream)
			size += try write(CEncodedString: key, toStream: stream)
			size += try write(BSONEncodedString: str, toStream: stream)
			
//		case let subObj as BSONDoc:
//			guard let s = sizesOfBSONObject(subObj), let subObjSize = s.first else {return nil}
//			size += subObjSize
//			subSizes = s

//		case let array as [Any?]:
//			var arraySize = 4 /* The size of the BSON doc (an array is a BSON doc) */
//			for (i, elt) in array.enumerated() {
//				guard let sizesInfo = sizesForBSONEntity(elt, withKey: String(i)) else {return nil}
//				subSizes.append(contentsOf: sizesInfo.1)
//				arraySize += sizesInfo.0
//			}
//			arraySize += 1 /* The zero terminator for a BSON doc */
//			subSizes.insert(arraySize, at: 0)
//			size += arraySize
//			
//		case     _   as MongoTimestamp: size += 8
//		case let bin as MongoBinary:    size += 4 /* Size of the data */ + 1 /* Binary subtype */ + bin.data.count
//		case     _   as MongoObjectId:  size += 12
			
		case let js as Javascript:
			size += try write(elementType: .javascript, toStream: stream)
			size += try write(CEncodedString: key, toStream: stream)
			size += try write(BSONEncodedString: js.javascript, toStream: stream)
			
//		case let sjs as JavascriptWithScope:
//			var jsWithScopeSize = 4 /* Size of the whole jsWithScope entry */
//			jsWithScopeSize += sizeOfBSONEncodedString(sjs.javascript)
//			guard let s = sizesOfBSONObject(sjs.scope), let subObjSize = s.first else {return nil}
//			jsWithScopeSize += subObjSize
//			size += jsWithScopeSize
//			
//			subSizes = s
//			subSizes.insert(jsWithScopeSize, at: 0)
			
		case _ as MinKey:
			size += try write(elementType: .minKey, toStream: stream)
			size += try write(CEncodedString: key, toStream: stream)
			
		case _ as MaxKey:
			size += try write(elementType: .maxKey, toStream: stream)
			size += try write(CEncodedString: key, toStream: stream)
			
//		case let dbPointer as MongoDBPointer:
//			size += sizeOfBSONEncodedString(dbPointer.stringPart)
//			size += 12
			
		default:
			throw BSONSerializationError.invalidBSONObject(invalidElement: entity! /* nil case already processed above */)
		}
		
		return size
	}
	
	private class func write(CEncodedString str: String, toStream stream: OutputStream) throws -> Int {
		var written = 0
		
		/* Let's get the UTF8 bytes of the string. */
		let bytes = [UInt8](str.utf8)
		guard !bytes.contains(0) else {throw BSONSerializationError.unserializableKey(str)}
		
		let curWrite = bytes.withUnsafeBufferPointer { p -> Int in return stream.write(p.baseAddress!, maxLength: bytes.count) }
		guard curWrite == bytes.count else {throw BSONSerializationError.cannotWriteToStream(streamError: stream.streamError)}
		written += curWrite
		
		var zero: Int8 = 0
		written += try write(value: &zero, toStream: stream)
		
		return written
	}
	
	private class func write(BSONEncodedString str: String, toStream stream: OutputStream) throws -> Int {
		var written = 0
		var strLength: Int32 = str.utf8.count + 1 /* The zero */
		
		/* Let's write the size of the string to the stream */
		written += try write(value: &strLength, toStream: stream)
		
		/* Let's get the UTF8 bytes of the string. */
		let bytes = [UInt8](str.utf8)
		let curWrite = bytes.withUnsafeBufferPointer { p -> Int in return stream.write(p.baseAddress!, maxLength: bytes.count) }
		guard curWrite == bytes.count else {throw BSONSerializationError.cannotWriteToStream(streamError: stream.streamError)}
		written += curWrite
		
		var zero: Int8 = 0
		written += try write(value: &zero, toStream: stream)
		
		return written
	}
	
	private class func write<T>(value: inout T, toStream stream: OutputStream) throws -> Int {
		return try withUnsafePointer(to: &value) { pointer -> Int in
			let size = MemoryLayout<T>.size
			let writtenSize = stream.write(unsafeBitCast(pointer, to: UnsafePointer<UInt8>.self), maxLength: size)
			guard size == writtenSize else {throw BSONSerializationError.cannotWriteToStream(streamError: stream.streamError)}
			return size
		}
	}
	
	private class func write(elementType: BSONElementType, toStream stream: OutputStream) throws -> Int {
		var t = elementType.rawValue
		return try write(value: &t, toStream: stream)
	}
	
}



private extension BufferStream {
	
	func readCString(encoding: String.Encoding) throws -> String {
		let data = try readData(upToDelimiters: [Data(bytes: [0])], matchingMode: .anyMatchWins, includeDelimiter: false, alwaysCopyBytes: false)
		_ = try readData(size: 1, alwaysCopyBytes: false)
		
		/* This String init fails if the data is invalid for the given encoding. */
		guard let str = String(data: data, encoding: encoding) else {
			/* MUST copy the data as the original bytes are not owned by us. */
			let dataCopy = Data(bytes: Array(data))
			throw BSONSerialization.BSONSerializationError.invalidString(dataCopy)
		}
		
		return str
	}
	
	func readBSONString(encoding: String.Encoding) throws -> String {
		/* Reading the string size. */
		let stringSize: Int32 = try readType()
		
		/* Reading the actual string. */
		let data = try readData(size: Int(stringSize)-1, alwaysCopyBytes: false)
		assert(data.count == stringSize-1)
		guard let str = String(data: data, encoding: encoding) else {
			/* MUST copy the data as the original bytes are not owned by us. */
			let dataCopy = Data(bytes: Array(data))
			throw BSONSerialization.BSONSerializationError.invalidString(dataCopy)
		}
		
		/* Reading the last byte and checking it is indeed 0. */
		let null = try readData(size: 1, alwaysCopyBytes: false)
		assert(null.count == 1)
		guard null.first == 0 else {throw BSONSerialization.BSONSerializationError.invalidEndOfString(null.first)}
		
		return str
	}
	
}
