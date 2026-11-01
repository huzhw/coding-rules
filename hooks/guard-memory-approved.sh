#!/bin/bash
export PATH="/usr/bin:/bin:$PATH"
# =====================================================================
# 记忆写入记账（PostToolUse）— 配套 guard-memory-write.sh
#
# 作用（两笔记账）：
#   ① memory-ai/ 写入成功的文件 → ~/.claude/memory-ai-approved.txt 台账，
#      此后该文件再被修改时 PreToolUse 守卫直接放行，不再反复打扰
#   ② memory/（用户记录区）写入成功 = 本会话已获人工批准，记会话标记
#      ~/.claude/memory-session-ok/<会话id>，本会话内 memory/ 后续写入放行
# 幂等：台账已记录的不重复追加；会话标记直接覆盖。
# 清理：记账时顺手删 3 天前的旧会话标记，防堆积。
# =====================================================================

IFS= read -r -d '' INPUT || true
FILE=$(printf '%s' "$INPUT" | jq -r '.tool_response.filePath // .tool_input.file_path // empty')
[ -z "$FILE" ] && exit 0

NORM=${FILE//\\/\/}

case "$NORM" in
  # ---- memory-ai/：维持原台账逻辑 ----
  */memory-ai/*|/memory-ai/*|memory-ai/*) ;;

  # ---- memory/：写入成功 = 本会话已获人工批准，记会话标记 ----
  */memory/*|/memory/*|memory/*)
    SESSION=$(printf '%s' "$INPUT" | jq -r '.session_id // empty')
    [ -z "$SESSION" ] && SESSION="${CLAUDE_SESSION_ID:-}"
    if [ -n "$SESSION" ]; then
      # 与 guard-memory-write.sh 同一套字符白名单，保证两端文件名对得上
      SESSION=${SESSION//[^A-Za-z0-9._-]/_}
      OK_DIR="$HOME/.claude/memory-session-ok"
      mkdir -p "$OK_DIR" 2>/dev/null
      printf 'approved\n' > "$OK_DIR/$SESSION" 2>/dev/null
      # 3 天前的旧会话标记顺手清掉
      find "$OK_DIR" -type f -mtime +3 -delete 2>/dev/null
    fi
    exit 0
    ;;

  *) exit 0 ;;
esac

# AI 区索引无需记账
[ "$(basename "$NORM")" = "MEMORY.md" ] && exit 0

APPROVED="$HOME/.claude/memory-ai-approved.txt"

# 幂等追加
if [ -f "$APPROVED" ]; then
  grep -qxF "$NORM" "$APPROVED" 2>/dev/null && exit 0
fi
printf '%s\n' "$NORM" >> "$APPROVED"
exit 0
