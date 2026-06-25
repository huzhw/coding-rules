# coding-rules

一套实战检验过的 AI 编码协作规范，解决 AI 写代码"手快脑子快但缺乏判断力"的问题。

经过数百次提交验证，适配 Java/Python/前端项目。

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
- 全局通用事实存用户级别（`~/.claude/memory/`）
- 不在代码库里存 AI 临时文件

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

## 配套工具

- [git-commit-skill](https://github.com/huzhw/git-commit-skill) — 同系列的 Git 提交规范技能

## 许可

MIT
