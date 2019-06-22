/*
 * BSONSerialization.swift
 * BSONSerialization
 *
 * Created by François Lamboley on 1/17/16.
 * Copyright © 2016 frizlab. All rights reserved.
 */

import Foundation
import SimpleStream



public typealias BSONDoc = [String: Any?]


final public class BSONSerialization {
	
	public struct ReadingOptions : OptionSet {
		
		public let rawValue: Int
		/* Empty. We just create the enum in case we want to add something to it later. */
		
		public init(rawValue v: Int) {
			rawValue = v
		}
		
	}
	
	public struct WritingOptions : OptionSet {
		
		public let rawValue: Int
		
		/** Set all sizes to 0 in generated BSON. Mainly useful internally for
		optimization purposes. */
		public static let skipSizes = WritingOptions(rawValue: 1 << 0)
		
		public init(rawValue v: Int) {
			rawValue = v
		}
		
	}
	
	/** The BSON Serialization errors enum. */
	public enum BSONSerializationError : Error {
		/** The given data/stream contains too few bytes to be a valid bson doc. */
		case dataTooSmall
		/** The given data size is not the one declared by the bson doc. */
		case dataLengthDoNotMatch
		
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
		/**
		Tried to serialize an unserializable string (using the C
		representation). This is due to the fact that the '\0' char can be used in
		a valid UTF8 string. (Note: the characters '\254' and '\255' can NEVER be
		used in a valid UTF8 string. Why were they not the separator?)
		
		Usually, the BSON strings represented using the C representation are
		dictionary keys. But they can also be the components of a regexp. */
		case unserializableCString(String)
		
		/** Cannot allocate memory (either with `malloc` or `UnsafePointer.alloc()`). */
		case cannotAllocateMemory(Int)
		/** An internal error occurred rendering the serialization impossible. */
		case internalError
	}
	
	/**
	Serialize the given data into a dictionary with String keys, object values.
	
	- Parameter data: The data to parse. Must be exactly an entire BSON doc.
	- Parameter options: Some options to customize the parsing. See
	`ReadingOptions`.
	- Throws: `BSONSerializationError` in case of error.
	- Returns: The serialized BSON data.
	*/
	public class func bsonObject(with data: Data, options opt: ReadingOptions = []) throws -> BSONDoc {
		/* Let's check whether the length of the data correspond to the length
		 * declared in the data. */
		guard data.count >= 5 else {throw BSONSerializationError.dataTooSmall}
		let length32 = data.withUnsafeBytes{ $0.load(as: Int32.self) }
		guard Int(length32) == data.count else {throw BSONSerializationError.dataLengthDoNotMatch}
		
		let bufferedData = SimpleDataStream(data: data)
		return try bsonObject(with: bufferedData, options: opt)
	}
	
	/**
	Serialize the given stream into a dictionary with String keys, object values.
	
	Exactly the size of the BSON document will be read from the stream. If an
	error occurs while reading the BSON document, you are guaranteed that less
	than the size of the BSON doc is read. If the size of the BSON declared in
	the stream is invalid, the read bytes count is undetermined.
	
	- Parameter stream: The stream to parse. Must already be opened and
	configured.
	- Parameter options: Some options to customize the parsing. See
	`ReadingOptions`.
	- Throws: `BSONSerializationError` in case of error.
	- Returns: The serialized BSON data.
	*/
	public class func bsonObject(with stream: InputStream, options opt: ReadingOptions = []) throws -> BSONDoc {
		let bufferedInputStream = SimpleInputStream(stream: stream, bufferSize: 1024*1024, streamReadSizeLimit: nil)
		return try bsonObject(with: bufferedInputStream, options: opt)
	}
	
	/* Note: Whenever we can, I'd like to have a non-escaping optional closure...
	 * Other Note: decodeCallback is **NOT** called when a SUB-key is decoded. */
	class func bsonObject(with bufferStream: SimpleStream, options opt: ReadingOptions = [], initialReadPosition: Int = 0, decodeCallback: (_ key: String, _ val: Any?) throws -> Void = {_,_ in}) throws -> BSONDoc {
		precondition(MemoryLayout<Int32>.size <= MemoryLayout<Int>.size, "I currently need Int32 to be lower or equal in size than Int")
		precondition(MemoryLayout<Double>.size == 8, "I currently need Double to be 64 bits")
		
		/* TODO: Handle endianness! */
		
		let length32: Int32 = try bufferStream.readType()
		guard length32 >= 5 else {throw BSONSerializationError.dataTooSmall}
		
		let length = Int(length32)
		let previousStreamReadSizeLimit: Int?
		if let bufferedInputStream = bufferStream as? SimpleInputStream {previousStreamReadSizeLimit = bufferedInputStream.streamReadSizeLimit; bufferedInputStream.streamReadSizeLimit = initialReadPosition + length}
		else                                                            {previousStreamReadSizeLimit = nil}
		defer {if let bufferedInputStream = bufferStream as? SimpleInputStream {bufferedInputStream.streamReadSizeLimit = previousStreamReadSizeLimit}}
		
		var ret = [String: Any?]()
		
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
				ret[key] = .some(nil)
				
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
				for c in options {
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
				let val: NSRegularExpression
				do    {val = try NSRegularExpression(pattern: pattern, options: foundationOptions)}
				catch {throw BSONSerializationError.invalidRegularExpression(pattern: pattern, error: error)}
				
				try decodeCallback(key, val)
				ret[key] = val
				
			case .utf8String?:
				let val = try bufferStream.readBSONString(encoding: .utf8)
				try decodeCallback(key, val)
				ret[key] = val
				
			case .dictionary?:
				let val = try bsonObject(with: bufferStream, options: opt, initialReadPosition: bufferStream.currentReadPosition)
				try decodeCallback(key, val)
				ret[key] = val
				
			case .array?:
				var val = [Any?]()
				var prevKey: String? = nil
				_ = try bsonObject(with: bufferStream, options: opt, initialReadPosition: bufferStream.currentReadPosition, decodeCallback: { subkey, subval in
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
				let scope = try bsonObject(with: bufferStream, options: opt, initialReadPosition: bufferStream.currentReadPosition)
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
				ret[key] = .some(nil)
				
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
	
	public class func data(withBSONObject BSONObject: BSONDoc, options opt: WritingOptions = []) throws -> Data {
		let stream = OutputStream(toMemory: ())
		
		stream.open()
		defer {stream.close()}
		
		var sizes = [Int: Int32]()
		_ = try write(BSONObject: BSONObject, toStream: stream, options: opt.union(.skipSizes), initialWritePosition: 0, sizes: nil, sizeFoundCallback: { offset, size in
			assert(sizes[offset] == nil)
			sizes[offset] = size
		})
		
		guard let nsdata = stream.property(forKey: Stream.PropertyKey.dataWrittenToMemoryStreamKey) as? NSData else {
			throw BSONSerializationError.internalError
		}
		
		var data = Data(referencing: nsdata)
		if !opt.contains(.skipSizes) {
			data.withUnsafeMutableBytes{ (bytes: UnsafeMutableRawBufferPointer) -> Void in
				let baseAddress = bytes.baseAddress!
				for (offset, size) in sizes {
					/* We can either bind the memory, or assume it’s already bound,
					 * both cases are “working” (well the tests pass). Justification:
					 * we know the data won’t be aliased as we will modify and access
					 * it in this method only.
					 * I prefer to bind as the doc says “Any typed memory access,
					 * either via a normal safe language construct or via ${Self}<T>,
					 * requires that the access type be compatible with the memory’s
					 * currently ‘bound’ type.” Otherwise it’s an undefined behavior.
					 * https://github.com/atrick/swift/blob/type-safe-mem-docs/docs/TypeSafeMemory.rst#introduction
					 * For a trivial type I don’t think it matters, but still, let’s
					 * do the things “the right way.” */
					(baseAddress + offset).bindMemory(to: type(of: size), capacity: 1).pointee = size
					/* Note: Ideally I’d love to be able to do the line below, but
					 * currently it can crash with “storeBytes to misaligned raw
					 * pointer” (which is expected as per the documentation).
					 * Joe said there should be a version of storeBytes in the stdlib
					 * able to store at unaligned locations, but it is not there yet.*/
//					(baseAddress + offset).storeBytes(of: size, as: type(of: size))
				}
			}
			/* A variant of the code above. While this variant is “safer” because
			 * we know we won’t have memory binding problems, it is MUCH slower.*/
//			let int32Size = MemoryLayout<Int32>.size
//			for (offset, var size) in sizes {
//				let sizeData = Data(bytes: &size, count: int32Size)
//				data[offset..<(offset + int32Size)] = sizeData
//			}
		}
		
		return data
	}
	
	/** Write the given BSON object to a write stream.
	
	- Returns: The number of bytes written. */
	public class func writeBSONObject(_ BSONObject: BSONDoc, to stream: OutputStream, options opt: WritingOptions = []) throws -> Int {
		return try write(BSONObject: BSONObject, toStream: stream, options: opt, initialWritePosition: 0, sizes: nil, sizeFoundCallback: {_,_ in})
	}
	
	public class func sizesOfBSONObject(_ obj: BSONDoc) throws -> [Int] {
		precondition(MemoryLayout<Double>.size == 8, "I currently need Double to be 64 bits")
		precondition(MemoryLayout<Int>.size <= MemoryLayout<Int64>.size, "I currently need Int to be lower or equal in size than Int64")
		
		var curSize = 4 /* Size of the BSON Doc */
		var sizes = [Int]()
		for key in obj.keys.sorted().reversed() {
			let val = obj[key]!
			let sizesInfo = try sizesForBSONEntity(val, withKey: key)
			sizes.append(contentsOf: sizesInfo.1)
			curSize += sizesInfo.0
		}
		curSize += 1 /* The zero-terminator for BSON docs */
		sizes.append(curSize)
		return sizes
	}
	
	public class func isValidBSONObject(_ obj: BSONDoc) -> Bool {
		return (try? sizesOfBSONObject(obj)) != nil
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
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
		/** `RegularExpression`. Raw value is two cstring: Regexp pattern first,
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
	
	private class func sizesForBSONEntity(_ entity: Any?, withKey key: String) throws -> (Int /* Size for whole entity with key */, [Int] /* Subsizes (often empty) */) {
		var subSizes = [Int]()
		
		var size = 1 /* Type of the element */
		size += key.utf8.count + 1 /* Size of the encoded key */
		
		switch entity {
		case nil: (/*nop; this value does not have anything to write*/)
		case _ as Bool:                        size += 1
			
		case _ as Int32: fallthrough
		case _ as Int where MemoryLayout<Int>.size == MemoryLayout<Int32>.size:
			size += MemoryLayout<Int32>.size
			
		case _ as Int64: fallthrough
		case _ as Int where MemoryLayout<Int>.size == MemoryLayout<Int64>.size:
			size += MemoryLayout<Int64>.size
			
		case _ as Double:                      size += 8  /* 64  bits is 8  bytes */
		case _ as Double128:                   size += 16 /* 128 bits is 16 bytes */
		case _ as Date:                        size += 8  /* Encoded as an Int64 */
			
		case let regexp as NSRegularExpression:
			size += regexp.pattern.utf8.count + 1
			size += bsonRegexpOptionsString(fromFoundationRegexp: regexp).utf8.count + 1
			
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
	argument is `nil`).
	
	- Note: When possible, `sizeFoundCallback` should be optional (cannot be a
	non-escaped closure in current Swift state). */
	private class func write(BSONEntity entity: Any?, withKey key: String, toStream stream: OutputStream, options opt: WritingOptions, initialWritePosition: Int, sizes: UnsafeMutablePointer<[Int]>?, sizeFoundCallback: (_ offset: Int, _ size: Int32) -> Void = {_,_ in}) throws -> Int {
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
			
		case let regexp as NSRegularExpression:
			size += try write(elementType: .regularExpression, toStream: stream)
			size += try write(CEncodedString: key, toStream: stream)
			size += try write(CEncodedString: regexp.pattern, toStream: stream)
			size += try write(CEncodedString: bsonRegexpOptionsString(fromFoundationRegexp: regexp), toStream: stream)
			
		case let str as String:
			size += try write(elementType: .utf8String, toStream: stream)
			size += try write(CEncodedString: key, toStream: stream)
			size += try write(BSONEncodedString: str, toStream: stream)
			
		case let subObj as BSONDoc:
			size += try write(elementType: .dictionary, toStream: stream)
			size += try write(CEncodedString: key, toStream: stream)
			size += try write(BSONObject: subObj, toStream: stream, options: opt, initialWritePosition: initialWritePosition + size, sizes: sizes, sizeFoundCallback: sizeFoundCallback)
			
		case let array as [Any?]:
			size += try write(elementType: .array, toStream: stream)
			size += try write(CEncodedString: key, toStream: stream)
			let arrayStart = initialWritePosition + size
			
			var arraySize: Int32
			var computedArraySize = 0
			if let sizes = sizes {arraySize = Int32(sizes.pointee.popLast()!)}
			else                 {arraySize = 0}
			computedArraySize += try write(value: &arraySize, toStream: stream)
			for (i, elt) in array.enumerated() {
				computedArraySize += try write(BSONEntity: elt, withKey: String(i), toStream: stream, options: opt, initialWritePosition: arrayStart + computedArraySize, sizes: sizes, sizeFoundCallback: sizeFoundCallback)
			}
			
			var zero: Int8 = 0
			computedArraySize += try write(value: &zero, toStream: stream)
			
			if sizes == nil {sizeFoundCallback(arrayStart, Int32(computedArraySize))}
			size += computedArraySize
			
		case let val as MongoTimestamp:
			size += try write(elementType: .timestamp, toStream: stream)
			size += try write(CEncodedString: key, toStream: stream)
			
			var subVal: (UInt8, UInt8, UInt8, UInt8)
			subVal = val.increment; size += try write(value: &subVal, toStream: stream)
			subVal = val.timestamp; size += try write(value: &subVal, toStream: stream)
			
		case let bin as MongoBinary:
			size += try write(elementType: .binary, toStream: stream)
			size += try write(CEncodedString: key, toStream: stream)
			
			var dataSize: Int32 = Int32(bin.data.count)
			size += try write(value: &dataSize, toStream: stream)
			
			var type = bin.binaryTypeAsInt
			size += try write(value: &type, toStream: stream)
			
			/* Writing a 0-length data seems to make next writes to the stream fail */
			if bin.data.count > 0 {
				/* Note: Joe says we can bind the memory (or even assume it’s
				 * already bound) to UInt8 because the memory will be immutable in
				 * the closure, and thus cannot be aliased.
				 * https://twitter.com/jckarter/status/1142446184700624896 */
				let written = bin.data.withUnsafeBytes{ (bytes: UnsafeRawBufferPointer) -> Int in
					let boundBytes = bytes.bindMemory(to: UInt8.self)
					assert(bin.data.count == boundBytes.count, "INTERNAL ERROR")
					return stream.write(boundBytes.baseAddress!, maxLength: boundBytes.count)
				}
				guard written == bin.data.count else {throw BSONSerializationError.cannotWriteToStream(streamError: stream.streamError)}
				size += written
			}
			
		case var val as MongoObjectId:
			size += try write(elementType: .objectId, toStream: stream)
			size += try write(CEncodedString: key, toStream: stream)
			size += try write(value: &val, toStream: stream)
			
		case let js as Javascript:
			size += try write(elementType: .javascript, toStream: stream)
			size += try write(CEncodedString: key, toStream: stream)
			size += try write(BSONEncodedString: js.javascript, toStream: stream)
			
		case let sjs as JavascriptWithScope:
			size += try write(elementType: .javascriptWithScope, toStream: stream)
			size += try write(CEncodedString: key, toStream: stream)
			let sjsStart = initialWritePosition + size
			
			var sjsSize: Int32
			var computedSJSSize = 0
			if let sizes = sizes {sjsSize = Int32(sizes.pointee.popLast()!)}
			else                 {sjsSize = 0}
			computedSJSSize += try write(value: &sjsSize, toStream: stream)
			computedSJSSize += try write(BSONEncodedString: sjs.javascript, toStream: stream)
			computedSJSSize += try write(BSONObject: sjs.scope, toStream: stream, options: opt, initialWritePosition: sjsStart + computedSJSSize, sizes: sizes, sizeFoundCallback: sizeFoundCallback)
			
			if sizes == nil {sizeFoundCallback(sjsStart, Int32(computedSJSSize))}
			size += computedSJSSize
			
		case _ as MinKey:
			size += try write(elementType: .minKey, toStream: stream)
			size += try write(CEncodedString: key, toStream: stream)
			
		case _ as MaxKey:
			size += try write(elementType: .maxKey, toStream: stream)
			size += try write(CEncodedString: key, toStream: stream)
			
		case let dbPointer as MongoDBPointer:
			var bytes = dbPointer.bytesPart
			size += try write(elementType: .dbPointer, toStream: stream)
			size += try write(CEncodedString: key, toStream: stream)
			size += try write(BSONEncodedString: dbPointer.stringPart, toStream: stream)
			size += try write(value: &bytes, toStream: stream)
			
		default:
			throw BSONSerializationError.invalidBSONObject(invalidElement: entity! /* nil case already processed above */)
		}
		
		return size
	}
	
	/** Write the given BSON object to a write stream.
	
	- Parameter sizeFoundCallback: Only called when options contain `.skipSizes`.
	- Returns: The number of bytes written. */
	private class func write(BSONObject: BSONDoc, toStream stream: OutputStream, options opt: WritingOptions, initialWritePosition: Int, sizes knownSizes: UnsafeMutablePointer<[Int]>?, sizeFoundCallback: (_ offset: Int, _ size: Int32) -> Void) throws -> Int {
		let skipSizes = opt.contains(.skipSizes)
		
		var zero: Int8 = 0
		
		var docSize: Int32
		let allocatedPointer: Bool
		var currentRelativeWritePosition = 0
		let sizesPointer: UnsafeMutablePointer<[Int]>?
		
		if skipSizes {allocatedPointer = false; sizesPointer = nil; docSize = 0}
		else {
			let nonNilSizesPointer: UnsafeMutablePointer<[Int]>
			if let s = knownSizes {
				allocatedPointer = false
				nonNilSizesPointer = s
			} else {
				allocatedPointer = true
				nonNilSizesPointer = UnsafeMutablePointer<[Int]>.allocate(capacity: 1)
				nonNilSizesPointer.initialize(repeating: try sizesOfBSONObject(BSONObject), count: 1)
			}
			docSize = Int32(nonNilSizesPointer.pointee.popLast()!/* If nil, this is an internal error */)
			sizesPointer = nonNilSizesPointer
		}
		
		/* Writing doc size to the doc (if size is skipped, set to 0) */
		currentRelativeWritePosition += try write(value: &docSize, toStream: stream)
		
		/* Writing key values to the doc */
		if skipSizes {
			for (key, val) in BSONObject {
				currentRelativeWritePosition += try write(BSONEntity: val, withKey: key, toStream: stream, options: opt, initialWritePosition: currentRelativeWritePosition, sizes: sizesPointer, sizeFoundCallback: sizeFoundCallback)
			}
		} else {
			for key in BSONObject.keys.sorted() {
				let val = BSONObject[key]!
				currentRelativeWritePosition += try write(BSONEntity: val, withKey: key, toStream: stream, options: opt, initialWritePosition: currentRelativeWritePosition, sizes: sizesPointer, sizeFoundCallback: sizeFoundCallback)
			}
		}
		
		/* Writing final 0 */
		currentRelativeWritePosition += try write(value: &zero, toStream: stream)
		
		/* If skipping sizes, we have to call the callback for size found (the doc
		 * is written entirely, we now know its size!) */
		if skipSizes {sizeFoundCallback(initialWritePosition, Int32(currentRelativeWritePosition))}
		
		if allocatedPointer, let sizesPointer = sizesPointer {
			sizesPointer.deinitialize(count: 1)
			sizesPointer.deallocate()
		}
		
		/* The current write position is indeed the number of bytes written... */
		return currentRelativeWritePosition
	}
	
	private class func write(CEncodedString str: String, toStream stream: OutputStream) throws -> Int {
		var written = 0
		
		/* Apparently writing 0 bytes to the stream will f**ck it up... */
		if str.count > 0 {
			/* Let's get the UTF8 bytes of the string. */
			let bytes = [UInt8](str.utf8)
			guard !bytes.contains(0) else {throw BSONSerializationError.unserializableCString(str)}
			
			let curWrite = bytes.withUnsafeBufferPointer{ p -> Int in return stream.write(p.baseAddress!, maxLength: bytes.count) }
			guard curWrite == bytes.count else {throw BSONSerializationError.cannotWriteToStream(streamError: stream.streamError)}
			written += curWrite
		}
		
		var zero: Int8 = 0
		written += try write(value: &zero, toStream: stream)
		
		return written
	}
	
	private class func write(BSONEncodedString str: String, toStream stream: OutputStream) throws -> Int {
		var written = 0
		var strLength = Int32(str.utf8.count + 1 /* The zero */)
		
		/* Let's write the size of the string to the stream */
		written += try write(value: &strLength, toStream: stream)
		
		/* Apparently writing 0 bytes to the stream will f**ck it up... */
		if str.count > 0 {
			/* Let's get the UTF8 bytes of the string. */
			let bytes = [UInt8](str.utf8)
			let curWrite = bytes.withUnsafeBufferPointer{ p -> Int in return stream.write(p.baseAddress!, maxLength: bytes.count) }
			guard curWrite == bytes.count else {throw BSONSerializationError.cannotWriteToStream(streamError: stream.streamError)}
			written += curWrite
		}
		
		var zero: Int8 = 0
		written += try write(value: &zero, toStream: stream)
		
		return written
	}
	
	private class func write<T>(value: inout T, toStream stream: OutputStream) throws -> Int {
		let size = MemoryLayout<T>.size
		guard size > 0 else {return 0} /* Less than probable that size is equal to zero... */
		
		return try withUnsafePointer(to: &value){ pointer -> Int in
			#warning("This is illegal! (Line below) Memory rebound must be done with type that have the same size as the original one.")
			return try pointer.withMemoryRebound(to: UInt8.self, capacity: size, { bytes -> Int in
				let writtenSize = stream.write(bytes, maxLength: size)
				guard size == writtenSize else {throw BSONSerializationError.cannotWriteToStream(streamError: stream.streamError)}
				return size
			})
		}
	}
	
	private class func write(elementType: BSONElementType, toStream stream: OutputStream) throws -> Int {
		var t = elementType.rawValue
		return try write(value: &t, toStream: stream)
	}
	
	private class func bsonRegexpOptionsString(fromFoundationRegexp foundationRegexp: NSRegularExpression) -> String {
		var result = ""
		
		let opt = foundationRegexp.options
		if  opt.contains(.caseInsensitive)          {result += "i" /* Case insensitive matching */}
		if !opt.contains(.anchorsMatchLines)        {result += "m" /* Multiline matching. Not sure if what we've set corresponds exactly to the MongoDB implementation's... */}
		/* Unsupported in foundation flag: x (verbose) */
		result += "l" /* We consider this flag to be a default, unremovable behaviour in Foundation (makes \w, \W, etc. locale dependent) */
		if  opt.contains(.dotMatchesLineSeparators) {result += "s" /* Dotall mode ('.' matches everything). Not sure if exactly equivalent to Foundation option... */}
		if  opt.contains(.useUnicodeWordBoundaries) {result += "u" /* Make \w, \W, etc. match unicode */}
		/* Ignored foundation options: .allowCommentsAndWhitespace, .ignoreMetacharacters, .useUnixLineSeparators */
		
		return result
	}
	
}

/* *******
   MARK: -
   ******* */

private extension SimpleStream {
	
	func readCString(encoding: String.Encoding) throws -> String {
		let data = try readData(upToDelimiters: [Data([0])], matchingMode: .anyMatchWins, includeDelimiter: false, alwaysCopyBytes: false)
		_ = try readData(size: 1, alwaysCopyBytes: false)
		
		/* This String init fails if the data is invalid for the given encoding. */
		guard let str = String(data: data, encoding: encoding) else {
			/* MUST copy the data as the original bytes are not owned by us. */
			throw BSONSerialization.BSONSerializationError.invalidString(Data(data))
		}
		
		return str
	}
	
	func readBSONString(encoding: String.Encoding) throws -> String {
		/* Reading the string size. */
		let stringSize: Int32 = try readType()
		
		/* Reading the actual string. */
		let data = try readData(size: Int(stringSize)-1, alwaysCopyBytes: false)
		assert(data.count == Int(stringSize-1))
		guard let str = String(data: data, encoding: encoding) else {
			/* MUST copy the data as the original bytes are not owned by us. */
			throw BSONSerialization.BSONSerializationError.invalidString(Data(data))
		}
		
		/* Reading the last byte and checking it is indeed 0. */
		let null = try readData(size: 1, alwaysCopyBytes: false)
		assert(null.count == 1)
		guard null.first == 0 else {throw BSONSerialization.BSONSerializationError.invalidEndOfString(null.first)}
		
		return str
	}
	
}
