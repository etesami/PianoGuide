#!/bin/sh
# Runs the PianoCore unit tests (XCTest via SwiftPM).
#   scripts/check-core.sh                                         -> run tests
#   scripts/check-core.sh --write-samples App/Resources/SampleSongs  -> regenerate sample .mid files
set -e
cd "$(dirname "$0")/.."
if [ "$1" = "--write-samples" ]; then
  DIR=$(cd "$2" && pwd)
  cd Packages/PianoCore && exec swift run write-samples "$DIR"
fi
cd Packages/PianoCore && swift test
