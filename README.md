# Scoop Bucket — Codex Bridge

个人维护的 Scoop Bucket，使用 [Fanch-hui/codex-bridge](https://github.com/Fanch-hui/codex-bridge) 官方 Windows 便携包。此仓库不是 Codex Bridge 或 ScoopInstaller 的官方仓库。

## 安装

在 PowerShell 中：

```powershell
scoop bucket add bridge https://github.com/silencestarrystarry/scoop
scoop install bridge/codex-bridge
```

支持 Windows **x64 / ARM64**。会创建 “Codex Bridge” 开始菜单快捷方式，程序放在 Scoop 安装目录。

如先前使用本地 `codex-bridge.json` 安装过同名应用，请先退出程序、备份设置，再执行 `scoop uninstall codex-bridge`，然后通过新 bucket 安装。不要同时运行安装版与便携版实例。

## 升级

```powershell
scoop update
scoop update codex-bridge
```

Scoop 不会自行升级本机软件，需要你运行以上命令；此仓库的自动化负责维护新版清单。升级前请从托盘完全退出 Codex Bridge，不要在 Scoop 管理的便携目录中使用应用自身的内置升级功能。

## 自动维护

- `bucket/codex-bridge.json`：含官方 x64/ARM64 下载地址、SHA256、`checkver` 和 `autoupdate`
- `.github/workflows/excavator.yml`：每 6 小时检查 [GitHub Releases](https://github.com/Fanch-hui/codex-bridge/releases) 的最新稳定版，使用 [ScoopInstaller/GithubActions](https://github.com/ScoopInstaller/GithubActions) 生成并提交清单更新
- `.github/workflows/validate.yml`：在清单变动时验证文件、地址和 GitHub 官方发布的 SHA256 摘要

请检查仓库 **Settings → Actions → General**：允许 GitHub Actions，并确保工作流具备所需的 `contents: write` 权限。打开 **Actions → Update Scoop manifests → Run workflow** 可以手动执行首次检查。

GitHub Actions 的 `schedule` 在低活跃度仓库中可能延迟或被停用。若自动更新停滞，请检查 Actions 页面。

## 查看状态

- [自动更新工作流](https://github.com/silencestarrystarry/scoop/actions/workflows/excavator.yml)
- [清单校验工作流](https://github.com/silencestarrystarry/scoop/actions/workflows/validate.yml)

本仓库的发布与静态检查并不等于在 Windows 实机完成安装测试。程序运行可能需要系统环境依赖，请参考上游项目文档。
