# Sub-Store 接入宝塔外部应用商店完整说明

本文档用于记录一次完整、可复现的上架流程：将 Sub-Store 添加到你自己的 apphub 外部仓库，并在宝塔 Docker 应用商店中正常导入、安装、更新。

## 1. 目标与原则

### 1.1 目标

1. 在外部仓库中只保留你需要的应用（Sub-Store）。
2. 符合 apphub 目录规范，避免初始化失败。
3. 支持宝塔托管能力（状态识别、重建、资源限制、反代联动）。
4. 可持续更新（模板更新 + 镜像更新）。

### 1.2 关键原则

1. 应用目录下必须有 `app.json`、`icon.png`。
2. 每个版本目录（如 `latest`）必须同时有 `docker-compose.yml` 和 `.env`。
3. `app.json` 的 `env` 与 `.env` 变量（转大写后）必须一一对应。
4. 每次更新模板后都要更新 `updateat`（Unix 秒级时间戳）。

## 2. 最终目录结构（可直接对照）

```text
apphub/
  substore/
    app.json
    icon.png
    latest/
      docker-compose.yml
      .env
```

## 3. 实操步骤（含命令 + 原因）

### 步骤 1：克隆并进入仓库

```powershell
Set-Location "D:\Wesley\Desktop\GithubCapilot\BtPanel"
git clone --depth 1 https://github.com/Daimao-wesley/apphub.git
Set-Location "D:\Wesley\Desktop\GithubCapilot\BtPanel\apphub"
```

原因：
1. 在你自己的 fork 仓库上维护，避免受官方模板仓库限制。
2. `--depth 1` 速度更快，适合模板维护场景。

### 步骤 2：创建应用目录

```powershell
New-Item -ItemType Directory -Force apphub/substore/latest
```

原因：
1. 宝塔按固定路径扫描应用。
2. `latest` 是最常用的默认安装版本。

### 步骤 3：编写 app.json

文件：`apphub/substore/app.json`

本次核心设计：
1. `appname=substore`，与目录同名。
2. `appversion` 先保留 `latest`，简化运维。
3. `field` 暴露以下用户输入：
   - 域名（可选）
   - 是否允许外部访问
   - Sub-Store 端口
   - 前后端通信路径
   - CPU/内存限制
4. `env` 必须包含：
   - `substore_api_port`
   - `substore_backend_path`
   - `app_path`
   - `host_ip`
   - `cpus`
   - `memory_limit`
5. `updateat` 使用 Unix 秒级时间戳。

校验命令：

```powershell
Get-Content "apphub/substore/app.json" | ConvertFrom-Json | Out-Null
Write-Output "app.json OK"
```

原因：
1. JSON 不合法会导致应用不显示或导入失败。

### 步骤 4：编写 docker-compose.yml

文件：`apphub/substore/latest/docker-compose.yml`

本次模板采用：
1. 镜像：`xream/sub-store:latest`（**显式加 tag**，详见 §8）
2. 资源限制：`CPUS` / `MEMORY_LIMIT`
3. 环境变量：
   - `SUB_STORE_BACKEND_API_HOST=0.0.0.0`
   - `SUB_STORE_BACKEND_API_PORT=3001`
   - `SUB_STORE_BACKEND_MERGE=true`
   - `SUB_STORE_FRONTEND_BACKEND_PATH=${SUBSTORE_BACKEND_PATH}`
   - `SUB_STORE_BACKEND_SYNC_CRON=50 23 * * *`
4. 端口：`${HOST_IP}:${SUBSTORE_API_PORT}:3001`
5. 数据卷：`${APP_PATH}/data:/opt/app/data`
6. 标签：`createdBy: "bt_apps"`
7. 网络：`baota_net`

原因：
1. 保持与宝塔模板规范一致。
2. 让应用被宝塔正确识别和托管。
3. 与你原本 `docker run` 使用场景对齐（含定时任务、路径隔离）。

### 步骤 5：补齐 .env（关键步骤）

文件：`apphub/substore/latest/.env`

示例：

```env
SUBSTORE_API_PORT=
SUBSTORE_BACKEND_PATH=
HOST_IP=
CPUS=
MEMORY_LIMIT=
APP_PATH=
```

原因：
1. 宝塔安装时会先读取 `.env` 并做变量替换。
2. 缺失 `.env` 时，面板可能报"docker-compose.yml 不存在"的误导性错误。

### 步骤 6：准备图标

文件：`apphub/substore/icon.png`

要求：
1. PNG 格式。
2. 推荐 100x100。

可选生成命令（PowerShell + System.Drawing）：

```powershell
$logoUrl='https://raw.githubusercontent.com/cc63/ICON/main/Sub-Store.png'
$tmp='apphub\substore\substore-src.png'
Invoke-WebRequest -Uri $logoUrl -OutFile $tmp
Add-Type -AssemblyName System.Drawing
$img=[System.Drawing.Image]::FromFile((Resolve-Path $tmp))
$bmp=New-Object System.Drawing.Bitmap 100,100
$g=[System.Drawing.Graphics]::FromImage($bmp)
$g.InterpolationMode=[System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.SmoothingMode=[System.Drawing.Drawing2D.SmoothingMode]::HighQuality
$g.PixelOffsetMode=[System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$g.DrawImage($img,0,0,100,100)
$iconPath='apphub\substore\icon.png'
$bmp.Save((Resolve-Path .\).Path + '\\' + $iconPath,[System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose(); $img.Dispose()
Remove-Item $tmp -Force
```

原因：
1. 统一商店视觉展示。
2. 避免导入后图标异常。

### 步骤 7：删除示例应用（只保留 Sub-Store）

```powershell
git rm -r apphub/alist apphub/deeplx
```

原因：
1. 宝塔导入外部仓库时会把 `apphub/*` 下全部应用都加载出来。
2. 不删除示例目录会导致 alist/deeplx 一并出现。

### 步骤 8：提交与推送

```powershell
git status --short

git config user.name "Daimao-wesley"
git config user.email "Daimao-wesley@users.noreply.github.com"

git add apphub/substore apphub/alist apphub/deeplx
git commit -m "feat: add substore and clean template apps"

git remote set-url origin https://github.com/Daimao-wesley/apphub.git
git push -u origin main
```

原因：
1. 保证推送目标是你的 fork。
2. 一次提交包含新增和清理，历史清晰。

## 4. 宝塔导入与安装

1. 打开 Docker 应用商店。
2. 导入外部仓库：`https://github.com/Daimao-wesley/apphub`
3. 同步/刷新外部仓库。
4. 安装 Sub-Store，填写：
   - 端口
   - 前后端通信路径（建议随机长路径）
   - 是否允许外部访问

## 5. 常见问题与处理

### 5.1 初始化失败：提示 docker-compose.yml 不存在

排查顺序：
1. `latest/docker-compose.yml` 是否存在。
2. `latest/.env` 是否存在。
3. `.env` 变量名是否与 `app.json env` 对应。

结论：大多数是 `.env` 缺失或键名不匹配。

### 5.2 页面打开正常，但提示无法连接后端

原因：
1. MERGE 模式下首次访问前端需要显式指定 API 地址。

处理：

```text
https://你的域名?api=https://你的域名/你的通信路径
```

示例：

```text
https://example.com?api=https://example.com/LonelyWesley
```

### 5.3 推送失败（443 连接超时）

处理：
1. 走代理后重试。
2. 多执行一次 `git push -u origin main`。

## 6. 更新策略（非常重要）

### 6.1 模板更新（app.json/compose/.env）

流程：
1. 修改文件。
2. 更新时间戳 `updateat`。
3. 提交推送。
4. 宝塔面板同步外部仓库。

获取当前时间戳：

```powershell
[int](Get-Date -UFormat %s)
```

### 6.2 镜像更新（xream/sub-store）

流程：
1. 在宝塔应用中执行"更新镜像/重建容器"（不同版本按钮名略有差异）。
2. 本质是 `docker pull` + 重建。

说明：
1. `latest` 不会自动实时刷新，需手动触发。

## 7. 当前建议的运维基线

1. 默认只维护 `latest`，减少维护成本。
2. 生产环境可增加固定版本目录，降低最新镜像变更风险。
3. 每次改动都同步更新 `updateat`。
4. 提交前做 3 项检查：
   - `app.json` 可解析
   - `latest` 下 `docker-compose.yml` 与 `.env` 同时存在
   - `.env` 与 `app.json env` 键名一致

## 8. 对齐官方风格的后续优化（2026-04-22 回头补的）

Sub-Store 首版"能用"之后，对照 `aaPanel/apphub` 仓库里官方维护的 `alist` / `deeplx` 两个示例，发现 4 处**不影响功能、但不统一**的细节。这里记录下来作为以后做任何新应用的参考。

### 8.1 改动清单

| 文件 | 字段 | 修改前 | 修改后 |
|---|---|---|---|
| `app.json` | `domain.suffix` | `浏览器访问域名，可不填`（全角逗号 + "的"字不同） | `浏览器访问的域名,非必填` |
| `app.json` | `allow_access.suffix` | `允许通过主机IP+端口访问` | `允许直接通过主机IP+端口访问，如果您设置了域名请不要勾选这里` |
| `app.json` | `cpus.suffix` | `0为不限制` | `0为不限制,最大可用核心数为: ` |
| `app.json` | `memory_limit.suffix` | `0为不限制` | `0为不限制,最大可用内存为: ` |
| `docker-compose.yml` | `image` | `xream/sub-store` | `xream/sub-store:latest` |

### 8.2 每一条为什么重要

#### 8.2.1 `cpus` / `memory_limit.suffix` 尾部的"冒号+空格"

```json
"suffix": "0为不限制,最大可用核心数为: "
```

**末尾两个字符（冒号 `:` + 一个空格）**是面板前端的拼接锚点。面板会把主机实际容量拼到后面，显示成：

```text
0为不限制,最大可用核心数为: 8
```

缺这两个字符的话，显示会变成 `0为不限制8`，看起来像 bug。这是最容易忽略的细节。

#### 8.2.2 `allow_access.suffix` 补充域名提示

原版只说"允许通过主机IP+端口访问"，用户看不出"配了域名 + 勾选这里"会带来什么问题。

官方文案"如果您设置了域名请不要勾选这里"直接提醒用户：反代场景下勾选这个 = 公网口暴露 = **绕过 Nginx 的 WAF/日志/SSL**。这是一个安全提示，不是废话。

#### 8.2.3 `domain.suffix` 半角逗号 + "非必填"

```text
浏览器访问的域名,非必填     ← 官方
浏览器访问域名，可不填       ← 自己第一版
```

两处差异：
1. **半角逗号** vs 全角逗号（官方统一半角）
2. **"非必填"** vs "可不填"（官方更正式）

纯字面差异，但统一后 UI 视觉更整齐。

#### 8.2.4 `image` 加 `:latest` 显式 tag

```yaml
image: xream/sub-store            # 隐式 latest，但不显式
image: xream/sub-store:latest     # 显式，推荐
```

好处：
1. **意图明确**：告诉读代码的人"这就是 latest 分支"，不是忘了写
2. **未来做多版本时的基线**：将来新增 `apphub/substore/2.x/docker-compose.yml`，能直接对比 `:2.x` vs `:latest`，结构一致
3. 官方 alist 示例的 compose 就是显式 tag

### 8.3 修改流程（作为"如何修正已上架的应用"示例）

```powershell
# 1. 修改文件（手动编辑 app.json、compose）

# 2. 可选：更新 updateat 时间戳
$ts = [int](Get-Date -UFormat %s)
# 手动把 app.json 里 updateat 改成这个值

# 3. 校验 JSON
Get-Content apphub/substore/app.json | ConvertFrom-Json | Out-Null
Write-Output "app.json OK"

# 4. 提交
git add apphub/substore
git commit -m "refactor: polish substore app.json to align with official style"
git push origin main
```

### 8.4 已安装实例不会自动吃到这次改动

**重要提醒**：只是 `suffix` / `image tag` 这种**元数据级**修改，对已部署的实例没任何影响（suffix 只在安装表单展示，image tag 只在下次 `docker pull` 时生效）。

所以这次优化不需要通知现有用户做任何动作——纯粹是让下次新装时体验更好。

### 8.5 本次优化总结（经验外推）

**原则**：**即使应用"能跑"，也要去翻官方示例对照文案和细节**。

apphub 作为面板的二级界面，用户看到的每一行文案都会影响"这个仓库是不是可靠"的第一印象。一点点文案不统一都会破坏这种信任。

## 9. 延伸阅读

1. `docs/sillytavern-apphub-完整上架说明.md` —— SillyTavern 完整复盘（含 Forbidden/白名单踩坑）
2. `docs/宝塔apphub完整配置参考.md` —— 全字段超集参考（覆盖本文没用到的配置）
3. `docs/新应用脚手架清单.md` —— 新增应用时的逐项勾选清单
