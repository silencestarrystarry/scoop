# Starry · Scoop Bucket

自用、可扩展的 Windows Scoop Bucket，使用上游项目发布的官方文件并核验 SHA256。该仓库不是 ScoopInstaller、Codex Bridge 或 SagerNet 官方维护的仓库。

**仓库：** https://github.com/silencestarrystarry/scoop  
**推荐本地别名：** `starry`（别名只影响你的电脑，不需要修改 GitHub 仓库名）

## 1. 添加 Bucket

```powershell
scoop bucket add starry https://github.com/silencestarrystarry/scoop
scoop bucket list
```

如先前已添加同一仓库为 `bridge`：

```powershell
scoop bucket rm bridge
scoop bucket add starry https://github.com/silencestarrystarry/scoop
```

删除 Bucket 的注册不会自动卸载已装软件。迁移旧版本地清单前先备份数据。

## 2. 已收录软件

| 软件 | Scoop 命令 | 包形式 | 架构 |
| --- | --- | --- | --- |
| [Codex Bridge](https://github.com/Fanch-hui/codex-bridge) | `scoop install starry/codex-bridge` | 官方便携 ZIP | x64 / ARM64 |
| [sing-box for Desktop](https://sing-box.sagernet.org/clients/desktop/) | `scoop install -g starry/sing-box-desktop` | **官方 NSIS 系统安装器，非便携** | x64 / x86 / ARM64 |

`codex-bridge` 在 Scoop 应用目录中解压运行，添加开始菜单快捷方式；`sing-box-desktop` 会以 `/allusers /S` 运行官方 Windows 安装器，**不会安装到 Scoop 版本目录**，需要使用管理员 PowerShell 和 `-g`。

### sing-box Desktop 的现有 WinGet 安装

如果已通过 WinGet 或官方 EXE 安装了 sing-box Desktop，**建议保持现状，不必再通过 Scoop 安装一次**。Scoop 的安装脚本会尝试识别现有 sing-box 卸载注册项，避免覆盖。

只有确定迁移至 Scoop 管理时，才先从 WinGet/Windows 应用管理中卸载原程序，备份配置并完全退出 SFW，再从管理员 PowerShell 运行 `scoop install -g starry/sing-box-desktop`。SFW 官方卸载器默认保留数据，但仍建议单独备份。

sing-box Desktop 的安装器不支持通过 Scoop 指定应用目录。它涉及系统服务和权限检查，不建议通过 7-Zip 强行解包当作便携版。此非便携清单目前完成了 GitHub CI 静态检查，**尚未在用户 Windows 系统中实装测试**。

## 3. 更新与卸载

```powershell
scoop update
scoop update codex-bridge
# 管理员 PowerShell（仅 sing-box Desktop 非便携版）
scoop update -g sing-box-desktop
```

卸载：

```powershell
scoop uninstall codex-bridge
# 管理员 PowerShell
scoop uninstall -g sing-box-desktop
```

**更新前从系统托盘完全退出对应程序。** Scoop 管理的 Codex Bridge 应使用 Scoop 更新，而不是让程序自身改写 Scoop 目录。

## 4. 自动维护

每 6 小时，`.github/workflows/excavator.yml` 通过两份更新脚本分别查询上游最新稳定版本和官方 GitHub Release SHA256，若有变更则更新 `bucket/*.json` 并尝试提交。

`.github/workflows/validate.yml` 对两份清单进行 PowerShell 解析、下载 URL 格式和官方 SHA256 对比。

- [自动更新工作流](https://github.com/silencestarrystarry/scoop/actions/workflows/excavator.yml)
- [清单校验工作流](https://github.com/silencestarrystarry/scoop/actions/workflows/validate.yml)

仓库设置中需允许 Actions 的 `GITHUB_TOKEN` 写入 contents。GitHub 的定时任务可能延迟或因长期不活跃而被停用。自动化更新的是 GitHub 清单；**你的电脑仍需手动执行 `scoop update` 才会升级应用。**

## 5. 连接代理（如有需要）

假设 sing-box 在 `127.0.0.1:2080` 提供 HTTP/mixed 代理：

```powershell
scoop config proxy 127.0.0.1:2080
scoop update
# 不再使用时
scoop config rm proxy
```

这里只修改 Scoop 的网络代理配置，不修改 Windows 系统代理。
