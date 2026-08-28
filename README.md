# coding-rules

## 相关技能
- [git-commit](https://github.com/huzhw/git-commit-skill)：Git 提交规范
- [daily-record](https://github.com/huzhw/daily-record-skill)：日报记录 + 工时评估
- [daily-merge](https://github.com/huzhw/daily-merge-skill)：日报 Excel 合并
- [reread-claude-md](https://github.com/huzhw/reread-claude-md-skill)：重新加载 CLAUDE.md 规则
- [token-3000](https://github.com/huzhw/token-3000-skill)：API Token 一键切换
- [service-manager](https://github.com/huzhw/service-manager)：桌面服务管理工具
- [code-check](https://github.com/huzhw/code-check-skill)：增量代码隐患检查

---

一套实战检验过的 AI 编码协作规范，解决 AI 写代码"手快脑子快但缺乏判断力"的问题。

经过数百次提交验证，适配 Java/Python/前端项目。

> **"亲爱的架构师"不是客套——是上下文压缩探针。** AI 长对话中上下文逐步压缩，CLAUDE.md 规则会丢。AI 漏了这句开头 = 规则丢了 = 说"规则丢了"触发 [reread-claude-md](https://github.com/huzhw/reread-claude-md-skill) 重载。

## 快速开始

**全局生效（推荐）：所有项目自动应用。**

| AI 工具 | 放到哪里 | 说明 |
|--------|---------|------|
| **Claude Code** | `~/.claude/CLAUDE.md` | 用户级全局配置，所有项目生效 |
| **Codex (OpenAI)** | 设置 → Instructions → 粘贴进去 | 全局 system prompt |
| **Cursor** | `~/.cursorrules` | 全局规则文件 |
| **Windsurf** | `~/.windsurfrules` | 全局规则文件 |
| **Cline (VS Code)** | 设置 → Custom Instructions → 粘贴进去 | 自定义指令 |
| **Continue (VS Code)** | `~/.continue/config.json` 的 `systemMessage` | 系统消息字段 |
| **Aider** | `~/.aider.conf.yml` 或 `.aider.conf.yml` | 配置文件 |
| **通用** | 工具的 System Prompt / Instructions 设置页 | 直接粘贴 CLAUDE.md 内容 |

**单项目生效：** 需要精细化控制时，复制到项目根目录。

| AI 工具 | 放到哪里 |
|--------|---------|
| Claude Code | `<项目>/.claude/CLAUDE.md` |
| Cursor | `<项目>/.cursorrules` |
| Windsurf | `<项目>/.windsurfrules` |

**直接用这套规范：**

```bash
# 全局生效（Claude Code）
cp CLAUDE.md ~/.claude/CLAUDE.md

# 或者单项目
cp CLAUDE.md 你的项目/.claude/CLAUDE.md
```

**其他工具：** 打开 CLAUDE.md，复制全文粘贴到工具的 「Instructions」「System Prompt」「自定义指令」设置页即可。

## 核心规则

### 三步确认工作流

```
分析问题 → 出方案（带确认词）→ 等用户回确认词 → 才动手
```

改一行代码也一样，不存在"太简单就跳过"。方案结尾必须带随机四字成语作为确认词，用户回了那个成语才执行。

**例子：**

```
AI：问题在 UserService.java 第 42 行空指针，需要加 null 检查。
    方案：加 @NonNull 注解 + Objects.requireNonNull。 [回复：画龙点睛]

用户：画龙点睛

AI：（此时才动手改代码）
```

**为什么有效：** 杜绝 AI 边说边改、擅自做主。用户有时间审视方案，AI 不会被一句话就带偏。

### 只说确认词

用户说"改""行""好""提交""OK""go ahead"等任何非确认词语句**一律不算**，必须等到方案里那个具体四字成语。

**例子：**

```
用户：改
AI：（不动，等确认词）

用户：快刀斩乱麻
AI：（此时才执行）
```

### 多个方案列出来让我选

不替用户做主。有多个合理方案时列出来让用户选，附上各自的优劣。

### 代码复用优先级

```
① 标准库自带 → ② 平台原生（OS/框架/中间件）→ ③ pom.xml/requirements.txt 已装依赖 → ④ 搜开源方案
```

Java 项目优先用 [Hutool](https://hutool.cn/)，Python 项目优先标准库。

### 修根因不修症状

出问题先看日志，追溯所有调用方，在共享层一次修好。

**反面例子：**

```java
// ❌ 症状修复：每个调用方都加 try-catch
@Service
class UserService {
    void login() {
        try { tokenService.verify(); } catch (Exception e) { ... }
    }
}
@Service
class OrderService {
    void submit() {
        try { tokenService.verify(); } catch (Exception e) { ... }
    }
}
```

**正确做法：** 在 TokenService.verify() 内部统一处理异常。

### 循环内禁止重复查库

```
循环外批量查询 → 内存分组计算 → 批量写回
```

**反面例子：**

```java
// ❌ 100 个用户就 100 次 SQL
for (Long id : userIds) {
    User user = userMapper.selectById(id);  // 循环内查库
    process(user);
}
```

**正确做法：**

```java
// ✅ 一次 SQL，内存处理
List<User> users = userMapper.selectByIds(userIds);
Map<Long, User> map = users.stream().collect(toMap(User::getId, u -> u));
for (Long id : userIds) {
    process(map.get(id));
}
```

HTTP 等外部 IO 确实无法批量的可例外，但需在方案里说明原因。

### 别当舔狗

用户有错直接指出，坏主意用技术理由反驳。不确定就说不知道，别胡编。

**例子：**

```
用户：把密码存到 cookie 里
AI：不安全。cookie 明文传输，密码应该只在登录请求体中传一次，
    验证后立即丢弃，后续用 session token。不能存 cookie。
```

### 方案必须分析风险

非平凡改动列出至少 1 个具体失败模式 + 怎么防，高风险改动 2 个以上。

**例子：**

```
方案：修改认证拦截器，补充 token 过期检查
风险：如果 Redis 在高峰期延迟 > 100ms，checkToken() 可能超
      时导致所有用户被踢出。防范：加失败开放开关，Redis 不可
      用时跳过过期检查，只验证签名。
```

### 去废话

回复里去掉 just / really / simply / sure / certainly / of course 等填充词，直接给信息，不铺垫。

### 只改任务要求的

不顺手优化碰到的代码。任务让改 A，不动 BC。保持 diff 干净、review 简单。

### 编辑前先读文件

改文件之前必须读取最新内容，不能凭记忆或上次对话改代码。

## 环境约束

- **nvm** 管理 Node 版本，**pyenv** 管理 Python 版本，禁止直接安装覆盖系统级
- Java 统一 **1.8**，语法和 API 都按 1.8
- Python 通过 `pyenv exec python` 调用（Windows 下直接 `python` 可能 exit code 49）

## 代码风格

- MVC 分层，方法短小、文件不过大，单一职责
- 注释写全：类、方法、关键逻辑都要有

## 记忆规则

- 项目相关记忆默认存项目级别（`<项目>/memory/`）
- AI 自动记录写 `<项目>/memory/ai/` 子目录；项目根 `memory/` 只放用户主动记录，用户区文件 AI 只读不改
- AI 自动记录（`memory/ai/`）不提交 git，项目 `.gitignore` 排除；`memory/ai/` 有自己的 `MEMORY.md` 索引
- 全局通用事实存用户级别（`~/.claude/memory/`）
- 不在代码库里存 AI 临时文件

## Hooks（命令守卫 + 记忆守卫）

把 CLAUDE.md 的关键约束做成硬拦截/提醒。脚本在本仓库 `hooks/` 下，部署时复制到 `~/.claude/hooks/`：

| 脚本 | 事件（matcher） | 作用 |
|------|----------------|------|
| `block-amper-and.sh` | PreToolUse（Bash） | 禁止 `&&` 串联命令，必须拆成多个独立 Bash 调用（引号内的 `&&` 视为文本放行） |
| `block-dangerous-git.sh` | PreToolUse（Bash） | git 危险操作拦截：reset --hard、clean、branch -D、checkout/restore .、push --force，及 `git add .`/`-A`/`-a`/`--all` 全部暂存 |
| `guard-dangerous-bash.sh` | PreToolUse（Bash） | 危险 Bash 命令拦截（不依赖权限模式）：rm 指向非构建/缓存白名单、reg delete、sc delete、shutdown/reboot、bcdedit、DROP/TRUNCATE、无 WHERE 的 DELETE/UPDATE、chmod -R 777/chown -R、find -delete/-exec、mkfs/fdisk/fork bomb 一律 deny；taskkill /f、net stop/start、sc stop/start 放行；rm 指向 target/node_modules/dist/__pycache__ 等构建缓存目录放行 |
| `warn-download-location.sh` | PostToolUse（Bash） | 下载落盘提醒：curl/wget/xh 带 `-o`/`--output` 且目标不在 `N:\文件下载\ai自动下载\` 时提醒（仅提醒不拦截） |
| `guard-memory-write.sh` | PreToolUse（Write\|Edit\|MultiEdit） | 写 `memory/` 前把关：用户区 ask、AI 区新文件 ask、命名不合规 deny、已批准放行 |
| `guard-memory-approved.sh` | PostToolUse（Write\|Edit\|MultiEdit） | 写入 `memory/ai/` 成功后记入批准台账 `~/.claude/memory-ai-approved.txt`，后续不再打扰 |

接入全局 `~/.claude/settings.json`：

```json
"hooks": {
  "PreToolUse": [
    { "matcher": "Bash", "hooks": [
      { "type": "command", "command": "\"$HOME\"/.claude/hooks/block-dangerous-git.sh", "timeout": 600 },
      { "type": "command", "command": "\"$HOME\"/.claude/hooks/guard-dangerous-bash.sh", "timeout": 600 },
      { "type": "command", "command": "\"$HOME\"/.claude/hooks/block-amper-and.sh", "timeout": 30 }
    ]},
    { "matcher": "Write|Edit|MultiEdit", "hooks": [
      { "type": "command", "command": "\"$HOME\"/.claude/hooks/guard-memory-write.sh", "timeout": 30 }
    ]}
  ],
  "PostToolUse": [
    { "matcher": "Bash", "hooks": [
      { "type": "command", "command": "\"$HOME\"/.claude/hooks/warn-download-location.sh", "timeout": 30 }
    ]},
    { "matcher": "Write|Edit|MultiEdit", "hooks": [
      { "type": "command", "command": "\"$HOME\"/.claude/hooks/guard-memory-approved.sh", "timeout": 30 }
    ]}
  ]
}
```

## 为什么需要这套规范

默认 AI 编码助手有几个通病：

| 通病 | 表现 | 规范对策 |
|------|------|----------|
| 擅自行动 | 觉得懂了就自己改，不问确认 | 三步确认工作流 |
| 过度讨好 | 用户说什么都照做，不说"这不对" | 别当舔狗 |
| 修标不修本 | 看到报错就加 try-catch，不追溯根因 | 修根因不修症状 |
| 话多且废 | 满屏 just/really/simply | 去废话 |
| N+1 查库 | 循环里逐条 SQL | 批量查 → 内存处理 |
| 手贱 | 改 A 顺手把 BC 也优化了 | 只改任务要求的 |

## 许可

MIT
