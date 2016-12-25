# BSONSerialization
BSON Serialization in native Swift 3

## Installation & Compatibility
Currently BSONSerialization has been tested on macOS only, in Xcode 8.2.1

It should work by just archiving the project and retrieving the resulting
framework. This framework can then be used normally in a macOS project.

A SwiftPM compatible version of the project will soon be done.

## Usage
`BSONSerialization` has the same basic interface than `JSONSerialization`.

Most BSON frameworks create a specific type in which you can insert new
data, then retrieve the serialized bytes from, etc.
This project takes a different approach. It is merely a converter from the
serialized BSON data to actual Foundation or native objects, or the  reverse
(just like Foundation’s `JSONSerialization` is a converter from Foundation
objects to the serialized JSON data).

Example of use:
```swift
let myFirstBSONDoc = ["key": "value"]
let serializedBSONDoc = try BSONSerialization.data(withBSONObject: myFirstBSONDoc, options: [])
let unserializedBSONDoc = try BSONSerialization.BSONObject(data: serializedBSONDoc, options: [])
areBSONDocEqual(myFirstBSONDoc, unserializedBSONDoc) /* Returns true */
```

Serializing/deserializing to/from a stream is also supported. (Note: Due to
the BSON format, serializing to a Data object is faster than serializing to
a stream.)

## Alternative
If you prefer having an actual BSON object to which you can add elements
instead of standard Foundation object which are serialized later, I would
recommend you go check this project: https://github.com/OpenKitten/BSON

## Reference
I used the BSON specification version 1.1 from http://bsonspec.org/spec.html

All types in this specification, including deprecated ones are supported.
