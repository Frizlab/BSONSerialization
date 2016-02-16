/*
 * BSONSerialization.swift
 * BSONSerialization
 *
 * Created by François Lamboley on 1/17/16.
 * Copyright © 2016 frizlab. All rights reserved.
 */

import Cocoa



struct BSONReadingOptions : OptionSetType {
	let rawValue: Int
	/* Empty. We just create the enum in case we want to add something to it later. */
}


struct BSONWritingOptions : OptionSetType {
	let rawValue: Int
	/* Empty. We just create the enum in case we want to add something to it later. */
}


class BSONSerialization {
	
	/** The BSON Serialization errors enum. */
	enum BSONSerializationError : ErrorType {
		/** The given data/stream contains too few bytes to be a valid bson doc. */
		case DataTooSmall
		/** The given data size is not the one declared by the bson doc. */
		case DataLengthDoNotMatch
		
		/** The stream ended before the end of the bson doc was reached. */
		case EarlyStreamEnding
		
		/** The length of the bson doc is invalid. */
		case InvalidLength
		/** An invalid element was found. The element is given in argument to this
		enum case. */
		case InvalidElementType(CUnsignedChar)
		
		/** Invalid UTF8 string found. The raw data forming the invalid UTF8
		string is given in argument to this enum case. */
		case InvalidUTF8String(NSData)
		
		/** Cannot allocate memory (either with `malloc` or `UnsafePointer.alloc()`). */
		case CannotAllocateMemory(Int)
		/** An internal error occurred rendering the serialization impossible. */
		case InternalError
	}
	
	/** The recognized BSON element types. */
	private enum BSONElementType : UInt8 {
		/** The end of the document. Parsing ends when this element is found. */
		case EndOfDocument       = 0x00
		
		/** `NSNull()` */
		case Null                = 0x0A
		/** `Bool`. Raw value is a single byte, containing `'\0'` (`false`) or
		`'\1'` (`true`). */
		case Boolean             = 0x08
		/** `Int32`. 4 bytes (32-bit signed integer, two’s complement). */
		case Int32Bits           = 0x10
		/** `Int64`. 8 bytes (64-bit signed integer, two’s complement). */
		case Int64Bits           = 0x12
		/** `Double`. 8 bytes (64-bit IEEE 754-2008 binary floating point)/ */
		case Double64Bits        = 0x01
		/** `NSDate`. Raw value is the number of milliseconds since the Epoch in
		UTC in an Int64. */
		case UTCDateTime         = 0x09
		/** `NSRegularExpression`. Raw value is two cstring: Regexp pattern first,
		then regexp options. */
		case RegularExpression   = 0x0B
		
		/** `String`. Raw value is an Int32 representing the length of the string
		+ 1, then the actual bytes of the string, then a single 0 byte. */
		case UTF8String          = 0x02
		
		/** `NSDictionary`. Raw value is an embedded BSON document */
		case Dictionary          = 0x03
		/** `NSArray`. Raw value is an embedded BSON document; keys are "0", "1",
		etc. and must be ordered in numerical order. */
		case Array               = 0x04
		
		/**
      `NSData`.
      Special internal type used by MongoDB replication and sharding.
		First 4 bytes are an increment, second 4 are a timestamp. */
		case Timestamp           = 0x11
		/** `NSData`. Raw value is an Int32, followed by a subtype (1 byte) then
		the actual bytes. */
		case Binary              = 0x05
		/** `NSData`. 12 bytes, used by MongoDB. */
		case ObjectId            = 0x07
		/** `String`. */
		case Javascript          = 0x0D
		/**
		`(String, NSDictionary)`. Raw value is an Int32 representing the length of
		the whole raw value, then a string, then an embedded BSON doc.
		
		The document is a mapping from identifiers to values, representing the
		scope in which the string should be evaluated.*/
		case JavascriptWithScope = 0x0F
		
		/** Special type which compares lower than all other possible BSON element
		values. */
		case MinKey              = 0xFF
		/** Special type which compares higher than all other possible BSON
		element values. */
		case MaxKey              = 0x7F
		
		/** Undefined value. Deprecated */
		case Undefined           = 0x06
		/** Deprecated. Raw value is a string followed by 12 bytes. */
		case DBPointer           = 0x0C
		/** Valye is `String`. Deprecated. */
		case Symbol              = 0x0E
	}
	
	private enum BSONElementBinarySubtype : UInt8 {
		case GenericBinary = 0x00
		case Function      = 0x01
		case UUID          = 0x04
		case MD5           = 0x05
		case UserDefined   = 0x80
		
		case UUIDOld       = 0x03
		case BinaryOld     = 0x02
	}
	
	/**
	Serialize the given data into a dictionary with String keys, object values.
	
	- Parameter data: The data to parse. Must be exactly an entire BSON doc.
	- Parameter options: Some options to customize the parsing. See `BSONReadingOptions`.
	- Throws: `BSONSerializationError` in case of error.
	- Returns: The serialized BSON data.
	*/
	class func BSONObjectWithData(data: NSData, options opt: BSONReadingOptions) throws -> [String: AnyObject] {
		guard data.length >= 5 else {
			throw BSONSerializationError.DataTooSmall
		}
		
		let dataBytes = data.bytes
		let length = unsafeBitCast(dataBytes, UnsafePointer<Int32>.self).memory
		
		guard Int32(data.length) == length else {
			throw BSONSerializationError.DataLengthDoNotMatch
		}
		
		/* We must not release the bytes memory (which explains the latest
		 * argument to the stream creation function): the data object will do it
		 * when released (after the stream has finished being used). */
		guard let stream = CFReadStreamCreateWithBytesNoCopy(kCFAllocatorDefault, unsafeBitCast(dataBytes, UnsafePointer<UInt8>.self), data.length, kCFAllocatorNull) else {
			throw BSONSerializationError.InternalError
		}
		guard CFReadStreamOpen(stream) else {
			throw BSONSerializationError.InternalError
		}
		defer {CFReadStreamClose(stream)}
		return try BSONObjectWithStream(stream, options: opt)
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
	class func BSONObjectWithStream(stream: NSInputStream, options opt: BSONReadingOptions) throws -> [String: AnyObject] {
		precondition(sizeof(Double.self) == 8, "I currently need Double to be 64 bits")
		
		var bufferSize = 0
		var posInBuffer = 0
		var totalBytesRead = 0
		let maxBufferSize = 1024*1024 /* 1MB */
		let buffer = UnsafeMutablePointer<UInt8>.alloc(maxBufferSize)
		if buffer == nil {throw BSONSerializationError.CannotAllocateMemory(maxBufferSize)}
		defer {buffer.dealloc(maxBufferSize)}
		
		/* TODO: Handle endianness! */
		
		let length32: Int32 = try readTypeFromStream(stream, buffer: buffer, maxBufferSize: maxBufferSize, totalNReadBytes: &totalBytesRead)
		guard length32 >= 5 else {throw BSONSerializationError.DataTooSmall}
		
		let length = Int(length32)
		
		bufferSize = stream.read(buffer, maxLength: min(length, maxBufferSize))
		guard bufferSize > 0 else {throw BSONSerializationError.EarlyStreamEnding}
		totalBytesRead += bufferSize
		
		var ret = [String: AnyObject]()
		
		var isAtEnd = false
		while !isAtEnd {
			guard totalBytesRead <= length else {throw BSONSerializationError.InvalidLength}
			
			let currentElementType: UInt8 = try readTypeFromBuffer(buffer, bufferStartPos: &posInBuffer, bufferValidLength: &bufferSize, maxBufferSize: maxBufferSize, totalNReadBytes: &totalBytesRead, stream: stream)
			guard currentElementType != BSONElementType.EndOfDocument.rawValue else {
				isAtEnd = true
				break
			}
			
			let key = try readCStringFromBuffer(buffer, bufferStartPos: &posInBuffer, bufferValidLength: &bufferSize, maxBufferSize: maxBufferSize, totalNReadBytes: &totalBytesRead, stream: stream)
			switch currentElementType {
			case BSONElementType.Double64Bits.rawValue:
				let val: Double = try readTypeFromBuffer(buffer, bufferStartPos: &posInBuffer, bufferValidLength: &bufferSize, maxBufferSize: maxBufferSize, totalNReadBytes: &totalBytesRead, stream: stream)
				ret[key] = val
			case BSONElementType.UTF8String.rawValue:
				ret[key] = try readStringFromBuffer(buffer, bufferStartPos: &posInBuffer, bufferValidLength: &bufferSize, maxBufferSize: maxBufferSize, totalNReadBytes: &totalBytesRead, stream: stream)
			default: throw BSONSerializationError.InvalidElementType(currentElementType)
			}
		}
		guard totalBytesRead == length else {throw BSONSerializationError.InvalidLength}
		return ret
	}
	
	class func dataWithBSONObject(obj: AnyObject, options opt: BSONWritingOptions) throws -> NSData {
		return NSData()
	}
	
	class func writeBSONObject(obj: AnyObject, toStream stream: NSOutputStream, options opt: BSONWritingOptions, error: NSErrorPointer) -> Int {
		return 0
	}
	
	class func isValidBSONObject(obj: AnyObject) -> Bool {
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
	private class func readTypeFromStream<Type>(stream: NSInputStream, buffer: UnsafeMutablePointer<UInt8>, maxBufferSize: Int, inout totalNReadBytes: Int) throws -> Type {
		let size = sizeof(Type)
		if maxBufferSize < size {
			/* If the given buffer is too small, we create our own buffer. */
			print("Got too small buffer of size \(maxBufferSize) to read type \(Type.self) of size \(size). Retrying with a bigger buffer.")
			let buffer = UnsafeMutablePointer<UInt8>.alloc(size)
			if buffer == nil {throw BSONSerializationError.CannotAllocateMemory(size)}
			defer {buffer.dealloc(size)}
			return try readTypeFromStream(stream, buffer: buffer, maxBufferSize: size, totalNReadBytes: &totalNReadBytes)
		}
		
		var sRead = 0
		repeat {
			assert(sRead < size)
			let r = stream.read(buffer.advancedBy(sRead), maxLength: size-sRead)
			guard r > 0 else {throw BSONSerializationError.EarlyStreamEnding}
			sRead += r
		} while sRead != size
		totalNReadBytes += sRead
		return unsafeBitCast(buffer, UnsafePointer<Type>.self).memory
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
	private class func readTypeFromBuffer<Type>(buffer: UnsafeMutablePointer<UInt8>, inout bufferStartPos: Int, inout bufferValidLength: Int, maxBufferSize: Int, inout totalNReadBytes: Int, stream: NSInputStream) throws -> Type {
		let data = try readDataFromBuffer(dataSize: sizeof(Type), alwaysCopyBytes: false, buffer: buffer, bufferStartPos: &bufferStartPos, bufferValidLength: &bufferValidLength, maxBufferSize: maxBufferSize, totalNReadBytes: &totalNReadBytes, stream: stream)
		assert(data.length == sizeof(Type))
		return unsafeBitCast(data.bytes, UnsafePointer<Type>.self).memory
	}
	
	private enum BufferHandling {
		/** Copy the bytes from the buffer to the new NSData object. */
		case CopyBytes
		/** Create the NSData with bytes from the buffer directly without copying.
		Buffer ownership stays to the caller, which means the NSData object is
		invalid as soon as the buffer is released (and modified when the buffer is
		modified). */
		case UseBufferLeaveOwnership
		/** Create the NSData with bytes from the buffer directly without copying.
		Takes buffer ownership, which must have been alloc'd using alloc(). */
		case UseBufferTakeOwnership
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
	private class func readDataInBigEnoughBuffer(dataSize size: Int, bufferHandling: BufferHandling, buffer: UnsafeMutablePointer<UInt8>, inout bufferStartPos: Int, inout bufferValidLength: Int, maxBufferSize: Int, inout totalNReadBytes: Int, stream: NSInputStream) throws -> NSData {
		assert(maxBufferSize >= size)
		
		let bufferStart = buffer.advancedBy(bufferStartPos)
		
		while bufferValidLength < size {
			let r = stream.read(bufferStart.advancedBy(bufferValidLength), maxLength: maxBufferSize - (bufferStartPos + bufferValidLength))
			guard r > 0 else {
				if bufferHandling == .UseBufferTakeOwnership {free(buffer)}
				throw BSONSerializationError.EarlyStreamEnding
			}
			bufferValidLength += r
			totalNReadBytes += r
		}
		bufferValidLength -= size
		bufferStartPos += size
		
		let ret: NSData
		switch bufferHandling {
		case .CopyBytes:               ret = NSData(bytes: bufferStart, length: size)
		case .UseBufferTakeOwnership:  ret = NSData(bytesNoCopy: bufferStart, length: size, freeWhenDone: true)
		case .UseBufferLeaveOwnership: ret = NSData(bytesNoCopy: bufferStart, length: size, freeWhenDone: false)
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
	- Parameter alwaysCopyBytes: If `true`, the bytes will be copied from the buffer in the NSData object. Else, the returned NSData object might share its bytes with the buffer.
	- Parameter buffer: The buffer from which to start reading the bytes.
	- Parameter bufferStartPos: Where to start reading the data from in the given buffer.
	- Parameter bufferValidLength: The valid number of bytes from `bufferStartPos` in the buffer.
	- Parameter maxBufferSize: The maximum number of bytes the buffer can hold (from the start of the buffer).
	- Parameter totalNReadBytes: The total number of bytes read from the stream so far. Incremented by the number of bytes read in the function on output.
	- Parameter stream: The stream from which to read new bytes if needed.
	- Throws: `BSONSerializationError` in case of error.
	- Returns: The required type.
	*/
	private class func readDataFromBuffer(dataSize size: Int, alwaysCopyBytes: Bool, buffer: UnsafeMutablePointer<UInt8>, inout bufferStartPos: Int, inout bufferValidLength: Int, maxBufferSize: Int, inout totalNReadBytes: Int, stream: NSInputStream) throws -> NSData {
		assert(maxBufferSize > 0)
		assert(bufferStartPos <= maxBufferSize)
		assert(bufferValidLength <= maxBufferSize - bufferStartPos)
		
		let bufferStart = buffer.advancedBy(bufferStartPos)
		
		switch size {
		case let s where s <= maxBufferSize - bufferStartPos:
			/* The buffer is big enough to hold the size we want to read, from
			 * buffer start pos. */
			return try readDataInBigEnoughBuffer(
				dataSize: size,
				bufferHandling: (alwaysCopyBytes ? .CopyBytes : .UseBufferLeaveOwnership),
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
			buffer.assignFrom(bufferStart, count: bufferValidLength); bufferStartPos = 0
			return try readDataInBigEnoughBuffer(
				dataSize: size,
				bufferHandling: (alwaysCopyBytes ? .CopyBytes : .UseBufferLeaveOwnership),
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
			if m == nil {throw BSONSerializationError.CannotAllocateMemory(size)}
			let biggerBuffer = unsafeBitCast(m, UnsafeMutablePointer<UInt8>.self)
			
			/* Copying data in our given buffer to the new buffer. */
			biggerBuffer.assignFrom(bufferStart, count: bufferValidLength) /* size is greater than maxBufferSize. We know we will never overflow our own buffer using bufferValidLength */
			var newStartPos = 0, newValidLength = bufferValidLength
			
			bufferStartPos = 0; bufferValidLength = 0
			
			return try readDataInBigEnoughBuffer(
				dataSize: size,
				bufferHandling: .UseBufferTakeOwnership,
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
	private class func readCStringFromBuffer(buffer: UnsafeMutablePointer<UInt8>, inout bufferStartPos: Int, inout bufferValidLength: Int, maxBufferSize: Int, inout totalNReadBytes: Int, stream: NSInputStream) throws -> String {
		/* Let's find the end of the string ('\0') */
		var strBytesLength = 0
		let bufferStart = buffer.advancedBy(bufferStartPos)
		let bufferEnd = bufferStart.advancedBy(bufferValidLength)
		for b in bufferStart..<bufferStart.advancedBy(bufferValidLength) {
			strBytesLength += 1
			guard b.memory != 0 else {
				bufferStartPos += strBytesLength
				bufferValidLength -= strBytesLength
				/* Found the 0 */
				guard let str = String.fromCString(unsafeBitCast(bufferStart, UnsafePointer<CChar>.self)) else {
					throw BSONSerializationError.InvalidUTF8String(NSData(bytes: bufferStart, length: strBytesLength))
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
					newBuffer.assignFrom(newBufferStart, count: newBufferValidLength)
					newBufferStart = newBuffer; newBufferEnd = newBufferStart.advancedBy(newBufferValidLength); newBufferStartPos = 0
					if newBuffer == buffer {bufferStartPos = 0}
				} else {
					/* The buffer is not big enough anymore. We need to create a new
					 * bigger one. */
					bufferStartPos = 0; bufferValidLength = 0
					
					assert(newBufferStartPos == 0)
					
					let oldBuffer = newBuffer
					let oldBufferSize = newMaxBufferSize
					
					newMaxBufferSize += min(newMaxBufferSize, 4*1024 /* 4KB */)
					newBuffer = UnsafeMutablePointer<UInt8>.alloc(newMaxBufferSize)
					if newBuffer == nil {throw BSONSerializationError.CannotAllocateMemory(newMaxBufferSize)}
					newBuffer.assignFrom(oldBuffer, count: newBufferValidLength)
					newBufferStart = newBuffer; newBufferEnd = newBufferStart.advancedBy(newBufferValidLength)
					
					if oldBuffer != buffer {oldBuffer.dealloc(oldBufferSize)}
				}
			}
			
			/* Let's read from the stream now. */
			let r = stream.read(newBufferEnd, maxLength: newMaxBufferSize - (newBufferStartPos + newBufferValidLength))
			guard r > 0 else {throw BSONSerializationError.EarlyStreamEnding}
			newBufferValidLength += r
			totalNReadBytes += r
			
			/* Did we read the end of the string? */
			for b in bufferEnd..<bufferEnd.advancedBy(r) {
				strBytesLength += 1
				guard b.memory != 0 else {
					/* Found the 0 */
					if newBuffer == buffer {
						bufferStartPos += strBytesLength
						bufferValidLength = newBufferValidLength - strBytesLength
					}
					guard let str = String.fromCString(unsafeBitCast(newBufferStart, UnsafePointer<CChar>.self)) else {
						throw BSONSerializationError.InvalidUTF8String(NSData(bytes: bufferStart, length: strBytesLength))
					}
					return str
				}
			}
			newBufferEnd = newBufferStart.advancedBy(newBufferValidLength)
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
	private class func readStringFromBuffer(buffer: UnsafeMutablePointer<UInt8>, inout bufferStartPos: Int, inout bufferValidLength: Int, maxBufferSize: Int, inout totalNReadBytes: Int, stream: NSInputStream) throws -> String {
		let stringSize: Int32 = try readTypeFromBuffer(buffer, bufferStartPos: &bufferStartPos, bufferValidLength: &bufferValidLength, maxBufferSize: maxBufferSize, totalNReadBytes: &totalNReadBytes, stream: stream)
		let data = try readDataFromBuffer(dataSize: Int(stringSize)-1, alwaysCopyBytes: false, buffer: buffer, bufferStartPos: &bufferStartPos, bufferValidLength: &bufferValidLength, maxBufferSize: maxBufferSize, totalNReadBytes: &totalNReadBytes, stream: stream)
		assert(data.length == Int32(stringSize)-1)
		guard let str = String(data: data, encoding:NSUTF8StringEncoding) else {
			throw BSONSerializationError.InvalidUTF8String(data)
		}
		let _ = try readDataFromBuffer(dataSize: 1, alwaysCopyBytes: false, buffer: buffer, bufferStartPos: &bufferStartPos, bufferValidLength: &bufferValidLength, maxBufferSize: maxBufferSize, totalNReadBytes: &totalNReadBytes, stream: stream)
		return str
	}
	
}
