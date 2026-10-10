# =====================================================================
# sync-rules.ps1 — 全局规则文件同步脚本
#
# 作用：把 coding-rules 仓库的规则内容推送到 C 盘的 6 个全局规则文件
#       （.claude\CLAUDE.md + .codex/.dsh/.zcode/.qoder/.minimax 五处 AGENTS.md；
#       .minimax 端 = MiniMax Code，2026-10-10 接入，全局规则 = ~/.minimax/AGENTS.md），
#       并生成/刷新 CodeBuddy 用户规则副本
#       （.codebuddy\rules\core-discipline.md = frontmatter + F 源全文）。
# 实现：C 盘 6 个文件 = 硬链接组（同 inode，改任一同步六处）。
#       CodeBuddy 官方不读用户目录下的 CLAUDE.md/CODEBUDDY.md（2026-10-10
#       实测：全局规则未注入会话；官方只认项目级 CODEBUDDY.md），用户级
#       规则唯一通道 = ~/.codebuddy/rules/ 下带 alwaysApply:true frontmatter
#       的 md——它是拷贝端不是硬链接（frontmatter 须独立于组内容），
#       由本脚本 -Push 生成/刷新、agent-config-sync-check 的 RulesCopyDrift 看管。
# 用法：
#   powershell -File sync-rules.ps1 -Push     # 把 F 仓库内容推送到 C 盘组 + 刷新 CodeBuddy 副本
#   powershell -File sync-rules.ps1 -Check    # 检查一致性（含 CodeBuddy 副本）
#   powershell -File sync-rules.ps1           # 默认 Check
# =====================================================================

param(
    [switch]$Push,
    [switch]$Check
)

$ErrorActionPreference = "Stop"

$F_MAIN = "F:\idea-workspase-skills\coding-rules\CLAUDE.md"
$CFile  = "C:\Users\Administrator\.claude\CLAUDE.md"
$Group  = @(
    "C:\Users\Administrator\.claude\CLAUDE.md",
    "C:\Users\Administrator\.codex\AGENTS.md",
    "C:\Users\Administrator\.dsh\AGENTS.md",
    "C:\Users\Administrator\.zcode\AGENTS.md",
    "C:\Users\Administrator\.qoder\AGENTS.md",
    "C:\Users\Administrator\.minimax\AGENTS.md"
)

# CodeBuddy 用户规则副本（拷贝端，非硬链接）：frontmatter 固定不变，正文跟随 F 源。
# 用户若在 CodeBuddy 规则界面改动，会被下次 -Push 覆盖（与 C 盘组同一条红线）。
$CB_RULES_DIR   = "C:\Users\Administrator\.codebuddy\rules"
$CB_COPY        = "$CB_RULES_DIR\core-discipline.md"
$CB_FRONTMATTER = @"
---
description: 全局核心纪律：编辑前确认流程、环境约束、工具约定（与 C 盘六链接规则同源；改规则走 coding-rules 仓库再 -Push，勿直改本文件）
alwaysApply: true
enabled: true
---
"@

if (-not $Push -and -not $Check) { $Check = $true }

# 确保组内前两个文件存在（.claude\CLAUDE.md 为组底座）
if (-not (Test-Path -LiteralPath $CFile)) {
    if (Test-Path -LiteralPath $F_MAIN) {
        Copy-Item -LiteralPath $F_MAIN -Destination $CFile
        Write-Host "[建]  .claude\CLAUDE.md 已从 F 仓库复制" -ForegroundColor Green
    } else {
        throw "F 仓库规则文件不存在: $F_MAIN"
    }
}

# 组内缺失成员自动补建：硬链接挂到底座（同卷 C:，等价 mklink /H；新端接入零手工）。
# 只补「不存在」的成员——已存在的独立副本/分叉内容绝不静默接管，那归 sync-check.ps1 -FixHardlink 管
foreach ($f in $Group) {
    if ($f -eq $CFile) { continue }
    if (-not (Test-Path -LiteralPath $f)) {
        New-Item -ItemType HardLink -Path $f -Value $CFile | Out-Null
        Write-Host "[建]  $f 已硬链接到底座（同 inode 自动跟随组内容）" -ForegroundColor Green
    }
}

if ($Check) {
    Write-Host "=== 检查规则文件一致性 ==="
    $rootHash = (Get-FileHash -LiteralPath $CFile -Algorithm MD5).Hash
    foreach ($f in $Group) {
        if (-not (Test-Path -LiteralPath $f)) {
            Write-Host "[缺]  $f" -ForegroundColor Red
            continue
        }
        $h = (Get-FileHash -LiteralPath $f -Algorithm MD5).Hash
        if ($h -eq $rootHash) {
            Write-Host "[OK]  $f" -ForegroundColor Green
        } else {
            Write-Host "[异]  $f" -ForegroundColor Yellow
        }
    }
    # 与 F 仓库对比
    $fh = (Get-FileHash -LiteralPath $F_MAIN -Algorithm MD5).Hash
    if ($fh -eq $rootHash) {
        Write-Host "[OK]  F 仓库 == C 盘组（内容一致）" -ForegroundColor Green
    } else {
        Write-Host "[异]  F 仓库与 C 盘组内容不同（跑 -Push 同步）" -ForegroundColor Yellow
    }
    # CodeBuddy 用户规则副本：剥 frontmatter 后比对正文（与 sync-check 口径一致）
    if (-not (Test-Path -LiteralPath $CB_COPY)) {
        Write-Host "[缺]  $CB_COPY（CodeBuddy 用户规则副本，跑 -Push 生成）" -ForegroundColor Red
    } else {
        $cbText = [IO.File]::ReadAllText($CB_COPY)
        $fm = [regex]::Match($cbText, '(?s)\A\s*---\r?\n.*?\r?\n---\s*')
        if ($fm.Success) { $cbText = $cbText.Substring($fm.Length) }
        $srcText = (Get-Content -LiteralPath $F_MAIN -Raw -Encoding UTF8).Trim()
        if ($cbText.Trim() -eq $srcText) {
            Write-Host "[OK]  CodeBuddy 用户规则副本 == F 仓库（正文一致）" -ForegroundColor Green
        } else {
            Write-Host "[异]  CodeBuddy 用户规则副本与 F 仓库不同（跑 -Push 同步）" -ForegroundColor Yellow
        }
    }
}

if ($Push) {
    Write-Host "=== 推送 F 仓库 -> C 盘组 ==="
    # 先用临时文件写入底座（避免组内部瞬时不一致）
    $tmp = "$CFile.tmp"
    Copy-Item -LiteralPath $F_MAIN -Destination $tmp -Force
    # 触发硬链接组其余文件更新：先删底座再复制替换会破坏组关联。
    # 正确方式：原地写底座（WriteAllText 截断写同 inode），硬链接组其它成员同步变化。
    # 注意：必须无 BOM 写入（PS5.1 的 Set-Content -Encoding UTF8 会烙 BOM，导致与 F 源 MD5 永远对不齐）。
    $content = Get-Content -LiteralPath $tmp -Raw -Encoding UTF8
    [System.IO.File]::WriteAllText($CFile, $content, (New-Object System.Text.UTF8Encoding($false)))
    Remove-Item -LiteralPath $tmp -Force
    Write-Host "[推送完成] C 盘组已同步 F 仓库内容" -ForegroundColor Green
    # CodeBuddy 用户规则副本：目录不存在自动建，整文件重写（frontmatter 固定 + F 源全文，无 BOM UTF8）
    if (-not (Test-Path -LiteralPath $CB_RULES_DIR)) {
        New-Item -ItemType Directory -Path $CB_RULES_DIR -Force | Out-Null
        Write-Host "[建]  $CB_RULES_DIR 目录已创建" -ForegroundColor Green
    }
    [System.IO.File]::WriteAllText($CB_COPY, $CB_FRONTMATTER + "`r`n`r`n" + $content, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host "[推送完成] CodeBuddy 用户规则副本已生成: $CB_COPY" -ForegroundColor Green
}