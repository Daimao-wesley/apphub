# SillyTavern 接入宝塔外部应用商店完整复盘

本文记录一次**从 0 到 1 完整落地** SillyTavern 到 apphub 外部仓库的全过程，包含：
1. 原始 docker-compose 转换为 apphub 规范的每一步推理
2. 对齐 aaPanel 官方风格的微调
3. 部署后实际撞到的坑（Forbidden / IP 白名单）与最终解决方案
4. 每一步为什么要这么做

下次新增任何应用，都可以把这份文档当"带思路的 checklist"照着走。

## 1. 目标

1. 把官方 `ghcr.io/sillytavern/sillytavern:latest` 镜像包装成宝塔外部应用。
2. 让用户在安装表单填写几个变量就能跑，**不需要任何安装后的手动编辑**。
3. 面板能识别容器状态、跟踪重建、限制资源。
4. 对齐 `aaPanel/apphub` 官方代码风格，便于后续与上游对比或提 PR。

## 2. 最终目录结构

```text
apphub/
  sillytavern/
    app.json
    icon.png             # 100x100 PNG
    latest/
      docker-compose.yml
      .env
```

## 3. 第一步：拿到原始 compose

用户提供的原始内容（简化）：

```yaml
services:
  sillytavern:
    build: ..
    container_name: sillytavern
    hostname: sillytavern
    image: ghcr.io/sillytavern/sillytavern:latest
    environment:
      - NODE_ENV=production
      - FORCE_COLOR=1
      - SILLYTAVERN_HEARTBEATINTERVAL=30
    ports:
      - "8000:8000"
    volumes:
      - "./config:/home/node/app/config"
      - "./data:/home/node/app/data"
      - "./plugins:/home/node/app/plugins"
      - "./extensions:/home/node/app/public/scripts/extensions/third-party"
    healthcheck:
      test: ["CMD", "node", "src/healthcheck.js"]
      interval: 30s
      timeout: 10s
      start_period: 20s
      retries: 3
    restart: unless-stopped
```

### 3.1 识别需要修改的点（照着宝塔规范表扫一遍）

| 原 compose 内容 | apphub 规范要求 | 动作 |
|---|---|---|
| `build: ..` | 只走镜像拉取 | **删** |
| `container_name: sillytavern` | 禁止，影响状态识别 | **删** |
| `hostname: sillytavern` | 不需要 | **删** |
| `image: ghcr.io/...:latest` | OK，显式 tag 更好 | **保留** |
| `environment` 里的 `30` 等硬编码值 | 应变成 `${VAR}` 让用户填 | **改为变量** |
| `ports: "8000:8000"` | 必须 `${HOST_IP}:${PORT}:容器端口` | **改** |
| `volumes: "./data:..."` | 必须 `${APP_PATH}/data:...` | **改** |
| `healthcheck` | 非强制但允许 | **保留** |
| `restart: unless-stopped` | 官方示例用 `always`，但 `unless-stopped` 合法 | **保留**（按原意） |
| 缺少 `deploy.resources.limits` | 必须 | **加** |
| 缺少 `labels.createdBy: "bt_apps"` | 必填 | **加** |
| 缺少 `networks: baota_net` | 建议 | **加** |

## 4. 第二步：设计 app.json

### 4.1 应用类型归类

SillyTavern 是 LLM 前端，对照 `apptype` 枚举表：

| apptype | appTypeCN | 是否合适 |
|---|---|---|
| AI | AI/大模型 | ✅ 最合适 |
| Tools | 实用工具 | 备选 |

最终选 `AI` / `AI/大模型`。

### 4.2 设计 field（安装表单的输入项）

按"业务有几个可变量"拆分。最初版本识别出的可变量：
1. Web 访问端口（容器内 `8000`，映射到宿主机）
2. 心跳间隔（原 compose 的 `30`）

加上必填四件套（`domain`、`allow_access`、`cpus`、`memory_limit`），共 6 项。

### 4.3 设计 env（变量表）

**命名规则**：
1. field 的 `attr` → env 的 `key`（**必须同名，小写下划线**）
2. .env 里的 KEY = `attr.upper()`
3. compose 里 `${KEY}` 引用

**必填四件套**：
1. `app_path` → 挂载目录根
2. `host_ip` → 端口绑定前缀
3. `cpus` → 资源限制
4. `memory_limit` → 资源限制

### 4.4 设计 volumes

对应 compose 里 `${APP_PATH}/` 下的子目录清单：

| key | 对应 compose 挂载 | desc |
|---|---|---|
| `config` | `${APP_PATH}/config:/home/node/app/config` | 配置目录 |
| `data` | `${APP_PATH}/data:/home/node/app/data` | 数据目录 |
| `plugins` | `${APP_PATH}/plugins:/home/node/app/plugins` | 插件目录 |
| `extensions` | `${APP_PATH}/extensions:/home/node/app/public/scripts/extensions/third-party` | 第三方扩展 |

**volumes 的 key 必须与 `${APP_PATH}/<key>` 一致**，否则面板不会自动创建对应子目录。

## 5. 第三步：编写 docker-compose.yml（转换后）

```yaml
services:
  sillytavern:
    image: ghcr.io/sillytavern/sillytavern:latest
    restart: unless-stopped
    deploy:
      resources:
        limits:
          cpus: ${CPUS}
          memory: ${MEMORY_LIMIT}
    environment:
      - NODE_ENV=production
      - FORCE_COLOR=1
      - SILLYTAVERN_HEARTBEATINTERVAL=${SILLYTAVERN_HEARTBEAT_INTERVAL}
    ports:
      - ${HOST_IP}:${SILLYTAVERN_WEB_PORT}:8000
    volumes:
      - ${APP_PATH}/config:/home/node/app/config
      - ${APP_PATH}/data:/home/node/app/data
      - ${APP_PATH}/plugins:/home/node/app/plugins
      - ${APP_PATH}/extensions:/home/node/app/public/scripts/extensions/third-party
    healthcheck:
      test: ["CMD", "node", "src/healthcheck.js"]
      interval: 30s
      timeout: 10s
      start_period: 20s
      retries: 3
    labels:
      createdBy: "bt_apps"
    networks:
      - baota_net

networks:
  baota_net:
    external: true
```

### 5.1 关键转换点逐条说明

1. **`${HOST_IP}:${SILLYTAVERN_WEB_PORT}:8000`**：前两个是"要不要被外部访问 + 宿主机端口"由面板动态填，最后的 `8000` 是容器内端口固定值。
2. **`${APP_PATH}`**：面板会把这个变量替换成 `/www/dk_project/wwwroot/{实例名}/` 这样的路径。
3. **`deploy.resources.limits`**：即使你不限制，也必须写，`${CPUS}` 为 0 时 docker 会无视。
4. **`labels.createdBy: "bt_apps"`**：没这个 label，面板不把容器列进"已安装"。
5. **`networks.baota_net.external: true`**：接入宝塔内部网络（需要宝塔先创建过 `baota_net`，通常安装 Docker 管理就有了）。

## 6. 第四步：编写 .env

```env
SILLYTAVERN_WEB_PORT=
SILLYTAVERN_HEARTBEAT_INTERVAL=
HOST_IP=
CPUS=
MEMORY_LIMIT=
APP_PATH=
```

**关键点**：
1. 值必须留空，面板安装时会根据 field 输入值回填。
2. 缺少 `.env` 文件，面板会报"docker-compose.yml 不存在"的误导性错误。
3. 键名顺序不重要，但建议业务变量在前，必填四件套在后。

## 7. 第五步：准备图标

SillyTavern 官方仓库 `public/img/logo.png` 就是现成的品牌 logo（大脑+ST 字样的红色设计），直接下载缩放。

```powershell
# 下载原图
Invoke-WebRequest `
  -Uri "https://raw.githubusercontent.com/SillyTavern/SillyTavern/release/public/img/logo.png" `
  -OutFile "apphub/sillytavern/icon.png" `
  -UseBasicParsing

# 用 System.Drawing 缩放到 100x100
Add-Type -AssemblyName System.Drawing
$src = [System.Drawing.Image]::FromFile("apphub/sillytavern/icon.png")
$dst = New-Object System.Drawing.Bitmap 100, 100
$g = [System.Drawing.Graphics]::FromImage($dst)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$g.Clear([System.Drawing.Color]::Transparent)
$g.DrawImage($src, 0, 0, 100, 100)
$dst.Save("apphub/sillytavern/icon.png", [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $src.Dispose(); $dst.Dispose()
```

**要求**：
1. 必须是 PNG（不能是 ICO、JPG）
2. 推荐 100x100（本模板标准）
3. 文件名固定 `icon.png`
4. 建议透明背景，面板上显示更干净

## 8. 第六步：提交与推送

```powershell
# 校验 JSON
Get-Content apphub/sillytavern/app.json | ConvertFrom-Json | Out-Null
Write-Output "app.json OK"

# 提交
git add apphub/sillytavern
git commit -m "feat: add SillyTavern app"
git push origin main
```

## 9. 第七步：对齐官方代码风格（复盘发现的 4 个差异）

对照 `aaPanel/apphub` 仓库的 `alist` / `deeplx` 示例，初版有 4 处可以打磨（不影响功能，但统一后更专业）：

| # | 字段 | 问题 | 修正 |
|---|---|---|---|
| 1 | `image` | `xream/sub-store`（隐式 latest） | 加 `:latest` 显式 tag |
| 2 | `cpus.suffix` | `"0为不限制"` | `"0为不限制,最大可用核心数为: "`（尾部冒号+空格是面板拼接主机容量的锚点） |
| 3 | `memory_limit.suffix` | 同上 | `"0为不限制,最大可用内存为: "` |
| 4 | `allow_access.suffix` | 缺失域名提示 | `"允许直接通过主机IP+端口访问，如果您设置了域名请不要勾选这里"` |

**结论**：即使"能跑"，也应该去翻官方示例对照文案和细节。

## 10. 第八步：踩坑复盘 —— Forbidden / IP 白名单

### 10.1 现象

安装完成、启动正常、域名解析正常，访问返回：

```
Forbidden
Connection from 172.18.0.1 (forwarded from <你的公网IP>) has been blocked.
```

### 10.2 根因

SillyTavern 默认 `whitelistMode: true`，只放行 `127.0.0.1`。宝塔反代过来的请求走 Docker 网桥（`172.18.0.1`），被拦。

### 10.3 决策：补字段进模板，而不是写在文档里让用户手动改

原则：**能在模板里让用户填的，就不要让用户装完去改配置文件**。

新增字段：

| field | 默认值 | 目的 |
|---|---|---|
| `sillytavern_whitelist_mode` | `false` | 关掉 IP 白名单 |
| `sillytavern_basicauth_mode` | `true` | 默认开 HTTP 基础认证 |
| `sillytavern_basicauth_user` | `admin` | 基础认证账号 |
| `sillytavern_basicauth_password` | `please_change_me` | **强提示必须改** |
| `sillytavern_enable_user_accounts` | `false` | 可选，SillyTavern 1.12+ 的账号系统 |

compose 里对应加 6 条环境变量：

```yaml
    environment:
      - NODE_ENV=production
      - FORCE_COLOR=1
      - SILLYTAVERN_LISTEN=true
      - SILLYTAVERN_HEARTBEATINTERVAL=${SILLYTAVERN_HEARTBEAT_INTERVAL}
      - SILLYTAVERN_WHITELISTMODE=${SILLYTAVERN_WHITELIST_MODE}
      - SILLYTAVERN_BASICAUTHMODE=${SILLYTAVERN_BASICAUTH_MODE}
      - SILLYTAVERN_BASICAUTHUSER_USERNAME=${SILLYTAVERN_BASICAUTH_USER}
      - SILLYTAVERN_BASICAUTHUSER_PASSWORD=${SILLYTAVERN_BASICAUTH_PASSWORD}
      - SILLYTAVERN_ENABLEUSERACCOUNTS=${SILLYTAVERN_ENABLE_USER_ACCOUNTS}
```

### 10.4 SillyTavern 环境变量命名规则（方便以后加配置）

`config.yaml` 里任何嵌套键：`foo.barBaz.qux`，对应环境变量是 `SILLYTAVERN_FOO_BARBAZ_QUX`（全大写、点和驼峰全部拉平）。

示例：
1. `listen` → `SILLYTAVERN_LISTEN`
2. `whitelistMode` → `SILLYTAVERN_WHITELISTMODE`
3. `basicAuthUser.username` → `SILLYTAVERN_BASICAUTHUSER_USERNAME`
4. `enableUserAccounts` → `SILLYTAVERN_ENABLEUSERACCOUNTS`

## 11. 第九步：已安装实例如何吃到模板更新

**关键事实**：模板更新**不会**自动更新已安装的实例，只影响新装的。

### 11.1 已安装实例的升级路径

**选项 A：热补丁**（保留数据）

1. 宝塔 → Docker → 已安装 → 找到 SillyTavern 实例
2. 编辑 compose 文件，把新增的 `environment` 行加进去
3. 编辑 `.env` 补上对应变量值
4. 重建容器

**选项 B：卸载重装**（彻底走新模板）

1. 备份 `${APP_PATH}/data` 和 `${APP_PATH}/config`
2. 宝塔刷新外部仓库 → 卸载旧实例 → 新版本重装
3. 覆盖回备份数据

## 12. 第十步：关于"安装时默认名称 sillytavern_xxx"的已知限制

### 12.1 现象

宝塔 Docker → 已安装 → 实例名显示为 `sillytavern_<随机后缀>`。

### 12.2 结论（已查过公开源码）

1. aaPanel 公开仓库里 `{appname}_{random}` 格式是**面板后端硬编码**行为，用来支持多实例隔离。
2. 官方 `template.md` 和两个示例 app.json 都没有提供自定义这个默认值的字段。
3. 用户只能在**安装表单最顶部的"名称"输入框**里手动改这个默认值（**这是唯一通道**）。

### 12.3 建议

在 app.json `appdesc` 或 help 文档里提醒用户"安装前可改顶部名称字段"，不要试图绕过。

## 13. 上线前检查清单（每次新增应用都走一遍）

复用 `docs/新应用脚手架清单.md` 的 10 项清单，外加本次新增：

1. [ ] `docker-compose.yml` 里 `environment` 的每个 `${VAR}` 都在 `.env` 和 `app.json.env[]` 里有对应
2. [ ] 应用的**默认安全配置**（如白名单、默认密码）是否在 field 里暴露为可配置项
3. [ ] 对照官方 `alist` / `deeplx` 的 app.json 检查 `suffix` 文案风格
4. [ ] 图标已缩放到 100x100 且是 PNG
5. [ ] 第一次在宝塔测试安装时，**完整跑一次访问流程**，而不是只看容器启动
6. [ ] 遇到应用自身的默认安全拦截（Forbidden / Unauthorized / ACL），优先补字段而非写文档

## 14. 参考资源

1. 官方模板仓库：<https://github.com/aaPanel/apphub>
2. 国内镜像：<https://cnb.cool/btpanel/apphub> / <https://gitee.com/btpanel/apphub>
3. 完整字段参考：见本仓库 `docs/宝塔apphub完整配置参考.md`
4. SillyTavern 上游：<https://github.com/SillyTavern/SillyTavern>
5. SillyTavern 文档：<https://docs.sillytavern.app/>
6. 本应用目录：`apphub/sillytavern/`

## 15. 本次 commit 轨迹（参考时间线）

```text
feat: add SillyTavern app                                       # 第一版
refactor: polish substore app.json to align with official style # 顺手修了 Sub-Store
feat(sillytavern): add listen/whitelist and auth toggles        # 补认证/白名单
```

从"能装"到"装完直接能用"走了三个 commit，下一次可以一次到位。
