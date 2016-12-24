/*
 * BufferedInputStreamTests.swift
 * BSONSerialization
 *
 * Created by François Lamboley on 18/12/2016.
 * Copyright © 2016 frizlab. All rights reserved.
 */

import XCTest
import Foundation
@testable import BSONSerialization



class BufferedInputStreamTests: XCTestCase {
	
	override func setUp() {
		super.setUp()
		
		/* Setup code goes here. */
	}
	
	override func tearDown() {
		/* Teardown code goes here. */
		
		super.tearDown()
	}
	
	func testReadSmallerThanBufferData() {
		let s = InputStream(data: Data(hexEncoded: "01 23 45 67 89")!)
		s.open(); defer {s.close()}
		
		let bs = BufferedInputStream(stream: s, bufferSize: 3, streamReadSizeLimit: nil)
		let d = try? bs.readData(size: 2, alwaysCopyBytes: false)
		XCTAssert(d == Data(hexEncoded: "01 23")!)
	}
	
	func testReadBiggerThanBufferData() {
		let s = InputStream(data: Data(hexEncoded: "01 23 45 67 89")!)
		s.open(); defer {s.close()}
		
		let bs = BufferedInputStream(stream: s, bufferSize: 3, streamReadSizeLimit: nil)
		let d = try? bs.readData(size: 4, alwaysCopyBytes: false)
		XCTAssert(d == Data(hexEncoded: "01 23 45 67")!)
	}
	
}
