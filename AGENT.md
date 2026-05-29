# AGENT.md — aitool_standalone

本文件供 AI agent（Claude Code 等）在此 repo 工作時參考。

## 專案目的

GitHub Actions 自動打包離線工具集。所有建置都在 CI 完成，本地不需要任何環境設定。
每週日自動建置全部套件，並發布 GitHub Release（tag 格式：`bundle-YYYYMMDD`）。

## 關鍵檔案

| 檔案 | 說明 |
|------|------|
| `packages.yml` | **唯一套件定義來源**，新增/移除套件只需改這裡 |
| `scripts/build.sh` | 標準類型（binary/node/go/python/rust）通用建置腳本 |
| `scripts/build-*.sh` | 各 custom 套件的建置腳本 |
| `.github/workflows/scheduled-build.yml` | 每週自動建置 + bundle + release |
| `.github/workflows/manual-build.yml` | 手動觸發單一套件 |

## 新增套件的規則

### binary 類型（GitHub release 有現成二進位）

只需在 `packages.yml` 加一條：

```yaml
- name: <工具名稱>
  type: binary
  repo: owner/repo
  asset_pattern: <檔名>        # 支援 {VERSION} 佔位符，版本號在檔名中時必填
```

**不需要**修改任何 workflow。

### custom 類型（需要特殊建置步驟）

1. `packages.yml` 加一條：
   ```yaml
   - name: <工具名稱>
     type: custom
     script: scripts/build-<工具名稱>.sh
   ```
2. 建立 `scripts/build-<工具名稱>.sh`，遵守以下規範：
   - 輸出成品放 `dist/` 目錄
   - 必須寫 `dist/BUILD_INFO.txt`，格式：
     ```
     name=<工具名稱>
     version=<版本號>
     ```
   - 版本號透過環境變數覆寫（預設抓最新）：
     ```bash
     VERSION="${MY_TOOL_VERSION:-$(curl ... | jq -r ...)}"
     ```

**不需要**修改任何 workflow。

## 版本決策原則

- 所有套件版本**預設自動抓最新**，不寫死版本號
- Node.js LTS 版本：`curl https://nodejs.org/dist/index.json | jq -r '[.[] | select(.lts != false)] | first | .version'`
- npm 套件版本：`curl https://registry.npmjs.org/<pkg>/latest | jq -r '.version'`
- GitHub release：`curl https://api.github.com/repos/<owner>/<repo>/releases/latest | jq -r .tag_name`

## BUILD_INFO.txt 位置規則

| 類型 | 路徑 |
|------|------|
| binary | `BUILD_INFO.txt`（build.sh 輸出在工作目錄） |
| custom | `dist/BUILD_INFO.txt` |

bundle job 會從 `all-packages/*/BUILD_INFO.txt` 收集所有套件版本。

## 不需要做的事

- 修改 workflow YAML 來新增套件（只改 packages.yml + 必要時加 script）
- 在 Windows 本地測試腳本（所有 .sh 都在 Ubuntu runner 上執行）
- 手動指定版本號（除非需要鎖定特定版本）
