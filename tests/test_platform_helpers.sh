#!/usr/bin/env bash
#
# test_platform_helpers.sh — Cross-platform test suite for lib/platform_helpers
#
# Runs on Linux, macOS, and Windows (Git Bash/MSYS2).
# Exit code 0 = all pass, 1 = at least one failure.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$REPO_DIR/lib/platform_helpers"

PASS_COUNT=0
FAIL_COUNT=0

pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  echo "  PASS: $1"
}

fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  echo "  FAIL: $1"
}

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    pass "$desc"
  else
    fail "$desc (expected='$expected', got='$actual')"
  fi
}

assert_gt() {
  local desc="$1" val="$2" threshold="$3"
  if [[ "$val" -gt "$threshold" ]]; then
    pass "$desc"
  else
    fail "$desc (expected > $threshold, got $val)"
  fi
}

assert_ge() {
  local desc="$1" val="$2" threshold="$3"
  if [[ "$val" -ge "$threshold" ]]; then
    pass "$desc"
  else
    fail "$desc (expected >= $threshold, got $val)"
  fi
}

assert_le() {
  local desc="$1" val="$2" threshold="$3"
  if [[ "$val" -le "$threshold" ]]; then
    pass "$desc"
  else
    fail "$desc (expected <= $threshold, got $val)"
  fi
}

assert_match() {
  local desc="$1" pattern="$2" actual="$3"
  if echo "$actual" | grep -qE "$pattern"; then
    pass "$desc"
  else
    fail "$desc (pattern='$pattern', got='$actual')"
  fi
}

# ============================================================
echo "=== Platform Detection ==="
# ============================================================

platform="$(get_platform)"
echo "  Detected platform: $platform"
assert_match "platform is a known value" "^(linux|macos|freebsd|windows|unknown)$" "$platform"

# Verify platform matches what we'd expect from uname
uname_s="$(uname -s 2>/dev/null || echo Unknown)"
case "$uname_s" in
  Linux*)   assert_eq "Linux detected correctly" "linux" "$platform" ;;
  Darwin*)  assert_eq "macOS detected correctly" "macos" "$platform" ;;
  FreeBSD*) assert_eq "FreeBSD detected correctly" "freebsd" "$platform" ;;
  CYGWIN*|MINGW*|MSYS*)
    assert_eq "Windows detected correctly" "windows" "$platform" ;;
esac

# is_wsl returns a boolean exit code
if is_wsl; then
  echo "  WSL detected"
else
  echo "  Not WSL"
fi
pass "is_wsl runs without error"

# ============================================================
echo ""
echo "=== Memory Functions ==="
# ============================================================

total="$(get_total_memory_mb)"
avail="$(get_available_memory_mb)"
pct="$(get_memory_usage_pct)"

echo "  Total: ${total}MB, Available: ${avail}MB, Usage: ${pct}%"

# On all CI runners we expect real memory info
if [[ "$platform" != "windows" && "$platform" != "unknown" ]]; then
  assert_gt "total memory > 0" "$total" 0
  assert_ge "available memory >= 0" "$avail" 0
  assert_ge "usage pct >= 0" "$pct" 0
  assert_le "usage pct <= 100" "$pct" 100
  # Available should be <= total
  if [[ "$avail" -le "$total" ]]; then
    pass "available <= total"
  else
    fail "available ($avail) > total ($total)"
  fi
else
  # Windows/unknown: functions should still return without error
  pass "memory functions returned on $platform (total=$total, avail=$avail)"
fi

# ============================================================
echo ""
echo "=== Process RSS ==="
# ============================================================

my_pid=$$
rss="$(get_pid_rss_kb "$my_pid")"
echo "  Own PID ($my_pid) RSS: ${rss}KB"

# ps -o rss should work on all platforms
assert_ge "own RSS >= 0" "$rss" 0

# Dead PID
dead_rss="$(get_pid_rss_kb 999999)"
assert_eq "dead PID RSS = 0" "0" "$dead_rss"

# ============================================================
echo ""
echo "=== File Stat Functions ==="
# ============================================================

tmpfile="$(mktemp)"
echo -n "test12" > "$tmpfile"

mtime="$(get_file_mtime_epoch "$tmpfile")"
fsize="$(get_file_size_bytes "$tmpfile")"

echo "  tmpfile mtime: $mtime, size: $fsize"

assert_eq "file size = 6" "6" "$fsize"
assert_gt "mtime is a valid epoch" "$mtime" 1700000000

# Non-existent file
bad_mtime="$(get_file_mtime_epoch "/nonexistent/path/file")"
bad_size="$(get_file_size_bytes "/nonexistent/path/file")"
assert_eq "nonexistent file mtime = 0" "0" "$bad_mtime"
assert_eq "nonexistent file size = 0" "0" "$bad_size"

rm -f "$tmpfile"

# ============================================================
echo ""
echo "=== Date Parsing ==="
# ============================================================

epoch="$(parse_date_to_epoch "2026-03-04T15:00:00Z")"
echo "  2026-03-04T15:00:00Z -> $epoch"
assert_gt "valid ISO date parses to epoch" "$epoch" 1700000000

# Expected: 2026-03-04 15:00:00 UTC = 1772636400
# Allow some tolerance for timezone issues in CI
if [[ "$epoch" -ge 1772600000 && "$epoch" -le 1772700000 ]]; then
  pass "epoch is in expected range for 2026-03-04"
else
  fail "epoch $epoch not in expected range 1772600000-1772700000"
fi

bad_epoch="$(parse_date_to_epoch "not-a-date")"
assert_eq "invalid date returns 0" "0" "$bad_epoch"

# ============================================================
echo ""
echo "=== Base64 Functions ==="
# ============================================================

tmpfile="$(mktemp)"
echo -n "Hello, World!" > "$tmpfile"

encoded="$(base64_encode_file "$tmpfile")"
echo "  Encoded: $encoded"
assert_eq "base64 encode produces expected output" "SGVsbG8sIFdvcmxkIQ==" "$encoded"

decoded="$(echo "$encoded" | base64_decode)"
assert_eq "base64 roundtrip" "Hello, World!" "$decoded"

rm -f "$tmpfile"

# ============================================================
echo ""
echo "=== format_bytes_human ==="
# ============================================================

# Test various magnitudes
r0="$(format_bytes_human 0)"
r500="$(format_bytes_human 500)"
r2048="$(format_bytes_human 2048)"
r1m="$(format_bytes_human 1048576)"
r1g="$(format_bytes_human 1073741824)"

echo "  0 -> $r0"
echo "  500 -> $r500"
echo "  2048 -> $r2048"
echo "  1048576 -> $r1m"
echo "  1073741824 -> $r1g"

# The exact output depends on numfmt availability, but patterns should hold
assert_match "0 bytes is small" "^0" "$r0"
assert_match "500 bytes is small" "^500" "$r500"
assert_match "2048 shows K" "[Kk]" "$r2048"
assert_match "1MB shows M" "[Mm]" "$r1m"
assert_match "1GB shows G" "[Gg]" "$r1g"

# ============================================================
echo ""
echo "=== to_lowercase ==="
# ============================================================

assert_eq "HELLO -> hello" "hello" "$(to_lowercase "HELLO")"
assert_eq "MiXeD -> mixed" "mixed" "$(to_lowercase "MiXeD")"
assert_eq "already lowercase" "test" "$(to_lowercase "test")"
assert_eq "empty string" "" "$(to_lowercase "")"
assert_eq "numbers unchanged" "abc123" "$(to_lowercase "ABC123")"

# ============================================================
echo ""
echo "=== OOM Detection (smoke test) ==="
# ============================================================

# These shouldn't crash, just return a code
check_oom_in_logs
oom_rc=$?
if [[ "$oom_rc" -eq 0 ]]; then
  echo "  OOM detected in logs (unusual for CI)"
else
  echo "  No OOM in logs (expected)"
fi
pass "check_oom_in_logs runs without error"

death_cause="$(determine_death_cause)"
echo "  Death cause: $death_cause"
assert_match "death cause is non-empty" "." "$death_cause"

# ============================================================
echo ""
echo "=== Script Syntax Validation ==="
# ============================================================

for script in "$REPO_DIR"/skills/*/bin/*; do
  [ -f "$script" ] || continue
  name="${script#$REPO_DIR/}"
  if bash -n "$script" 2>/dev/null; then
    pass "syntax OK: $name"
  else
    fail "syntax error: $name"
  fi
done

# Also check install.sh
if bash -n "$REPO_DIR/install.sh" 2>/dev/null; then
  pass "syntax OK: install.sh"
else
  fail "syntax error: install.sh"
fi

# Also check lib/platform_helpers
if bash -n "$REPO_DIR/lib/platform_helpers" 2>/dev/null; then
  pass "syntax OK: lib/platform_helpers"
else
  fail "syntax error: lib/platform_helpers"
fi

# ============================================================
echo ""
echo "========================================"
echo "Results: $PASS_COUNT passed, $FAIL_COUNT failed"
echo "========================================"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  exit 1
fi
exit 0
