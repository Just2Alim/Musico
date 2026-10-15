#!/usr/bin/env bash
set -euo pipefail

coverage_file="coverage/lcov.info"
if [[ ! -f "$coverage_file" ]]; then
  echo "Missing $coverage_file; run flutter test --coverage first." >&2
  exit 2
fi

awk -F: '
  /^LF:/ { total += $2 }
  /^LH:/ { hit += $2 }
  END {
    if (total == 0) {
      print "Coverage report contains no executable lines." > "/dev/stderr"
      exit 2
    }
    percent = 100 * hit / total
    printf "Line coverage: %d/%d = %.1f%%\n", hit, total, percent
    if (percent < 80) {
      print "Project requirement is at least 80% line coverage." > "/dev/stderr"
      exit 1
    }
  }
' "$coverage_file"
