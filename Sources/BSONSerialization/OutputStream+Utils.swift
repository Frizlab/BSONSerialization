/*
 * OutputStream+Utils.swift
 * BSONSerialization
 *
 * Created by François Lamboley on 2022/02/09.
 * Copyright © 2022 frizlab. All rights reserved.
 */

import Foundation



extension OutputStream {
	
	func write(dataPtr: UnsafeRawBufferPointer) throws -> Int {
		var countToWrite = dataPtr.count
		guard countToWrite > 0 else {return 0}
		
		/* Note: Joe says we can bind the memory (or even assume it’s already bound) to UInt8
		 *       because the memory will be immutable in the closure, and thus cannot be aliased.
		 * https://twitter.com/jckarter/status/1142446184700624896 */
		var memToWrite = dataPtr.bindMemory(to: UInt8.self).baseAddress! /* !-safe because we have checked against a 0-length buffer. */
		while countToWrite > 0 {
			/* Note: This blocks until at least 1 byte is written to the stream (or an error occurs). */
			let writeRes = write(memToWrite, maxLength: countToWrite)
			guard writeRes > 0 else {throw Err.cannotWriteToStream(streamError: streamError)}
			
			memToWrite = memToWrite.advanced(by: writeRes)
			countToWrite -= writeRes
		}
		
		return dataPtr.count
	}
	
}
