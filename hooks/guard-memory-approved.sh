#!/bin/bash
# =====================================================================
# 记忆写入记账（PostToolUse）— 配套 guard-memory-write.sh
#
# 作用：memory/ai/ 下的文件写入成功后，把文件路径记入批准台账
#       ~/.claude/memory-ai-approved.txt，此后该文件再被修改时
#       PreToolUse 守卫直接放行，不再反复打扰人工确认。
# 幂等：已记录的不重复追加。
# =====================================================================

INPUT=$(cat)
FILE=$(printf '%s' "$INPUT" | jq -r '.tool_response.filePath // .tool_input.file_path // empty')
[ -z "$FILE" ] && exit 0

NORM=${FILE//\\/\/}

# 仅处理 memory/ai/ 目录段
case "$NORM" in
  */memory/ai/*|/memory/ai/*|memory/ai/*) ;;
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
