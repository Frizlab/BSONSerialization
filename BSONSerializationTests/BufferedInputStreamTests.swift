/*
 * BufferedInputStreamTests.swift
 * BSONSerialization
 *
 * Created by François Lamboley on 18/12/2016.
 * Copyright © 2016 frizlab. All rights reserved.
 */

import XCTest
@testable import BSONSerialization



class BufferStreamTests: XCTestCase {
	
	override func setUp() {
		super.setUp()
		
		/* Setup code goes here. */
	}
	
	override func tearDown() {
		/* Teardown code goes here. */
		
		super.tearDown()
	}
	
	func testReadSmallerThanBufferData() {
		let s = stream(fromData: Data(hexEncoded: "0123456789")!)!
		CFReadStreamOpen(s)
		defer {CFReadStreamClose(s)}
		
		let bs = BufferedInputStream(stream: s, bufferSize: 3, streamSizeLimit: nil)
		let d = try? bs.readData(size: 2, alwaysCopyBytes: false)
		XCTAssert(d == Data(hexEncoded: "0123")!)
	}
	
	func testReadBiggerThanBufferData() {
		let s = stream(fromData: Data(hexEncoded: "0123456789")!)!
		CFReadStreamOpen(s)
		defer {CFReadStreamClose(s)}
		
		let bs = BufferedInputStream(stream: s, bufferSize: 3, streamSizeLimit: nil)
		let d = try? bs.readData(size: 4, alwaysCopyBytes: false)
		XCTAssert(d == Data(hexEncoded: "01234567")!)
	}
	
	/* ***************
	   MARK: - Helpers
	   *************** */
	
	private func stream(fromData data: Data) -> CFReadStream? {
		let dataBytes = (data as NSData).bytes
		
		/* We must not release the bytes memory (which explains the latest
		 * argument to the stream creation function): the data object will do it
		 * when released (after the stream has finished being used). */
		guard let stream = CFReadStreamCreateWithBytesNoCopy(kCFAllocatorDefault, unsafeBitCast(dataBytes, to: UnsafePointer<UInt8>.self), data.count, kCFAllocatorNull) else {
			return nil
		}
		return stream
	}
	
}
