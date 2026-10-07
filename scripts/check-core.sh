#!/bin/sh
# Runs the PianoCore unit tests (XCTest via SwiftPM).
#   scripts/check-core.sh                                         -> run tests
#   scripts/check-core.sh --write-samples App/Resources/SampleSongs  -> regenerate sample .mid files
#   scripts/check-core.sh --write-test-songs TestSongs              -> regenerate the import test songs
set -e
cd "$(dirname "$0")/.."
if [ "$1" = "--write-samples" ]; then
  DIR=$(cd "$2" && pwd)
  cd Packages/PianoCore && exec swift run write-samples "$DIR"
fi
if [ "$1" = "--write-test-songs" ]; then
  mkdir -p "$2"
  DIR=$(cd "$2" && pwd)
  cd Packages/PianoCore && exec swift run write-samples --test-songs "$DIR"
fi
cd Packages/PianoCore && swift test
