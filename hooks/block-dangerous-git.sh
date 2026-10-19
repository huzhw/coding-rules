#!/bin/bash
export PATH="/usr/bin:/bin:$PATH"

IFS= read -r -d '' INPUT || true
COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command')

DANGEROUS_PATTERNS=(
  "git reset --hard"
  "git clean -fd"
  "git clean -f"
  "git branch -D"
  "git checkout \."
  "git restore \."
  "push --force"
  "reset --hard"
  # git 逐文件 stage：禁止 git add 全部（规则：禁止 git add . && git commit）
  "git add[[:space:]]+\.([[:space:]]|$)"
  "git add[[:space:]]+-A([[:space:]]|$)"
  "git add[[:space:]]+-a([[:space:]]|$)"
  "git add[[:space:]]+--all([[:space:]]|$)"
)

shopt -s nocasematch
for pattern in "${DANGEROUS_PATTERNS[@]}"; do
  if [[ "$COMMAND" =~ $pattern ]]; then
    echo "BLOCKED: '$COMMAND' matches dangerous pattern '$pattern'. The user has prevented you from doing this." >&2
    exit 2
  fi
done

exit 0
