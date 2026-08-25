#!/bin/bash
# =====================================================================
# 命令串联守卫（PreToolUse）— 禁止 && 串联命令
#
# 规则（全局 CLAUDE.md）：
#   禁止 && 串联命令，改为多个独立 Bash 调用分开执行。
#
# 说明：
#   - 只拦 &&，不拦 ;（规则只禁了 &&）
#   - 连带拦截用户 `!` 前缀手动输入的命令（含 && 同样拒绝）
# =====================================================================

INPUT=$(cat)
COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')
[ -z "$COMMAND" ] && exit 0

if printf '%s' "$COMMAND" | grep -q '&&'; then
  echo "BLOCKED: 禁止 && 串联命令，改为多个独立 Bash 调用分开执行。命令: $COMMAND" >&2
  exit 2
fi

exit 0
