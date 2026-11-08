# CLAUDE.md - Agent Skills Junction 架构镜像

> **Single Source of Truth (SSOT) 跨 Agent 技能穿透系统**  
> 消除多客户端存储割裂与幽灵文件，以操作系统内核级 NTFS Directory Junction 达成零拷贝、零延迟、零常驻守护进程。

---

## 1. 架构骨架 (Directory Tree)

```
f:\whatst
├── config/
│   └── harnesses.json       # 声明被管辖 Agent 客户端的技能寻址路径及开关状态
├── scripts/
│   ├── audit-tokens.ps1     # 扫描中央库 Frontmatter，审计高负载技能对 System Prompt 的 Token 膨胀
│   ├── sync.ps1             # Windows 原生 NTFS 联接建立与存量资产无损合并引擎
│   └── sync.sh              # POSIX 环境 (macOS/Linux) 软链接同步引擎
├── .gitignore               # 版本控制忽略清单
├── LICENSE                  # MIT 许可证
├── README.en.md             # 英文架构设计与操作指南
└── README.md                # 中文核心设计规范与使用指南
```

---

## 2. 模块职责与依赖边界

| 模块 / 文件 | 定位与关注点 | 核心职责 |
| :--- | :--- | :--- |
| `config/harnesses.json` | 拓扑描述层 | 集中声明各 Agent 客户端（Pi、Codex、Gemini、Claude、Cursor 等）的本地目标路径，解耦脚本逻辑与外部路径变动。 |
| `scripts/sync.ps1` | 底层联接引擎 | 执行 Pre-Merge 存量合并、安全重命名备份、以及 `mklink /J` 建立穿透联接。 |
| `scripts/audit-tokens.ps1` | 资源健康守卫 | 静态解析 YAML Frontmatter，监控 `description` 长度与常驻 Token 损耗，防范提示词膨胀。 |
| `~/.agents/skills` | 物理单一源 (SSOT) | 本机技能唯一物理落盘地，纳入 Git 版本控制，充当所有客户端的共享母库与安全气囊。 |

---

## 3. 设计原则与工程规范

1. **零冗余 (Physical Singleton)**：全机只保留一份技能物理文件，杜绝跨端拷贝与版本漂移。
2. **防误删安全气囊 (Pre-Merge & Backup)**：物理目录被联接接管前，必先执行独有资产提取合并，原目录以时间戳后缀隔离备份，永不直接暴力删除。
3. **零提权无感接入 (NTFS Junction)**：Windows 严格使用 Directory Junction（联接），无需开发者模式或管理员 UAC 权限。
4. **对话式驱动**：用户日常与任何 Agent 交互增删技能，操作系统内核自动穿透落地，无需任何专有 CLI。

---

## 4. 变更日志 (Changelog)

- **2026-11-08**：
  - 修复 `sync.ps1` 在 PowerShell 5.1 环境下参数作用域导致 `$PSScriptRoot` 为空并降级至默认配置的问题。
  - 修复 `Resolve-HomePath` 跨平台路径斜杠混用缺陷，增加统一规范化绝对路径。
  - 增强迁移安全策略：物理文件夹重命名为 `.bak_<timestamp>` 进行不可逆隔离保护，移除直接递归删除危险动作。
  - 初始化中央仓库 `~/.agents/skills` 的本地 Git 跟踪保护并纳管 8 处客户端（110 个技能）。
  - 执行 67 款膨胀技能的一键卸载，直接作用于物理 SSOT，瞬时穿透全机 8 大客户端，System Prompt 静态开销降低 85.6%（从 ~8,666 Tokens 骤降至 ~1,247 Tokens）。
  - 重构过滤引擎：彻底消除硬编码过滤坏味道，建立「基础通配规则 + `config/harnesses.json` + `~/.agents/skills/.gitignore` + CLI 参数」的多级动态排除管线。
  - 全量卸载 31 款 `dbs*` 技能，中央母库精炼收敛至 12 款核心高密度技能，全局常驻 System Prompt 开销最终降至 ~446 Tokens（相比最初 8,666+ Tokens 累计优化 94.9%）。


