# AGENT.md — aitool-standalone

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

Node.js 這類完整 runtime 也建議用 custom 類型，讓 build script 先把官方 release tarball 解壓，再輸出一個頂層 wrapper 給 bundle 使用。

## 版本決策原則

- 所有套件版本**預設自動抓最新**，不寫死版本號
- Node.js LTS 版本：`curl https://nodejs.org/dist/index.json | jq -r '[.[] | select(.lts != false)] | first | .version'`
- npm 套件版本：`curl https://registry.npmjs.org/<pkg>/latest | jq -r '.version'`
- GitHub release：`curl https://api.github.com/repos/<owner>/<repo>/releases/latest | jq -r .tag_name`

## Bundle shell 入口

- bundle 內保留 `setup.sh`
- 另提供 `setup.csh`，給 `csh` / `tcsh` 使用；優先先 `cd` 到 bundle 根目錄再 `source setup.csh`
- 若要從其他目錄使用 `setup.csh`，先設定 `AITOOL_BUNDLE_DIR=/path/to/bundle`

## bin/ wrapper 與使用量統計

bundle 組裝（`scheduled-build.yml` 的 `Assemble bundle` step）會把**所有**套件（不論 `binary` 或
`custom` 類型）都組成同樣的佈局：

- `bin/<套件>`：一律是薄 wrapper script（由 `write_wrapper` 動態產生），不會放原始執行檔
- `lib/<套件>/<套件>`：實際成品的進入點
- wrapper 在 `exec` 真正程式前，會 `source` `lib/_usage.sh` 並呼叫 `log_usage`，
  append 一行 `<UTC ISO8601 時間戳記>\t<版本號>` 到 `usage/<套件>.log`（行數即使用次數，供統計用）

新增套件時**不需要**處理這件事 —— bundle 組裝階段會自動讀取每個套件 `BUILD_INFO.txt` 的
`version=` 並產生對應 wrapper，custom build script 只要照前述規範把進入點放在
`lib/<套件>/<套件>` 即可（多數現有 build script 已是如此）。

## LICENSE.md（授權稽核彙總表）

bundle 根目錄會放一份 `LICENSE.md`，彙整所有套件的 `name=` / `version=` / `license=`
（同樣讀自 `all-packages/*/BUILD_INFO.txt`，與 Build summary / Release notes 用同一份資料來源），
供內部稽核各工具的版本與授權狀態。新增套件時只要 `BUILD_INFO.txt` 有正確填寫 `license=`
（custom 類型透過 `lib-license.sh` 的 `gh_license` 取得），就會自動列入，不需額外處理。

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

## 檔案格式

- 所有文字檔請維持 LF 行尾，不要提交 CRLF
