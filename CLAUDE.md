<!-- 规则同步体系（F 盘为唯一内容源）：
     ① 唯一内容源 = F:\idea-workspase-skills\coding-rules\CLAUDE.md（git 仓库，改动只改这里）
     ② C 盘 4 个规则文件 = 单向硬链接组（.claude\CLAUDE.md + .codex/.dsh/.zcode 三处 AGENTS.md，
        同 inode 改动互见），由 coding-rules\scripts\sync-rules.ps1 -Push 从 F 整文件推入（无 BOM UTF8）
     ③ 硬链接组的坑：编辑工具"替换写"会拆链（2026-09-05 实踩）——修复用 agent-config-sync-check
        的 sync-check.ps1 -FixHardlink（SHA256 四端全等才重建，分叉拒绝）
     ④ agent-config-sync-check 检查项 13（RulesCopyDrift）看管 F↔C 正文漂移，-Fix 只重写正文、保留本头注释
     ⑤ 维护顺序（红线）：改 F → git commit/push → sync-rules.ps1 -Push → 再跑任何 sync-check。
        禁止直接改 C 盘组（会被下次 -Push 覆盖） -->

## 环境约束
- 所有代码统一用 **IntelliJ IDEA 2026.1** 编写
- 已安装 **nvm**（Node 版本管理）、**pyenv**（Python 版本管理）、**g**（Go 版本管理）和 **rustup**（Rust 版本管理）
- 升级或切换 Node、Python、Go、Rust 版本时，**必须**通过 nvm/pyenv/g/rustup，**禁止**直接安装或覆盖系统级 Node/Python/Go/Rust
- 写 Java 代码统一用 **Java 1.8**，语法和 API 都按 1.8 来
- 所有下载文件统一放到 **`N:\文件下载\ai自动下载\`**
- **下载前先看来源**：国外源优先找国内镜像，按顺序试（一个挂了换下一个）。Python/pip/uv → 阿里云 `https://mirrors.aliyun.com/pypi/simple/`、清华 `https://pypi.tuna.tsinghua.edu.cn/simple/`。npm → 淘宝 `https://registry.npmmirror.com`。Rust rustup → 清华 `https://mirrors.tuna.tsinghua.edu.cn/rustup/`、cargo → rsproxy `https://rsproxy.cn/`。GitHub 文件 → `https://ghproxy.net/` 前缀代理
- **查数据库统一用 DBX MCP**：所有数据库操作（达梦/MySQL/Oracle/PostgreSQL/Kingbase）通过全局 DBX MCP 的 `dbx_*` 系列工具执行，连接已在 DBX 桌面端（`D:\tools\DBX\dbx.exe`）配置好。禁止在各项目 `.mcp.json` 里单独配数据库 MCP
- **读/写 Excel 用 `officecli`**：`officecli view file.xlsx text --json` 读，`officecli create/batch/set/add` 写，不写 Python 脚本
- **JSON 处理用 `jq`**：`curl ... | jq .` 格式化、`jq '.data[].NAME'` 提取字段
- **调 HTTP 接口用 `xh`**：`xh :8080/api/list page=1` 替代 curl，JSON 自动美化
- **代码统计用 `tokei`**：`tokei` 看项目语言/文件/行数占比

## 代码风格
- MVC 分层，方法短小、文件不过大，单一职责
- 注释写全，类、方法、关键逻辑都要有
- **缩进格式**：JSP 用 4 空格缩进、CSS 属性分行；TSX/React 用 4 空格缩进；Java 用 IDEA 默认格式；XML 用原文件已有缩进（tabs）。新建文件参照已有文件的格式化风格，不乱改缩进

## 写代码流程
- **🔴 任何编辑前必须三步，缺一步立刻回滚**：①分析 → ②出方案结尾带确认词 → ③等我回确认词才动手。改一行代码、删一行日志、改个变量名也不例外，不存在太简单就跳过
- **方案结尾必须带随机确认词**：四字成语每次不重复，格式 [回复：画龙点睛]、[答：一箭双雕]。我没回那个确认词就不动代码
- **用户说"改""行""好""提交"等任何非确认词语句一律不算**，必须等到方案里那个具体四字成语
- **多个方案列出来让我选**，别替我做主
- **编辑文件前检查缩进**：如果原文件使用 tabs 但我编辑内容用了 spaces（或相反），导致 Edit 工具失败，**立即提示用户 IDE 格式化该文件**，不反复硬怼
- **🔴 "权限"二字有歧义，必须追问**：用户说"权限"时，分不清是①业务系统权限（角色/用户/菜单/按钮 + URL 白名单/登录控制）还是② Claude Code 工具权限（`settings.json` allowlist）。**必须先反问确认**，不许猜
- 写代码前按顺序复用：①标准库自带就用 → ②平台原生功能（OS/框架/中间件）就用 → ③pom.xml/requirements.txt 已装依赖就用（Java项目优先Hutool） → ④以上都不行，搜开源方案列出来让我选
- 只改任务要求的，不顺手优化碰到的代码
- 编辑文件前先读，出问题先看日志别猜，修根因不修症状：追溯所有调用方，在共享层一次修好
- **循环内禁止重复查库**：已查出来的数据在内存里用，循环内不准逐条查库。循环外批量查询→内存分组计算→批量写回。HTTP等外部IO确实无法批量的可例外，但需在方案里说明
- **别当舔狗**：我有错直接指出，坏主意用技术理由反驳。不确定就说不知道，别胡编
- **方案必须分析风险**：非平凡改动列出至少 1 个具体失败模式 + 怎么防，高风险改动 2 个以上
- 回复去废话：去掉 just/really/simply/sure/certainly 等词，直接给信息，别铺垫
- **禁止 `&&` 串联命令**：改为多个独立 Bash 调用分开执行
- **git 提交用 skill**：任何 git commit/push 必须先 `Skill("git-commit")`，逐文件 stage、中文标题、原子提交，禁止 `git add . && git commit`。相关改动攒齐统一提交，别改一行提一次。提交前必须等我确认

## 记忆规则
- 记忆放**项目根目录 `memory/`**（不是 `~/.claude/projects/` 下）；分两层：`memory/` 根 = 用户主动记录（AI 只读），`memory/ai/` = AI 自动记录（写入需人工确认）
- **文件名用中文且带日期后缀 `-YYYY-MM-DD`**；更新时同步改日期和 `MEMORY.md` 索引
- `MEMORY.md` 作索引（一行一条链接）：根管用户记录，`memory/ai/MEMORY.md` 管 AI 记录
- **AI 自动记录写 `memory/ai/`，不入 git**（`.gitignore` 已排除）
- **晋升机制**：值得长期保留的 AI 记录，由用户手动移到根目录
- 违规写入（写用户区、命名不合规）会被记忆守卫 hook 拦截并需人工确认

## 交互风格
- AI 每次回复开头加"亲爱的架构师："，换行后再正文
