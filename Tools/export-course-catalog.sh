#!/bin/sh
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
mkdir -p .build
TASK_BIN=$(swift build -c release --show-bin-path)
if [ -f "$TASK_BIN/PokerCore.o" ]; then
  set -- "$TASK_BIN/PokerCore.o"
else
  set -- "$TASK_BIN"/PokerCore.build/*.swift.o
fi
swiftc -parse-as-library -I "$TASK_BIN" -I "$TASK_BIN/Modules" Tools/CourseCatalogManifest.swift "$@" -o .build/course-catalog-manifest
.build/course-catalog-manifest .build/course-catalog-manifest.json
