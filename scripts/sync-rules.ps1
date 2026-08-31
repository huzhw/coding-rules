# =====================================================================
# sync-rules.ps1 — 全局规则文件同步脚本
#
# 作用：把 coding-rules 仓库的规则内容推送到 C 盘的 4 个全局规则文件
#       （.claude\CLAUDE.md + .codex\AGENTS.md + .dsh\AGENTS.md + .zcode\AGENTS.md）。
# 实现：C 盘 4 个文件 = 硬链接组（同 inode，改任一同步四处）。
#       本脚本把 F 仓库内容写入组内任一文件，即全组一致。
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
    "C:\Users\Administrator\.zcode\AGENTS.md"
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
    # 正确方式：用 Set-Content 写底座，硬链接组同 inode 其它成员同步变化。
    $content = Get-Content -LiteralPath $tmp -Raw -Encoding UTF8
    Set-Content -LiteralPath $CFile -Value $content -Encoding UTF8 -NoNewline
    Remove-Item -LiteralPath $tmp -Force
    Write-Host "[推送完成] C 盘组已同步 F 仓库内容" -ForegroundColor Green
}