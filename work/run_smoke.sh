#!/bin/bash
# 无窗口回归：逐个跑 work/*_smoke.gd，把结果汇总到 $LOG。
# 判失败看 Assertion failed / SCRIPT ERROR / Parse Error。
# 注意：不要同时跑两份，Godot 会互相踩 .godot 缓存，结果不可信。
GODOT="${GODOT:-/c/Users/admin/Tools/Godot/Godot_v4.3-stable_win64_console.exe}"
cd "$(dirname "$0")/.." || exit 1
LOG="${1:-work/smoke_final.txt}"
: > "$LOG"
for f in work/*_smoke.gd; do
  out=$("$GODOT" --headless --path . --script "$f" 2>&1)
  if echo "$out" | grep -qi "Assertion failed\|SCRIPT ERROR\|Parse Error\|Invalid access"; then
    echo "FAIL $f" >> "$LOG"
    echo "$out" | grep -i "Assertion failed\|SCRIPT ERROR\|Parse Error\|Invalid access" | head -4 >> "$LOG"
  else
    echo "ok   $f" >> "$LOG"
  fi
done
echo "SMOKE_DONE" >> "$LOG"
