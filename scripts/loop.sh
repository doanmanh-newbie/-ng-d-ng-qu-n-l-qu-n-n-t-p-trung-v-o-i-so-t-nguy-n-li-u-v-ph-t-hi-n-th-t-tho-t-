#!/usr/bin/env bash
# Safe bounded workflow loop. Run from repo root: AGENT=codex MAX_ITER=2 bash scripts/loop.sh
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKFLOW="$ROOT"
TODO="$WORKFLOW/TODO.md"
cd "$ROOT"

AGENT="${AGENT:-codex}"
MAX_ITER="${MAX_ITER:-2}"
MAX_TURNS="${MAX_TURNS:-40}"
mkdir -p "$WORKFLOW/.loop"

if ! [[ "$MAX_ITER" =~ ^[1-9][0-9]*$ ]]; then
  echo "MAX_ITER phải là số nguyên dương." >&2
  exit 2
fi
if [ -n "$(git status --porcelain)" ]; then
  echo "DỪNG: working tree có thay đổi chưa commit. Lưu/commit chúng trước khi chạy loop để tránh commit nhầm." >&2
  exit 4
fi

left() { grep -c '^- \[ \]' "$TODO" || true; }

iter=0
last_task=""
same=0
while [ "$iter" -lt "$MAX_ITER" ]; do
  if [ -f "$WORKFLOW/.loop/check_failed" ]; then
    prompt="Lần kiểm tra trước thất bại. Đọc .loop/check.log, sửa lỗi và chạy bash scripts/check.sh đến khi qua. Không bắt đầu việc mới. Làm theo AGENTS.md. Không tự stage hoặc commit."
    task="Sửa lỗi kiểm tra đã lưu"
  else
    task="$(grep -m1 '^- \[ \]' "$TODO" || true)"
    if [ -z "$task" ]; then
      if bash "$WORKFLOW/scripts/check.sh" --full > "$WORKFLOW/.loop/check.log" 2>&1; then
        echo "HOÀN THÀNH: TODO hết và check --full qua."
        exit 0
      fi
      touch "$WORKFLOW/.loop/check_failed"
      echo "Check --full thất bại; dừng để tránh loop sửa không có mục tiêu. Xem .loop/check.log."
      exit 5
    fi
    prompt="Làm theo AGENTS.md: đọc SPEC.md, NOTES.md và TODO.md; làm đúng mục chưa xong đầu tiên, rồi dừng. Không tự stage hoặc commit."
  fi

  if [ "$task" = "$last_task" ]; then same=$((same+1)); else same=0; last_task="$task"; fi
  if [ "$same" -ge 2 ]; then
    echo "DỪNG: cùng một việc chưa tiến triển qua nhiều lượt: $task"
    exit 2
  fi

  echo "=== Lượt $((iter+1))/$MAX_ITER | còn $(left) việc | $task"
  case "$AGENT" in
    codex)
      if ! command -v codex >/dev/null 2>&1; then
        echo "Không tìm thấy codex trong PATH của Git Bash." >&2
        exit 127
      fi
      codex exec --sandbox workspace-write "$prompt" > "$WORKFLOW/.loop/agent_$((iter+1)).log" 2>&1
      rc=$?
      ;;
    claude)
      if ! command -v claude >/dev/null 2>&1; then
        echo "Không tìm thấy claude trong PATH của Git Bash." >&2
        exit 127
      fi
      claude -p "$prompt" --max-turns "$MAX_TURNS" > "$WORKFLOW/.loop/agent_$((iter+1)).log" 2>&1
      rc=$?
      ;;
    *)
      echo "AGENT chỉ nhận codex hoặc claude." >&2
      exit 2
      ;;
  esac

  if [ "$rc" -ne 0 ]; then
    echo "DỪNG: agent lỗi (rc=$rc), không retry. Xem .loop/agent_$((iter+1)).log."
    exit 3
  fi

  if bash "$WORKFLOW/scripts/check.sh" > "$WORKFLOW/.loop/check.log" 2>&1; then
    rm -f "$WORKFLOW/.loop/check_failed"
    if [ -n "$(git status --porcelain)" ]; then
      git add -A && git commit -m "loop: lượt $((iter+1)) — $task" || exit $?
    else
      echo "Không có thay đổi file; bỏ qua commit."
    fi
  else
    touch "$WORKFLOW/.loop/check_failed"
    echo "Check lỗi. Lượt kế tiếp chỉ sửa lỗi này; xem .loop/check.log."
  fi
  iter=$((iter+1))
done

echo "Hết $MAX_ITER lượt. Còn $(left) việc; xem TODO.md và NOTES.md."
