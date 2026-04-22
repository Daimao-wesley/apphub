# 宝塔 AppHub 完整配置参考（超集版）

本文是 `template.md` 的**超集扩展版**，把官方模板里只用一行注释带过的字段都展开讲透，并补上所有在 `sillytavern` / `substore` 里没用到但**规范允许**的配置选项。

目标：你新增任何复杂度的应用，这份文档都足够用。

## 1. 整体目录规范

```text
apphub/                              # 固定为 apphub
  <appname>/                         # 小写英文应用名，等同于 app.json.appname
    app.json                         # 应用元信息（必填）
    icon.png                         # 100x100 PNG 图标（必填）
    latest/                          # latest 版本目录（推荐每个应用都有）
      docker-compose.yml
      .env
    <大版本号>/                      # 可选的具体版本目录
      docker-compose.yml
      .env
```

### 1.1 版本目录的命名规则

以 alist 为例：

```json
"appversion": [
    { "m_version": "latest", "s_version": [] },
    { "m_version": "3",      "s_version": ["42.0", "40.0"] }
]
```

面板渲染会拼接 `{m_version}.{s_version}` 得到：`latest`、`3.42.0`、`3.40.0`。

**每个渲染出来的版本号都必须有对应的目录**，目录里必须同时存在 `docker-compose.yml` 和 `.env`。

## 2. app.json 字段全解

### 2.1 顶层元信息

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `appid` | int | ✅ | 固定 `-1` |
| `appname` | string | ✅ | 应用唯一名（小写），与目录同名 |
| `apptitle` | string | ✅ | 展示标题，可含大小写、空格 |
| `apptype` | string | ✅ | 英文类型，见下表 |
| `appTypeCN` | string | ✅ | 中文类型，必须与 `apptype` 对应 |
| `appversion` | array | ✅ | 版本配置，见下面说明 |
| `appdesc` | string | ✅ | 简介，1~2 句话 |
| `appstatus` | int | ✅ | `1`=上架 / `0`=下架（不显示） |
| `home` | string | ❌ | 项目主页（GitHub 或官网）；可留空 `""` |
| `help` | string | ❌ | 使用/帮助文档 URL |
| `updateat` | int | ✅ | 最后更新 Unix 秒级时间戳；面板按这个判断是否有新版 |
| `depend` | any | ✅ | 暂未启用，固定 `null` |
| `field` | array | ✅ | 安装表单字段，见 §3 |
| `env` | array | ✅ | 变量定义，见 §4 |
| `volumes` | object | ✅ | 挂载目录描述，见 §5 |

### 2.2 apptype / appTypeCN 枚举对照表

| apptype | appTypeCN |
|---|---|
| `BuildWebsite` | 建站 |
| `Database` | 数据库 |
| `Storage` | 存储/网盘 |
| `Tools` | 实用工具 |
| `Middleware` | 中间件 |
| `AI` | AI/大模型 |
| `Media` | 多媒体 |
| `Email` | 邮件/邮局 |
| `DevOps` | DevOps |
| `System` | 系统 |

**必须从表中选**，写其他值面板可能不分类显示。

### 2.3 appversion 结构

```json
"appversion": [
    {
        "m_version": "latest",
        "s_version": []
    },
    {
        "m_version": "3",
        "s_version": ["42.0", "40.0"]
    }
]
```

规则：
1. `s_version` 为 `[]` 时只保留 `m_version` 作为完整版本号（`latest`）。
2. `s_version` 有值时渲染为 `{m_version}.{s_version[i]}`（如 `3.42.0`）。
3. 每个渲染出来的版本字符串都必须对应一个版本目录。
4. 排列顺序决定面板下拉列表顺序。

## 3. field[] 字段（安装表单输入项）

field 里的每一项会变成安装表单上的**一行输入框**。字段解析：

| 键 | 说明 |
|---|---|
| `attr` | 变量名（小写下划线）；部分 attr 是保留项，见 §3.2 |
| `name` | 表单左侧显示的中文标签 |
| `type` | 控件类型，见 §3.1 |
| `default` | 默认值；类型必须与 `type` 匹配 |
| `suffix` | 输入框右侧/下方的提示文案 |
| `unit` | 单位标记，如 `GB`、`s`；通常为 `""` |

### 3.1 可用的 type

| type | 控件 | default 类型 | 使用场景 |
|---|---|---|---|
| `string` | 单行文本框 | `""` | 路径、短文本、开关字符串 |
| `textarea` | 多行文本框 | `""` | 域名（支持多域名换行） |
| `number` | 数字输入框 | `int` | 端口、资源限制 |
| `checkbox` | 复选框 | `true`/`false` | 开关；**注意**：面板对"部分保留 attr"有特殊转换逻辑 |

**目前观察到的限制**：
1. 文档里没出现 `select` / `radio` / `password` 等更丰富的控件类型，保守使用以上 4 种。
2. 需要"枚举选择"时可以用 `string` + `suffix` 里写清楚候选值。

### 3.2 保留/推荐的 attr（每个应用都应该有）

这 4 项来自官方 alist/deeplx 示例，建议每个应用都完全复用：

| attr | type | default | 作用 |
|---|---|---|---|
| `domain` | textarea | `""` | 填了就自动创建宝塔网站反代到容器 |
| `allow_access` | checkbox | `true` | 控制 `HOST_IP` 值：`true`→`0.0.0.0`，`false`→`127.0.0.1` |
| `cpus` | number | `0` | CPU 核心数限制（0=不限） |
| `memory_limit` | number | `0` | 内存限制（0=不限） |

**`cpus` / `memory_limit` 的 suffix 文案固定写法**（面板会把主机实际容量拼接到末尾）：

```json
{
    "attr": "cpus",
    "suffix": "0为不限制,最大可用核心数为: "
},
{
    "attr": "memory_limit",
    "suffix": "0为不限制,最大可用内存为: "
}
```

末尾的**冒号+空格**是面板拼接锚点，不要漏。

**`allow_access` 的 suffix 官方文案**：

```text
允许直接通过主机IP+端口访问，如果您设置了域名请不要勾选这里
```

带上"如果您设置了域名请不要勾选这里"很关键，避免用户既配域名又开公网口。

### 3.3 业务字段（自定义 attr）

1. 命名全小写，下划线分隔（如 `alist_web_port`、`substore_backend_path`）。
2. 必须在 `env[]` 中有完全同名的 `key`。
3. 在 `.env` 里对应大写版本（`ALIST_WEB_PORT`）。
4. 在 `docker-compose.yml` 里用 `${ALIST_WEB_PORT}` 引用。

### 3.4 field 字段完整示例

```json
{
    "attr": "alist_web_port",       // 变量名（小写）
    "name": "web管理端口",          // 展示名
    "type": "number",               // 控件类型
    "default": 15244,               // 默认值
    "suffix": "alist的web管理端口", // 右侧提示
    "unit": ""                      // 单位后缀
}
```

## 4. env[] 字段（变量定义）

env 里每项描述一个会被注入到 `.env` 的变量。字段解析：

| 键 | 说明 |
|---|---|
| `key` | 变量名（小写）；与某个 field.attr 一一对应（保留项除外） |
| `type` | 值类型，见 §4.1 |
| `default` | 通常 `null`，由 field 填充 |
| `desc` | 后台描述（不直接展示给用户） |

### 4.1 可用的 type

| type | 说明 | 特殊行为 |
|---|---|---|
| `port` | 端口号 | **面板会在安装时做端口占用检测**；占用则阻止安装 |
| `number` | 数字 | 单纯数值，不检测 |
| `string` | 字符串 | 原样写入 |
| `path` | 宿主机路径 | 通常用于 `app_path` |

### 4.2 四个必填 env 项（不可省）

```json
{ "key": "app_path",     "type": "path",   "default": null, "desc": "应用数据目录" },
{ "key": "host_ip",      "type": "string", "default": null, "desc": "主机IP" },
{ "key": "cpus",         "type": "number", "default": null, "desc": "CPU核心数限制" },
{ "key": "memory_limit", "type": "number", "default": null, "desc": "内存大小限制" }
```

这 4 个由面板自动注入，不在安装表单里显示，但必须写在 `env[]` 里。

### 4.3 field ↔ env ↔ .env 对应关系（核心机制）

```text
app.json.field[i].attr   →   app.json.env[j].key   →   .env (UPPERCASE)  →   compose ${VAR}
       ↓                           ↓                        ↓                     ↓
  alist_web_port  ====同名====  alist_web_port  →  ALIST_WEB_PORT=  →  ${ALIST_WEB_PORT}
```

不同名就串不起来，安装会失败。

## 5. volumes{} 字段（挂载目录描述）

```json
"volumes": {
    "data": {
        "type": "path",
        "desc": "数据目录"
    },
    "mnt": {
        "type": "path",
        "desc": "配置文件"
    }
}
```

### 5.1 规则

1. **key 必须与 `${APP_PATH}/<key>` 的子目录名一致**。
2. 面板会根据 volumes 的 key 预创建对应子目录，并处理权限。
3. `type` 目前可取 `path`（目录）或 `file`（单文件挂载）。
4. `desc` 用于面板"数据管理"页展示。

### 5.2 什么时候可以留空 `{}`

应用完全无状态（例如 deeplx 这种翻译中转）时可以：

```json
"volumes": {}
```

否则**只要 compose 里有 `${APP_PATH}/xxx` 挂载，这里就必须声明 xxx**。

## 6. docker-compose.yml 规范

### 6.1 必须包含的项

```yaml
services:
  <appname>:                        # 不建议用 container_name
    image: <image>:<tag>            # 显式 tag，不要裸 image
    deploy:
      resources:
        limits:
          cpus: ${CPUS}             # 必须
          memory: ${MEMORY_LIMIT}   # 必须
    labels:
      createdBy: "bt_apps"          # 必填，否则面板不识别
    networks:
      - baota_net                   # 推荐使用外部网络

networks:
  baota_net:
    external: true
```

### 6.2 ports 规范

```yaml
    ports:
      - ${HOST_IP}:${XXX_PORT}:<container_port>
```

**解释**：
1. `${HOST_IP}`：`0.0.0.0` 或 `127.0.0.1`，由 `allow_access` 控制
2. `${XXX_PORT}`：用户填的宿主机端口
3. `<container_port>`：容器内固定端口（硬编码）

### 6.3 volumes 规范

```yaml
    volumes:
      - ${APP_PATH}/data:/app/data
      - ${APP_PATH}/config:/app/config
```

**不要用命名卷**（如 `my_volume:/app/data`），面板无法跟踪命名卷的数据位置。

### 6.4 禁止/不推荐的字段

| 字段 | 原因 |
|---|---|
| `container_name` | 面板会给容器生成自己的名字，硬编码会导致状态识别异常 |
| `build: .` | 宝塔走镜像拉取，不走本地 build |
| `hostname` | 无必要，面板会管理 |

### 6.5 restart 策略

| 值 | 场景 |
|---|---|
| `always` | 官方示例默认值，**推荐** |
| `unless-stopped` | 手动停止时不自动拉起（合法） |
| `on-failure` | 只在失败时重启 |
| `no` | 不自动重启（不推荐） |

### 6.6 healthcheck（可选）

```yaml
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      start_period: 20s
      retries: 3
```

官方示例没有使用，但 Docker Compose 原生字段，宝塔不会反对。加了面板能更准确显示健康状态。

### 6.7 多服务（services > 1）的场景

1. 服务数 ≤ 5 个：沿用 `baota_net: external: true`。
2. 服务数 ≥ 5 个：建议 compose 自建内部网络：

```yaml
networks:
  internal:
    driver: bridge
  baota_net:
    external: true
```

具体每个服务按需加入不同网络。

### 6.8 环境变量的三种写法对比

```yaml
    environment:
      - KEY1=固定值                        # 硬编码，不需要用户配
      - KEY2=${VAR_FROM_ENV}               # 完全由 .env 驱动
      - KEY3=${VAR_FROM_ENV:-fallback}     # 带默认值（docker-compose 原生特性）
```

## 7. .env 规范

### 7.1 写入规则

```env
MY_APP_PORT=
ANOTHER_VAR=
HOST_IP=
CPUS=
MEMORY_LIMIT=
APP_PATH=
```

1. 键名**全部大写**，与 `app.json.env[].key` 的大写版本一一对应。
2. 值必须**留空**（面板在安装时根据用户输入回填）。
3. 顺序不影响功能，但约定：业务变量在前，必填四件套（`HOST_IP`、`CPUS`、`MEMORY_LIMIT`、`APP_PATH`）在后。
4. **每个版本目录都要有自己的 `.env`**，不会跨版本继承。

### 7.2 常见错误

| 错误 | 后果 |
|---|---|
| `.env` 不存在 | 报"docker-compose.yml 不存在"的误导性错误 |
| 键名拼写与 `env[].key` 不匹配 | 变量注入失败，容器启动参数为空 |
| 键名没有大写 | 同上 |
| 在 `.env` 里写了实际值 | 覆盖用户输入，导致安装表单失效 |

## 8. icon.png 规范

| 项 | 要求 |
|---|---|
| 格式 | PNG |
| 尺寸 | 100x100（强烈推荐） |
| 背景 | 透明（推荐） |
| 文件名 | 固定 `icon.png`，放应用根目录 |
| 大小 | 建议 < 30KB |

### 8.1 从上游仓库扒图标的通用思路

1. 优先找上游仓库 `public/img/`、`assets/`、`docs/images/` 等路径下的 `logo.png` 或 `icon.png`
2. 其次找 `apple-touch-icon-*.png`（通常正方形）
3. 最后才考虑 `favicon.ico`（可能需要转 PNG）

## 9. 宝塔面板导入流程

### 9.1 首次导入外部仓库

1. 进入宝塔面板
2. 左侧菜单 → Docker → 应用商店
3. 右上角"外部仓库管理" → 添加仓库
4. 填写你的仓库地址（如 `https://github.com/yourname/apphub`）
5. 保存后点"同步"

### 9.2 日常更新流程

1. 改模板文件
2. **更新 `updateat`** 为当前 Unix 时间戳
3. git 提交 + 推送
4. 面板 → 应用商店 → 同步外部仓库
5. 已安装应用如需吃新模板：卸载重装，或手动 patch compose

### 9.3 获取当前 Unix 时间戳

```powershell
[int](Get-Date -UFormat %s)
```

```bash
date +%s
```

## 10. 宝塔面板在安装流程里做的事（机制理解）

按顺序发生：

1. **读 app.json**：渲染安装表单
2. **读 .env 模板**：记录要填哪些变量
3. **用户填表**：每个 field 值对应一个 env key
4. **特殊转换**：
   - `allow_access=true`  → `HOST_IP=0.0.0.0`
   - `allow_access=false` → `HOST_IP=127.0.0.1`
   - `domain` 非空 → 自动创建网站反代（Nginx 配置）
5. **端口检测**：`env[].type=port` 的会检测占用
6. **创建实例目录**：`/www/dk_project/wwwroot/{appname}_{random}/`
7. **复制 compose 和 .env 到实例目录**
8. **回填 .env**：把用户填的值写入
9. **创建挂载子目录**：按 `volumes{}` 声明创建 `${APP_PATH}/<key>/`
10. **`docker-compose up -d`**

## 11. 字段交叉引用速查（超高频）

```text
┌─────────────────────────────────────────────────────────────────┐
│ 场景：新加一个业务变量，需要改的 4 个地方                       │
├─────────────────────────────────────────────────────────────────┤
│ 1. app.json > field[]   添加 { "attr": "my_key", ... }          │
│ 2. app.json > env[]     添加 { "key": "my_key", ... }           │
│ 3. .env                 添加 MY_KEY=                            │
│ 4. docker-compose.yml   使用 ${MY_KEY}                          │
└─────────────────────────────────────────────────────────────────┘
```

## 12. 常见问题排查

### 12.1 安装后报 "docker-compose.yml 不存在"

排查顺序：
1. `<version>/docker-compose.yml` 存在吗？
2. `<version>/.env` 存在吗？**大概率是这个缺了**
3. `.env` 变量名与 `app.json.env[]` 对应吗？

### 12.2 安装后容器启动，但面板显示异常

可能原因：
1. `container_name` 写死了
2. `labels.createdBy: "bt_apps"` 缺失
3. 端口没走 `${HOST_IP}:${PORT}:容器端口` 格式

### 12.3 用户改了模板但面板没提示更新

1. `updateat` 没递增
2. 外部仓库未点"同步"
3. 宝塔有仓库缓存，可以删除外部仓库再重新添加

### 12.4 应用默认安全机制拦截访问（Forbidden / 403 / ACL）

**策略**：
1. 优先在 field 里暴露可配置的认证开关 + 账号密码
2. 用对应环境变量注入 compose
3. 宁可多加字段，也不要让用户装完去改 `config.yaml`

（见 SillyTavern 案例的 §10）

### 12.5 已安装的实例改不了默认名 `appname_xxx`

**这是面板硬编码行为**，app.json 不支持自定义。
唯一通道：**安装表单顶部的"名称"输入框**里手动改。

## 13. 应用设计时的 checklist

每次新增应用，问自己这 12 个问题：

1. [ ] apptype 分类对不对？
2. [ ] appname 和目录同名吗？（全小写）
3. [ ] 业务变量是不是都暴露成 field 让用户填了？
4. [ ] 必填四件套（domain/allow_access/cpus/memory_limit）都有吗？
5. [ ] 必填 env 四件套（app_path/host_ip/cpus/memory_limit）都有吗？
6. [ ] field.attr 和 env.key **同名且小写**吗？
7. [ ] .env 大写版本键名和 env.key 对得上吗？
8. [ ] compose 端口用 `${HOST_IP}:${PORT}:容器端口` 格式了吗？
9. [ ] compose 卷用 `${APP_PATH}/xxx` 格式了吗？
10. [ ] volumes{} 的 key 和 compose 里 `${APP_PATH}/<key>` 一致吗？
11. [ ] `labels.createdBy: "bt_apps"` 加了吗？
12. [ ] 应用默认是否有认证/白名单，是否已经通过 field 暴露？

## 14. 延伸阅读

1. 官方仓库：<https://github.com/aaPanel/apphub>
2. 国内镜像：<https://cnb.cool/btpanel/apphub>
3. 官方 `template.md`：<https://github.com/aaPanel/apphub/blob/main/template.md>
4. aaPanel 公开源码（了解内部机制）：<https://github.com/aaPanel/aaPanel>
5. 宝塔 Docker 使用手册：<https://docs.bt.cn/10.0/user-guide/docker/deployment/>
6. 本仓库实例：
   - `apphub/sillytavern/` - 完整功能（资源限制+认证+白名单）
   - `apphub/substore/` - 无状态 + 单端口 + 自定义路径
