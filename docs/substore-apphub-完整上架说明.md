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
1. 镜像：`xream/sub-store`
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
2. 缺失 `.env` 时，面板可能报“docker-compose.yml 不存在”的误导性错误。

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
1. 在宝塔应用中执行“更新镜像/重建容器”（不同版本按钮名略有差异）。
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
