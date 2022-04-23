#!/usr/bin/env bash
if type "swift-format" > /dev/null 2>&1; then
    swift-format -p --recursive ./Sources ./Tests --in-place
else
    swift run --skip-build -c release --package-path Tools swift-format -p --recursive ./Sources ./Tests --in-place
fi