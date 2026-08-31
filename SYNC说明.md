# 五目录同步说明（coding-rules）

本仓库 `coding-rules` 是整个 AI 编码协作规范与自研技能的**唯一内容源**，统一负责向 5 个用户级目录分发。

**五个目录：**
  1. `C:\Users\Administrator\.claude`（Claude Code）
  2. `C:\Users\Administrator\.zcode`（Zcode）
  3. `C:\Users\Administrator\.codex`（Codex）
  4. `C:\Users\Administrator\.dsh`（DSH）
  5. `F:\idea-workspase-skills`（内容源，git 仓库）

---

## 一、技能（skills）同步模型

每个工具全局 `skills` 目录下的**自研技能**都是指向 `F:\...\idea-workspase-skills\<仓库>\[子技能]` 的 **junction**（跨盘无需管理员特权，改 F 即全局生效）。

### 自研技能清单（14 项）

| 全局技能名 | 指向（junction） |
|---|---|
| `code-check` | `F:\idea-workspase-skills\code-check` |
| `code-check-today` | `F:\idea-workspase-skills\code-check\code-check-today` |
| `code-check-yesterday` | `F:\idea-workspase-skills\code-check\code-check-yesterday` |
| `code-check-from` | `F:\idea-workspase-skills\code-check\code-check-from` |
| `code-check-history` | `F:\idea-workspase-skills\code-check\code-check-history` |
| `code-recheck-today` | `F:\idea-workspase-skills\code-check\code-recheck-today` |
| `code-recheck-yesterday` | `F:\idea-workspase-skills\code-check\code-recheck-yesterday` |
| `code-recheck-from` | `F:\idea-workspase-skills\code-check\code-recheck-from` |
| `claude-code-token-3000` | `F:\idea-workspase-skills\claude-code-token-3000` |
| `daily-merge-gitlab-excel` | `F:\idea-workspase-skills\daily-merge-gitlab-excel` |
| `daily-record-gitlab-md` | `F:\idea-workspase-skills\daily-record-gitlab-md` |
| `deepseek-harness-settings-curator` | `F:\idea-workspase-skills\deepseek-harness-settings-curator` |
| `git-commit` | `F:\idea-workspase-skills\claude-git-commit-skill\git-commit` |
| `reread-rules` | `F:\idea-workspase-skills\reread-rules` |

### 各全局 skills 目录的 junction 数量（校验基线）

| 全局目录 | 自研 14 个 | 官方 builtin | 说明 |
|---|---|---|---|
| `.claude\skills` | ✅ 14 | 25 个真实目录 | 官方技能在 claude 目录是**真实独立目录**（非 junction） |
| `.dsh\skills` | ✅ 14 | 无 | 纯自研 |
| `.codex\skills` | ✅ 14 | `.system\`（5 个内置） | 无需动 |
| `.zcode\skills` | ✅ 14 | 25 个 `-> .claude\skills\...` junction | 官方技能**保持绕道 claude**（用户指示不用管） |

> **约定**：zcode 的 25 个官方 builtin（`api-and-interface-design` 等）继续`-> C:\...\.claude\skills\...`，**不迁移**，只保证其目标真实存在。zcode 的自研 14 个自 2026-08-31 起全部直连 F。

### 检查 & 重建脚本

`scripts/sync-skills.ps1`

```powershell
# 校验（只检查不修改，输出 [OK]/[误]/[缺]）
powershell -File scripts\sync-skills.ps1

# 校验并修复（删除旧链接重建，仅动 14 项自研，官方不碰）
powershell -File scripts\sync-skills.ps1 -Fix

# 只看某目录
powershell -File scripts\sync-skills.ps1 -Base "C:\Users\Administrator\.zcode\skills"
```

---

## 二、规则文件（CLAUDE.md / AGENTS.md）同步模型

> `coding-rules` 的规则正文源 = **`coding-rules\CLAUDE.md`**（F 盘，参与 git）。
> C 盘 4 个规则文件 = **单向硬链接组**（同 inode，改任一同步四处），由 push 推入。

### 硬链接组（C 盘）

| 路径 | 链接类型 |
|---|---|
| `C:\Users\Administrator\.claude\CLAUDE.md` | HardLink |
| `C:\Users\Administrator\.codex\AGENTS.md` | HardLink |
| `C:\Users\Administrator\.dsh\AGENTS.md` | HardLink |
| `C:\Users\Administrator\.zcode\AGENTS.md` | HardLink |

四个文件 **FileID 相同**（同一 inode），MD5 与 `coding-rules\CLAUDE.md` 完全一致（`55BED891…`）。

**同步时注意：**
- 改 `coding-rules\CLAUDE.md` 后，**跑 push 脚本**把内容推给 C 盘组（硬链接无法跨盘自动同步）。
- C 盘组里改任一文件，文件内容需 git 之外手动回源（一般不直接改 C 盘；规则源只改 F）。
- 硬链接组**重建要整组一起**：删底座重建会破坏其他三个链接。

### 脚本

`scripts/sync-rules.ps1`

```powershell
# 检查一致性（组内 + F 源）
powershell -File scripts\sync-rules.ps1 -Check

# 推送 F 仓库 -> C 盘组
powershell -File scripts\sync-rules.ps1 -Push
```

---

## 三、hooks 脚本分发模型（2026-08-31 新增）

四端工具的防护钩子（危险命令拦截、记忆守卫、下载提醒）**能力对齐、实现各异**：

### 事实源与分发链

| 层 | 位置 | 说明 |
|---|---|---|
| **事实源** | `F:\idea-workspase-skills\coding-rules\hooks\`（6 脚本，git 管理） | 改防护逻辑**只改这里** |
| Claude Code | `~\.claude\hooks\`（分发副本） | `~\.claude\settings.json` hooks 段加载 |
| Zcode | 引用 `~\.claude\hooks\` 同一路径 | `~\.zcode\settings.json` hooks 段，与 Claude 共用脚本 |
| Codex | `~\.codex\hooks\guard-memory-write-codex.sh`、`guard-memory-approved-codex.sh`（**专用适配版**，适配 apply_patch 工具与 Codex 输出格式）；Bash 拦截直接引用 `~\.claude\hooks\` 两脚本 | `~\.codex\config.toml` 的 `[[hooks.*]]` 段，需 `[features] hooks = true` |

**6 个通用脚本**：block-dangerous-git.sh、block-amper-and.sh、guard-dangerous-bash.sh、guard-memory-write.sh、guard-memory-approved.sh、warn-download-location.sh

### 分发方式与维护规则

- 通用脚本是**手动复制分发**（改完事实源后 copy 到 `~\.claude\hooks\`），**不是链接**——改脚本后必须同步复制，否则 Claude/Zcode/Codex 用旧版
- Codex 适配版只存在于 `~\.codex\hooks\`（Codex 的 apply_patch 工具名与输入输出格式与 Claude 不同，拦截输出需 JSON 转义适配）；改它们不涉及其他端
- 脚本改动走 coding-rules 仓库 git 提交；`~\.codex\hooks\` 不入 git
- Codex 的 `config.toml` 里每条 hook 命令有 `trusted_hash` 登记，**hook 命令文本变更后 Codex 会要求重新信任**，属正常机制

### 各端加载点速查

| 端 | 配置文件 | 挂载内容 |
|---|---|---|
| Claude Code | `~\.claude\settings.json` → `hooks` | PreToolUse：Bash×3（危险 git / && / 危险 bash）、Write\|Edit 记忆守卫；PostToolUse：记忆台账、下载提醒；Stop/SessionEnd：tokentracker 通知 |
| Zcode | `~\.zcode\settings.json` → `hooks` | 同 Claude（不含 rtk、不含 tokentracker） |
| Codex | `~\.codex\config.toml` → `[[hooks.PreToolUse/PostToolUse]]` | Bash 前置×2、apply_patch 前后置记忆守卫；`notify` 已接 tokentracker |
| DSH | 无 hooks 机制，等价物见 `agent-config-sync-check\HOOKS说明.md` | rules.yaml 规则 + 内置基线 + dsh-permission-rules / dsh-auto-review / dsh-defend / dsh-notification 四插件 |

---

## 四、维护节奏（推荐）

| 操作 | 怎么做 |
|---|---|
| 新增/修改自研技能 | 改 `F:\...\skills\<仓库>` → 跑 `sync-skills.ps1 -Fix` 同步四个全局目录 |
| 修改规则正文 | 改 `coding-rules\CLAUDE.md` → **commit/push gitlab** → 跑 `sync-rules.ps1 -Push` 推 C 盘 |
| 从新机器恢复 | clone 5 仓库到 `F:\...\skills\` → 跑两类脚本再校验 |
| 校验全部 | `sync-skills.ps1` + `sync-rules.ps1 -Check` |

---

## 五、回滚/重建方法

### skills junction 回滚（恢复独立副本）
```bat
rd "C:\Users\Administrator\.claude\skills\code-check"
rd "C:\Users\Administrator\.dsh\skills\code-check"
rd "C:\Users\Administrator\.codex\skills\code-check"
rd "C:\Users\Administrator\.zcode\skills\code-check"
```
> `rd` 不加 `/s` 只删链接不删 F 源。14 项技能按清单逐个处理。

### 规则硬链接组重建
```bat
del "C:\Users\Administrator\.codex\AGENTS.md" "C:\Users\Administrator\.dsh\AGENTS.md" "C:\Users\Administrator\.zcode\AGENTS.md"
copy  "C:\Users\Administrator\.claude\CLAUDE.md" "C:\Users\Administrator\.codex\AGENTS.md"
mklink /H "C:\Users\Administrator\.dsh\AGENTS.md"   "C:\Users\Administrator\.claude\CLAUDE.md"
mklink /H "C:\Users\Administrator\.zcode\AGENTS.md" "C:\Users\Administrator\.claude\CLAUDE.md"
```
> `mklink /H` 建文件硬链接（同卷）。

---

## 六、为什么 coding-rules 没有 JUNCTION说明.md

其他 7 个技能仓库都建了 junction，所以各自写 `JUNCTION说明.md` 记录“全局谁→F 仓库谁”。coding-rules 是**内容源仓库**，自身不在任何全局目录里（不是 junction 目标），它的分发机制是上面这套 **skills junction + 规则硬链接组**，所以用本说明替代原来的 JUNCTION 模板。