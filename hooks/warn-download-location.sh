#!/bin/bash
# =====================================================================
# 下载落盘位置提醒（PostToolUse）— 下载文件须放 N:\文件下载\ai自动下载\
#
# 规则（全局 CLAUDE.md）：
#   所有下载文件统一放到 N:\文件下载\ai自动下载\
#
# 说明：
#   - 启发式：只覆盖 curl/wget/xh 带 -o/--output 的显式落盘场景
#   - 仅提醒（additionalContext），不拦截
#   - 测不到的场景：git clone、curl -O 落当前目录、管道重定向等
# =====================================================================

INPUT=$(cat)
COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')
[ -z "$COMMAND" ] && exit 0

# 只处理含下载命令的命令
case "$COMMAND" in
  *curl*|*wget*|*xh*) ;;
  *) exit 0 ;;
esac

# 提取 -o/--output 的落盘目标（支持空格和等号两种写法）
OUT=$(printf '%s' "$COMMAND" | grep -oE '(--output|-o)([[:space:]]|=)[^[:space:]]+' | head -1 | sed -E 's/^(--output|-o)([[:space:]]|=)//')
# 去掉路径首尾引号（curl -o "path" 场景，否则前缀匹配会带引号）
OUT=$(printf '%s' "$OUT" | sed "s/^[\"']//; s/[\"']$//")
[ -z "$OUT" ] && exit 0

NORM=${OUT//\\/\/}
# 已落在下载目录 → 静默
case "$NORM" in
  "N:/文件下载/ai自动下载/"*) exit 0 ;;
esac

printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"下载落盘目标 %s 不在 N:/文件下载/ai自动下载/，按规则下载文件应放该目录。"}}' "$OUT"
exit 0
