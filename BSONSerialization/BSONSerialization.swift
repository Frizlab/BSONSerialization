/*
 * BSONSerialization.swift
 * BSONSerialization
 *
 * Created by François Lamboley on 1/17/16.
 * Copyright © 2016 frizlab. All rights reserved.
 */

import Foundation



struct BSONReadingOptions : OptionSet {
	let rawValue: Int
	/* Empty. We just create the enum in case we want to add something to it later. */
}


struct BSONWritingOptions : OptionSet {
	let rawValue: Int
	/* Empty. We just create the enum in case we want to add something to it later. */
}


class BSONSerialization {
	
	/* TODO: Study the feasibility of creating a Decimal128 type. */
//	typealias Decimal128 = (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)
//	struct Decimal128/* : AbsoluteValuable, BinaryFloatingPoint, ExpressibleByIntegerLiteral, Hashable, LosslessStringConvertible, CustomDebugStringConvertible, CustomStringConvertible, Strideable*/ {
//		
//	}
	
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
		case invalidElementType(CUnsignedChar)
		
		/** Invalid UTF8 string found. The raw data forming the invalid UTF8
		string is given in argument to this enum case. */
		case invalidUTF8String(Data)
		/** Invalid end of BSON string found. Expected NULL (0), but found the
		bytes given in argument to this enum case (if nil, no data can be read
		after the string). */
		case invalidEndOfString(UInt8?)
		
		/** Cannot allocate memory (either with `malloc` or `UnsafePointer.alloc()`). */
		case cannotAllocateMemory(Int)
		/** An internal error occurred rendering the serialization impossible. */
		case internalError
	}
	
	/** The recognized BSON element types. */
	private enum BSONElementType : UInt8 {
		/** The end of the document. Parsing ends when this element is found. */
		case endOfDocument       = 0x00
		
		/** `NSNull()` */
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
		/** `Double`. 16 bytes (128-bit IEEE 754-2008 decimal floating point).
		Currently returned as a Data object containing 16 bytes. */
		case double128Bits       = 0x13
		/** `NSDate`. Raw value is the number of milliseconds since the Epoch in
		UTC in an Int64. */
		case utcDateTime         = 0x09
		/** `NSRegularExpression`. Raw value is two cstring: Regexp pattern first,
		then regexp options. */
		case regularExpression   = 0x0B
		
		/** `String`. Raw value is an Int32 representing the length of the string
		+ 1, then the actual bytes of the string, then a single 0 byte. */
		case utf8String          = 0x02
		
		/** `NSDictionary`. Raw value is an embedded BSON document */
		case dictionary          = 0x03
		/** `NSArray`. Raw value is an embedded BSON document; keys are "0", "1",
		etc. and must be ordered in numerical order. */
		case array               = 0x04
		
		/**
		`NSData`.
		Special internal type used by MongoDB replication and sharding.
		First 4 bytes are an increment, second 4 are a timestamp. */
		case timestamp           = 0x11
		/** `NSData`. Raw value is an Int32, followed by a subtype (1 byte) then
		the actual bytes. */
		case binary              = 0x05
		/** `NSData`. 12 bytes, used by MongoDB. */
		case objectId            = 0x07
		/** `String`. */
		case javascript          = 0x0D
		/**
		`(String, NSDictionary)`. Raw value is an Int32 representing the length of
		the whole raw value, then a string, then an embedded BSON doc.
		
		The document is a mapping from identifiers to values, representing the
		scope in which the string should be evaluated.*/
		case javascriptWithScope = 0x0F
		
		/** Special type which compares lower than all other possible BSON element
		values. */
		case minKey              = 0xFF
		/** Special type which compares higher than all other possible BSON
		element values. */
		case maxKey              = 0x7F
		
		/** Undefined value. Deprecated */
		case undefined           = 0x06
		/** Deprecated. Raw value is a string followed by 12 bytes. */
		case dbPointer           = 0x0C
		/** Valye is `String`. Deprecated. */
		case symbol              = 0x0E
	}
	
	private enum BSONElementBinarySubtype : UInt8 {
		case genericBinary = 0x00
		case function      = 0x01
		case uuid          = 0x04
		case md5           = 0x05
		case userDefined   = 0x80
		
		case uuidOld       = 0x03
		case binaryOld     = 0x02
	}
	
	/**
	Serialize the given data into a dictionary with String keys, object values.
	
	- Parameter data: The data to parse. Must be exactly an entire BSON doc.
	- Parameter options: Some options to customize the parsing. See `BSONReadingOptions`.
	- Throws: `BSONSerializationError` in case of error.
	- Returns: The serialized BSON data.
	*/
	class func BSONObject(data: Data, options opt: BSONReadingOptions) throws -> [String: Any] {
		guard data.count >= 5 else {
			throw BSONSerializationError.dataTooSmall
		}
		
		let dataBytes = (data as NSData).bytes
		let length = unsafeBitCast(dataBytes, to: UnsafePointer<Int32>.self).pointee
		
		guard Int32(data.count) == length else {
			throw BSONSerializationError.dataLengthDoNotMatch
		}
		
		/* We must not release the bytes memory (which explains the latest
		 * argument to the stream creation function): the data object will do it
		 * when released (after the stream has finished being used). */
		guard let stream = CFReadStreamCreateWithBytesNoCopy(kCFAllocatorDefault, unsafeBitCast(dataBytes, to: UnsafePointer<UInt8>.self), data.count, kCFAllocatorNull) else {
			throw BSONSerializationError.internalError
		}
		guard CFReadStreamOpen(stream) else {
			throw BSONSerializationError.internalError
		}
		defer {CFReadStreamClose(stream)}
		return try BSONObject(stream: stream, options: opt)
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
	class func BSONObject(stream: InputStream, options opt: BSONReadingOptions) throws -> [String: Any] {
		precondition(MemoryLayout<Double>.size == 8, "I currently need Double to be 64 bits")
		
		var bufferSize = 0
		var posInBuffer = 0
		var totalBytesRead = 0
		let maxBufferSize = 1024*1024 /* 1MB */
		let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: maxBufferSize)
//		if buffer == nil {throw BSONSerializationError.cannotAllocateMemory(maxBufferSize)}
		defer {buffer.deallocate(capacity: maxBufferSize)}
		
		/* TODO: Handle endianness! */
		
		let length32: Int32 = try readType(stream: stream, buffer: buffer, maxBufferSize: maxBufferSize, totalNReadBytes: &totalBytesRead)
		guard length32 >= 5 else {throw BSONSerializationError.dataTooSmall}
		
		let length = Int(length32)
		
		bufferSize = stream.read(buffer, maxLength: min(length, maxBufferSize))
		guard bufferSize > 0 else {throw BSONSerializationError.earlyStreamEnding}
		totalBytesRead += bufferSize
		
		var ret = [String: Any]()
		
		var isAtEnd = false
		while !isAtEnd {
			guard totalBytesRead <= length else {throw BSONSerializationError.invalidLength}
			
			let currentElementType: UInt8 = try readType(buffer: buffer, bufferStartPos: &posInBuffer, bufferValidLength: &bufferSize, maxBufferSize: maxBufferSize, totalNReadBytes: &totalBytesRead, stream: stream)
			guard currentElementType != BSONElementType.endOfDocument.rawValue else {
				isAtEnd = true
				break
			}
			
			let key = try readCString(buffer: buffer, bufferStartPos: &posInBuffer, bufferValidLength: &bufferSize, maxBufferSize: maxBufferSize, totalNReadBytes: &totalBytesRead, stream: stream)
			switch currentElementType {
			case BSONElementType.double64Bits.rawValue:
				let val: Double = try readType(buffer: buffer, bufferStartPos: &posInBuffer, bufferValidLength: &bufferSize, maxBufferSize: maxBufferSize, totalNReadBytes: &totalBytesRead, stream: stream)
				ret[key] = val
				
			case BSONElementType.double128Bits.rawValue:
				let val = try readDataFromBuffer(dataSize: 16, alwaysCopyBytes: true, buffer: buffer, bufferStartPos: &posInBuffer, bufferValidLength: &bufferSize, maxBufferSize: maxBufferSize, totalNReadBytes: &totalBytesRead, stream: stream)
				ret[key] = val
				
			case BSONElementType.utf8String.rawValue:
				ret[key] = try readString(buffer: buffer, bufferStartPos: &posInBuffer, bufferValidLength: &bufferSize, maxBufferSize: maxBufferSize, totalNReadBytes: &totalBytesRead, stream: stream)
				
			default: throw BSONSerializationError.invalidElementType(currentElementType)
			}
		}
		guard totalBytesRead == length else {throw BSONSerializationError.invalidLength}
		return ret
	}
	
	class func data(BSONObject: [String: Any], options opt: BSONWritingOptions) throws -> Data {
		guard let stream = CFWriteStreamCreateWithAllocatedBuffers(kCFAllocatorDefault, kCFAllocatorDefault) else {
			throw BSONSerializationError.internalError
		}
		guard CFWriteStreamOpen(stream) else {
			throw BSONSerializationError.internalError
		}
		defer {CFWriteStreamClose(stream)}
		_ = try write(BSONObject: BSONObject, toStream: stream, options: opt)
		guard let data = CFWriteStreamCopyProperty(stream, .dataWritten) as AnyObject as? Data else {
			throw BSONSerializationError.internalError
		}
		return data
	}
	
	class func write(BSONObject: [String: Any], toStream stream: OutputStream, options opt: BSONWritingOptions) throws -> Int {
		return 0
	}
	
	class func isValidBSONObject(_ obj: [String: Any]) -> Bool {
		return false
	}
	
	/** Reads exactly the size of Type in the stream and puts it at the beginning
	of the buffer. Returns the read value.
	
	If maxBufferSize is lower than the size of the read value type, will
	create it’s own buffer to read the value.
	
	- Parameter stream: The stream from which to read the type. Must already be opened and configured.
	- Parameter buffer: The default buffer to use to store the bytes to read the data from. If too small, another buffer will be created.
	- Parameter maxBufferSize: The buffer size of the given buffer.
	- Parameter totalNReadBytes: The total number of bytes read from the stream so far. Incremented by the number of bytes read in the function on output.
	- Throws: `BSONSerializationError` in case of error.
	- Returns: The required type.
	*/
	private class func readType<Type>(stream: InputStream, buffer: UnsafeMutablePointer<UInt8>, maxBufferSize: Int, totalNReadBytes: inout Int) throws -> Type {
		let size = MemoryLayout<Type>.size
		if maxBufferSize < size {
			/* If the given buffer is too small, we create our own buffer. */
			print("Got too small buffer of size \(maxBufferSize) to read type \(Type.self) of size \(size). Retrying with a bigger buffer.")
			let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: size)
//			if buffer == nil {throw BSONSerializationError.cannotAllocateMemory(size)}
			defer {buffer.deallocate(capacity: size)}
			return try readType(stream: stream, buffer: buffer, maxBufferSize: size, totalNReadBytes: &totalNReadBytes)
		}
		
		var sRead = 0
		repeat {
			assert(sRead < size)
			let r = stream.read(buffer.advanced(by: sRead), maxLength: size-sRead)
			guard r > 0 else {throw BSONSerializationError.earlyStreamEnding}
			sRead += r
		} while sRead != size
		totalNReadBytes += sRead
		return unsafeBitCast(buffer, to: UnsafePointer<Type>.self).pointee
	}
	
	/** Reads the given type from the buffer at the given position. If there are
	not enough bytes in the buffer to read the given type, the function will
	either move the data in the buffer to have enough free space to read the type
	from the given buffer, or create a temporary buffer to read the type.
	
	- Parameter buffer: The buffer from which to start reading the bytes.
	- Parameter bufferStartPos: Where to start reading the data from in the given buffer.
	- Parameter bufferValidLength: The valid number of bytes from `bufferStartPos` in the buffer.
	- Parameter maxBufferSize: The maximum number of bytes the buffer can hold (from the start of the buffer).
	- Parameter totalNReadBytes: The total number of bytes read from the stream so far. Incremented by the number of bytes read in the function on output.
	- Parameter stream: The stream from which to read new bytes if needed.
	- Throws: `BSONSerializationError` in case of error.
	- Returns: The required type.
	*/
	private class func readType<Type>(buffer: UnsafeMutablePointer<UInt8>, bufferStartPos: inout Int, bufferValidLength: inout Int, maxBufferSize: Int, totalNReadBytes: inout Int, stream: InputStream) throws -> Type {
		let data = try readDataFromBuffer(dataSize: MemoryLayout<Type>.size, alwaysCopyBytes: false, buffer: buffer, bufferStartPos: &bufferStartPos, bufferValidLength: &bufferValidLength, maxBufferSize: maxBufferSize, totalNReadBytes: &totalNReadBytes, stream: stream)
		assert(data.count == MemoryLayout<Type>.size)
		return unsafeBitCast((data as NSData).bytes, to: UnsafePointer<Type>.self).pointee
	}
	
	private enum BufferHandling {
		/** Copy the bytes from the buffer to the new NSData object. */
		case copyBytes
		/** Create the NSData with bytes from the buffer directly without copying.
		Buffer ownership stays to the caller, which means the NSData object is
		invalid as soon as the buffer is released (and modified when the buffer is
		modified). */
		case useBufferLeaveOwnership
		/** Create the NSData with bytes from the buffer directly without copying.
		Takes buffer ownership, which must have been alloc'd using alloc(). */
		case useBufferTakeOwnership
	}
	/** Reads and return the asked size from the buffer and completes with the
	stream if needed. Uses the given buffer to read the first bytes and store the
	bytes read from the stream if applicable. The buffer must be big enough to
	contain the asked size from `bufferStartPos`.
	
	- Parameter dataSize: The size of the data to return.
	- Parameter bufferHandling: How to handle the buffer for the NSData object creation. See the `BufferHandling` enum.
	- Parameter buffer: The buffer from which to start reading the bytes.
	- Parameter bufferStartPos: Where to start reading the data from in the given buffer.
	- Parameter bufferValidLength: The valid number of bytes from `bufferStartPos` in the buffer.
	- Parameter maxBufferSize: The maximum number of bytes the buffer can hold (from the start of the buffer).
	- Parameter totalNReadBytes: The total number of bytes read from the stream so far. Incremented by the number of bytes read in the function on output.
	- Parameter stream: The stream from which to read new bytes if needed.
	- Throws: `BSONSerializationError` in case of error.
	- Returns: The required type.
	*/
	private class func readDataInBigEnoughBuffer(dataSize size: Int, bufferHandling: BufferHandling, buffer: UnsafeMutablePointer<UInt8>, bufferStartPos: inout Int, bufferValidLength: inout Int, maxBufferSize: Int, totalNReadBytes: inout Int, stream: InputStream) throws -> Data {
		assert(maxBufferSize >= size)
		
		let bufferStart = buffer.advanced(by: bufferStartPos)
		
		while bufferValidLength < size {
			let r = stream.read(bufferStart.advanced(by: bufferValidLength), maxLength: maxBufferSize - (bufferStartPos + bufferValidLength))
			guard r > 0 else {
				if bufferHandling == .useBufferTakeOwnership {free(buffer)}
				throw BSONSerializationError.earlyStreamEnding
			}
			bufferValidLength += r
			totalNReadBytes += r
		}
		bufferValidLength -= size
		bufferStartPos += size
		
		let ret: Data
		switch bufferHandling {
		case .copyBytes:               ret = Data(bytes: UnsafePointer<UInt8>(bufferStart), count: size)
		case .useBufferTakeOwnership:  ret = Data(bytesNoCopy: UnsafeMutablePointer<UInt8>(bufferStart), count: size, deallocator: .free)
		case .useBufferLeaveOwnership: ret = Data(bytesNoCopy: UnsafeMutablePointer<UInt8>(bufferStart), count: size, deallocator: .none)
		}
		return ret
	}
	
	/** Reads the dataSize bytes from the buffer at the given position. If there
	are not enough bytes in the buffer, the function will continue reading from
	the stream.
	
	The data in the buffer might be moved so the number of bytes asked fits in
	it.
	
	If the buffer is too small to contain the number of bytes asked to be read,
	a new buffer big enough is created.
	
	- Parameter dataSize: The size of the data to return.
	- Parameter alwaysCopyBytes: If `true`, the bytes will be copied from the buffer in the Data object. Else, the returned Data object might share its bytes with the buffer.
	- Parameter buffer: The buffer from which to start reading the bytes.
	- Parameter bufferStartPos: Where to start reading the data from in the given buffer.
	- Parameter bufferValidLength: The valid number of bytes from `bufferStartPos` in the buffer.
	- Parameter maxBufferSize: The maximum number of bytes the buffer can hold (from the start of the buffer).
	- Parameter totalNReadBytes: The total number of bytes read from the stream so far. Incremented by the number of bytes read in the function on output.
	- Parameter stream: The stream from which to read new bytes if needed.
	- Throws: `BSONSerializationError` in case of error.
	- Returns: The required type.
	*/
	private class func readDataFromBuffer(dataSize size: Int, alwaysCopyBytes: Bool, buffer: UnsafeMutablePointer<UInt8>, bufferStartPos: inout Int, bufferValidLength: inout Int, maxBufferSize: Int, totalNReadBytes: inout Int, stream: InputStream) throws -> Data {
		assert(maxBufferSize > 0)
		assert(bufferStartPos <= maxBufferSize)
		assert(bufferValidLength <= maxBufferSize - bufferStartPos)
		
		let bufferStart = buffer.advanced(by: bufferStartPos)
		
		switch size {
		case let s where s <= maxBufferSize - bufferStartPos:
			/* The buffer is big enough to hold the size we want to read, from
			 * buffer start pos. */
			return try readDataInBigEnoughBuffer(
				dataSize: size,
				bufferHandling: (alwaysCopyBytes ? .copyBytes : .useBufferLeaveOwnership),
				buffer: buffer,
				bufferStartPos: &bufferStartPos,
				bufferValidLength: &bufferValidLength,
				maxBufferSize: maxBufferSize,
				totalNReadBytes: &totalNReadBytes,
				stream: stream
			)
			
		case let s where s <= maxBufferSize:
			/* The buffer total size is enough to hold the size we want to read.
			 * However, we must relocate data in the buffer so the buffer start
			 * position is 0. */
			buffer.assign(from: bufferStart, count: bufferValidLength); bufferStartPos = 0
			return try readDataInBigEnoughBuffer(
				dataSize: size,
				bufferHandling: (alwaysCopyBytes ? .copyBytes : .useBufferLeaveOwnership),
				buffer: buffer,
				bufferStartPos: &bufferStartPos,
				bufferValidLength: &bufferValidLength,
				maxBufferSize: maxBufferSize,
				totalNReadBytes: &totalNReadBytes,
				stream: stream
			)
			
		default:
			/* The buffer is not big enough to hold the data we want to read. We
			 * must create our own buffer. */
			print("Got too small buffer of size \(maxBufferSize) to read size \(size) from buffer. Retrying with a bigger buffer.")
			let m = malloc(size) /* NOT free'd here. Free'd later when set in NSData, or by the readDataInBigEnoughBuffer function. */
			if m == nil {throw BSONSerializationError.cannotAllocateMemory(size)}
			let biggerBuffer = unsafeBitCast(m, to: UnsafeMutablePointer<UInt8>.self)
			
			/* Copying data in our given buffer to the new buffer. */
			biggerBuffer.assign(from: bufferStart, count: bufferValidLength) /* size is greater than maxBufferSize. We know we will never overflow our own buffer using bufferValidLength */
			var newStartPos = 0, newValidLength = bufferValidLength
			
			bufferStartPos = 0; bufferValidLength = 0
			
			return try readDataInBigEnoughBuffer(
				dataSize: size,
				bufferHandling: .useBufferTakeOwnership,
				buffer: buffer,
				bufferStartPos: &newStartPos,
				bufferValidLength: &newValidLength,
				maxBufferSize: size,
				totalNReadBytes: &totalNReadBytes,
				stream: stream
			)
		}
	}
	
	/** Reads a "cstring" from the buffer, continuing with the stream if the
	buffer does not have the whole cstring.
	
	A "cstring" is a UTF8 encoded null-terminated string. As it is null-
	terminated, the "cstring" cannot represent all that can be represented in
	UTF8.
	
	- Parameter buffer: The buffer from which to start reading the bytes.
	- Parameter bufferStartPos: Where to start reading the data from in the given buffer.
	- Parameter bufferValidLength: The valid number of bytes from `bufferStartPos` in the buffer.
	- Parameter maxBufferSize: The maximum number of bytes the buffer can hold (from the start of the buffer).
	- Parameter totalNReadBytes: The total number of bytes read from the stream so far. Incremented by the number of bytes read in the function on output.
	- Parameter stream: The stream from which to read new bytes if needed.
	- Throws: `BSONSerializationError` in case of error.
	- Returns: The required type.
	*/
	private class func readCString(buffer: UnsafeMutablePointer<UInt8>, bufferStartPos: inout Int, bufferValidLength: inout Int, maxBufferSize: Int, totalNReadBytes: inout Int, stream: InputStream) throws -> String {
		/* Let's find the end of the string ('\0') */
		var strBytesLength = 0
		let bufferStart = buffer.advanced(by: bufferStartPos)
		let bufferEnd = bufferStart.advanced(by: bufferValidLength)
		for b in bufferStart..<bufferStart.advanced(by: bufferValidLength) {
			strBytesLength += 1
			guard b.pointee != 0 else {
				bufferStartPos += strBytesLength
				bufferValidLength -= strBytesLength
				/* Found the 0 */
				guard let str = String(validatingUTF8: unsafeBitCast(bufferStart, to: UnsafePointer<CChar>.self)) else {
					throw BSONSerializationError.invalidUTF8String(Data(bytes: UnsafePointer<UInt8>(bufferStart), count: strBytesLength))
				}
				return str
			}
		}
		
		var newBuffer = buffer
		var newBufferEnd = bufferEnd
		var newBufferStart = bufferStart
		var newMaxBufferSize = maxBufferSize
		var newBufferStartPos = bufferStartPos
		var newBufferValidLength = bufferValidLength
		
		while true {
			if newBufferStartPos + newBufferValidLength >= maxBufferSize {
				/* The buffer is not big enough to hold new data... Let's move the
				 * data to the beginning of the buffer or create a new buffer. */
				if newBufferStart != newBuffer {
					/* We can move the data to the beginning of the buffer. */
					assert(newBufferStartPos > 0)
					newBuffer.assign(from: newBufferStart, count: newBufferValidLength)
					newBufferStart = newBuffer; newBufferEnd = newBufferStart.advanced(by: newBufferValidLength); newBufferStartPos = 0
					if newBuffer == buffer {bufferStartPos = 0}
				} else {
					/* The buffer is not big enough anymore. We need to create a new
					 * bigger one. */
					bufferStartPos = 0; bufferValidLength = 0
					
					assert(newBufferStartPos == 0)
					
					let oldBuffer = newBuffer
					let oldBufferSize = newMaxBufferSize
					
					newMaxBufferSize += min(newMaxBufferSize, 4*1024 /* 4KB */)
					newBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: newMaxBufferSize)
//					if newBuffer == nil {throw BSONSerializationError.cannotAllocateMemory(newMaxBufferSize)}
					newBuffer.assign(from: oldBuffer, count: newBufferValidLength)
					newBufferStart = newBuffer; newBufferEnd = newBufferStart.advanced(by: newBufferValidLength)
					
					if oldBuffer != buffer {oldBuffer.deallocate(capacity: oldBufferSize)}
				}
			}
			
			/* Let's read from the stream now. */
			let r = stream.read(newBufferEnd, maxLength: newMaxBufferSize - (newBufferStartPos + newBufferValidLength))
			guard r > 0 else {throw BSONSerializationError.earlyStreamEnding}
			newBufferValidLength += r
			totalNReadBytes += r
			
			/* Did we read the end of the string? */
			for b in bufferEnd..<bufferEnd.advanced(by: r) {
				strBytesLength += 1
				guard b.pointee != 0 else {
					/* Found the 0 */
					if newBuffer == buffer {
						bufferStartPos += strBytesLength
						bufferValidLength = newBufferValidLength - strBytesLength
					}
					guard let str = String(validatingUTF8: unsafeBitCast(newBufferStart, to: UnsafePointer<CChar>.self)) else {
						throw BSONSerializationError.invalidUTF8String(Data(bytes: UnsafePointer<UInt8>(bufferStart), count: strBytesLength))
					}
					return str
				}
			}
			newBufferEnd = newBufferStart.advanced(by: newBufferValidLength)
		}
	}
	
	/** Reads a BSON string from the buffer, continuing with the stream if the
	buffer does not have the whole string.
	
	A BSON string is an UTF8 string. It is represented by its size+1 in an Int32
	followed by the actual bytes for the string (in UTF8), then a null-byte.
	
	- Parameter buffer: The buffer from which to start reading the bytes.
	- Parameter bufferStartPos: Where to start reading the data from in the given buffer.
	- Parameter bufferValidLength: The valid number of bytes from `bufferStartPos` in the buffer.
	- Parameter maxBufferSize: The maximum number of bytes the buffer can hold (from the start of the buffer).
	- Parameter totalNReadBytes: The total number of bytes read from the stream so far. Incremented by the number of bytes read in the function on output.
	- Parameter stream: The stream from which to read new bytes if needed.
	- Throws: `BSONSerializationError` in case of error.
	- Returns: The required type.
	*/
	private class func readString(buffer: UnsafeMutablePointer<UInt8>, bufferStartPos: inout Int, bufferValidLength: inout Int, maxBufferSize: Int, totalNReadBytes: inout Int, stream: InputStream) throws -> String {
		/* Reading the string size. */
		let stringSize: Int32 = try readType(buffer: buffer, bufferStartPos: &bufferStartPos, bufferValidLength: &bufferValidLength, maxBufferSize: maxBufferSize, totalNReadBytes: &totalNReadBytes, stream: stream)
		
		/* Reading the actual string. */
		let data = try readDataFromBuffer(dataSize: Int(stringSize)-1, alwaysCopyBytes: false, buffer: buffer, bufferStartPos: &bufferStartPos, bufferValidLength: &bufferValidLength, maxBufferSize: maxBufferSize, totalNReadBytes: &totalNReadBytes, stream: stream)
		assert(data.count == Int32(stringSize)-1)
		guard let str = String(data: data, encoding:String.Encoding.utf8) else {
			throw BSONSerializationError.invalidUTF8String(data)
		}
		
		/* Reading the last byte and checking it is indeed 0. */
		let null = try readDataFromBuffer(dataSize: 1, alwaysCopyBytes: false, buffer: buffer, bufferStartPos: &bufferStartPos, bufferValidLength: &bufferValidLength, maxBufferSize: maxBufferSize, totalNReadBytes: &totalNReadBytes, stream: stream)
		assert(null.count <= 1)
		guard null.first == 0 else {throw BSONSerializationError.invalidEndOfString(null.first)}
		
		return str
	}
	
}
