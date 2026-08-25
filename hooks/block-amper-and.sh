#!/bin/bash
# =====================================================================
# 命令串联守卫（PreToolUse）— 禁止 && 串联命令
#
# 规则（全局 CLAUDE.md）：
#   禁止 && 串联命令，改为多个独立 Bash 调用分开执行。
#
# 判定：
#   - 引号（单/双/反引号）内的 && 视为文本，放行（提交消息、echo 文本、
#     git log --grep 等不算命令串联）
#   - 引号外的 && 才是真实命令串联，拦截
#   - 转义 \& 跳过；$(...) 内部的 && 仍按真实串联拦截（罕见）
# =====================================================================

INPUT=$(cat)
COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')
[ -z "$COMMAND" ] && exit 0

# 引号感知扫描：追踪单引号(047)/双引号(042)/反引号(140)，引号外发现 && 记为串联
HAS_CHAIN=$(printf '%s' "$COMMAND" | awk '
{
  n = length($0)
  for (i = 1; i <= n; i++) {
    c = substr($0, i, 1)
    if (in_sq == 0 && in_dq == 0 && in_bt == 0) {
      # 引号外
      if (c == "\\") { i++; prev = ""; continue }   # 转义：跳过下一字符
      if (c == "\047") { in_sq = 1; prev = c; continue }
      if (c == "\042") { in_dq = 1; prev = c; continue }
      if (c == "\140") { in_bt = 1; prev = c; continue }
      if (c == "&" && prev == "&") { print "CHAIN"; exit }
    } else if (in_sq == 1) {
      if (c == "\047") in_sq = 0
    } else if (in_dq == 1) {
      if (c == "\\") { i++; prev = ""; continue }   # 双引号内转义
      if (c == "\042") in_dq = 0
    } else if (in_bt == 1) {
      if (c == "\140") in_bt = 0
    }
    prev = c
  }
}
')

[ -z "$HAS_CHAIN" ] && exit 0

echo "BLOCKED: 禁止 && 串联命令，改为多个独立 Bash 调用分开执行。命令: $COMMAND" >&2
exit 2
