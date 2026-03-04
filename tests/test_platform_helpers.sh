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

assert_ne() {
  local desc="$1" unexpected="$2" actual="$3"
  if [[ "$unexpected" != "$actual" ]]; then
    pass "$desc"
  else
    fail "$desc (should not be '$unexpected')"
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

assert_exit_code() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$expected" -eq "$actual" ]]; then
    pass "$desc"
  else
    fail "$desc (expected exit $expected, got $actual)"
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

# _PLATFORM should be set (internal var)
assert_ne "_PLATFORM is set" "" "$_PLATFORM"

# ============================================================
echo ""
echo "=== Memory Functions ==="
# ============================================================

total="$(get_total_memory_mb)"
avail="$(get_available_memory_mb)"
pct="$(get_memory_usage_pct)"

echo "  Total: ${total}MB, Available: ${avail}MB, Usage: ${pct}%"

# On all CI runners we expect real memory info (except Windows Git Bash)
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

  # Cross-validate: usage pct should match manual calculation
  if [[ "$total" -gt 0 ]]; then
    expected_pct=$(( (total - avail) * 100 / total ))
    assert_eq "usage pct matches manual calc" "$expected_pct" "$pct"
  fi

  # Repeated calls should return consistent results (not wildly different)
  total2="$(get_total_memory_mb)"
  assert_eq "total memory is stable across calls" "$total" "$total2"
else
  # Windows/unknown: functions should still return numbers without error
  assert_match "total is numeric on $platform" "^-?[0-9]+$" "$total"
  assert_match "avail is numeric on $platform" "^-?[0-9]+$" "$avail"
  assert_match "pct is numeric on $platform" "^-?[0-9]+$" "$pct"
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

# PID 0 (kernel) — should return 0 or a value, not crash
pid0_rss="$(get_pid_rss_kb 0)"
assert_match "PID 0 returns numeric" "^[0-9]+$" "$pid0_rss"

# Empty string PID — should not crash
empty_rss="$(get_pid_rss_kb "" 2>/dev/null || echo "0")"
assert_match "empty PID returns numeric" "^[0-9]+$" "$empty_rss"

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

# Empty file
empty_tmpfile="$(mktemp)"
empty_size="$(get_file_size_bytes "$empty_tmpfile")"
assert_eq "empty file size = 0" "0" "$empty_size"
empty_mtime="$(get_file_mtime_epoch "$empty_tmpfile")"
assert_gt "empty file has valid mtime" "$empty_mtime" 1700000000
rm -f "$empty_tmpfile"

# Larger file
large_tmpfile="$(mktemp)"
dd if=/dev/zero of="$large_tmpfile" bs=1024 count=100 2>/dev/null
large_size="$(get_file_size_bytes "$large_tmpfile")"
assert_eq "100KB file size = 102400" "102400" "$large_size"
rm -f "$large_tmpfile"

# File with spaces in path (important cross-platform edge case)
tmpdir="$(mktemp -d)"
spaced_file="$tmpdir/file with spaces.txt"
echo -n "spaced" > "$spaced_file"
spaced_size="$(get_file_size_bytes "$spaced_file")"
spaced_mtime="$(get_file_mtime_epoch "$spaced_file")"
assert_eq "file with spaces size = 6" "6" "$spaced_size"
assert_gt "file with spaces has valid mtime" "$spaced_mtime" 1700000000
rm -rf "$tmpdir"

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

# Standard ISO 8601 with Z suffix
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

# Different date
epoch2="$(parse_date_to_epoch "2025-01-01T00:00:00Z")"
echo "  2025-01-01T00:00:00Z -> $epoch2"
assert_gt "Jan 2025 parses to valid epoch" "$epoch2" 1700000000
# 2025-01-01 should be less than 2026-03-04
if [[ "$epoch2" -lt "$epoch" ]]; then
  pass "2025-01-01 < 2026-03-04"
else
  fail "date ordering: 2025-01-01 ($epoch2) should be < 2026-03-04 ($epoch)"
fi

# Invalid date
bad_epoch="$(parse_date_to_epoch "not-a-date")"
assert_eq "invalid date returns 0" "0" "$bad_epoch"

# Empty string — GNU date -d "" returns current time, so just verify it's numeric
empty_epoch="$(parse_date_to_epoch "")"
assert_match "empty date returns a number" "^[0-9]+$" "$empty_epoch"

# ============================================================
echo ""
echo "=== Base64 Functions ==="
# ============================================================

# ASCII text
tmpfile="$(mktemp)"
echo -n "Hello, World!" > "$tmpfile"
encoded="$(base64_encode_file "$tmpfile")"
echo "  Encoded: $encoded"
assert_eq "base64 encode produces expected output" "SGVsbG8sIFdvcmxkIQ==" "$encoded"
decoded="$(echo "$encoded" | base64_decode)"
assert_eq "base64 roundtrip (ASCII)" "Hello, World!" "$decoded"
rm -f "$tmpfile"

# Binary data roundtrip
bin_tmpfile="$(mktemp)"
# Write known binary bytes (0x00 through 0xFF)
printf '\x00\x01\x02\xff\xfe\xfd' > "$bin_tmpfile"
bin_encoded="$(base64_encode_file "$bin_tmpfile")"
assert_ne "binary encode is non-empty" "" "$bin_encoded"
# Decode and compare byte counts
bin_decoded_file="$(mktemp)"
echo "$bin_encoded" | base64_decode > "$bin_decoded_file"
orig_size="$(get_file_size_bytes "$bin_tmpfile")"
decoded_size="$(get_file_size_bytes "$bin_decoded_file")"
assert_eq "binary base64 roundtrip preserves size" "$orig_size" "$decoded_size"
rm -f "$bin_tmpfile" "$bin_decoded_file"

# Empty file
empty_b64_file="$(mktemp)"
: > "$empty_b64_file"
empty_encoded="$(base64_encode_file "$empty_b64_file")"
# Empty file should encode to empty string or padding only
empty_decoded="$(echo "$empty_encoded" | base64_decode)"
assert_eq "empty file base64 roundtrip" "" "$empty_decoded"
rm -f "$empty_b64_file"

# ============================================================
echo ""
echo "=== format_bytes_human ==="
# ============================================================

# Test various magnitudes
r0="$(format_bytes_human 0)"
r500="$(format_bytes_human 500)"
r1023="$(format_bytes_human 1023)"
r1024="$(format_bytes_human 1024)"
r2048="$(format_bytes_human 2048)"
r1m="$(format_bytes_human 1048576)"
r1g="$(format_bytes_human 1073741824)"

echo "  0 -> $r0"
echo "  500 -> $r500"
echo "  1023 -> $r1023"
echo "  1024 -> $r1024"
echo "  2048 -> $r2048"
echo "  1048576 -> $r1m"
echo "  1073741824 -> $r1g"

# The exact output depends on numfmt availability, but patterns should hold
assert_match "0 bytes is small" "^0" "$r0"
assert_match "500 bytes is small" "^500" "$r500"
assert_match "1024 shows K" "[Kk]" "$r1024"
assert_match "2048 shows K" "[Kk]" "$r2048"
assert_match "1MB shows M" "[Mm]" "$r1m"
assert_match "1GB shows G" "[Gg]" "$r1g"

# Boundary: 1023 should still be bytes (below 1K)
assert_match "1023 is sub-K" "^(1023|1023B|1023[^KkMmGg])$|^1023$" "$r1023"

# ============================================================
echo ""
echo "=== to_lowercase ==="
# ============================================================

assert_eq "HELLO -> hello" "hello" "$(to_lowercase "HELLO")"
assert_eq "MiXeD -> mixed" "mixed" "$(to_lowercase "MiXeD")"
assert_eq "already lowercase" "test" "$(to_lowercase "test")"
assert_eq "empty string" "" "$(to_lowercase "")"
assert_eq "numbers unchanged" "abc123" "$(to_lowercase "ABC123")"
assert_eq "special chars preserved" "hello-world_v2" "$(to_lowercase "HELLO-WORLD_V2")"
assert_eq "single char" "a" "$(to_lowercase "A")"

# ============================================================
echo ""
echo "=== OOM Detection (smoke test) ==="
# ============================================================

# These shouldn't crash on any platform, just return a code
check_oom_in_logs
oom_rc=$?
if [[ "$oom_rc" -eq 0 ]]; then
  echo "  OOM detected in logs (unusual for CI)"
else
  echo "  No OOM in logs (expected)"
fi
assert_match "check_oom_in_logs exit code is 0 or 1" "^[01]$" "$oom_rc"

death_cause="$(determine_death_cause)"
echo "  Death cause: $death_cause"
assert_match "death cause is non-empty" "." "$death_cause"
# On a normal system, it should mention "unexpectedly" or "OOM"
assert_match "death cause has meaningful text" "(unexpectedly|OOM|kill|died|crash)" "$death_cause"

# ============================================================
echo ""
echo "=== Double-source safety ==="
# ============================================================

# Sourcing platform_helpers twice should not error or change behavior
source "$REPO_DIR/lib/platform_helpers"
platform_again="$(get_platform)"
assert_eq "platform unchanged after re-source" "$platform" "$platform_again"

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
echo "=== Skill Structure Validation ==="
# ============================================================

# Every skill should have a SKILL.md and at least one bin script
for skill_dir in "$REPO_DIR"/skills/*/; do
  [ -d "$skill_dir" ] || continue
  skill_name="$(basename "$skill_dir")"

  if [[ -f "$skill_dir/SKILL.md" ]]; then
    pass "SKILL.md exists: $skill_name"
  else
    fail "missing SKILL.md: $skill_name"
  fi

  # Some skills are prompt-only (SKILL.md only, no bin/)
  if [[ -d "$skill_dir/bin" ]]; then
    bin_count=0
    for bin_file in "$skill_dir"/bin/*; do
      [ -f "$bin_file" ] && bin_count=$((bin_count + 1))
    done
    if [[ "$bin_count" -gt 0 ]]; then
      pass "has bin scripts ($bin_count): $skill_name"
    else
      fail "bin/ dir exists but is empty: $skill_name"
    fi
  else
    pass "prompt-only skill (no bin/): $skill_name"
  fi

  # Every bin script should have a shebang
  for bin_file in "$skill_dir"/bin/*; do
    [ -f "$bin_file" ] || continue
    bin_name="$(basename "$bin_file")"
    first_line="$(head -1 "$bin_file")"
    if echo "$first_line" | grep -q '^#!'; then
      pass "shebang present: $skill_name/bin/$bin_name"
    else
      fail "missing shebang: $skill_name/bin/$bin_name"
    fi
  done
done

# ============================================================
echo ""
echo "=== platform_helpers sources from skill paths ==="
# ============================================================

# Test the sourcing pattern used by actual skill scripts
for skill_bin_dir in "$REPO_DIR"/skills/*/bin; do
  [ -d "$skill_bin_dir" ] || continue
  skill_name="$(basename "$(dirname "$skill_bin_dir")")"
  ph_path="$skill_bin_dir/../../../lib/platform_helpers"
  if [[ -f "$ph_path" ]]; then
    # Verify it can be sourced from this relative path
    result="$(cd "$skill_bin_dir" && bash -c 'source ../../../lib/platform_helpers && get_platform' 2>&1)"
    if [[ -n "$result" ]]; then
      pass "relative source works from: $skill_name/bin/"
    else
      fail "relative source failed from: $skill_name/bin/"
    fi
  else
    fail "platform_helpers not reachable from: $skill_name/bin/"
  fi
done

# ============================================================
echo ""
echo "========================================"
echo "Results: $PASS_COUNT passed, $FAIL_COUNT failed"
echo "========================================"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  exit 1
fi
exit 0
