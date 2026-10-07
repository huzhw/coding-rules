#!/bin/bash
# =====================================================================
# 记忆写入守卫（PreToolUse）— 防止 AI 幻觉乱写记忆文件
#
# 规则（2026-10-07 目录重构：用户区 memory/ 与 AI 区 memory-ai/ 平级）：
#   - memory/（用户记录区）：AI 只读，写操作一律 ask 人工确认
#   - memory-ai/（AI 自动记录区，项目根、与 memory/ 平级）：
#       · MEMORY.md 索引           → 放行
#       · 命名不合规（无 -YYYY-MM-DD 日期后缀）→ deny
#       · 已批准台账中的文件       → 放行（不重复打扰）
#       · 新文件（未批准）         → 放行（AI 区首次写入免确认）
#   - 其他路径                     → 放行
#
# 配套：guard-memory-approved.sh（PostToolUse）负责把写入成功的
#       memory-ai/ 文件记入 ~/.claude/memory-ai-approved.txt 台账。
# =====================================================================

INPUT=$(cat)
FILE=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty')
[ -z "$FILE" ] && exit 0

# 归一化路径分隔符（\ → /）
NORM=${FILE//\\/\/}

BASE=$(basename "$NORM")
APPROVED="$HOME/.claude/memory-ai-approved.txt"

case "$NORM" in
  # ---- memory-ai/：AI 自动记录区 ----
  */memory-ai/*|/memory-ai/*|memory-ai/*)
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

    # 新记录直接放行（2026-09-12 调整：AI 区写入免人工确认，
    # 把关靠命名 deny + 晋升机制人工过目兜底）
    exit 0
    ;;

  # ---- memory/：用户记录区，AI 只读 ----
  # 注：旧结构 memory/ai/ 残留路径也落在本分支（视为用户区，人工把关）
  */memory/*|/memory/*|memory/*)
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"写入用户记录区 memory/（AI 只读）：%s。确需更新请批准，误写请拒绝。"}}' "$BASE"
    exit 0
    ;;

  # 非 memory/、memory-ai/ 目录段 → 放行
  *) exit 0 ;;
esac
