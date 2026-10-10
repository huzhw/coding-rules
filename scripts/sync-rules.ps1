# =====================================================================
# sync-rules.ps1 — 全局规则文件同步脚本
#
# 作用：把 coding-rules 仓库的规则内容推送到 C 盘的 7 个全局规则文件
#       （.claude\CLAUDE.md + .codex/.dsh/.zcode/.qoder 四处 AGENTS.md
#        + .codebuddy\CLAUDE.md + .codebuddy\CODEBUDDY.md）。
# 实现：C 盘 7 个文件 = 硬链接组（同 inode，改任一同步七处）。
#       本脚本把 F 仓库内容写入底座（.claude\CLAUDE.md），全组一致；
#       组内成员缺失时自动硬链接补建（新端接入零手工）。
# 用法：
#   powershell -File sync-rules.ps1 -Push     # 把 F 仓库内容推送到 C 盘组
#   powershell -File sync-rules.ps1 -Check    # 检查一致性
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
    "C:\Users\Administrator\.codebuddy\CLAUDE.md",
    "C:\Users\Administrator\.codebuddy\CODEBUDDY.md"
)

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
}