#!/bin/bash
# =====================================================================
# 危险 Bash 命令守卫（PreToolUse）— 与权限模式无关的硬性红线
#
# 背景：权限模式可能在 default / acceptEdits / auto / bypassPermissions
#       之间切换。bypassPermissions 与 auto 会跳过"逐条确认"，
#       本守卫把高危系统操作无条件拦截（deny），不依赖权限模式。
#
# 分层策略：
#   - 危险命令  → deny（硬拦，命令不执行，直接返回错误给模型）
#   - 其余命令  → { "continue": true } 放行给 SDK，交由权限模式
#                 / allow 规则判定（auto 下由模型分类器决定）
#
# 规则分类：
#   DANGER  危险（硬拦）     rm 指向系统/根目录、reg delete、sc delete、
#                           bcdedit、shutdown/reboot、DROP/TRUNCATE、
#                           无 WHERE 的 DELETE/UPDATE、chmod -R 777 /
#                           chown -R / chmod -r 000、find -delete/-exec/-ok、
#                           mkfs/fdisk/fork bomb
#   SAFE    安全目标（放行） rm 指向项目内构建/缓存/输出目录，包含：
#                           target/ node_modules/ dist/ build/ out/
#                           classes/ logs/ *.pyc __pycache__ .pytest_cache
#                           .coverage .mypy_cache .venv venv package/
#   PASS    常态放行         taskkill /f、net stop/start、sc stop/start
#                           （可逆的运维命令，不硬拦）
#
# 注意（P2）：SQL 语句常以引号字符串出现（mysql -e "DROP TABLE t1"），
#      不能走 STRIPPED（引号内会被剥掉 → 漏拦），必须用原始 COMMAND 匹配。
# =====================================================================

INPUT=$(cat)
COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')
[ -z "$COMMAND" ] && printf '{"continue":true}' && exit 0

# ---- 引号感知：剥掉单/双/反引号内的内容，只留"引号外"命令骨架 ----
# 与 block-amper-and.sh 保持同一套引号状态机，保证与现有 hook 判定一致。
STRIPPED=$(printf '%s' "$COMMAND" | awk '
{
  n = length($0)
  out = ""
  in_sq = 0; in_dq = 0; in_bt = 0
  for (i = 1; i <= n; i++) {
    c = substr($0, i, 1)
    if (in_sq == 0 && in_dq == 0 && in_bt == 0) {
      if (c == "\\") { out = out c; if (i+1 <= n) { out = out substr($0, i+1, 1); i++ } continue }
      if (c == "\047") { in_sq = 1; continue }
      if (c == "\042") { in_dq = 1; continue }
      if (c == "\140") { in_bt = 1; continue }
      out = out c
    } else {
      if      (in_sq == 1 && c == "\047") in_sq = 0
      else if (in_dq == 1) { if (c == "\\") { i++ } else if (c == "\042") in_dq = 0 }
      else if (in_bt == 1 && c == "\140") in_bt = 0
    }
  }
  print out
}
')

# ---- DANGER P0: 直接删数据（rm 危险目标 / find 批量删） ----
# 白名单优先：只有项目内构建/缓存/输出目录才放行，其余（含 /tmp、~/、系统目录、
# 未列入白名单的任意路径）一律 deny。宁可误拦不可漏拦，
# 因为 rm -rf 不可逆，而构建目录清缓存属于最常见且低风险操作。
# 目标先归一化：小写、去尾斜杠（支持 ./target / target/ / target 三种写法）
SAFE_RM_DIR='^(\./)?(target|node_modules|dist|build|out|classes|logs|package|__pycache__|\.pytest_cache|\.coverage|\.mypy_cache|\.venv|venv)(/|$)|\.pyc$'
if printf '%s' "$STRIPPED" | grep -qE '(^|[[:space:]]|/)rm([[:space:]]|$).*(-[a-z]*[rR][a-z]*)'; then
  # 取 rm 后面的目标（去掉 rm 本体及 -r/-f/-rf/-R 等选项）
  RM_TARGET=$(printf '%s' "$STRIPPED" | sed -E 's/.*(^|[[:space:]])rm([[:space:]]|$)//')
  RM_TARGET=$(printf '%s' "$RM_TARGET" | sed -E 's/^-[rRfF]+//')
  RM_TARGET=$(printf '%s' "$RM_TARGET" | tr -d '[:space:]')
  # 归一化：小写 + 去掉末尾斜杠（相对路径 ./ 前缀保留以便白名单判定）
  RM_TARGET_LC=$(printf '%s' "$RM_TARGET" | tr '[:upper:]' '[:lower:]')
  RM_TARGET_LC=${RM_TARGET_LC%/}
  if [ -z "$RM_TARGET_LC" ] || printf '%s' "$RM_TARGET_LC" | grep -qE '^(\.\.|/|[a-z]:|~)'; then
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"危险命令（P0 删除类）被拦截：rm 目标 %s 为空或为绝对/上级路径，禁止执行。"}}' "$RM_TARGET"
    exit 0
  fi
  # 白名单：项目内构建/缓存/输出目录 → 放行
  if printf '%s' "$RM_TARGET_LC" | grep -qE "$SAFE_RM_DIR"; then
    printf '{"continue":true}'
    exit 0
  fi
  # 其余（未列入白名单的相对/绝对路径）一律 deny
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"危险命令（P0 删除类）被拦截：rm 目标 %s 不在构建/缓存/输出白名单，且非本次确认的安全操作。如需删除请精确指定已确认的路径。"}}' "$RM_TARGET"
  exit 0
fi
if printf '%s' "$STRIPPED" | grep -qE 'find[[:space:]].*-(delete|-exec|-ok)([[:space:]]|$)'; then
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"危险命令（P0 删除类）被拦截：find 带 -delete/-exec/-ok 可能批量删除。请改用人工逐条确认的高置信度操作。"}}'
  exit 0
fi

# ---- DANGER P1: 系统状态变更（可逆的运维命令不在本清单） ----
for cmd in 'reg[[:space:]]+delete' 'sc[[:space:]]+delete' 'shutdown[[:space:]]*$|shutdown[[:space:]]+.*-r' '(^|[[:space:]])reboot([[:space:]]|$)|reboot$' 'bcdedit'; do
  if printf '%s' "$STRIPPED" | grep -qiE "$cmd"; then
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"危险命令（P1 系统状态变更）被拦截：命中 %s。系统级变更请人工在服务器上操作。"}}' "$cmd"
    exit 0
  fi
done

# ---- DANGER P2: 数据库 DDL / 危险 DML（用原始 COMMAND，避免引号内漏拦） ----
if printf '%s' "$COMMAND" | grep -qiE '(drop|truncate)[[:space:]]+(table|schema|database)'; then
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"危险命令（P2 数据库 DDL）被拦截：DROP/TRUNCATE。结构变更请在 DBX 或人工审核后执行。"}}'
  exit 0
fi
if printf '%s' "$COMMAND" | grep -qiE 'delete[[:space:]]+from[[:space:]]+[a-z0-9_.]+' && ! printf '%s' "$COMMAND" | grep -qiE 'delete[[:space:]]+from[[:space:]]+[a-z0-9_.]+[[:space:]]+where'; then
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"危险命令（P2 数据库 DML）被拦截：DELETE FROM 缺少 WHERE 会整表删除。"}}'
  exit 0
fi
if printf '%s' "$COMMAND" | grep -qiE 'update[[:space:]]+[a-z0-9_.]+[[:space:]]+set' && ! printf '%s' "$COMMAND" | grep -qiE 'update[[:space:]]+[a-z0-9_.]+[[:space:]]+set.*where'; then
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"危险命令（P2 数据库 DML）被拦截：UPDATE 缺少 WHERE 会全表改写。"}}'
  exit 0
fi

# ---- DANGER P3: 权限放大 ----
if printf '%s' "$STRIPPED" | grep -qiE '(chmod[[:space:]]+-R[[:space:]]*777|chown[[:space:]]+-R|chmod[[:space:]]+-?[rR]([[:space:]]|$)000)'; then
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"危险命令（P3 权限放大）被拦截：chmod/chown 递归修改权限。请限定到精确路径。"}}'
  exit 0
fi

# ---- DANGER P4: 系统破坏类 ----
if printf '%s' "$STRIPPED" | grep -qiE '(^|[[:space:]])(mkfs|fdisk|format)([[:space:]]|$)|:\(\)\{\|:' ; then
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"危险命令（P4 系统破坏类）被拦截：mkfs/fdisk/format/fork bomb 不允许由 AI 执行。"}}'
  exit 0
fi

# 未命中任何危险规则 → 交还给权限模式判定
printf '{"continue":true}'
exit 0