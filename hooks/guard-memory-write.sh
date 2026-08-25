#!/bin/bash
# =====================================================================
# 记忆写入守卫（PreToolUse）— 防止 AI 幻觉乱写记忆文件
#
# 规则（memory/ 目录段）：
#   - memory/ 根（用户记录区）：AI 只读，写操作一律 ask 人工确认
#   - memory/ai/（AI 自动记录区）：
#       · MEMORY.md 索引           → 放行
#       · 命名不合规（无 -YYYY-MM-DD 日期后缀）→ deny
#       · 已批准台账中的文件       → 放行（不重复打扰）
#       · 新文件（未批准）         → ask 人工确认（防幻觉）
#   - 非 memory/ 目录段            → 放行
#
# 配套：guard-memory-approved.sh（PostToolUse）负责把写入成功的
#       memory/ai/ 文件记入 ~/.claude/memory-ai-approved.txt 台账。
# =====================================================================

INPUT=$(cat)
FILE=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty')
[ -z "$FILE" ] && exit 0

# 归一化路径分隔符（\ → /）
NORM=${FILE//\\/\/}

# 仅处理包含 memory/ 目录段的路径
case "$NORM" in
  */memory/*|/memory/*|memory/*) ;;
  *) exit 0 ;;
esac

BASE=$(basename "$NORM")
APPROVED="$HOME/.claude/memory-ai-approved.txt"

# ---- memory/ 根：用户记录区，AI 只读 ----
if [[ "$NORM" != */memory/ai/* ]]; then
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"写入用户记录区 memory/（AI 只读）：%s。确需更新请批准，误写请拒绝。"}}' "$BASE"
  exit 0
fi

# ---- memory/ai/：AI 自动记录区 ----

# AI 区索引放行
[ "$BASE" = "MEMORY.md" ] && exit 0

# 命名校验：须带日期后缀 -YYYY-MM-DD（防止乱命名）
if ! [[ "$BASE" =~ -[0-9]{4}-[0-9]{2}-[0-9]{2}\.md$ ]]; then
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"AI 自动记录命名不合规：需中文名+日期后缀 -YYYY-MM-DD（例：服务器清单-2026-08-25.md），当前文件：%s"}}' "$BASE"
  exit 0
fi

# 已批准台账命中 → 放行
if [ -f "$APPROVED" ] && grep -qxF "$NORM" "$APPROVED" 2>/dev/null; then
  exit 0
fi

# 新记录 → ask 人工确认（防幻觉）
printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"AI 自动记录待确认（防幻觉）：%s。确认内容真实可考再批准，否则拒绝。"}}' "$BASE"
exit 0
