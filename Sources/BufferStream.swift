/*
 * BufferStream.swift
 * BSONSerialization
 *
 * Created by François Lamboley on 12/4/16.
 * Copyright © 2016 frizlab. All rights reserved.
 */

import Foundation



enum BufferStreamError : Error {
	
	/** The stream ended before the required data size could be read. */
	case noMoreData
	
	/** The maximum number of bytes allowed to be read from the stream have been
	read.
	
	- Important: Do not assume the position of the stream is necessarily at the
	max number of bytes allowed to be read. For optimization reasons, we might
	throw this error before all the bytes have actually been read from the
	stream. */
	case streamReadSizeLimitReached
	
	/** An error occurred reading the stream. */
	case streamReadError(streamError: Error?)
	
	/** Cannot find any of the delimiters in the stream when using the
	`readData(upToDelimiters:...)` method. (All of the stream has been read, or 
	the stream limit has been reached if this error is thrown.) */
	case delimitersNotFound
	
	/** Cannot allocate memory (either with `malloc` or `UnsafePointer.alloc()`). */
	case cannotAllocateMemory(Int)
	
}



/** How to match the delimiters for the `readData(upToDelimiters:...)` method.

In the description of the different cases, we'll use a common example:

- We'll use a `BufferedInputStream`, which uses a cache to hold some of the data
read from the stream;
- The delimiters will be (in this order):
   - `"45"`
   - `"67"`
   - `"234"`
   - `"12345"`

- The full data in the stream will be: `"0123456789"`;
- In the cache, we'll only have `"01234"` read. */
enum BufferStreamDelimiterMatchingMode {
	
	/** The lightest match algorithm (usually). In the given example, the third
	delimiter (`"234"`) will match, because the `BufferedInputStream` will first
	try to match the delimiters against what it already have in memory.
	
	- Note: This is our current implementation of this type of `BufferStream`.
	However, any delimiter can match, the implementation is really up to the
	implementer… However, implementers should keep in mind the goal of this
	matching mode, which is to match and return the data in the quickest way
	possible. */
	case anyMatchWins
	
	/** The matching delimiter that gives the shortest data will be used. In our
	example, it will be the fourth one (`"12345"`) which will yield the shortest
	data (`"0"`). */
	case shortestDataWins
	
	/** The matching delimiter that gives the longest data will be used. In our
	example, it will be the second one (`"67"`) which will yield the longest data
	(`"012345"`).
	
	- Important: Use this matching mode with care! It might have to read all of
	the stream (and thus fill the memory with it) to be able to correctly
	determine which match yields the longest data. Actually, the only case where
	the result can be returned safely before reaching the end of the data is when
	all of the delimiters match… */
	case longestDataWins
	
	/** The first matching delimiter will be used. In our example, it will be the
	first one (`"45"`).
	
	- Important: Use this matching mode with care! It might have to read all of
	the stream (and thus fill the memory with it) to be able to correctly
	determine the first match. Actually, the only case where the result can be
	returned safely before reaching the end of the data is when the first
	delimiter matches, or when all the delimiters have matched…
	
	- Note: If you need something like `latestMatchingDelimiterWins` or
	`shortestMatchingDelimiterWins` you can do it yourself by using this matching
	mode and simply sorting your delimiters list before giving it to the
	function.*/
	case firstMatchingDelimiterWins
	
}



internal protocol BufferStream {
	
	/** The index of the first byte returned from the stream at the next read,
	where 0 is the first byte of the stream.
	
	This is also the number of bytes that has been returned by the different read
	methods of the stream. */
	var currentReadPosition: Int {get}
	
	/** Read the given size from the buffer and returns it in a Data object.
	
	For performance reasons, you can specify you don't want to own the retrieved
	bytes by setting `alwaysCopyBytes` to `false`, in which case, you should be
	careful NOT to do any operation on the stream and make it stay in memory
	while you hold on to the returned data.
	
	- Parameter size: The size you want to read from the buffer.
	- Parameter alwaysCopyBytes: Whether to copy the bytes in the returned Data.
	- Throws: If any error occurs reading the data (including end of stream
	reached before the given size is read), an error is thrown.
	- Returns: The read Data. */
	func readData(size: Int, alwaysCopyBytes: Bool) throws -> Data
	
	/** Read from the stream, until one of the given delimiters is found. An
	empty delimiter matches nothing.
	
	If the delimiters list is empty, the data is read to the end of the stream
	(or the stream size limit).
	
	If none of the given delimiter matches, the `delimitersNotFound` error is
	thrown.
	
	Choose your matching mode with care. Some mode may have to read and put the
	whole stream in an internal cache before being able to return the data you
	want.
	
	For performance reasons, you can specify you don't want to own the retrieved
	bytes by setting `alwaysCopyBytes` to `false`, in which case, you should be
	careful NOT to do any operation on the stream and make it stay in memory
	while you hold on to the returned data.
	
	- Important: If the delimiters list is empty, the stream is read until the
	end (either end of stream or stream size limit is reached). If the delimiters
	list is **not** empty but no delimiters match, the `delimitersNotFound` error
	is thrown.
	
	- Parameter upToDelimiters: The delimiters you want to stop reading at. Once
	any of the given delimiters is reached, the read data is returned.
	- Parameter matchingMode: How to choose which delimiter will stop the reading
	of the data.
	- Parameter alwaysCopyBytes: Whether to copy the bytes in the returned Data.
	- Throws: If any error occurs reading the data (including end of stream
	reached before any of the delimiters is reached), an error is thrown.
	- Returns: The read Data. */
	func readData(upToDelimiters: [Data], matchingMode: BufferStreamDelimiterMatchingMode, includeDelimiter: Bool, alwaysCopyBytes: Bool) throws -> Data
	
}



internal extension BufferStream {
	
	func readType<Type>() throws -> Type {
		let data = try readData(size: MemoryLayout<Type>.size, alwaysCopyBytes: false)
		return data.withUnsafeBytes { (_ bytes: UnsafePointer<UInt8>) -> Type in
			return bytes.withMemoryRebound(to: Type.self, capacity: 1) { pointer -> Type in
				return pointer.pointee
			}
		}
	}
	
}



internal class BufferedInputStream : BufferStream {
	
	let sourceStream: InputStream
	
	var currentReadPosition = 0
	
	/** The maximum total number of bytes to read from the stream. Can be changed
	after some bytes have been read.
	
	If set to nil, there are no limits.
	
	If set to a value lower than or equal to the current total number of bytes
	read, no more bytes will be read from the stream, and the
	`.streamReadSizeLimitReached` error will be thrown when trying to read more
	data (if the current internal buffer end is reached). */
	var streamReadSizeLimit: Int?
	
	/** Initializes a BufferedInputStream.
	
	- Parameter stream: The stream to read data from. Must be opened.
	- Parameter bufferSize: The size of the buffer to use to read from the
	stream. Sometimes, more memory might be allocated if needed for some reads.
	- Parameter streamReadSizeLimit: The maximum number of bytes allowed to be
	read from the stream.
	*/
	init(stream: InputStream, bufferSize size: Int, streamReadSizeLimit streamLimit: Int?) {
		assert(size > 0)
		
		sourceStream = stream
		
		defaultBufferSize = size
		defaultSizedBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: size)
//		if defaultSizedBuffer == nil {throw BufferStreamError.cannotAllocateMemory(size)}
		
		buffer = defaultSizedBuffer
		bufferSize = defaultBufferSize
		
		bufferStartPos = 0
		bufferValidLength = 0
		totalReadBytesCount = 0
		streamReadSizeLimit = streamLimit
	}
	
	deinit {
		if buffer != defaultSizedBuffer {buffer.deallocate(capacity: bufferSize)}
		defaultSizedBuffer.deallocate(capacity: defaultBufferSize)
	}
	
	func readData(size: Int, alwaysCopyBytes: Bool) throws -> Data {
		let data = try readDataNoCurrentPosIncrement(size: size, alwaysCopyBytes: alwaysCopyBytes)
		currentReadPosition += data.count
		return data
	}
	
	private func readDataNoCurrentPosIncrement(size: Int, alwaysCopyBytes: Bool) throws -> Data {
		let bufferStart = buffer.advanced(by: bufferStartPos)
		
		switch size {
		case let s where s <= bufferSize - bufferStartPos:
			/* The buffer is big enough to hold the size we want to read, from
			 * buffer start pos. */
			return try readDataInBigEnoughBuffer(
				dataSize: size,
				allowReadingMore: true,
				bufferHandling: (alwaysCopyBytes ? .copyBytes : .useBufferLeaveOwnership),
				buffer: buffer,
				bufferStartPos: &bufferStartPos,
				bufferValidLength: &bufferValidLength,
				bufferSize: bufferSize,
				totalReadBytesCount: &totalReadBytesCount,
				maxTotalReadBytesCount: streamReadSizeLimit,
				stream: sourceStream
			)
			
		case let s where s <= defaultBufferSize:
			/* The default sized buffer is enough to hold the size we want to read.
			 * Let's copy the current buffer to the beginning of the default sized
			 * buffer! And get rid of the old (bigger) buffer if needed. */
			defaultSizedBuffer.assign(from: bufferStart, count: bufferValidLength); bufferStartPos = 0
			if defaultSizedBuffer != buffer {
				buffer.deallocate(capacity: bufferSize)
				buffer = defaultSizedBuffer
				bufferSize = defaultBufferSize
			}
			return try readDataInBigEnoughBuffer(
				dataSize: size,
				allowReadingMore: true,
				bufferHandling: (alwaysCopyBytes ? .copyBytes : .useBufferLeaveOwnership),
				buffer: buffer,
				bufferStartPos: &bufferStartPos,
				bufferValidLength: &bufferValidLength,
				bufferSize: bufferSize,
				totalReadBytesCount: &totalReadBytesCount,
				maxTotalReadBytesCount: streamReadSizeLimit,
				stream: sourceStream
			)
			
		case let s where s <= bufferSize:
			/* The current buffer total size is enough to hold the size we want to
			 * read. However, we must relocate data in the buffer so the buffer
			 * start position is 0. */
			buffer.assign(from: bufferStart, count: bufferValidLength); bufferStartPos = 0
			return try readDataInBigEnoughBuffer(
				dataSize: size,
				allowReadingMore: true,
				bufferHandling: (alwaysCopyBytes ? .copyBytes : .useBufferLeaveOwnership),
				buffer: buffer,
				bufferStartPos: &bufferStartPos,
				bufferValidLength: &bufferValidLength,
				bufferSize: bufferSize,
				totalReadBytesCount: &totalReadBytesCount,
				maxTotalReadBytesCount: streamReadSizeLimit,
				stream: sourceStream
			)
			
		default:
			/* The buffer is not big enough to hold the data we want to read. We
			 * must create a new buffer. */
//			print("Got too small buffer of size \(bufferSize) to read size \(size) from buffer. Retrying with a bigger buffer.")
			/* NOT free'd here. Free'd later when set in Data, or by the readDataInBigEnoughBuffer function. */
			guard let m = malloc(size) else {throw BufferStreamError.cannotAllocateMemory(size)}
			let biggerBuffer = m.assumingMemoryBound(to: UInt8.self)
			
			/* Copying data in our given buffer to the new buffer. */
			biggerBuffer.assign(from: bufferStart, count: bufferValidLength) /* size is greater than bufferSize. We know we will never overflow our own buffer using bufferValidLength */
			var newStartPos = 0, newValidLength = bufferValidLength
			
			bufferStartPos = 0; bufferValidLength = 0
			
			return try readDataInBigEnoughBuffer(
				dataSize: size,
				allowReadingMore: false, /* Not actually needed as the buffer size is exactly of the required size... */
				bufferHandling: .useBufferTakeOwnership,
				buffer: biggerBuffer,
				bufferStartPos: &newStartPos,
				bufferValidLength: &newValidLength,
				bufferSize: size,
				totalReadBytesCount: &totalReadBytesCount,
				maxTotalReadBytesCount: streamReadSizeLimit,
				stream: sourceStream
			)
		}
	}
	
	func readData(upToDelimiters delimiters: [Data], matchingMode: BufferStreamDelimiterMatchingMode, includeDelimiter: Bool, alwaysCopyBytes: Bool) throws -> Data {
		let (minDelimiterLength, maxDelimiterLength) = delimiters.reduce((delimiters.first?.count ?? 0, 0)) { (min($0.0, $1.count), max($0.1, $1.count)) }
		
		var unmatchedDelimiters = Array(delimiters.enumerated())
		var matchedDatas = [(delimiterIdx: Int, dataLength: Int)]()
		
		var searchOffset = 0
		repeat {
			assert(bufferValidLength - searchOffset >= 0)
			let bufferStart = buffer.advanced(by: bufferStartPos)
			let bufferSearchData = Data(bytesNoCopy: bufferStart.advanced(by: searchOffset), count: bufferValidLength - searchOffset, deallocator: .none)
			if let returnedLength = matchDelimiters(inData: bufferSearchData, usingMatchingMode: matchingMode, includeDelimiter: includeDelimiter, minDelimiterLength: minDelimiterLength, withUnmatchedDelimiters: &unmatchedDelimiters, matchedDatas: &matchedDatas) {
				bufferStartPos += returnedLength
				bufferValidLength -= returnedLength
				currentReadPosition += returnedLength
				return (alwaysCopyBytes ? Data(bytes: bufferStart, count: returnedLength) : Data(bytesNoCopy: bufferStart, count: returnedLength, deallocator: .none))
			}
			
			/* No confirmed match. We have to continue reading the data! */
			searchOffset = max(0, bufferValidLength - maxDelimiterLength + 1)
			
			if bufferStartPos + bufferValidLength >= bufferSize {
				/* The buffer is not big enough to hold new data... Let's move the
				 * data to the beginning of the buffer or create a new buffer. */
				if bufferStartPos > 0 {
					/* We can move the data to the beginning of the buffer. */
					assert(bufferStart != buffer)
					buffer.assign(from: bufferStart, count: bufferValidLength); bufferStartPos = 0
				} else {
					/* The buffer is not big enough anymore. We need to create a new,
					 * bigger one. */
					assert(bufferStartPos == 0)
					
					let oldBuffer = buffer
					let oldBufferSize = bufferSize
					
					bufferSize += min(bufferSize, 3*1024*1024 /* 3MB */)
					buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
//					if buffer == nil {throw BufferStreamError.cannotAllocateMemory(size)}
					buffer.assign(from: bufferStart, count: bufferValidLength)
					
					if oldBuffer != defaultSizedBuffer {oldBuffer.deallocate(capacity: oldBufferSize)}
				}
			}
			
			/* Let's read from the stream now! */
			let sizeToRead: Int
			let unmaxedSizeToRead = bufferSize - (bufferStartPos + bufferValidLength) /* The remaining space in the buffer */
			if let maxTotalReadBytesCount = streamReadSizeLimit {sizeToRead = min(unmaxedSizeToRead, max(0, maxTotalReadBytesCount - totalReadBytesCount) /* Number of bytes remaining allowed to be read */)}
			else                                                {sizeToRead =     unmaxedSizeToRead}
			
			assert(sizeToRead >= 0)
			if sizeToRead == 0 {/* End of the (allowed) data */break}
			let sizeRead = sourceStream.read(bufferStart.advanced(by: bufferValidLength), maxLength: sizeToRead)
			guard sizeRead >= 0 else {throw BufferStreamError.streamReadError(streamError: sourceStream.streamError)}
			guard sizeRead >  0 else {/* End of the data */break}
			bufferValidLength += sizeRead
			totalReadBytesCount += sizeRead
			assert(streamReadSizeLimit == nil || totalReadBytesCount <= streamReadSizeLimit!)
		} while true
		
		if let returnedLength = findBestMatch(fromMatchedDatas: matchedDatas, usingMatchingMode: matchingMode) {
			bufferStartPos += returnedLength
			bufferValidLength -= returnedLength
			currentReadPosition += returnedLength
			return (alwaysCopyBytes ? Data(bytes: buffer.advanced(by: bufferStartPos), count: returnedLength) : Data(bytesNoCopy: buffer.advanced(by: bufferStartPos), count: returnedLength, deallocator: .none))
		}
		
		if delimiters.count > 0 {throw BufferStreamError.delimitersNotFound}
		else {
			/* We return the whole data. */
			let returnedLength = bufferValidLength
			let bufferStart = buffer.advanced(by: bufferStartPos)
			
			currentReadPosition += bufferValidLength
			bufferStartPos += bufferValidLength
			bufferValidLength = 0
			
			return (alwaysCopyBytes ? Data(bytes: bufferStart, count: returnedLength) : Data(bytesNoCopy: bufferStart, count: returnedLength, deallocator: .none))
		}
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	/* Note: These two variables basically describe an UnsafeRawBufferPointer */
	private let defaultSizedBuffer: UnsafeMutablePointer<UInt8>
	private let defaultBufferSize: Int
	
	private var buffer: UnsafeMutablePointer<UInt8>
	private var bufferSize: Int
	
	private var bufferStartPos: Int
	private var bufferValidLength: Int
	
	/** The total number of bytes read from the source stream. */
	private var totalReadBytesCount = 0
	
}



internal class BufferedData : BufferStream {
	
	let sourceData: Data
	let sourceDataSize: Int
	var currentReadPosition = 0
	
	init(data: Data) {
		sourceData = data
		sourceDataSize = sourceData.count
	}
	
	func readData(size: Int, alwaysCopyBytes: Bool) throws -> Data {
		guard (sourceDataSize - currentReadPosition) >= size else {throw BufferStreamError.noMoreData}
		
		return getNextSubData(size: size, alwaysCopyBytes: alwaysCopyBytes)
	}
	
	func readData(upToDelimiters delimiters: [Data], matchingMode: BufferStreamDelimiterMatchingMode, includeDelimiter: Bool, alwaysCopyBytes: Bool) throws -> Data {
		let minDelimiterLength = delimiters.reduce(delimiters.first?.count ?? 0) { min($0, $1.count) }
		
		var unmatchedDelimiters = Array(delimiters.enumerated())
		var matchedDatas = [(delimiterIdx: Int, dataLength: Int)]()
		
		return try sourceData.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> Data in
			let searchedData = Data(bytesNoCopy: UnsafeMutablePointer<UInt8>(mutating: bytes).advanced(by: currentReadPosition), count: sourceDataSize-currentReadPosition, deallocator: .none)
			if let returnedLength = matchDelimiters(inData: searchedData, usingMatchingMode: matchingMode, includeDelimiter: includeDelimiter, minDelimiterLength: minDelimiterLength, withUnmatchedDelimiters: &unmatchedDelimiters, matchedDatas: &matchedDatas) {
				return getNextSubData(size: returnedLength, alwaysCopyBytes: alwaysCopyBytes)
			}
			if let returnedLength = findBestMatch(fromMatchedDatas: matchedDatas, usingMatchingMode: matchingMode) {
				return getNextSubData(size: returnedLength, alwaysCopyBytes: alwaysCopyBytes)
			}
			if delimiters.count == 0 {return getNextSubData(size: sourceDataSize - currentReadPosition, alwaysCopyBytes: alwaysCopyBytes)}
			else                     {throw BufferStreamError.delimitersNotFound}
		}
	}
	
	private func getNextSubData(size: Int, alwaysCopyBytes: Bool) -> Data {
		let nextPosition = currentReadPosition + size
		let range = Range<Int>(currentReadPosition..<nextPosition)
		currentReadPosition = nextPosition
		
		if alwaysCopyBytes {return sourceData.subdata(in: range)}
		else               {return sourceData.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> Data in
			/* Not sure if the unsafeBitCast below is so safe... It should be
			 * because we'll never modify the data object. */
			return Data(bytesNoCopy: UnsafeMutablePointer<UInt8>(mutating: bytes).advanced(by: range.lowerBound), count: size, deallocator: .none)
		}}
	}
	
}



/* ***************
   MARK: - Private
   *************** */

/* *****************************
   MARK: → For read data of size
   ***************************** */

private enum BufferHandling {
	/** Copy the bytes from the buffer to the new Data object. */
	case copyBytes
	/** Create the Data with bytes from the buffer directly without copying.
	Buffer ownership stays to the caller, which means the Data object is
	invalid as soon as the buffer is released (and modified when the buffer is
	modified). */
	case useBufferLeaveOwnership
	/** Create the Data with bytes from the buffer directly without copying.
	Takes buffer ownership, which must have been alloc'd using alloc(). */
	case useBufferTakeOwnership
}

/** Reads and return the asked size from the buffer and completes with the
stream if needed. Uses the given buffer to read the first bytes and store the
bytes read from the stream if applicable. The buffer must be big enough to
contain the asked size from `bufferStartPos`.

- Parameter dataSize: The size of the data to return.
- Parameter allowReadingMore: If `true`, this method may read more data than what is actually needed from the stream.
- Parameter bufferHandling: How to handle the buffer for the Data object creation. See the `BufferHandling` enum.
- Parameter buffer: The buffer from which to start reading the bytes.
- Parameter bufferStartPos: Where to start reading the data from in the given buffer.
- Parameter bufferValidLength: The valid number of bytes from `bufferStartPos` in the buffer.
- Parameter bufferSize: The maximum number of bytes the buffer can hold (from the start of the buffer).
- Parameter totalReadBytesCount: The total number of bytes read from the stream so far. Incremented by the number of bytes read in the function on output.
- Parameter maxTotalReadBytesCount: The maximum number of total bytes allowed to be read from the stream.
- Parameter stream: The stream from which to read new bytes if needed.
- Throws: `BufferStreamError` in case of error.
- Returns: The read data from the buffer or the stream if necessary.
*/
private func readDataInBigEnoughBuffer(dataSize size: Int, allowReadingMore: Bool, bufferHandling: BufferHandling, buffer: UnsafeMutablePointer<UInt8>, bufferStartPos: inout Int, bufferValidLength: inout Int, bufferSize: Int, totalReadBytesCount: inout Int, maxTotalReadBytesCount: Int?, stream: InputStream) throws -> Data {
	assert(bufferSize >= size)
	
	let bufferStart = buffer.advanced(by: bufferStartPos)
	
	if bufferValidLength < size {
		/* We must read from the stream. */
		if let maxTotalReadBytesCount = maxTotalReadBytesCount, maxTotalReadBytesCount < totalReadBytesCount || size - bufferValidLength /* To read from stream */ > maxTotalReadBytesCount - totalReadBytesCount /* Remaining allowed bytes to be read */ {
			/* We have to read more bytes from the stream than allowed. We bail. */
			throw BufferStreamError.streamReadSizeLimitReached
		}
		
		repeat {
			let sizeToRead: Int
			if !allowReadingMore {sizeToRead = size - bufferValidLength /* Checked to fit in the remaining bytes allowed to be read in "if" before this loop */}
			else {
				let unmaxedSizeToRead = bufferSize - (bufferStartPos + bufferValidLength) /* The remaining space in the buffer */
				if let maxTotalReadBytesCount = maxTotalReadBytesCount {sizeToRead = min(unmaxedSizeToRead, maxTotalReadBytesCount - totalReadBytesCount /* Number of bytes remaining allowed to be read */)}
				else                                                   {sizeToRead =     unmaxedSizeToRead}
			}
			assert(sizeToRead > 0)
			let sizeRead = stream.read(bufferStart.advanced(by: bufferValidLength), maxLength: sizeToRead)
			guard sizeRead > 0 else {
				if bufferHandling == .useBufferTakeOwnership {free(buffer)}
				throw (sizeRead == 0 ? BufferStreamError.noMoreData : BufferStreamError.streamReadError(streamError: stream.streamError))
			}
			bufferValidLength += sizeRead
			totalReadBytesCount += sizeRead
			assert(maxTotalReadBytesCount == nil || totalReadBytesCount <= maxTotalReadBytesCount!)
		} while bufferValidLength < size /* Reading until we have enough data in the buffer. */
	}
	
	bufferValidLength -= size
	bufferStartPos += size
	
	let ret: Data
	switch bufferHandling {
	case .copyBytes:               ret = Data(bytes: bufferStart, count: size)
	case .useBufferTakeOwnership:  ret = Data(bytesNoCopy: bufferStart, count: size, deallocator: .free)
	case .useBufferLeaveOwnership: ret = Data(bytesNoCopy: bufferStart, count: size, deallocator: .none)
	}
	return ret
}

/* ***********************************
   MARK: → For read data to delimiters
   *********************************** */

/* Returns nil if no confirmed matches were found, the length of the matched
 * data otherwise. */
private func matchDelimiters(inData data: Data, usingMatchingMode matchingMode: BufferStreamDelimiterMatchingMode, includeDelimiter: Bool, minDelimiterLength: Int, withUnmatchedDelimiters unmatchedDelimiters: inout [(offset: Int, element: Data)], matchedDatas: inout [(delimiterIdx: Int, dataLength: Int)]) -> Int? {
	for delimiter in unmatchedDelimiters.reversed().enumerated() {
		if let range = data.range(of: delimiter.element.element) {
			/* Found one of the delimiter. Let's see what we do with it... */
			let matchedLength = range.lowerBound + (includeDelimiter ? delimiter.element.element.count : 0)
			switch matchingMode {
			case .anyMatchWins:
				/* We found a match. With this matching mode, this is enough!
				 * We simply return here the data we found, no questions asked. */
				return matchedLength
				
			case .shortestDataWins:
				/* We're searching for the shortest match. A match of 0 is
				 * necessarily the shortest! So we can return straight away when
				 * we find a 0-length match. */
				guard matchedLength > (includeDelimiter ? minDelimiterLength : 0) else {return matchedLength}
				unmatchedDelimiters.remove(at: delimiter.offset)
				matchedDatas.append((delimiterIdx: delimiter.element.offset, dataLength: matchedLength))
				
			case .longestDataWins:
				unmatchedDelimiters.remove(at: delimiter.offset)
				matchedDatas.append((delimiterIdx: delimiter.element.offset, dataLength: matchedLength))
				
			case .firstMatchingDelimiterWins:
				guard delimiter.offset > 0 else {
					/* We're searching for the first matching delimiter. If the
					 * first delimiter matches, we can return the matched data
					 * straight away! */
					return matchedLength
				}
				unmatchedDelimiters.remove(at: delimiter.offset)
				matchedDatas.append((delimiterIdx: delimiter.element.offset, dataLength: matchedLength))
			}
		}
	}
	
	/* Let's search for a confirmed match. We can only do that if all the
	 * delimiters have been matched. All other obvious cases have been taken
	 * care of above. */
	guard unmatchedDelimiters.count == 0 else {return nil}
	return findBestMatch(fromMatchedDatas: matchedDatas, usingMatchingMode: matchingMode)
}

private func findBestMatch(fromMatchedDatas matchedDatas: [(delimiterIdx: Int, dataLength: Int)], usingMatchingMode matchingMode: BufferStreamDelimiterMatchingMode) -> Int? {
	/* We need to have at least one match in order to be able to return smthg. */
	guard let firstMatchedData = matchedDatas.first else {return nil}
	
	switch matchingMode {
	case .anyMatchWins: fatalError("INTERNAL LOGIC FAIL!") /* Any match is a trivial case and should have been filtered prior calling this method... */
	case .shortestDataWins: return matchedDatas.reduce(firstMatchedData, { $0.dataLength < $1.dataLength ? $0 : $1 }).dataLength
	case .longestDataWins:  return matchedDatas.reduce(firstMatchedData, { $0.dataLength > $1.dataLength ? $0 : $1 }).dataLength
	case .firstMatchingDelimiterWins: return matchedDatas.reduce(firstMatchedData, { $0.delimiterIdx < $1.delimiterIdx ? $0 : $1 }).dataLength
	}
}
