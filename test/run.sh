#!/usr/bin/env bash
# Every suite, one after the other; fails if any of them does.
# Usage: test/run.sh [-q]    (-q: failures and totals only)
here=$(dirname "$(realpath "${BASH_SOURCE[0]}")")
failed=0
for suite in "$here"/test-*.sh; do
    echo "━━━ ${suite##*/}"
    if [[ $1 == -q ]]; then
        bash "$suite" 2>&1 | grep -E '^  ✗|^      |^[0-9]+ passed'
        ((PIPESTATUS[0] == 0)) || failed=$((failed + 1))
    else
        bash "$suite" || failed=$((failed + 1))
    fi
done
echo
((failed == 0)) && echo "All suites passed." || echo "$failed suite(s) failed."
((failed == 0))
