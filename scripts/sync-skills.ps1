# =====================================================================
# sync-skills.ps1 — 统一技能 junction 同步脚本
#
# 作用：确保 claude / dsh / codex / zcode 四个全局 skills 目录中的
#       自研技能全部直连 F 仓库（F:\idea-workspase-skills）。
# 用法：
#   powershell -File sync-skills.ps1            # 校验 + 报告
#   powershell -File sync-skills.ps1 -Fix       # 校验并修复不一致
#   powershell -File sync-skills.ps1 -Base <某全局skills路径>   # 指定目录
#
# 幂等：已存在的 junction 且目标正确 → 不动；错误/缺失 → 重建。
# =====================================================================

param(
    [switch]$Fix,
    [string]$Base = ""
)

$ErrorActionPreference = "Stop"

# ---- 工具函数（定义在使用点之上，避免 PowerShell 作用域解析不到）----
function Get-JunctionTarget {
    param([string]$Path)
    $item = Get-Item -LiteralPath $Path -Force
    if ($null -eq $item.LinkType) { return $null }
    # junction 的 Target 属性是数组；取第一个真实路径
    $t = $item.Target
    if ($t -is [string]) { return $t }
    if ($t -is [array] -and $t.Length -gt 0) { return [string]$t[0] }
    return $null
}

function Remove-Junction {
    param([string]$Path)
    # 只删 junction 链接本身，不递归不删目标
    $item = Get-Item -LiteralPath $Path -Force
    if ($item.PSIsContainer) {
        # junction 目录用 rmdir（非 /s）
        cmd /c rmdir "$Path" | Out-Null
    }
}

function New-Junction {
    param([string]$Path, [string]$Target)
    # junction 目录跨盘创建：/J 无需符号链接权限（普通用户即可）
    cmd /c mklink /J "$Path" "$Target" 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $Path)) {
        throw "创建 junction 失败: mklink /J $Path $Target"
    }
}

# ---- F 仓库根 ----
$F_ROOT = "F:\idea-workspase-skills"

# ---- 自研技能清单：全局 name -> F 仓库相对路径 ----
# 说明：code-check 是家族仓库，主技能目录下还有 7 个子技能，各自建独立 junction。
# 其余为单技能仓库，直接指到其根目录。
$Map = @(
    # code-check 家族（主技能 + 7 子技能）
    @{ Name = "code-check";                        Target = "$F_ROOT\code-check" },
    @{ Name = "code-check-today";                  Target = "$F_ROOT\code-check\code-check-today" },
    @{ Name = "code-check-yesterday";              Target = "$F_ROOT\code-check\code-check-yesterday" },
    @{ Name = "code-check-from";                   Target = "$F_ROOT\code-check\code-check-from" },
    @{ Name = "code-check-history";                Target = "$F_ROOT\code-check\code-check-history" },
    @{ Name = "code-recheck-today";                Target = "$F_ROOT\code-check\code-recheck-today" },
    @{ Name = "code-recheck-yesterday";            Target = "$F_ROOT\code-check\code-recheck-yesterday" },
    @{ Name = "code-recheck-from";                 Target = "$F_ROOT\code-check\code-recheck-from" },
    # 其他单技能
    @{ Name = "claude-code-token-3000";            Target = "$F_ROOT\claude-code-token-3000" },
    @{ Name = "daily-merge-gitlab-excel";          Target = "$F_ROOT\daily-merge-gitlab-excel" },
    @{ Name = "daily-record-gitlab-md";            Target = "$F_ROOT\daily-record-gitlab-md" },
    @{ Name = "deepseek-harness-settings-curator"; Target = "$F_ROOT\deepseek-harness-settings-curator" },
    @{ Name = "git-commit";                        Target = "$F_ROOT\claude-git-commit-skill\git-commit" },
    @{ Name = "reread-rules";                      Target = "$F_ROOT\reread-rules" }
)

# 目标全局 skills 目录优先级
if ($Base -ne "") {
    $Targets = @($Base)
} else {
    $Targets = @(
        "C:\Users\Administrator\.claude\skills",
        "C:\Users\Administrator\.dsh\skills",
        "C:\Users\Administrator\.codex\skills",
        "C:\Users\Administrator\.zcode\skills"
    )
}

# 逐目录处理
foreach ($SkillsDir in $Targets) {
    Write-Host "`n===== $SkillsDir ====="
    if (-not (Test-Path -LiteralPath $SkillsDir)) {
        Write-Host "[跳过] 目录不存在 $SkillsDir" -ForegroundColor Yellow
        continue
    }

    foreach ($m in $Map) {
        $name   = [string]$m.Name
        $target = [string]$m.Target
        $link   = Join-Path $SkillsDir $name
        $needLink = $false

        if (Test-Path -LiteralPath $link) {
            $tgt = Get-JunctionTarget $link
            if ($tgt -and $tgt.TrimEnd('\') -eq $target.TrimEnd('\')) {
                Write-Host "  [OK]  $name" -ForegroundColor Green
            } else {
                Write-Host "  [误]  $name  指向 $tgt" -ForegroundColor Yellow
                if ($Fix) {
                    Remove-Junction $link
                    New-Junction $link $target
                    Write-Host "    -> 已重建为 $target" -ForegroundColor Green
                }
            }
        } else {
            if ($Fix) {
                New-Junction $link $target
                Write-Host "  [缺]  $name -> 已创建" -ForegroundColor Green
            } else {
                Write-Host "  [缺]  $name" -ForegroundColor Red
            }
        }
    }
}

Write-Host "`n====== 校验完成 ======"