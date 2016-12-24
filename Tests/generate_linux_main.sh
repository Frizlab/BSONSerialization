#!/bin/bash

cd "$(dirname "$0")"

output_file="LinuxMain.swift"

>"$output_file"
echo "import XCTest" >>"$output_file"
echo >>"$output_file"

find . -type d | while read test_module; do
	if [ "$test_module" != "." ]; then
		echo "@testable import $(basename "$test_module")" >>"$output_file"
	fi
done
echo >>"$output_file"

echo "var tests: [XCTestCaseEntry] = [" >>"$output_file"
find . -type d | while read test_module; do
	for test_file in "$test_module"/*.swift; do
		echo "	testCase([" >>"$output_file"
		test_file_class="$(basename "$test_file" .swift)"
		cat "$test_file" | grep -E 'func\stest' | sed -E -e 's|^.*func (.*)\(\).*'"|		(\"\1\", $test_file_class.\1),|" >>"$output_file"
		echo "	])," >>"$output_file"
	done
done
echo "]" >>"$output_file"
echo "XCTMain(tests)" >>"$output_file"
