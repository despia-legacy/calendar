#!/bin/bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(mktemp -d "${TMPDIR:?Set TMPDIR to an approved work directory}/despia-calendar.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
python3 - "$HERE/../ios/app/CalendarExtension.swift" "$WORK/Values.swift" <<'PYTHON'
from pathlib import Path
import sys
source=Path(sys.argv[1]).read_text()
Path(sys.argv[2]).write_text('import Foundation\nimport CoreFoundation\nimport EventKit\nimport CoreLocation\n'+source[source.index('enum CalendarFailure:'):])
PYTHON
cp "$HERE/values.swift" "$WORK/main.swift"
swiftc -swift-version 5 "$WORK/Values.swift" "$WORK/main.swift" -o "$WORK/calendar-values"
"$WORK/calendar-values"
