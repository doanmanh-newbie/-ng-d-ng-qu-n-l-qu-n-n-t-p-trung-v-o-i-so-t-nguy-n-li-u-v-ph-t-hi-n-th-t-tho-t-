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
if [ -f "$WORKFLOW/.loop/check_failed" ] && [ ! -s "$WORKFLOW/.loop/check.log" ]; then
  echo "check hỏng, không có log" >&2
  exit 5
fi
if [ -n "$(git status --porcelain)" ]; then
  echo "DỪNG: working tree có thay đổi chưa commit. Lưu/commit chúng trước khi chạy loop để tránh commit nhầm." >&2
  exit 4
fi

blocked="$(grep -m1 '^- \[!\]' "$TODO" || true)"
if [ -n "$blocked" ]; then
  echo "DỪNG: TODO có mục bị chặn: $blocked" >&2
  echo "Giải quyết nguyên nhân, rồi chuyển mục đó về [ ] trước khi chạy loop tiếp." >&2
  exit 6
fi

left() { grep -c '^- \[ \]' "$TODO" || true; }
item_id() { sed -E 's/^- \[ \] (T[0-9]+).*/\1/' <<< "$1"; }

set_item_status() {
  local id="$1"
  local status="$2"
  local unchecked checked
  unchecked="$(grep -c "^- \\[ \\] $id " "$TODO" || true)"
  checked="$(grep -c "^- \\[x\\] $id " "$TODO" || true)"
  if [ "$status" = "[x]" ]; then
    [ "$unchecked" -eq 1 ] || return 1
    sed -i "s/^- \\[ \\] $id /- [x] $id /" "$TODO"
  else
    if [ "$checked" -eq 1 ]; then
      sed -i "s/^- \\[x\\] $id /- [ ] $id /" "$TODO"
    fi
  fi
}

iter=0
last_task=""
same=0
while [ "$iter" -lt "$MAX_ITER" ]; do
  if [ -f "$WORKFLOW/.loop/check_failed" ]; then
    if [ -f "$WORKFLOW/.loop/current_item" ]; then
      current_id="$(tr -d '\r\n' < "$WORKFLOW/.loop/current_item")"
    else
      task="$(grep -m1 '^- \[ \]' "$TODO" || true)"
      current_id="$(item_id "$task")"
      if [ -n "$current_id" ]; then
        printf '%s\n' "$current_id" > "$WORKFLOW/.loop/current_item"
      fi
    fi
    if ! [[ "$current_id" =~ ^T[0-9]+$ ]]; then
      echo "DỪNG: thiếu mã mục hợp lệ trong .loop/current_item." >&2
      exit 5
    fi
    printf '%s\n' "$current_id" > "$WORKFLOW/.loop/current_item"
    prompt="Lần kiểm tra trước thất bại. Đọc .loop/check.log và sửa lỗi đó; không chạy scripts/check.sh, loop sẽ kiểm tra sau lượt này. Không bắt đầu việc mới. Làm theo AGENTS.md. Không tự tick TODO, stage hoặc commit."
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
    current_id="$(item_id "$task")"
    if ! [[ "$current_id" =~ ^T[0-9]+$ ]]; then
      echo "DỪNG: không đọc được mã mục TODO: $task" >&2
      exit 5
    fi
    printf '%s\n' "$current_id" > "$WORKFLOW/.loop/current_item"
    prompt="Làm theo AGENTS.md: đọc SPEC.md, NOTES.md và TODO.md; làm đúng mục chưa xong đầu tiên, rồi dừng. Ghi NOTES dòng 'Lượt <mã mục>: đã viết code/test, chờ check'. Không tự tick TODO, stage hoặc commit."
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

  # Enforce that the agent cannot mark its task complete before the check.
  set_item_status "$current_id" "[ ]" || {
    echo "DỪNG: không thể giữ $current_id ở trạng thái chưa check." >&2
    exit 5
  }

  if bash "$WORKFLOW/scripts/check.sh" > "$WORKFLOW/.loop/check.log" 2>&1; then
    if ! set_item_status "$current_id" "[x]"; then
      echo "DỪNG: check xanh nhưng không thể tick đúng mục $current_id." >&2
      exit 5
    fi
    printf 'Check xanh: %s %s\n' "$current_id" "$(date '+%Y-%m-%d %H:%M:%S')" >> "$WORKFLOW/NOTES.md"
    rm -f "$WORKFLOW/.loop/check_failed"
    if [ -n "$(git status --porcelain)" ]; then
      echo "Changes detected; no automatic staging or commit."
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
