/*
 * Errors.swift
 * BSONSerialization
 *
 * Created by François Lamboley on 2022/02/09.
 * Copyright © 2022 frizlab. All rights reserved.
 */

import Foundation



/** The BSON Serialization errors enum. */
public enum BSONSerializationError : Error {
	
	/** The given data/stream contains too few bytes to be a valid bson doc. */
	case dataTooSmall
	/** The given data size is not the one declared by the bson doc. */
	case dataLengthDoNotMatch
	
	/** The length of the bson doc is invalid. */
	case invalidLength
	/**
	 An invalid element was found.
	 The element is given in argument to this enum case. */
	case invalidElementType(UInt8)
	
	/** Found an invalid bool value (given in arg). */
	case invalidBooleanValue(UInt8)
	
	/**
	 Asked to read an invalid string for the required encoding.
	 The original data that has been tried to be parsed is given in arg of this error. */
	case invalidString(Data)
	/**
	 Invalid end of BSON string found.
	 Expected `NULL` (`0`), but found the bytes given in argument to this enum case (if `nil`, no data can be read after the string). */
	case invalidEndOfString(UInt8?)
	
	/**
	 An invalid key was found in an array:
	 Keys must be integers, sorted in ascending order from `0` to `n-1` (where `n = number of elements in the array`).
	 
	 - Note: Not so sure the increments from one element to the next should necessarily be of one…
	 The doc is pretty vague on the subject.
	 It says:
	 ```text
	 […] with integer values for the keys, starting with 0 and continuing sequentially.
	 […] The keys must be in ascending numerical order.
	 ``` */
	case invalidArrayKey(currentKey: String, previousKey: String?)
	
	/** Found an invalid regular expression options value (the complete options and the faulty character are given in arg). */
	case invalidRegularExpressionOptions(options: String, invalidCharacter: Character)
	/** Found an invalid regular expression value (the regular expression and the parsing error are given in arg). */
	case invalidRegularExpression(pattern: String, error: Error)
	
	/**
	 The JS with scope element gives the raw data length in its definition.
	 If the given length does not match the decoded length, this error is thrown.
	 The expected and actual length are given in the error. */
	case invalidJSWithScopeLength(expected: Int, actual: Int)
	
	/** An error occurred writing the stream. */
	case cannotWriteToStream(streamError: Error?)
	
	/**
	 An invalid BSON object was given to be serialized.
	 The invalid element is passed in argument to this error. */
	case invalidBSONObject(invalidElement: Any)
	/**
	 Tried to serialize an unserializable string (using the C representation).
	 This is due to the fact that the `\0` char can be used in a valid UTF8 string.
	 (Note: the characters `\254` and `\255` can NEVER be used in a valid UTF8 string.
	 Why were they not the separator?)
	 
	 Usually, the BSON strings represented using the C representation are dictionary keys.
	 But they can also be the components of a regexp. */
	case unserializableCString(String)
	
	/** Cannot allocate memory (either with `malloc` or `UnsafePointer.alloc()`). */
	case cannotAllocateMemory(Int)
	/** An internal error occurred rendering the serialization impossible. */
	case internalError
	
}

typealias Err = BSONSerializationError
