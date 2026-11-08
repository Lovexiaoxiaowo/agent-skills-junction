# CLAUDE.md - Agent Skills Junction 架构镜像

> **Single Source of Truth (SSOT) 跨 Agent 技能穿透中枢**  
> 消除多客户端存储孤岛、配置漂移与幽灵文件。基于操作系统内核级 NTFS Directory Junction (Windows) 与 Symlink (POSIX)，实现零物理拷贝、零生效延迟与绝对零常驻守护进程。

---

## 1. 架构骨架 (Directory Tree)

```
f:\whatst\agent-skills-junction
├── config/
│   └── harnesses.json       # 声明被管辖 Agent 客户端路径规则及全局通配排除项 (SSOT 拓扑配置)
├── scripts/
│   ├── audit-tokens.ps1     # 扫描中央库 Frontmatter，静态审计高负载技能对 System Prompt 的常驻 Token 损耗
│   ├── sync.ps1             # Windows 原生 NTFS Junction 批量联接与存量资产无损合并迁移引擎
│   └── sync.sh              # POSIX 环境 (Linux/macOS) 原生软链接建立与无损归档备份引擎
├── .gitignore               # 项目自身版本控制忽略清单
├── LICENSE                  # MIT 开源许可证
├── README.en.md             # 英文架构设计与操作指南
└── README.md                # 中文核心设计规范与使用指南
```

---

## 2. 模块职责与依赖边界

| 模块 / 路径 | 架构层级 | 核心职责与设计边界 |
| :--- | :--- | :--- |
| `config/harnesses.json` | 声明层 (Topology) | 解耦核心脚本与外部路径。集中声明各 Agent 客户端（Pi、Codex、Gemini、Claude、Cursor、OpenHands 等）的本地目标路径及全局通配排除规则。 |
| `scripts/sync.ps1` | Windows 引擎层 | 执行存量资产无损 Pre-Merge 并集归档，原物理目录时间戳隔离重命名保护，普通权限创建 NTFS Directory Junction。 |
| `scripts/sync.sh` | POSIX 引擎层 | Linux / macOS 下动态解析 JSON 客户端清单，时间戳无损隔离备份，建立原子软链接。 |
| `scripts/audit-tokens.ps1` | 资源健康守卫层 | 静态解析 YAML Frontmatter，支持多级动态排除管线（通配规则 + JSON 声明 + .gitignore + CLI 参数），监控 System Prompt 静态 Token 膨胀。 |
| `~/.agents/skills` | 物理单一源 (SSOT) | 本机技能唯一物理落盘地，受 Git 版本控制保护，充当所有客户端共享的不可变/版本受控母库。 |

---

## 3. 设计原则与工程美学

1. **物理单实例 (Single Source of Truth)**：全机技能只存一份物理实体，杜绝跨端拷贝与版本漂移。
2. **绝对零后台进程 (Zero Daemon)**：不运行任何 Node.js / Python 监听守护进程，纯靠操作系统文件系统寻址。
3. **不可逆破坏清零 (Non-destructive Migration)**：物理目录被接管前，必须先合并独有技能并以 `.bak_<timestamp>` 隔离备份，严禁直接递归删除。
4. **多级动态过滤管线 (Dynamic Exclusion Pipeline)**：
   - 基础规范通配：`.*` (隐藏/系统目录)、`_*` (私有目录)、`*cache*` (编译缓存)；
   - 配置文件集成：`config/harnesses.json` 中的 `"exclude"` 清单；
   - 仓库标准联动：自动穿透并挂接 `~/.agents/skills/.gitignore`；
   - 运行时覆盖：支持 `-Exclude` CLI 传参。

---

## 4. 关键演进日志 (Changelog)

- **v1.2.0 (当前版本)**：
  - **修复 PS 5.1 参数作用域缺陷**：解决 `sync.ps1` 中 `$PSScriptRoot` 在 `param()` 默认值阶段未绑定的问题，杜绝配置被静默忽略降级。
  - **无损备份策略重构**：移除 `sync.ps1` 与 `sync.sh` 中接管原物理目录后的暴力 `Remove-Item` / `rm -rf`，改为时间戳隔离归档（`.bak_<timestamp>`）。
  - **多级动态排除管线**：彻底消除硬编码过滤坏味道（`.system`, `_scripts`, `__pycache__` 等），统一由通配规则、JSON 声明、`.gitignore` 及 CLI 组合解析。
  - **全平台配置动态化**：`sync.sh` 增加 `jq`/`python3` 动态读取 `harnesses.json` 支持，补全 Cursor Agent 与 Gemini Antigravity CLI 默认路径。
  - **路径规范化修正**：Windows 端消除斜杠混用隐患，保证 `mklink` 原生绝对路径穿透。
