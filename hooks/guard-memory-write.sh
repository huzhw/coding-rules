#!/bin/bash
export PATH="/usr/bin:/bin:$PATH"
# =====================================================================
# 记忆写入守卫（PreToolUse）— 防止 AI 幻觉乱写记忆文件
#
# 规则（用户区 memory/ 与 AI 区 memory-ai/ 平级）：
#   - memory/（用户记录区）：AI 可改现有文件——每会话首次 ask，批准后本会话放行
#     （会话标记 ~/.claude/memory-session-ok/，由 guard-memory-approved.sh 记账、3 天自动清）；
#     新建文件须架构师指定——每次都 ask，不走会话信任
#   - memory-ai/（AI 自动记录区，项目根、与 memory/ 平级）：
#       · MEMORY.md 索引           → 放行
#       · 命名不合规（无 -YYYY-MM-DD 日期后缀）→ deny
#       · 已批准台账中的文件       → 放行（不重复打扰）
#       · 新文件（未批准）         → 放行（AI 区首次写入免确认）
#   - 其他路径                     → 放行
#
# 配套：guard-memory-approved.sh（PostToolUse）负责两笔记账：
#       ① memory-ai/ 写入成功的文件 → ~/.claude/memory-ai-approved.txt
#       ② memory/ 人工批准过的会话 → ~/.claude/memory-session-ok/
# =====================================================================

IFS= read -r -d '' INPUT || true
FILE=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty')
[ -z "$FILE" ] && exit 0

# 会话标识：优先 hook 输入 JSON 的 session_id，env CLAUDE_SESSION_ID 兜底；
# 两处都拿不到就退化为「每次 ask」，不放大权限
SESSION=$(printf '%s' "$INPUT" | jq -r '.session_id // empty')
[ -z "$SESSION" ] && SESSION="${CLAUDE_SESSION_ID:-}"
# 只留安全字符再当文件名用（防路径穿越）
SESSION=${SESSION//[^A-Za-z0-9._-]/_}
SESSION_OK_DIR="$HOME/.claude/memory-session-ok"

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

  # ---- memory/：用户记录区（现有文件可改，新建须架构师指定） ----
  # 注：旧结构 memory/ai/ 残留路径也落在本分支（视为用户区，人工把关）
  */memory/*|/memory/*|memory/*)
    # 新建文件：每次都问（“新建须指定”），不走会话信任
    if [ ! -e "$FILE" ]; then
      printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"新建用户记录（memory/）：%s。新建文件须架构师指定，请确认。"}}' "$BASE"
      exit 0
    fi
    # 现有文件：本会话已人工批准过 → 放行（批准记账在 guard-memory-approved.sh）
    if [ -n "$SESSION" ] && [ -f "$SESSION_OK_DIR/$SESSION" ]; then
      exit 0
    fi
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"修改用户记录区 memory/ 的现有文件：%s。确需更新请批准（本会话内只需批一次），误写请拒绝。"}}' "$BASE"
    exit 0
    ;;

  # 非 memory/、memory-ai/ 目录段 → 放行
  *) exit 0 ;;
esac
