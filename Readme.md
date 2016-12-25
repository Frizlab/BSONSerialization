# BSONSerialization
BSON Serialization in native Swift 3

## Installation & Compatibility
The recommended (and only tested) way to install and use BSONSerialization is
via `SwiftPM`.

The content of your `Package.swift` should be something resembling:
```swift
import PackageDescription

let package = Package(
	name: "toto",
	dependencies: [.Package(url: "https://github.com/Frizlab/BSONSerialization.git", majorVersion: 0, minorVersion: 9)]
)
```

Note: This repository also comes with an xcodeproj file. The Xcode project has
been configured to create a macOS Framework when archived. Though untested, the
framework should be usable as-is in any “pure Swift” macOS application. For Objc
projects, there’s probably some more work to do for the headers to be correct…
Finally, for iOS application, creating a target to have an iOS compatible
framework should be easy to do. Pull requests are welcome 😉

## Usage
`BSONSerialization` has the same basic interface than `JSONSerialization`.

Example of use:
```swift
let myFirstBSONDoc = ["key": "value"]
let serializedBSONDoc = try BSONSerialization.data(withBSONObject: myFirstBSONDoc, options: [])
let unserializedBSONDoc = try BSONSerialization.BSONObject(data: serializedBSONDoc, options: [])
areBSONDocEqual(myFirstBSONDoc, unserializedBSONDoc) /* Returns true */
```

Serializing/deserializing to/from a stream is also supported. (Note: Due to the
specifications of the BSON format, serializing to a Data object is faster than
serializing to a stream.)

Finally, a method lets you know if a given dictionary can be serialized as a
BSON document.

## Alternatives
First, a word about the philosophy of this project. Most BSON frameworks create
a whole new type to represent the BSON document. This is useful to add new
elements to the documents and have the document serialization ready at all times.

This project takes a different approach. It is merely a converter from the
serialized BSON data to actual Foundation or native objects, or the reverse.
It is actually just like Foundation’s `JSONSerialization` which is a converter
from Foundation objects to the serialized JSON data.

If you prefer having an actual BSON object to which you can add elements
instead of standard Foundation object which are serialized later, I would
recommend this project: https://github.com/OpenKitten/BSON

## Reference
I used the BSON specification version 1.1 from http://bsonspec.org/spec.html

All types in this specification, including deprecated ones are supported.

## To do
- Allow direct serialization of `Data` object instead of having to use the
`MongoBinary` type
- Allow serializing Int64 or Int32 to Int directly, depending on the platform
- Xcode target for an iOS Framework

I’ll work seriously on the project if it gains enough attention. Feel free to
open issues, I’ll do my best to answer.

Pull requests are welcome 😉

## License
MIT (see License.txt file)
