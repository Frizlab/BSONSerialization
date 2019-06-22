/*
 * TestHelpers.swift
 * BSONSerialization
 *
 * Created by François Lamboley on 18/12/2016.
 * Copyright © 2016 frizlab. All rights reserved.
 */

import Foundation



extension Data {
	
	/* "FC"   --> Returns data with bytes [0xFC]
	 * "A"    --> Returns data with bytes [0xA]
	 * "FCA"  --> Returns data with bytes [OxFC, 0x0A]
	 * "FC0A" --> Returns data with bytes [OxFC, 0x0A]
	 * ""     --> Returns data with bytes []
	 *
	 * Spaces are removed from input string ("AB CD 12" == "ABCD12"). */
	init?(hexEncoded str: String) {
		let str = str.replacingOccurrences(of: " ", with: "")
		let size = str.count/2 + (str.count%2 == 0 ? 0 : 1)
		var bytes = [UInt8](repeating: 0, count: size)
		for (i, c) in str.enumerated() {
			let byteNumber = i/2
			if i%2 == 1 {bytes[byteNumber] *= 0x10}
			
			switch c {
			case "0": bytes[byteNumber] += 0
			case "1": bytes[byteNumber] += 1
			case "2": bytes[byteNumber] += 2
			case "3": bytes[byteNumber] += 3
			case "4": bytes[byteNumber] += 4
			case "5": bytes[byteNumber] += 5
			case "6": bytes[byteNumber] += 6
			case "7": bytes[byteNumber] += 7
			case "8": bytes[byteNumber] += 8
			case "9": bytes[byteNumber] += 9
			case "a", "A": bytes[byteNumber] += 10
			case "b", "B": bytes[byteNumber] += 11
			case "c", "C": bytes[byteNumber] += 12
			case "d", "D": bytes[byteNumber] += 13
			case "e", "E": bytes[byteNumber] += 14
			case "f", "F": bytes[byteNumber] += 15
			default: return nil
			}
		}
		self.init(bytes)
	}
	
	func hexEncodedString(withSpaces: Bool = true) -> String {
		var res = ""
		var first = true
		for b in self {
			if !first && withSpaces {res += " "}
			res += String(format: "%02x", b)
			first = false
		}
		return res.uppercased()
	}
	
}
