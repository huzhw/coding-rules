#!/bin/bash
export PATH="/usr/bin:/bin:$PATH"
shopt -s nocasematch
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
#   DANGER  危险（硬拦）     递归 rm 的非白名单目标（项目内目标先移入隔离区再拒）、
#                           reg delete、sc delete、bcdedit、shutdown/reboot、
#                           DROP/TRUNCATE、无 WHERE 的 DELETE/UPDATE、
#                           chmod -R 777 / chown -R / chmod -r 000、
#                           find -delete/-exec/-ok、mkfs/fdisk/fork bomb
#   SAFE    安全目标（放行） 递归 rm 指向构建/缓存/输出目录（target/ node_modules/
#                           dist/ build/ out/ classes/ logs/ package/ __pycache__/
#                           .pytest_cache/.coverage/.mypy_cache/.venv/venv、*.pyc，
#                           末级目录同名即算）或临时区（/tmp、/x/temp、X:\Temp、
#                           %LOCALAPPDATA%\Temp、C:\Windows\Temp 的下一层及更深）
#   PASS    常态放行         taskkill /f、net stop/start、sc stop/start；
#                           非递归 rm（不带 -r/-R）不归本规则管
#
# 注意（P2）：SQL 语句常以引号字符串出现（mysql -e "DROP TABLE t1"），
#      不能走 STRIPPED（引号内会被剥掉 → 漏拦），必须用原始 COMMAND 匹配。
# =====================================================================

IFS= read -r -d '' INPUT || true
COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')
[ -z "$COMMAND" ] && printf '{"continue":true}' && exit 0

# ---- JSON 转义：deny 的 reason 嵌入动态值（反斜杠/双引号）会产出非法 JSON，Codex 解析失败即不拦截 ----
# 所有进入 reason 的动态值（RM_TARGET / cmd）必须先经 json_escape 再放入格式串
json_escape() {
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

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

# ---- DANGER P0: 递归删除（rm 带 -r/-R） ----
# 非递归 rm 不在本规则内（单文件删除交给权限模式）。
# 递归 rm 的每个目标独立判定（词法切分、逐目标，不粘串）：
#   ① 构建/缓存/输出白名单（末级目录同名即放行，相对/绝对均可）
#   ② 临时区（/tmp、/x/temp、%LOCALAPPDATA%\Temp、C:\Windows\Temp 的下一层及更深）
#   ③ 项目内目标（当前目录下，相对或绝对）→ 移入隔离区后拒（可原样搬回）
#   ④ 其余（系统绝对路径、根/家/上级路径/通配/变量）→ 直接拒，不移动
# 隔离区默认 X:/隔离区（GUARD_QUARANTINE_DIR 可改）；每次隔离顺手清
#   GUARD_QUARANTINE_DAYS（默认 14）天前旧条目，并压到 GUARD_QUARANTINE_MAX_MB（默认 10240）MB 内
QROOT_DEFAULT="X:/隔离区"
# 项目根：优先客户端注入的变量，其次进程 PWD（相对路径与隔离范围都以它为基准）
PROJ_DIR="${CLAUDE_PROJECT_DIR:-${ZCODE_PROJECT_DIR:-$PWD}}"

qroot_path() {
  local q="${GUARD_QUARANTINE_DIR:-$QROOT_DEFAULT}"
  case "$q" in /*|[a-zA-Z]:/*) printf '%s' "$q" ;; *) printf '%s' "$QROOT_DEFAULT" ;; esac
}

prune_quarantine() {
  local q days maxmb sz oldest
  q=$(qroot_path)
  days="${GUARD_QUARANTINE_DAYS:-14}"
  maxmb="${GUARD_QUARANTINE_MAX_MB:-10240}"
  case "$q" in ""|"/") return 0 ;; esac
  [ -d "$q" ] || return 0
  # 只碰隔离区下一层，路径钉死
  find "$q" -mindepth 1 -maxdepth 1 -type d -mtime +"$days" -exec rm -rf {} + 2>/dev/null
  # 容量上限：超了按最旧先删
  while :; do
    sz=$(du -sm "$q" 2>/dev/null | cut -f1)
    [ -z "$sz" ] && break
    [ "$sz" -le "$maxmb" ] && break
    oldest=$(ls -1d "$q"/*/ 2>/dev/null | head -1)
    [ -z "$oldest" ] && break
    rm -rf "$oldest" 2>/dev/null
  done
}

deny_json() {
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}' "$(json_escape "$1")"
  exit 0
}

# 词法切分：保留引号内容（去引号），命令分隔符输出 __SEP__；每行结束补 __SEP__
tokenize() {
  printf '%s\n' "$1" | awk '
  {
    n = length($0); tok = ""; sq = 0; dq = 0; bt = 0
    for (i = 1; i <= n; i++) {
      c = substr($0, i, 1)
      if (sq == 0 && dq == 0 && bt == 0) {
        if (c == "\\") { if (i + 1 <= n) { tok = tok substr($0, i + 1, 1); i++ } ; continue }
        if (c == "\047") { sq = 1; continue }
        if (c == "\042") { dq = 1; continue }
        if (c == "\140") { bt = 1; continue }
        if (c == " " || c == "\t") { if (tok != "") { print tok; tok = "" } ; continue }
        if (c == "&" || c == "|" || c == ";" || c == "(" || c == ")") {
          if (tok != "") { print tok; tok = "" }
          print "__SEP__"
          continue
        }
        tok = tok c
      } else if (sq == 1) {
        if (c == "\047") sq = 0; else tok = tok c
      } else if (dq == 1) {
        # 双引号内反斜杠只对 " \ $ ` 与换行有转义语义，其余字符保留反斜杠本身
        if (c == "\\") {
          if (i + 1 <= n) {
            nx = substr($0, i + 1, 1)
            if (nx == "\042" || nx == "\\" || nx == "$" || nx == "\140") { tok = tok nx; i++ }
            else tok = tok c
          } else tok = tok c
        }
        else if (c == "\042") dq = 0
        else tok = tok c
      } else {
        if (c == "\140") bt = 0; else tok = tok c
      }
    }
    if (tok != "") print tok
    print "__SEP__"
  }'
}

is_wrapper() {
  case "$1" in sudo|doas|command|time|nice|nohup|env|xargs|timeout|stdbuf) return 0 ;; *) return 1 ;; esac
}

# 目标分类：0=放行（白名单/临时区）；1=待处理（隔离或拒）；硬否决直接 deny 退出
classify_target() {
  local t="$1" norm base
  norm=$(printf '%s' "$t" | tr '\\' '/')
  norm=$(printf '%s' "$norm" | tr '[:upper:]' '[:lower:]')
  while [ "${norm%/}" != "$norm" ]; do norm="${norm%/}"; done
  case "$norm" in
    ""|"."|"/"|"~") deny_json "危险命令（P0 删除类）被拦截：rm 目标是空、根目录、当前目录或家目录，禁止执行。" ;;
    ..|../*|*/..|*/../*) deny_json "危险命令（P0 删除类）被拦截：rm 目标「$t」含上级路径（..），无法安全判定，禁止执行。" ;;
    *'$'*|*'*'*|*'?'*|*'['*) deny_json "危险命令（P0 删除类）被拦截：rm 目标「$t」含变量或通配符，无法安全隔离，禁止执行。" ;;
  esac
  # 临时区：根本身拒，下一层及更深放行
  case "$norm" in
    /tmp|/x/temp|x:/temp|c:/windows/temp) deny_json "危险命令（P0 删除类）被拦截：rm 目标是临时区根目录，禁止整目录删除。" ;;
    /tmp/?*|/x/temp/?*|x:/temp/?*|c:/windows/temp/?*|c:/users/*/appdata/local/temp/?*) return 0 ;;
  esac
  # 构建/缓存/输出白名单：末级目录同名即放行
  base="${norm##*/}"
  case "$base" in
    target|node_modules|dist|build|out|classes|logs|package|__pycache__|.pytest_cache|.coverage|.mypy_cache|.venv|venv) return 0 ;;
    *.pyc) return 0 ;;
  esac
  return 1
}

# 解析为真实路径，且限定"项目内"（PROJ_DIR 前缀）才允许进隔离区
resolve_in_project() {
  local t="$1" src pw
  case "$t" in
    /*) src="$t" ;;
    [a-zA-Z]:*) src=$(cygpath -u "$t" 2>/dev/null) || return 1 ;;
    *) src="$PROJ_DIR/$t" ;;
  esac
  [ -e "$src" ] || return 1
  pw=$(printf '%s' "$PROJ_DIR" | tr '\\' '/')
  case "$src" in
    "$pw"/*) printf '%s' "$src"; return 0 ;;
    *) return 1 ;;
  esac
}

evaluate_rm_targets() {
  local -a bad=()
  local t
  [ $# -eq 0 ] && deny_json "危险命令（P0 删除类）被拦截：rm 递归删除缺少目标，禁止执行。"
  for t in "$@"; do
    classify_target "$t" || bad+=("$t")
  done
  [ ${#bad[@]} -eq 0 ] && return 0

  local -a moved=() failed=()
  local q stamp proj name entry src
  q=$(qroot_path)
  for t in "${bad[@]}"; do
    if ! src=$(resolve_in_project "$t"); then
      failed+=("$t")
      continue
    fi
    mkdir -p "$q" 2>/dev/null
    stamp=$(date +%Y%m%d-%H%M%S)
    proj=$(basename "$PROJ_DIR")
    name=$(basename "$src")
    entry="$q/$stamp-$proj-$name"
    [ -e "$entry" ] && entry="$entry-$$"
    if mkdir -p "$entry" 2>/dev/null && mv "$src" "$entry/" 2>/dev/null; then
      printf '原路径: %s\n删除时间: %s\n触发命令: %s\n' "$(cygpath -w "$src" 2>/dev/null || printf '%s' "$src")" "$(date '+%F %T')" "$(printf '%s' "$COMMAND" | tr '\n' ' ')" > "$entry/README.txt" 2>/dev/null
      moved+=("$entry")
    else
      failed+=("$t")
    fi
  done
  [ ${#moved[@]} -gt 0 ] && prune_quarantine

  local msg="危险命令（P0 删除类）被拦截："
  [ ${#moved[@]} -gt 0 ] && msg="$msg目标「${bad[*]}」不在白名单，已移入隔离区 ${moved[*]}（${GUARD_QUARANTINE_DAYS:-14} 天内可找回）；"
  [ ${#failed[@]} -gt 0 ] && msg="$msg目标「${failed[*]}」无法隔离（不存在/无权限/非项目内路径），直接拒绝；"
  msg="$msg原命令未执行。"
  deny_json "$msg"
}

scan_command() {
  local text="$1" inner
  # 嵌套命令替换（$(...) 与反引号内层）尽力递归扫描
  while IFS= read -r inner; do
    [ -n "$inner" ] && scan_command "$inner"
  done < <(printf '%s\n' "$text" | grep -oE '\$\([^()]*\)|`[^`]*`' 2>/dev/null | sed -E 's/^\$\(([^()]*)\)$/\1/; s/^`([^`]*)`$/\1/')

  local -a toks targets
  mapfile -t toks < <(tokenize "$text")
  local i=0 n=${#toks[@]} first="" tok
  local rm_active=0 rm_flag=0 literal=0 shell_c=0
  targets=()
  while [ $i -lt $n ]; do
    tok="${toks[$i]}"
    i=$((i+1))
    if [ "$tok" = "__SEP__" ]; then
      if [ "$rm_active" = "1" ] && [ "$rm_flag" = "1" ]; then
        evaluate_rm_targets "${targets[@]}"
      fi
      first=""; rm_active=0; rm_flag=0; literal=0; shell_c=0; targets=()
      continue
    fi
    [ -z "$first" ] && first="$tok"
    if [ "$shell_c" = "1" ]; then
      # sh -c / bash -c 的内联命令字符串：递归扫描
      scan_command "$tok"
      shell_c=0
      continue
    fi
    if [ "$rm_active" = "0" ]; then
      if [ "$tok" = "sh" ] || [ "$tok" = "bash" ] || [ "$tok" = "zsh" ] || [ "$tok" = "dash" ]; then
        shell_c=2
      elif [ "$shell_c" = "2" ] && [ "$tok" = "-c" ]; then
        shell_c=1
      elif [ "$tok" = "rm" ] || [ "${tok##*/}" = "rm" ]; then
        if [ "$first" = "$tok" ] || is_wrapper "$first"; then
          rm_active=1; rm_flag=0; literal=0
        fi
      elif [ "$shell_c" = "2" ] && [ "$tok" != "-c" ]; then
        shell_c=0
      fi
    else
      if [ "$literal" = "0" ] && [ "$tok" = "--" ]; then
        literal=1
      elif [ "$literal" = "0" ] && [[ "$tok" == -* ]]; then
        [[ "$tok" =~ ^-[a-zA-Z]*[rR][a-zA-Z]*$ ]] && rm_flag=1
        [ "$tok" = "--recursive" ] && rm_flag=1
      else
        targets+=("$tok")
      fi
    fi
  done
  # 结尾兜底（tokenize 每行补 SEP，这里防多行拼尾）
  if [ "$rm_active" = "1" ] && [ "$rm_flag" = "1" ]; then
    evaluate_rm_targets "${targets[@]}"
  fi
}

scan_command "$COMMAND"
if [[ "$STRIPPED" =~ find[[:space:]].*-(delete|-exec|-ok)([[:space:]]|$) ]]; then
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"危险命令（P0 删除类）被拦截：find 带 -delete/-exec/-ok 可能批量删除。请改用人工逐条确认的高置信度操作。"}}'
  exit 0
fi

# ---- DANGER P1: 系统状态变更（可逆的运维命令不在本清单） ----
for cmd in 'reg[[:space:]]+delete' 'sc[[:space:]]+delete' 'shutdown[[:space:]]*$|shutdown[[:space:]]+.*-r' '(^|[[:space:]])reboot([[:space:]]|$)|reboot$' 'bcdedit'; do
  if [[ "$STRIPPED" =~ $cmd ]]; then
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"危险命令（P1 系统状态变更）被拦截：命中 %s。系统级变更请人工在服务器上操作。"}}' "$(json_escape "$cmd")"
    exit 0
  fi
done

# ---- DANGER P2: 数据库 DDL / 危险 DML（用原始 COMMAND，避免引号内漏拦） ----
if [[ "$COMMAND" =~ (drop|truncate)[[:space:]]+(table|schema|database) ]]; then
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"危险命令（P2 数据库 DDL）被拦截：DROP/TRUNCATE。结构变更请在 DBX 或人工审核后执行。"}}'
  exit 0
fi
if [[ "$COMMAND" =~ delete[[:space:]]+from[[:space:]]+[a-z0-9_.]+ ]] && ! [[ "$COMMAND" =~ delete[[:space:]]+from[[:space:]]+[a-z0-9_.]+[[:space:]]+where ]]; then
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"危险命令（P2 数据库 DML）被拦截：DELETE FROM 缺少 WHERE 会整表删除。"}}'
  exit 0
fi
if [[ "$COMMAND" =~ update[[:space:]]+[a-z0-9_.]+[[:space:]]+set ]] && ! [[ "$COMMAND" =~ update[[:space:]]+[a-z0-9_.]+[[:space:]]+set.*where ]]; then
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"危险命令（P2 数据库 DML）被拦截：UPDATE 缺少 WHERE 会全表改写。"}}'
  exit 0
fi

# ---- DANGER P3: 权限放大 ----
if [[ "$STRIPPED" =~ (chmod[[:space:]]+-R[[:space:]]*777|chown[[:space:]]+-R|chmod[[:space:]]+-?[rR]([[:space:]]|$)000) ]]; then
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"危险命令（P3 权限放大）被拦截：chmod/chown 递归修改权限。请限定到精确路径。"}}'
  exit 0
fi

# ---- DANGER P4: 系统破坏类 ----
if [[ "$STRIPPED" =~ (^|[[:space:]])(mkfs|fdisk|format)([[:space:]]|$)|:\(\)\{\|: ]] ; then
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"危险命令（P4 系统破坏类）被拦截：mkfs/fdisk/format/fork bomb 不允许由 AI 执行。"}}'
  exit 0
fi

# 未命中任何危险规则 → 交还给权限模式判定
printf '{"continue":true}'
exit 0