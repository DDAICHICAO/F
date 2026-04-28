# Context
Filename: TASK_v2board_integration.md
Created On: 2026-04-11
Last Updated: 2026-04-28 (二次审查补充 17 项修正：架构隔离方案、流程遗漏、API 细节、风险项等)
Created By: AI
Associated Protocol: RIPER-5 + Multidimensional + Agent Protocol

# Task Description
对 FlClash 进行二次开发，对接 V2Board 后台系统，新增登录、注册、用户中心、工单、套餐、订单、公告、邀请等功能模块。

# Project Overview
- **FlClash**：基于 ClashMeta 内核的多平台（Android/Windows/macOS/Linux）代理客户端，Flutter 框架，Riverpod 状态管理，Drift 数据库，无账号体系。
- **V2Board（修改版）**：Laravel 8 订阅管理面板，自定义 JWT（HS256）认证。本项目对接的是含 Emby、红包、SubscribeRule、SubscribeWatermark、SubscribeSignature 等扩展模块的修改版（位于 `D:\常用项目\v2board`）。API 通过 nginx 反代暴露，路径前缀为自定义值（非固定 `/api/v1`）。
- **配置分发策略**：面板地址及 API 配置通过多个 OSS URL 冗余分发，客户端启动时依次尝试拉取，任一可达即可获取完整配置，保证高可用性。

---
*以下部分由 AI 在协议执行过程中维护*
---

# Analysis (RESEARCH)

## FlClash 架构要点

### 初始化流程
`main.dart` -> `WidgetsFlutterBinding.ensureInitialized()` -> `globalState.init(version)` 返回 `ProviderContainer` -> `UncontrolledProviderScope` 包裹 `Application()`。

### 导航体系
- 页面枚举：`lib/enum/enum.dart` 中的 `PageLabel`（dashboard, proxies, profiles, tools, logs, requests, resources, connections）
- 导航注册：`lib/common/navigation.dart` 的 `Navigation.getItems()` 返回 `List<NavigationItem>`
- 页面切换：`currentPageLabelProvider` 驱动，`appController.toPage(PageLabel)` 触发

### 状态管理
- Riverpod 3 + 注解代码生成（`@riverpod` / `@Riverpod(keepAlive: true)`）
- Provider 目录：`lib/providers/`（app.dart, config.dart, state.dart, database.dart）
- 全局单例：`GlobalState`、`AppController`、`Navigation`

### HTTP 请求
- `lib/common/request.dart` 中 `Request` 单例持有两个 Dio 实例：
  - `dio`：普通请求（GitHub 更新检查等）
  - `_clashDio`：走 Clash 代理的请求（订阅拉取）
- 无统一 REST baseUrl，无拦截器链
- `lib/common/http.dart` 中 `FlClashHttpOverrides`：非 localhost 时走 `PROXY localhost:{mixedPort}`

### 数据库
- Drift，`schemaVersion = 1`
- 表：`Profiles`、`Scripts`、`Rules`、`ProfileRuleLinks`
- DAO：`ProfilesDao`、`ScriptsDao`、`RulesDao`

### 订阅机制（重要：方案 B' 的基础）
- `Profile.update()` -> `request.getFileResponseForUrl(url)` -> 解析 `subscription-userinfo` 响应头 -> `saveFile`
- 自动更新：`application.dart` 每 20 分钟 `autoUpdateProfiles()`
- 订阅 URL 直接 GET，**不支持自定义 Header**（这一点决定了 V2Board 订阅必须通过 URL 参数携带认证信息，即依赖 `subscribe_url` 中的 token）
- `subscription-userinfo` 响应头格式：`upload={u}; download={d}; total={transfer_enable}; expire={expired_at}`，FlClash 已能解析

### 数据模型
- freezed 不可变模型：`lib/models/`（app.dart, clash_config.dart, common.dart, config.dart, core.dart, profile.dart, state.dart）
- `NavigationItem`：icon, label(PageLabel), builder(WidgetBuilder), keep, path, modes

## V2Board（修改版）架构要点

### 认证机制
- 自定义 JWT（HS256，密钥为 `config('app.key')`），JWT payload 仅含 `id` + `session`，**无内建过期时间**
- 登录响应返回 `auth_data`（JWT）、`token`（32位用户订阅令牌）、`is_admin`（是否管理员）
- 鉴权携带方式：`Authorization` 头**直接传 JWT 原值**（**不带 `Bearer ` 前缀**），或请求参数 `auth_data`
- 服务端会话校验：JWT 解码后通过 `CacheKey::USER_SESSIONS` 缓存键验证，被 `removeAllSession` 后立刻失效
- 封禁拦截：被封禁用户访问任何 user 接口均返回 403

### 中间件
- `user`：已登录用户（JWT 有效 + 未封禁）
- `admin`：JWT + `is_admin`
- `staff`：JWT + `is_staff`
- `client`：订阅/客户端接口，用 `token` 校验

### 核心 API 端点（基于真实代码核对，路径前缀均为 `{path}`，即 OSS 配置中的 `path` 字段）

#### 认证（无鉴权，prefix=passport）
| 方法 | 路径 | 请求体（关键字段） | 响应 | 说明 |
|------|------|-------------------|------|------|
| POST | `/passport/auth/register` | `email`、`password`（min8）、可选 `email_code`/`invite_code`/`recaptcha_data` | `{data: {token, is_admin, auth_data}}` | 注册并自动生成 auth_data |
| POST | `/passport/auth/login` | `email`、`password`（min8） | `{data: {token, is_admin, auth_data}}` | 登录 |
| POST | `/passport/auth/forget` | `email`、`email_code`、`password` | `{data: true}` | 重置密码后需重新登录 |
| GET | `/passport/auth/token2Login` | `token`/`verify` | 重定向 | 一键登录跳转，客户端通常不用 |
| POST | `/passport/auth/getQuickLoginUrl` | 已登录用户 | `{data: url}` | 生成快速登录 URL |
| POST | `/passport/comm/sendEmailVerify` | `email` | `{data: true}` | 发送邮箱验证码 |
| POST | `/passport/comm/pv` | - | - | PV 统计（可忽略） |

#### 站点配置（无鉴权，prefix=guest）
| 方法 | 路径 | 响应字段 | 说明 |
|------|------|---------|------|
| GET | `/guest/comm/config` | `tos_url`, `is_email_verify`, `is_invite_force`, `email_whitelist_suffix`, `is_recaptcha`, `recaptcha_site_key`, `app_description`, `app_url`, `logo` | 决定登录/注册页是否显示验证码、邀请码强制等 |

#### 用户信息（middleware: user，prefix=user）
| 方法 | 路径 | 关键字段/参数 | 说明 |
|------|------|--------------|------|
| GET | `/user/info` | `email`, `transfer_enable`, `device_limit`, `last_login_at`, `created_at`, `banned`, `suspended`, `auto_renewal`, `expired_at`, `balance`, `commission_balance`, `plan_id`, `discount`, `commission_rate`, `telegram_id`, `uuid`, `avatar_url` | 用户基本信息 |
| GET | `/user/getStat` | `[unpaid_orders, open_tickets, invited_users]` | 数组形式 |
| GET | `/user/getSubscribe` | 见下方专表 | **核心接口**：含 `subscribe_url`（已签名）、流量、套餐、暂停状态等 |
| GET | `/user/checkLogin` | `{data: {is_login, is_admin?}}` | 校验 token 是否仍有效，启动时恢复会话用 |
| POST | `/user/changePassword` | `old_password`、`new_password` | 改密后服务端会清除所有 session，需重新登录 |
| POST | `/user/update` | 仅 `auto_renewal`/`remind_expire`/`remind_traffic`/`notify_subscribe` | 不能改邮箱 |
| GET | `/user/resetSecurity` | - | 重置 uuid + token，返回新 `subscribe_url`（订阅泄露后用） |
| GET | `/user/getSignedSubscribeUrl?flag=` | - | 主动获取签名订阅链接，可指定 client flag |
| GET | `/user/getActiveSession` | - | 获取活跃会话列表（多设备登录管理） |
| POST | `/user/removeActiveSession` | `session_id` | 踢除指定会话（登出策略可用此） |
| POST | `/user/transfer` | `transfer_amount` | 佣金转余额 |
| POST | `/user/redeemgiftcard` | `giftcard` | 兑换礼品卡 |
| GET | `/user/compensateLogs` | `current`/`pageSize` | 补偿记录（**暂不集成**，归入 Phase 9 未来扩展点） |
| GET | `/user/subscribeSecurity/info` | - | 订阅安全信息（限流、IP分布、风险评估） |
| POST | `/user/subscribeSecurity/requestUnban` | - | 申请订阅解封 |

#### 用户运行时配置（middleware: user）
| 方法 | 路径 | 响应字段 | 说明 |
|------|------|---------|------|
| GET | `/user/comm/config` | `is_telegram`, `telegram_discuss_link`, `stripe_pk`, `withdraw_methods`, `withdraw_close`, `currency`, `currency_symbol`, `commission_distribution_*`, `surplus_enable`, `auto_renewal_enable` | **必须**：仪表盘货币符号、提现方式等 |
| POST | `/user/comm/getStripePublicKey` | `id` | Stripe 支付方式公钥 |

#### 套餐（middleware: user）
| 方法 | 路径 | 参数 | 说明 |
|------|------|------|------|
| GET | `/user/plan/fetch` | 可选 `id`（详情） | 列表只返回 `show=1` 套餐，自动扣减 `capacity_limit` |

Plan 模型关键字段：`month_price`, `quarter_price`, `half_year_price`, `year_price`, `two_year_price`, `three_year_price`, `onetime_price`, `reset_price`, `reset_first/second/third_price`, `transfer_enable`(GB), `device_limit`, `speed_limit`, `capacity_limit`, `group_id`, `server_ids`, `show`, `renew`, `sort`, `subscribe_name`。

#### 订单/支付（middleware: user）
| 方法 | 路径 | 请求/响应要点 | 说明 |
|------|------|--------------|------|
| POST | `/user/order/save` | 请求：`plan_id`、`period`（枚举见下）、可选 `coupon_code`、`deposit_amount`（plan_id=0 时充值）<br>响应：`{data: trade_no}` | 创建订单 |
| POST | `/user/order/preview` | `plan_id`、`period`、可选 `coupon_code`<br>响应含 `original_price`/`coupon_discount_amount`/`vip_discount_amount`/`surplus_amount`/`balance_amount`/`pay_amount` | **下单前价格预览**（必备） |
| POST | `/user/order/checkout` | `trade_no`、`method`、可选 `token`(stripe)<br>响应：`{type, data}` | type=-1 余额支付完成；其他 type 表示支付方式（URL/HTML/表单） |
| GET | `/user/order/check` | `trade_no`<br>响应：`{data: status}` | status: 0=待支付/1=开通中/2=已取消/3=已完成/4=已折抵 |
| GET | `/user/order/detail` | `trade_no` | 订单详情（含 plan、surplus_orders 等） |
| GET | `/user/order/fetch` | 可选 `status` | 订单列表 |
| GET | `/user/order/getPaymentMethod` | - | 支付方式列表（id, name, payment, icon, handling_fee_*） |
| POST | `/user/order/cancel` | `trade_no` | 取消待支付订单 |
| GET | `/user/order/rechargeInfo` | - | 充值套餐列表（金额返回为元） |

`period` 枚举：`month_price | quarter_price | half_year_price | year_price | two_year_price | three_year_price | onetime_price | reset_price | deposit`

#### 优惠券（middleware: user）
| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/user/coupon/check` | 校验优惠券 |
| POST | `/user/coupon/getAvailableCoupons` | 当前可用优惠券 |

#### 工单（middleware: user）
| 方法 | 路径 | 请求/响应要点 | 说明 |
|------|------|--------------|------|
| GET | `/user/ticket/fetch` | 无 id：列表；带 id：详情含 `message[]`，每条 `is_me` 已由服务端计算 | 列表+详情共用一个端点 |
| POST | `/user/ticket/save` | `subject`、`level`(0/1/2)、`message`、可选 `images[]` | 创建工单（后端校验当前无未关闭工单） |
| POST | `/user/ticket/reply` | `id`、`message`、可选 `images[]` | 回复 |
| POST | `/user/ticket/close` | `id` | 关闭 |
| POST | `/user/ticket/upload` | multipart 字段以 `images` 开头（如 `images[]`），单张 ≤5MB，最多 5 张 | 返回 `{data: [url1, url2, ...]}` |

工单消息中**图片嵌入协议**：`message` 正文末尾用 `\n\n[TICKET_IMAGES]\n{url1}\n{url2}` 分隔，**客户端必须解析这个分隔符**才能在气泡中正确显示图片。

`POST /user/ticket/withdraw` 是"佣金提现申请"（创建一个 level=2 的提现工单），**不属于工单模块**，应归到邀请返利模块。后端**没有"撤回消息"功能**。

#### 公告（middleware: user）
| 方法 | 路径 | 参数 | 说明 |
|------|------|------|------|
| GET | `/user/notice/fetch` | 无 id：列表（`current` + `pageSize`，默认 5，max 100），返回 `{data, total}`<br>带 id：单条详情 | Notice 字段：`id`, `title`, `content`(HTML), `img_url`, `tags`, `show`, `created_at` |

#### 邀请返利（middleware: user）
| 方法 | 路径 | 请求/响应要点 | 说明 |
|------|------|--------------|------|
| **GET** | `/user/invite/save` | - | **是 GET 不是 POST**！生成新邀请码（受 `invite_gen_limit` 限制） |
| GET | `/user/invite/fetch` | 响应：`{data: {codes: [...], stat: [registered, valid_commission, uncheck_commission, commission_rate, available_commission]}}` | stat 是**位置数组** |
| GET | `/user/invite/details` | `current`/`page_size` | 返利明细分页 |
| POST | `/user/invite/drop` | `id` | 删除/禁用邀请码 |
| POST | `/user/ticket/withdraw` | `withdraw_method`、`withdraw_account` | **佣金提现入口**（功能上属于邀请返利） |

#### 节点（middleware: user）
| 方法 | 路径 | 响应 | 说明 |
|------|------|------|------|
| GET | `/user/server/fetch` | `{data: [...servers], unavailable_reason?: {...}}`<br>响应头 `ETag: "{sha1}"` | 用户不可用时返回 `unavailable_reason`（type/icon/title/message/action）；支持 `If-None-Match` → 304 |

> **节点 type 包含**：`shadowsocks`, `vmess`, `vless`, `trojan`, `tuic`, `hysteria`, `hysteria2`(独立type), `anytls`, `v2node`(内联适配协议)
> 端口范围：`port` 含 `-` 时保留为字符串，并写入 `mport` 字段；hysteria 系列额外有 `ports`

> **重要**：方案 B' 不需要客户端解析这些节点字段，仅作为参考保留。

#### 知识库（middleware: user）
| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/user/knowledge/fetch` | 知识库列表（可考虑 WebView） |
| GET | `/user/knowledge/getCategory` | 知识库分类 |

#### 用户流量统计（middleware: user）
| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/user/stat/getTrafficLog` | 月度流量记录 |
| GET | `/user/stat/getNodeTrafficLog` | 按节点流量统计 |
| GET | `/user/stat/getSubscribeLog` | 订阅拉取日志 |
| GET | `/user/stat/getAliveIpLog` | 在线 IP 日志 |
| GET | `/user/stat/getSubscribeStat` | 订阅统计 |

#### 客户端订阅（middleware: client）
| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `{subscribe_url}` | **从 `getSubscribe` 返回值中取**，URL 自带 `token` + 签名，可附加 `&flag=meta` 指定 ClashMeta |
| GET | `/client/app/getConfig?token=` | 返回 yaml 文本（不是 JSON） |
| GET | `/client/app/getVersion?token=` | 客户端版本（按 UA 区分平台） |

> **关键**：`/client/subscribe` 路由在后台配置了 `subscribe_path` 时**不会注册**，订阅必须从 `getSubscribe` 返回的 `subscribe_url` 取，**不能在客户端硬编码路径**。

#### 修改版扩展模块（暂不集成，列为未来扩展点）
- `/user/redpacket/*` 红包系统
- `/user/emby/*`, `/user/emby/charity/*` Emby 账号管理与公益服
- `/user/jellyseerr/*` Jellyseerr 媒体请求
- `/user/subscribeRule/*` 用户订阅规则系统（含可视化配置、模板、聚合策略组等 20+ 子接口）
- `/user/telegram/getBotInfo`, `/user/unbindTelegram` Telegram 绑定

### `/user/getSubscribe` 关键字段（核心数据源）

| 字段 | 类型 | 用途 |
|------|------|------|
| `id` | int | 用户 ID |
| `email` | String | 邮箱 |
| `plan_id` | int? | 当前套餐 ID |
| `plan` | Plan? | 套餐对象 |
| `token` | String(32) | 订阅 token |
| `uuid` | String | 用户 UUID（节点凭据） |
| `expired_at` | int? | 到期时间戳（null=长期） |
| `u`, `d` | int | 已用上行/下行（字节） |
| `transfer_enable` | int | 总流量额度（字节） |
| `device_limit` | int? | 设备数限制 |
| `alive_ip` | int | 当前在线设备数 |
| `reset_day` | int? | 流量重置剩余天数 |
| `auto_renewal` | int | 自动续费开关 |
| `allow_new_period` | int | 允许续期 |
| `balance` | int | 余额（分） |
| `subscribe_url` | **String** | **服务端已生成的签名订阅链接（核心）** |
| `subscribe_ban` | bool | 风控封禁 |
| `suspended`, `suspend_reason`, `suspended_at` | - | 暂停信息 |
| `suspend_info` | object? | 暂停详情（仅 suspended 时） |

---

# Proposed Solution (INNOVATE)

## 方案演进

### 方案 A：轻量嵌入式 -- 仅登录 + 自动订阅 + WebView
在 FlClash 中增加登录页面，登录成功后自动获取订阅链接并添加为 Profile。工单等功能通过 WebView 内嵌 V2Board 前端。
- 优点：改动最小、风险最低
- 缺点：体验割裂，WebView 页面与原生 UI 风格不统一

### 方案 B（已弃用）：客户端自建 ClashMeta 协议构建器
登录后调用 `server/fetch` 取节点 JSON 数组，客户端 Dart 侧实现 7 个 build 方法（shadowsocks/vmess/vless/trojan/tuic/hysteria/anytls）将节点组装为 ClashMeta YAML，存为 file 类型 Profile。
- 优点：节点数据自包含，可离线缓存
- 缺点：
  - 需移植 600+ 行协议构建代码（参考 `app/Protocols/ClashMeta.php`）
  - 必须持续跟进 Reality / xhttp / mlkem encryption / SS2022 / hysteria2 obfs salamander 等协议升级
  - 丢失服务端的用户自定义订阅规则（`SubscribeRuleService`）
  - 丢失服务端的订阅水印、host override、域名替换等功能
  - 修改版后端的 `v2node` 内联协议、`hysteria2` 独立 type 需要额外适配

### 方案 B'（**最终选定**）：直接复用 `subscribe_url`
登录后调用 `/user/getSubscribe` 取到服务端已签名的 `subscribe_url`，在客户端把它当作普通订阅 URL（追加 `&flag=meta` 强制 ClashMeta 协议），通过 `Profile.normal(url=subscribeUrl)` 注册为标准 URL 类型 Profile。流量数据双通道获取：
- **被动通道**：复用 FlClash 现有 `subscription-userinfo` 响应头解析（`Profile.update()` 流程）
- **主动通道**：定时调 `/user/getSubscribe` 同步 `u/d/transfer_enable/expired_at/alive_ip/plan` 到 `authProvider`，用于仪表盘精确展示

优点：
- 客户端代码量最小（无需协议构建器，无需配置模板，无需 ETag 处理）
- 自动跟进协议升级（服务端改完客户端零修改）
- 保留服务端的用户自定义规则、订阅水印、host override
- 复用 FlClash 现有的 20 分钟自动更新机制

缺点：
- 强依赖 `subscribe_url` 可达性，但服务端在 nginx 反代后已经走同一域名，与 API 故障转移共享高可用方案
- 不能离线获取节点列表（但客户端本地有 Profile YAML 缓存，离线启动 OK）

### 方案 C：混合方案 -- 核心原生 + 次要 WebView
高频核心功能（登录、注册、仪表盘、订阅管理、工单）用原生 Flutter 实现；低频功能（知识库、支付页面、订阅安全详情、邀请详情等）通过 WebView 承载。
- 优点：开发效率与用户体验的最佳平衡
- 缺点：需维护两种渲染方式

## 最终决策
采用 **方案 C（混合）+ 方案 B'（订阅复用）** 组合：
- **订阅集成**走方案 B'：直接复用 `subscribe_url`，零协议构建代码
- **UI 集成**走方案 C：登录/注册/仪表盘/套餐/订单/工单/公告/邀请用原生 Flutter，支付页面/知识库/订阅安全详情用 WebView

---

# Implementation Plan (PLAN)

## 一、整体架构分层

```
+---------------------------------------------------+
|                FlClash Application                |
+---------------------------------------------------+
|  原有功能层 (代理/配置/日志/连接/资源)             |
+---------------------------------------------------+
|  V2Board UI 层 (登录/注册/仪表盘/套餐/工单/公告)   |
+---------------------------------------------------+
|  V2Board API 服务层 (统一封装)                    |
+---------------------------------------------------+
|  认证管理层 (Token 持久化/拦截器/面板地址故障转移) |
+---------------------------------------------------+
|  Riverpod 状态层 (新增 Provider)                  |
+---------------------------------------------------+
|  OSS 远程配置层 (多源拉取/缓存/Base64 解码)       |
+---------------------------------------------------+
|  Drift 数据层 (新增本地缓存表)                    |
+---------------------------------------------------+
```

## 二、新增目录结构

在 `lib/` 下新增以下目录，与现有代码风格保持一致：

```
lib/
  v2board/                          # V2Board 集成模块（独立目录，低侵入）
    api/                            # API 接口封装
      v2board_api.dart              # 统一 API 客户端（独立 Dio + 故障转移拦截器 + 认证拦截器）
      api_paths.dart                # 所有相对路径常量
      auth_api.dart                 # 登录/注册/找回密码/checkLogin/resetSecurity
      user_api.dart                 # info/getStat/getSubscribe/update/changePassword/comm.config
      session_api.dart              # getActiveSession/removeActiveSession（登出用）
      plan_api.dart                 # plan/fetch
      order_api.dart                # order/save/preview/checkout/check/detail/fetch/cancel/getPaymentMethod/rechargeInfo
      coupon_api.dart               # coupon/check/getAvailableCoupons
      ticket_api.dart               # ticket/fetch/save/reply/close/upload（不含 withdraw）
      notice_api.dart               # notice/fetch
      invite_api.dart               # invite/save(GET)/fetch/details/drop + ticket/withdraw（提现）
      guest_api.dart                # guest/comm/config
      subscribe_bridge.dart         # 订阅桥接：getSubscribe -> Profile.normal(url=subscribe_url+&flag=meta) -> 定时 sync 流量
    models/                         # V2Board 数据模型（freezed）
      auth.dart                     # AuthResponse(token, is_admin, auth_data)
      user_info.dart                # UserInfo, SubscribeInfo（含 subscribe_url 等全字段）
      site_config.dart              # GuestConfig, UserCommConfig
      plan.dart                     # Plan（含全部周期价格字段）
      order.dart                    # Order, OrderDetail, OrderPreview, PaymentMethod, RechargePackage
      coupon.dart                   # Coupon, CouponCheckResult
      ticket.dart                   # Ticket, TicketMessage（带 images 解析）
      notice.dart                   # Notice
      invite.dart                   # InviteCode, CommissionLog, InviteStat（位置数组解析）
      api_response.dart             # 统一响应包装 ApiResponse<T>
      api_error.dart                # ApiError（401/403/422/500 的语义化错误）
    providers/                      # Riverpod Provider
      remote_config_provider.dart   # OSS 远程配置（loading/ready/error）
      auth_provider.dart            # 认证状态（登录态/auth_data/token/is_admin）
      site_config_provider.dart     # 站点配置（guest+user 合并）。刷新时机：App 启动时拉取一次并缓存到内存；进入注册页时强制刷新 `guest/comm/config`（确保邀请码/验证码开关实时）；每次调 `syncSubscribeInfo` 时顺带刷新 `user/comm/config`（确保货币符号等同步）。不采用"每次打开页面都请求"策略以减少请求量
      user_provider.dart            # UserInfo + SubscribeInfo（含流量数据）
      plan_provider.dart            # 套餐列表
      order_provider.dart           # 订单列表/详情
      ticket_provider.dart          # 工单列表/详情/消息
      notice_provider.dart          # 公告列表
      invite_provider.dart          # 邀请码/返利/提现
    views/                          # 页面 UI
      auth/
        splash_view.dart            # 启动加载页（OSS 配置拉取中）
        config_error_view.dart      # OSS 全部失败时的兜底页（手动输入面板地址）
        login_view.dart
        register_view.dart
        forget_password_view.dart
      dashboard/
        user_dashboard_view.dart    # 用户中心仪表盘
      plan/
        plan_list_view.dart
        plan_detail_view.dart       # 含 preview 价格预览 + 优惠券输入
      order/
        order_list_view.dart
        order_detail_view.dart
        payment_webview.dart        # 支付页面（WebView）
      ticket/
        ticket_list_view.dart
        ticket_detail_view.dart     # 聊天气泡式 + 解析 [TICKET_IMAGES]
        ticket_create_view.dart
      notice/
        notice_list_view.dart
        notice_detail_view.dart     # HTML 富文本渲染
      invite/
        invite_view.dart            # 邀请码 + 返利明细 + 提现入口
        withdraw_dialog.dart        # 提现表单（withdraw_method + withdraw_account）
    widgets/                        # 复用组件
      v2board_scaffold.dart         # 统一页面脚手架
      traffic_progress.dart         # 流量进度条
      plan_card.dart                # 套餐卡片
      ticket_message_bubble.dart    # 工单消息气泡（含图片解析）
      currency_text.dart            # 按 user/comm/config 货币符号显示金额
    config/                         # 配置
      remote_config.dart            # OSS 多源拉取（直连 Dio + Base64 解码 + 缓存）
      v2board_local_storage.dart    # shared_preferences 封装（统一 key 管理）
      remote_config_model.dart      # 远程配置数据模型（freezed，api[]+path+oss?[]）
```

> 与原方案对比：**移除** `clash_config_builder.dart`、`server_api.dart`、节点模型、ClashMeta 模板等所有协议构建相关内容。

## 三、OSS 多源配置分发架构

### 3.1 设计背景
面板域名可能因 DNS 污染、CDN 故障、域名封锁等原因不可达。将配置信息托管到多个 OSS 平台（阿里云 OSS、腾讯云 COS、Cloudflare R2 等），客户端依次尝试拉取，任一源可达即可获取完整配置。同时 API 路径通过 nginx 反代自定义（如 `/xkD93rN81qpL0mz7/v1`），面板地址使用 Base64 编码做基础混淆。

### 3.2 OSS 配置文件格式（基于实际线上结构）
参考实际 OSS 配置：`https://bust-sh.oss-cn-shanghai.aliyuncs.com/sntp.yaml`

文件后缀为 `.yaml` 但实际内容为 JSON，结构如下：

```json
{
  "api": [
    "aHR0cHM6Ly90LnhuLS1od3FwMnppdDJhbW5hLm5ldA==",
    "aHR0cHM6Ly95LnhuLS1od3FwMnppdDJhbW5hLm5ldA=="
  ],
  "path": "/xkD93rN81qpL0mz7/v1"
}
```

字段说明：

| 字段 | 类型 | 说明 |
|------|------|------|
| `api` | List\<String\> | 面板地址数组，每个元素为 **Base64 编码**的完整 URL。多个地址做冗余 |
| `path` | String | nginx 反代后的 API 路径前缀，替代固定的 `/api/v1` |
| `oss` | List\<String\>? | 可选：OSS 源列表自引用，用于热更新 OSS URL 列表 |

设计要点：
- **Base64 编码**是一层基础混淆，防止 OSS 文件被扫描时直接暴露面板明文域名
- **api 数组多地址冗余**：多个面板域名指向同一后端，某个域名被封时自动切换
- **path 含随机字符串**：增加反代路径的隐蔽性
- **文件后缀 `.yaml`**：伪装为普通配置文件

### 3.3 双层冗余架构

**第一层：OSS 源冗余**
客户端内置多个 OSS URL（不同厂商/地域），依次尝试拉取配置文件。任一 OSS 可达即可获取到 `api` 和 `path`。

**第二层：面板地址冗余**
配置文件中 `api` 数组包含多个面板地址（Base64 编码）。发起 API 请求时，如果第一个面板地址不通，自动切换到第二个。

### 3.4 多源拉取与启动流程

```
App 启动
  |
  v
读取本地缓存的 OSS 配置（shared_preferences）
  |
  +-- 有缓存 --> 用缓存的 api[] + path 先启动（不阻塞用户）
  |              同时后台异步拉取最新配置（静默更新）
  |
  +-- 无缓存（首次安装）--> 阻塞式拉取
                  |
                  v
        依次尝试内置 OSS URL 列表
          |
          +-- 某个成功 --> 解析 + Base64 解码 + 缓存到本地
          |
          +-- 全部失败 --> ConfigErrorView（手动输入面板地址兜底）
```

拉取细节：
- 每个 OSS URL 设置 **5 秒超时**，总体不超过 15-20 秒
- 使用**直连 Dio 实例**（不走 Clash 代理）
- 响应内容按 JSON 解析（虽然文件后缀可能是 `.yaml`）
- 解析成功后 Base64 解码 `api` 数组中的每个元素

### 3.5 面板地址故障转移
活跃地址缓存在内存中（`activeApiIndex`），请求失败（超时/连接拒绝/DNS 失败）时切换到 `api[next]` 重试同一请求。

**持久化 `activeApiIndex`**：将上次成功的 `activeApiIndex` 写入 `shared_preferences`（key: `v2board_active_api_index`），下次冷启动直接使用上次成功的地址，避免每次启动都先尝试不可达的第一个域名导致 5 秒超时等待。当 `api[]` 数组被 OSS 配置更新替换时，重置为 0。

## 四、认证架构设计

### 4.1 认证流程

```
App 启动
  |
  v
拉取/恢复 OSS 配置 --> 得到 api[] + path
  |
  v
检查本地持久化的 auth_data (JWT) 和 token
  |
  +-- 无 --> 显示登录页
  |
  +-- 有 --> 调用 /user/checkLogin 验证
            |
            +-- is_login=true --> 加载 getSubscribe + comm/config + Profile 同步 --> 进入主页
            |
            +-- 401/false --> 清除本地 + 跳登录页
```

### 4.2 V2Board API 客户端设计（关键）

`v2board_api.dart` 持有一个独立的 Dio 实例，关键设计点：

| 设计点 | 实现 |
|--------|------|
| Base URL | 动态：`api[activeIndex]`（Base64 解码后） + `path` |
| 故障转移 | 请求失败（超时/DNS/连接拒绝）时自动切换 `api[next]` 重试 |
| 认证头 | `Authorization: <jwt>`（**无 `Bearer ` 前缀**） |
| 401 处理 | 清除本地 `auth_data` + `token`，跳转登录页 |
| 403 处理 | "账户已被封禁"等友好提示 |
| 422 处理 | 表单验证错误（提取 errors 字段） |
| 错误统一解包 | V2Board 标准格式 `{data}` / `{message}`，统一封装 ApiResponse<T> |
| 代理绕过 | 使用独立 `HttpClient` 实例，**不受 `FlClashHttpOverrides` 影响**（代理未启动时也能登录）。具体做法：创建 `HttpClient()` 后设置 `findProxy = (uri) => HttpClient.findProxyFromEnvironment(uri, environment: {'http_proxy': '', 'https_proxy': ''});` 强制直连，然后通过 `Dio(httpClientAdapter: IOHttpClientAdapter(httpClient: customClient))` 注入到 Dio 实例。**注意**：该独立 `HttpClient` 需在 `FlClashHttpOverrides.setGlobal()` 调用之前创建，或确保 Dio 的 `httpClientAdapter` 已绑定了不走系统代理的 `HttpClient`，否则可能被全局 `HttpOverrides` 覆盖 |

### 4.3 Token 持久化（shared_preferences）

| Key | 值 | 说明 |
|-----|-----|------|
| `v2board_oss_config` | JSON 字符串 | OSS 配置缓存（`{"api":[...],"path":"..."}`） |
| `v2board_oss_urls` | JSON 数组 | 运行时 OSS 源列表（可被 `oss` 字段动态更新） |
| `v2board_auth_data` | JWT 字符串 | 认证凭证 |
| `v2board_token` | 32 位字符串 | 用户订阅 token（与 auth_data 用途不同，前者订阅，后者鉴权） |
| `v2board_is_admin` | bool | 是否管理员 |
| `v2board_user_email` | String | 记住账号 |
| `v2board_profile_id` | int | 与 V2Board 关联的 Profile ID（订阅自动更新用） |
| `v2board_manual_api_url` | String? | OSS 全部失败时手动输入的面板地址（兜底） |
| `v2board_active_api_index` | int | 上次成功的面板地址索引（冷启动快速切换用） |
| `v2board_last_notice_time` | String | 最近一次查看公告的 ISO8601 时间戳（新公告标记用） |

## 五、对现有代码的改动点（最小侵入）

### 5.1 lib/enum/enum.dart
在 `PageLabel` 枚举中新增：
```dart
enum PageLabel {
  // ... 原有 ...
  userCenter,     // 用户中心（仪表盘 + 套餐 + 订单入口）
  tickets,        // 工单
  notices,        // 公告
}
```

### 5.2 lib/common/navigation.dart
在 `getItems()` 中追加 3 个 `NavigationItem`，分别对应上述 PageLabel。modes 设置为 `[mobile, desktop]` 或按需分配到 more。

### 5.3 lib/application.dart
在 `MaterialApp` 的 `home` 参数处做三层条件判断。

**注意事项**：FlClash 原有的 `home` 赋值方式需在 EXECUTE 前调研确认——当前 `home` 可能是 `Scaffold` + `Navigation` 的组合结构而非简单的 `HomePage()`。三层守卫不应直接替换原有 `home` 逻辑，而是在外层包裹：配置未就绪时显示 `SplashView`/`ConfigErrorView`，就绪后进入原有 `home` 流程（但需在原有流程入口处判断认证状态，未登录则跳转 `LoginView`）。具体插入点在 EXECUTE 阶段需先读取 `application.dart` 全文再确定。

```dart
// 概念示例，实际插入点需根据 application.dart 现有结构确定
home: switch (ref.watch(remoteConfigProvider).status) {
  ConfigStatus.loading => const SplashView(),
  ConfigStatus.error => const ConfigErrorView(),
  ConfigStatus.ready => ref.watch(authProvider).isLoggedIn
      ? const原有HomePage结构()
      : const LoginView(),
}
```

### 5.4 lib/state.dart / lib/controller.dart
- `globalState.init()` 中增加：
  - OSS 配置恢复（从 shared_preferences 读取缓存的 `api[]` + `path`）
  - 认证状态恢复（读取 `auth_data` + `token`）
  - 后台异步刷新 OSS 配置
- `AppController` 中增加：
  - `loginAndAttachProfile(authResp)` —— 登录/注册成功后：getSubscribe → 取 `subscribe_url` → `Profile.normal(label: siteName, url: Uri.parse(subscribeUrl).replace(queryParameters: {'flag': 'meta'}).toString())` → `putProfile()` → 设为当前 Profile → 持久化 profile_id
  - `syncSubscribeInfo()` —— 定时（与原 `autoUpdateProfiles` 同周期或独立 5 分钟）调 `getSubscribe` 刷新流量数据到 userProvider
  - `logoutAndCleanup()` —— 调 `removeActiveSession`（失败不阻塞）→ 清本地 → 删除 V2Board Profile（可选）
  - `checkBanStatus()` —— 在 `checkLogin` 成功后，立即调 `getSubscribe` 检查 `banned`/`suspended` 字段，若被封禁则弹出提示并强制跳转登录页，避免用户先看到主页再被 403 拦截
  - `handleChangePasswordSuccess()` —— `changePassword` 成功后，服务端会清除所有 session，客户端必须立即执行 `logoutAndCleanup()` 并跳转登录页，不要等下次请求 401 才发现

### 5.5 lib/models/profile.dart
**无需修改**。V2Board 订阅以 `Profile.normal(url=...)` 走标准 URL 类型 Profile，复用现有 `Profile.update()` 流程，自动获得 `subscription-userinfo` 响应头解析能力。

### 5.6 lib/database/database.dart
`schemaVersion` 从 1 升至 2，新增本地缓存表（**可选**，用于离线浏览）：

| 表名 | 字段 | 用途 |
|------|------|------|
| V2boardTickets | id, subject, status, createdAt, updatedAt, level | 工单列表缓存 |
| V2boardTicketMessages | id, ticketId, message, isMe, images(JSON 字符串), createdAt | 工单消息缓存 |
| V2boardNotices | id, title, content, createdAt, imgUrl, readAt | 公告缓存（含已读标记） |

migration 策略采用 Drift 推荐的 step-by-step 模式：

```dart
// 在 onUpgrade 回调中
if (oldVersion < 2) {
  await customStatement('CREATE TABLE IF NOT EXISTS v2board_tickets (...)');
  await customStatement('CREATE TABLE IF NOT EXISTS v2board_ticket_messages (...)');
  await customStatement('CREATE TABLE IF NOT EXISTS v2board_notices (...)');
}
// 预留后续升级口：
// if (oldVersion < 3) { ... }
```

缓存写入时机：每次 API 成功返回后写入本地，覆盖旧数据。缓存失效策略：工单关闭后保留 7 天自动清除；公告保留最近 50 条。离线模式时 UI 顶部显示"离线模式"横幅提示。

### 5.7 pubspec.yaml
新增依赖：

| 包名 | 用途 |
|------|------|
| `webview_flutter` | 支付页面、知识库、订阅安全详情等 WebView 承载 |
| `flutter_widget_from_html_core` | 公告/工单 HTML 富文本渲染 |
| `cached_network_image` | 工单图片缓存 |
| `image_picker` | 工单上传图片 |

### 5.8 国际化 lib/l10n/*.arb
为所有新增的 PageLabel 和 UI 文案补充中英文翻译。

## 六、各功能模块详细设计

### 6.1 登录 / 注册 / 找回密码

**对接 API**（路径均为相对路径，实际 URL = `api[activeIndex]` + `path` + 相对路径）：

| 功能 | 方法 | 相对路径 | 请求体 | 响应 |
|------|------|----------|--------|------|
| 登录 | POST | `/passport/auth/login` | `email`, `password` | `{data: {token, is_admin, auth_data}}` |
| 注册 | POST | `/passport/auth/register` | `email`, `password`, 可选 `email_code`, `invite_code`, `recaptcha_data` | `{data: {token, is_admin, auth_data}}` |
| 忘记密码 | POST | `/passport/auth/forget` | `email`, `email_code`, `password` | `{data: true}`（需重新登录） |
| 发送验证码 | POST | `/passport/comm/sendEmailVerify` | `email` | `{data: true}` |
| 站点配置 | GET | `/guest/comm/config` | - | 决定是否显示验证码、邀请码等 |
| 校验登录 | GET | `/user/checkLogin` | - | `{data: {is_login, is_admin?}}` |

**注册页字段开关由站点配置控制**：
- `is_email_verify === 1` → 显示并强制邮箱验证码
- `is_invite_force === 1` → 邀请码必填
- `is_recaptcha === 1` → 降级方案分两级：优先使用 `flutter_recaptcha_enterprise` 等 Flutter 原生插件集成 reCAPTCHA；若原生方案不可行，则降级为 WebView 承载整个注册页（`{apiUrl}/#/register`）。**不要仅提示用户去网页注册**，这会导致 App 内注册流程断裂
- `email_whitelist_suffix` → 校验邮箱后缀

**登录成功后自动流程**：
1. 持久化 `auth_data`、`token`、`is_admin`
2. 调 `/user/getSubscribe` 取 `subscribe_url` + 其他用户数据
3. 调 `/user/comm/config` 取 `currency_symbol` 等运行时配置
4. `Profile.normal(label: siteName, url: Uri.parse(subscribeUrl).replace(queryParameters: {'flag': 'meta'}).toString())` → `putProfile()` → 设为当前 → 持久化 `v2board_profile_id`
5. 触发一次 `Profile.update()` 拉取节点
6. 导航到主页

### 6.2 用户中心 / 仪表盘

**对接 API**：

| 功能 | 方法 | 相对路径 |
|------|------|----------|
| 用户信息 | GET | `/user/info` |
| 用户统计 | GET | `/user/getStat`（unpaid_orders / open_tickets / invited_users） |
| 订阅信息 | GET | `/user/getSubscribe`（含全字段） |
| 运行时配置 | GET | `/user/comm/config`（货币符号等） |
| 修改资料 | POST | `/user/update`（仅自动续费/通知开关） |
| 修改密码 | POST | `/user/changePassword` |
| 重置订阅 UUID/Token | GET | `/user/resetSecurity` |
| 订阅安全详情 | GET | `/user/subscribeSecurity/info`（可选，WebView 内嵌） |
| 多设备会话 | GET | `/user/getActiveSession` |
| 踢除会话 | POST | `/user/removeActiveSession` |
| 兑换礼品卡 | POST | `/user/redeemgiftcard`（可选） |
| 登出 | - | 客户端清本地 + 调 `removeActiveSession`（失败不阻塞） |

**UI 设计**：
`UserDashboardView` 作为 userCenter 页面主体：
- 用户信息卡片（邮箱、套餐名、到期时间、设备数）
- 流量使用进度条（u + d / transfer_enable，从 getSubscribe 取）
- 余额 / 佣金余额（按 currency_symbol 显示）
- 在线设备数（alive_ip / device_limit）
- 暂停/封禁警示卡片（suspended / subscribe_ban 时）
- 快捷入口（套餐购买、我的订单、工单、邀请返利、订阅安全、修改密码）
- 重置订阅 / 退出登录按钮

**启动时封禁/暂停主动检测**：`checkLogin` 返回 `is_login=true` 后，必须立即调 `getSubscribe` 并检查 `banned`/`suspended` 字段。若 `banned=true`，弹出"账户已被封禁"对话框（不可关闭）并强制跳转登录页；若 `suspended=true`，在仪表盘显示醒目暂停卡片并限制订阅/购买功能，但不强制退出。此检测应在进入主页前完成，避免用户先看到主页再被 403 拦截。

**`changePassword` 成功后处理**：服务端会清除所有 session，客户端必须立即执行 `logoutAndCleanup()` 跳转登录页，不能等后续请求 401 才发现。

### 6.3 套餐 / 订单 / 支付

**对接 API**：

| 功能 | 方法 | 相对路径 |
|------|------|----------|
| 套餐列表 | GET | `/user/plan/fetch` |
| 套餐详情 | GET | `/user/plan/fetch?id=` |
| 优惠券校验 | POST | `/user/coupon/check` |
| 当前可用券 | POST | `/user/coupon/getAvailableCoupons` |
| 订单预览 | POST | `/user/order/preview` |
| 创建订单 | POST | `/user/order/save` |
| 结算 | POST | `/user/order/checkout` |
| 支付方式 | GET | `/user/order/getPaymentMethod` |
| 检查状态 | GET | `/user/order/check` |
| 订单详情 | GET | `/user/order/detail` |
| 订单列表 | GET | `/user/order/fetch` |
| 取消 | POST | `/user/order/cancel` |
| 充值套餐 | GET | `/user/order/rechargeInfo` |

**购买流程**：
```
PlanListView -> PlanDetailView
  -> 选择 period (month_price/quarter_price/...)
  -> 输入优惠券（可选） -> coupon/check
  -> order/preview 实时预览（original/coupon_discount/vip_discount/surplus/balance/pay_amount）
  -> order/save -> trade_no
  -> 选择 payment_method (getPaymentMethod)
  -> order/checkout
       -> type=-1: 余额支付完成，跳订单详情
       -> type=其他: 拿 data (URL/HTML/表单) 用 WebView 加载支付页面
  -> WebView 关闭后 order/check 轮询 status
       -> status=3: 支付成功，刷新 getSubscribe + Profile.update()
       -> status=2: 已取消
       -> 其他: 继续轮询/超时提示
```

**`order/checkout` 返回值补充**：
`{type, data}` 中 `type` 含义需在 EXECUTE 前从后端 `OrderService::checkout()` 确认完整枚举。目前已知的映射关系：
- `type = -1`：余额支付，已完成，无需 WebView
- `type = 0`：跳转支付 URL（data 为 URL 字符串，WebView 直接加载）
- `type = 1`：HTML 表单自动提交（data 为 HTML 字符串，WebView 加载 `data:text/html;charset=utf-8,{html}`）
- `type = 2`：扫码支付（data 为二维码 URL 或内容）
- 其他 type 值：待确认，WebView 通用兜底处理

**`subscribe_url` 安全拼接 `&flag=meta`**：
不要硬编码 `subscribe_url + "&flag=meta"`，应使用 Dart 的 `Uri` API 安全拼接：
```dart
final uri = Uri.parse(subscribeUrl).replace(
  queryParameters: {'flag': 'meta'},
);
final finalUrl = uri.toString();
```
此方式正确处理 `subscribe_url` 已有/无 query string 的所有边界情况。所有出现 `subscribe_url + "&flag=meta"` 的地方统一改用此方法。

### 6.4 工单系统

**对接 API**：

| 功能 | 方法 | 相对路径 |
|------|------|----------|
| 工单列表 | GET | `/user/ticket/fetch` |
| 工单详情 | GET | `/user/ticket/fetch?id=` |
| 创建工单 | POST | `/user/ticket/save`（subject + level[0/1/2] + message + 可选 images[]） |
| 回复工单 | POST | `/user/ticket/reply` |
| 关闭工单 | POST | `/user/ticket/close` |
| 上传图片 | POST | `/user/ticket/upload`（multipart `images[]`，单张 ≤5MB，最多 5 张） |

**关键实现点**：
- `level` 枚举：0=低 / 1=中 / 2=高
- 图片上传**先调 upload** 拿到 url[]，再把 url[] 作为 `images[]` 字段传给 save/reply
- **upload multipart 字段名**：后端 Laravel `Request` 验证中字段名需在 EXECUTE 前确认（可能是 `images`、`images[]`、或 `images[0]`/`images[1]`）。Dio `FormData` 构建方式取决于此：若为 `images[]`，则用 `formData.files.addAll(files.map((f) => MapEntry('images[]', f)))`；若为 `images`，则多文件需用 `images[0]`/`images[1]` 逐个添加。**建议在 EXECUTE 前查看后端 `TicketController::upload` 方法的 `$request->validate()` 规则确认精确字段名**
- **图片解析**：服务端将 `images[]` 拼接到 `message` 末尾形成 `\n\n[TICKET_IMAGES]\n{url}\n{url}` 格式，**客户端在 TicketDetailView 必须解析此分隔符**，把图片单独渲染到气泡中
- `is_me` 由服务端在详情接口已计算好，气泡左右对齐直接用
- 工单创建有限制：当前若有未关闭工单，无法新建（500 错误，按消息提示）

**UI 设计**：
- `TicketListView` —— 列表展示所有工单（标题、状态标签、最后回复时间），支持下拉刷新
- `TicketDetailView` —— 聊天气泡式，区分用户/客服，底部输入框 + 图片选择器（image_picker）+ 发送按钮
- `TicketCreateView` —— 主题、优先级、内容、图片选择，提交按钮

### 6.5 公告

**对接 API**：

| 功能 | 方法 | 相对路径 |
|------|------|----------|
| 公告列表 | GET | `/user/notice/fetch?current=&pageSize=` |
| 公告详情 | GET | `/user/notice/fetch?id=` |

**UI 设计**：
- `NoticeListView` —— 卡片式分页列表，新公告标记
- `NoticeDetailView` —— `flutter_widget_from_html` 渲染 HTML 内容

**新公告标记逻辑**：后端无 `is_new` 字段，需客户端自行实现。方案：在 `shared_preferences` 中持久化 key `v2board_last_notice_time`（最近一次查看公告列表的时间戳，String 类型 ISO8601 格式）。每次拉取公告列表时，`created_at > lastNoticeTime` 的公告标记为"NEW"徽章。用户点开公告详情时更新 `lastNoticeTime` 为该公告的 `created_at`（取两者较新的）。首次安装无 `lastNoticeTime` 时所有公告不标记为 NEW。

### 6.6 邀请返利与提现

**对接 API**：

| 功能 | 方法 | 相对路径 | 备注 |
|------|------|----------|------|
| 生成邀请码 | **GET** | `/user/invite/save` | **是 GET** |
| 邀请码列表 | GET | `/user/invite/fetch` | 响应 `data: {codes, stat[5]}` |
| 返利明细 | GET | `/user/invite/details` | 分页 `current` + `page_size` |
| 删除邀请码 | POST | `/user/invite/drop` | `id` |
| 申请提现 | POST | `/user/ticket/withdraw` | `withdraw_method` + `withdraw_account` |

**UI 设计**：
`InviteView`：
- 顶部统计卡片（已注册用户数、有效佣金、确认中佣金、佣金比例%、可用佣金）—— 注意 `stat` 是 5 位数组
- 邀请链接展示（一键复制：`{site_url}/#/register?invite_code={code}`）+ 生成新邀请码按钮
- 邀请码列表（含删除按钮）
- "申请提现"按钮 → `WithdrawDialog`：选择 `withdraw_method`（从 `user/comm/config` 的 `withdraw_methods` 取）+ 输入 `withdraw_account` → POST `ticket/withdraw`
- 返利明细 Tab（CommissionLog 列表分页）

`withdraw_close === 1` 时禁用提现按钮。

## 七、订阅桥接（subscribe_bridge.dart 核心实现）

### 7.1 流程

```
登录成功 / 手动刷新 / 定时刷新
  |
  v
GET /user/getSubscribe (Authorization: auth_data)
  --> 取 subscribe_url + 流量字段
  |
  v
首次：
  Profile.normal(
    label: "[V2B] {site_name}",
    url: Uri.parse(subscribe_url).replace(queryParameters: {'flag': 'meta'}).toString(),  // 安全拼接
  ).update()  --> 拉取并解析 subscription-userinfo --> saveFile
  --> putProfile()
  --> 持久化 profile_id 到 shared_preferences
  --> 设为当前 Profile

更新：
  从 v2board_profile_id 找到已有 Profile
  --> 复用 FlClash 现有 autoUpdateProfiles() 机制（20 分钟自动 update）
  --> 客户端代码无需做任何配置组装
```

### 7.2 流量数据双通道
- **被动**：`Profile.update()` 自动从订阅响应头 `subscription-userinfo` 解析并存储到 Profile 中（FlClash 现有机制）
- **主动**：`syncSubscribeInfo()` 每 5 分钟调 `getSubscribe`，更新 `userProvider` 的 SubscribeInfo（仪表盘读取此处获得精确实时数据，包含 alive_ip / suspend_info 等响应头里没有的字段）

**权威源定义**：仪表盘 UI **始终从 `userProvider`（主动通道）读取流量数据**。`subscription-userinfo` 被动通道的数据仅作为 Profile 自身的辅助展示（如订阅管理页），不用于仪表盘。两者数据不一致时以主动通道为准，因为 `getSubscribe` 返回的字段更完整（含 `alive_ip`、`suspend_info`、`reset_day` 等）且由服务端实时计算。

**轮询频率协调**：`syncSubscribeInfo()` 每 5 分钟、`autoUpdateProfiles()` 每 20 分钟，两者走不同的 Dio 实例（前者直连、后者可能走 Clash 代理），不会对后端 `subscribe_url` 产生重复请求。但 `getSubscribe` 的 API 请求需注意后端 `subscribeSecurity` 限流模块，若发现被限流则自适应降低频率。

### 7.3 退出登录处理
- **必须删除** V2Board Profile（通过 `v2board_profile_id` 定位）。原因：不删除的话，该 Profile 仍会参与 `autoUpdateProfiles()` 的 20 分钟自动更新，而此时 `auth_data` 已清除，虽然 `subscribe_url` 带 token 不需鉴权头，但更新会覆盖本地 YAML 缓存且消耗订阅拉取次数。删除后重新登录会重新创建 Profile，无需担心丢失
- 清除 `v2board_profile_id`、`v2board_auth_data`、`v2board_token`、`v2board_is_admin`
- 调 `removeActiveSession`（失败不阻塞）
- 跳转到 LoginView

## 八、数据流示意

### 启动配置拉取流程
```
App 启动 --> globalState.init()
  --> 读取本地缓存 OSS 配置
  +-- 有缓存 --> 解析 api[] + path --> remoteConfigProvider.status = ready
  |              后台异步请求 OSS URL 列表更新缓存
  |
  +-- 无缓存 --> remoteConfigProvider.status = loading
               依次请求内置 OSS URL 列表（每个 5 秒超时）
               +-- 某个成功 --> 解析 + Base64 解码 + 缓存到本地 --> status = ready
               +-- 全部失败 --> status = error --> ConfigErrorView
```

### 启动认证恢复流程
```
remoteConfigProvider.status == ready
  --> 读取本地 auth_data + token
  +-- 无 --> LoginView
  +-- 有 --> /user/checkLogin
            +-- is_login=true --> 并行 getSubscribe + comm/config
            |                  --> 检查 getSubscribe 返回的 banned/suspended 字段
            |                  --> banned=true? --> 弹窗提示 + 强制跳 LoginView
            |                  --> suspended=true? --> 进入主页（仪表盘显示暂停卡片）
            |                  --> 正常 --> 触发一次 syncSubscribeInfo --> HomePage
            +-- 401/false --> 清本地 --> LoginView
```

### 登录流程
```
用户输入邮箱密码
  --> authApi.login(email, password)
      URL = api[activeIndex] + path + '/passport/auth/login'
      Header: Content-Type: application/json
  --> 请求失败? --> 切换 api[next] 重试（面板地址故障转移）
  --> 响应 {data: {token, is_admin, auth_data}}
  --> authProvider 更新 + 持久化
  --> getSubscribe --> 取 subscribe_url 等
  --> Profile.normal(label, url=Uri.parse(subscribe_url).replace(queryParameters: {'flag': 'meta'})) --> update() --> putProfile()
  --> 持久化 profile_id
  --> 进入主页
```

### 工单查看流程
```
用户点击"工单"导航
  --> ticketProvider.fetch()
  --> ticketApi.fetch() (Authorization: auth_data)
  --> {data: [Ticket]}
  --> UI 渲染列表

用户点开某工单
  --> ticketApi.fetch(id: x)
  --> {data: Ticket{message: [TicketMessage{is_me, message}]}}
  --> 解析每条 message 中的 [TICKET_IMAGES] 协议 --> 拆出 text + images[]
  --> 气泡渲染（is_me 决定左/右）
```

## 九、风险点与注意事项

1. **API 请求与 OSS 请求均不走代理** —— V2Board API 请求和 OSS 配置拉取都必须直连，不能经过 Clash 代理端口。否则代理未启动时用户无法登录，也无法拉取配置。`v2board_api.dart` 和 `remote_config.dart` 中的 Dio 实例需使用独立 HttpClient，不受 `FlClashHttpOverrides.findProxy` 影响。

2. **订阅 URL 也要绕过 Clash 代理？** 不需要！订阅 URL 走 FlClash 现有 `_clashDio`（如果代理已启动）或直连 Dio（代理未启动）的逻辑，由 FlClash 自身处理，与 OSS 拉取路径分离。

3. **`Authorization` 头不带 `Bearer ` 前缀** —— V2Board 中间件直接读 header 原值。客户端 Dio 拦截器写法：
   ```dart
   options.headers['Authorization'] = authData;  // 不要写成 'Bearer $authData'
   ```

4. **JWT 无内建过期时间** —— 服务端会话由 `USER_SESSIONS` 缓存控制，通过 401 响应判断失效。客户端不能从 JWT 自行判断过期，必须依赖请求结果。

5. **OSS 配置安全性** —— Base64 编码 + `.yaml` 后缀只是基础混淆，非加密。如需更高安全性，可将整个 JSON 内容做 AES 加密，客户端内置解密密钥；或在 JSON 中加入 `sign` 字段用内置公钥验签。

6. **Token 安全存储** —— 当前方案使用 `shared_preferences`，桌面端安全性有限。如需更高安全性，可改用 `flutter_secure_storage`。

7. **修改版 V2Board 兼容性** —— 目标 V2Board 含大量扩展（Emby、SubscribeRule、SubscribeWatermark 等），但本方案只对接核心模块（认证 + 用户 + 套餐 + 订单 + 工单 + 公告 + 邀请），扩展模块全部走 WebView 或暂不集成。

8. **订阅冲突** —— 登录后自动添加的 V2Board Profile 与用户手动添加的 Profile 可能并存。通过 `v2board_profile_id` 持久化区分，且 label 加 `[V2B]` 前缀便于用户识别。

9. **subscribe_url 失效** —— 当用户手动 `resetSecurity` 重置 token、或服务端禁用了用户后，旧 `subscribe_url` 会拉取失败。客户端需要在 Profile 拉取失败时主动触发一次 `getSubscribe` 重新获取最新 URL，并 `updateProfile(url=newUrl)`。

10. **`flag=meta` 参数附加** —— 在 `subscribe_url` 后追加 `flag=meta` 时应使用 `Uri.parse(subscribeUrl).replace(queryParameters: {'flag': 'meta'})` 安全拼接，不要硬编码 `"&flag=meta"`。虽然 `subscribe_url` 通常已带 `?token=...&sign=...` 等参数，硬编码 `&` 恰好能工作，但防御性编程应使用 `Uri` API 处理所有边界情况。

11. **多设备会话** —— V2Board 支持多设备同时登录。客户端登出时 `removeActiveSession` 仅踢当前 session，不影响其他设备。

12. **OSS 源全部不可达** —— 提供手动输入面板地址作为兜底（ConfigErrorView），手动输入后持久化为 `v2board_manual_api_url`，后续启动优先使用并跳过 OSS 拉取。

13. **`changePassword` 后 session 全清** —— 服务端 `changePassword` 成功后会调用 `removeAllSession` 清除该用户所有 session。客户端必须在密码修改成功后立即执行 `logoutAndCleanup()` 跳转登录页，**不能等后续请求 401 才发现**。`changePassword` 的 UI 流程应提示用户"密码修改成功，请重新登录"。

14. **启动时封禁检测盲区** —— `checkLogin` 仅返回 `is_login`，不返回 `banned`/`suspended`。若用户已被封禁但 JWT 仍有效，`checkLogin` 会返回 `is_login=true`，但后续所有 user 接口返回 403。**必须在 `checkLogin` 成功后立即调 `getSubscribe` 检查封禁状态**，在进入主页前拦截。

15. **`invite/save` 是 GET 方法** —— REST 语义上 GET 应幂等，但此接口会生成新邀请码（非幂等）。Dio 默认 GET 不发 body，此接口确认无请求体。注意不要误用 POST。

16. **`getStat` 返回位置数组** —— 响应为 `[unpaid_orders, open_tickets, invited_users]` 位置数组，**极度脆弱**。后端增减字段或调换顺序会静默出错。模型层必须加防御性注释，且在解析时检查数组长度 >= 3。

17. **`checkout` 返回 type 值不完整** —— 目前仅确认 `type=-1`（余额支付），其他 type 值对 `data` 的格式影响未完全确认。EXECUTE 前需从后端 `OrderService::checkout()` 方法确认完整映射。

18. **`activeApiIndex` 冷启动超时** —— 若不持久化上次成功的 index，每次冷启动都先尝试 `api[0]`，若该域名已长期不可达则浪费 5 秒超时。已补充持久化方案（见 3.5 节）。

19. **Dio 实例与 `FlClashHttpOverrides` 的隔离时序** —— 独立 `HttpClient` 必须在 `FlClashHttpOverrides.setGlobal()` 调用前创建并绑定到 Dio 的 `httpClientAdapter`，否则可能被全局 `HttpOverrides` 覆盖而仍走代理。已补充具体做法（见 4.2 节）。

20. **API 版本兼容性** —— 后端 V2Board 升级可能导致字段增减或端点变化。当前无 API 版本协商机制。建议在 `guest/comm/config` 响应中预留 `api_version` 字段检测（若后端支持），客户端对关键字段做 null 安全访问（`field ?? defaultValue`），避免后端新增字段导致 JSON 解析崩溃。

---

# Implementation Checklist

## Phase 1 -- 基础设施（预估 3-4 天）
- [ ] 1. 创建 `lib/v2board/` 完整目录结构
- [ ] 2. 实现 `remote_config_model.dart`（freezed：`api: List<String>`、`path: String`、可选 `oss: List<String>`，含 Base64 解码方法）
- [ ] 3. 实现 `remote_config.dart`（OSS 多源拉取：内置 `kBuiltinOssUrls`、依次请求 + 5 秒超时、JSON 解析、Base64 解码、缓存比对、直连 Dio 实例）
- [ ] 4. 实现 `v2board_local_storage.dart`（统一 shared_preferences key 管理：oss_config / oss_urls / auth_data / token / is_admin / user_email / profile_id / manual_api_url / active_api_index / last_notice_time）
- [ ] 5. 实现 `remoteConfigProvider`（Riverpod，管理 loading/ready/error 状态、持有 api[] + path、`activeApiIndex` 故障转移、**持久化 activeApiIndex 到 shared_preferences**，启动时读取上次成功的 index）
- [ ] 6. 实现 `api_paths.dart`（所有相对路径常量）
- [ ] 7. 实现 `v2board_api.dart`（独立直连 Dio、Base URL 动态拼接、面板地址故障转移拦截器、认证拦截器（Authorization 不带 Bearer）、401/403/422/500 错误统一处理、错误解包。**关键**：使用独立 `HttpClient` 并强制 `findProxy` 返回直连，通过 `IOHttpClientAdapter` 注入到 Dio，不受 `FlClashHttpOverrides` 影响）
- [ ] 8. 实现 `api_response.dart` 与 `api_error.dart`（freezed）
- [ ] 9. 实现 `auth_api.dart`（login / register / forget / sendEmailVerify / checkLogin）
- [ ] 10. 实现 `auth.dart` 数据模型（AuthResponse 含 token + is_admin + auth_data）
- [ ] 11. 实现 `auth_provider.dart`（认证状态管理、token 持久化与恢复、checkLogin 自动校验）
- [ ] 12. 实现 `guest_api.dart`（guest/comm/config）+ `site_config.dart` 模型
- [ ] 13. 在 `pubspec.yaml` 中添加新依赖（webview_flutter / flutter_widget_from_html_core / cached_network_image / image_picker）

## Phase 2 -- 配置守卫与登录注册（预估 2-3 天）
- [ ] 14. 实现 `SplashView`（启动加载页，展示配置拉取进度）
- [ ] 15. 实现 `ConfigErrorView`（OSS 全部失败时手动输入面板地址兜底，持久化为 `v2board_manual_api_url`）
- [ ] 16. 实现 `LoginView` 页面 UI（站点名称从 site_config 读取）
- [ ] 17. 实现 `RegisterView` 页面 UI（注册开关、邮箱验证、邀请码强制由 site_config 控制；**reCAPTCHA 降级方案**：优先集成 `flutter_recaptcha_enterprise` 原生插件，不可行时降级为 WebView 承载整个注册页 `{apiUrl}/#/register`，不要仅提示用户去网页注册）
- [ ] 18. 实现 `ForgetPasswordView` 页面 UI
- [ ] 19. 在 `application.dart` 中集成三层守卫（配置加载状态 → 认证状态 → 主页）。**注意**：需先调研 `application.dart` 现有 `home` 赋值方式，三层守卫应在外层包裹而非直接替换原有 `home` 逻辑
- [ ] 20. 在 `globalState.init()` 中初始化 OSS 配置恢复 + 认证状态恢复 + 后台异步刷新 OSS 配置 + checkLogin 校验 + **checkLogin 成功后立即调 getSubscribe 检查 banned/suspended 封禁状态**

## Phase 3 -- 订阅桥接（预估 1 天）
- [ ] 21. 实现 `user_api.dart`（info / getStat / getSubscribe / update / changePassword / resetSecurity / comm/config / getActiveSession / removeActiveSession）
- [ ] 22. 实现 `user_info.dart`、`SubscribeInfo` 等模型（含 subscribe_url、suspend_info、alive_ip 等全字段）
- [ ] 23. 实现 `subscribe_bridge.dart`（登录后流程：getSubscribe → **使用 `Uri.parse(subscribeUrl).replace(queryParameters: {'flag': 'meta'})` 安全拼接 flag=meta** → Profile.normal → update() → putProfile() → 持久化 profile_id → 设为当前；定时 syncSubscribeInfo 每 5 分钟刷新流量到 userProvider。**退出登录时必须删除 V2Board Profile**）
- [ ] 24. `AppController` 增加 `loginAndAttachProfile` / `syncSubscribeInfo` / `logoutAndCleanup` / `checkBanStatus` / `handleChangePasswordSuccess` 方法。`checkBanStatus` 在 checkLogin 后调 getSubscribe 检查 banned/suspended；`handleChangePasswordSuccess` 在密码修改成功后立即执行 logoutAndCleanup 跳转登录页
- [ ] 25. `application.dart` 定时器加入 `syncSubscribeInfo()` 调用（与 autoUpdateProfiles 并列）

## Phase 4 -- 用户中心与仪表盘（预估 1-2 天）
- [ ] 26. 在 `PageLabel` 中添加 `userCenter` 枚举值
- [ ] 27. 实现 `user_provider.dart`（UserInfo + SubscribeInfo + UserCommConfig 合并）
- [ ] 28. 实现 `currency_text.dart` 组件（按 currency_symbol 显示金额）
- [ ] 29. 实现 `traffic_progress.dart` 组件
- [ ] 30. 实现 `UserDashboardView`（用户卡片、流量进度条、套餐信息、暂停/封禁警示、快捷入口、登出按钮）。**流量数据始终从 userProvider（主动通道）读取**，不以 Profile 的 subscription-userinfo 为准
- [ ] 31. 实现修改密码（**成功后立即调用 `handleChangePasswordSuccess` 强制登出跳转登录页**）、重置订阅、多设备会话子页面
- [ ] 32. 在 `navigation.dart` 中注册 `userCenter` 导航项
- [ ] 33. 补充 l10n 翻译

## Phase 5 -- 工单系统（预估 2 天）
- [ ] 34. 在 `PageLabel` 中添加 `tickets` 枚举值
- [ ] 35. 实现 `ticket.dart` 模型（含 `[TICKET_IMAGES]` 解析方法 → 拆为 text + images[]）
- [ ] 36. 实现 `ticket_api.dart`（fetch 含列表/详情双行为、save、reply、close、upload）。**EXECUTE 前需确认 upload 的 multipart 字段名**（查看后端 TicketController::upload 的 validate 规则）
- [ ] 37. 实现 `ticket_provider.dart`
- [ ] 38. 实现 `TicketListView`
- [ ] 39. 实现 `ticket_message_bubble.dart`（解析图片 + 区分 is_me）
- [ ] 40. 实现 `TicketDetailView`（聊天气泡 + 输入框 + image_picker 集成）
- [ ] 41. 实现 `TicketCreateView`（先 upload 拿 url，再 save）
- [ ] 42. 在 `navigation.dart` 中注册 `tickets` 导航项
- [ ] 43. （可选）Drift 新增工单缓存表，schemaVersion 升级到 2（采用 step-by-step migration 模式，预留后续升级口）

## Phase 6 -- 套餐 / 订单 / 支付（预估 2-3 天）
- [ ] 44. 实现 `plan.dart`、`order.dart`、`coupon.dart` 模型（含全部 period 字段）
- [ ] 45. 实现 `plan_api.dart`（fetch 含列表/详情）
- [ ] 46. 实现 `coupon_api.dart`（check / getAvailableCoupons）
- [ ] 47. 实现 `order_api.dart`（save / preview / checkout / check / detail / fetch / cancel / getPaymentMethod / rechargeInfo）。**EXECUTE 前需确认 checkout 返回的 type 完整枚举**（查看后端 OrderService::checkout）
- [ ] 48. 实现 `plan_provider.dart`、`order_provider.dart`
- [ ] 49. 实现 `plan_card.dart` + `PlanListView`
- [ ] 50. 实现 `PlanDetailView`（period 选择 + 优惠券 + preview 实时计算 + save → checkout）
- [ ] 51. 实现 `payment_webview.dart`（加载支付 URL/HTML，监听关闭后轮询 check）
- [ ] 52. 实现 `OrderListView`、`OrderDetailView`
- [ ] 52a. 确认后端 `OrderService::checkout()` 返回的 `type` 完整枚举及其 `data` 格式，更新 `payment_webview.dart` 的处理逻辑

## Phase 7 -- 公告与邀请返利（预估 1-2 天）
- [ ] 53. 实现 `notice.dart`、`invite.dart` 模型（InviteFetchResp.stat 解析 5 位数组）
- [ ] 54. 实现 `notice_api.dart`（fetch 含列表分页 + 详情）
- [ ] 55. 实现 `invite_api.dart`（save GET / fetch / details / drop / withdraw）
- [ ] 56. 实现 `notice_provider.dart`、`invite_provider.dart`
- [ ] 57. 实现 `NoticeListView` + `NoticeDetailView`（HTML 富文本）。**新公告标记**：用 `v2board_last_notice_time` 持久化上次查看时间，`created_at > lastNoticeTime` 的公告显示 NEW 徽章
- [ ] 58. 实现 `InviteView`（5 项统计卡片、邀请码列表、明细 Tab、提现按钮）
- [ ] 59. 实现 `WithdrawDialog`（withdraw_method 下拉 + withdraw_account 输入）
- [ ] 60. （可选）在 `PageLabel` 中添加 `notices` 独立导航；或合并到 userCenter 内子页
- [ ] 60a. 确认后端 `TicketController::upload` 的 multipart 字段名（`images` / `images[]` / `images[0]`），更新 `ticket_api.dart` 的 FormData 构建方式

## Phase 8 -- 打磨与测试（预估 2 天）
- [ ] 61. 全面的错误处理与边界情况覆盖（401 自动跳登录、403 封禁提示、422 表单错、500 友好消息）
- [ ] 62. 网络异常 / 服务器不可达 / OSS 全部失败的友好提示
- [ ] 63. Token 过期自动跳登录的完整测试
- [ ] 64. OSS 多源拉取的失败切换与缓存恢复测试
- [ ] 65. 面板地址故障转移测试（模拟第一个面板域名不通）
- [ ] 66. 订阅自动更新与流量同步测试
- [ ] 67. resetSecurity 后 subscribe_url 失效自动重新获取的测试
- [ ] 68. 工单 [TICKET_IMAGES] 协议解析与图片渲染测试
- [ ] 69. 订单 preview / checkout / WebView 支付 / check 轮询的完整链路测试
- [ ] 70. 多平台（Android/Windows/macOS/Linux）适配验证
- [ ] 71. 深色 / 浅色主题适配
- [ ] 72. l10n 中英文完整校验
- [ ] 73. `changePassword` 成功后自动登出并跳转登录页的完整测试
- [ ] 74. 启动时封禁检测测试（模拟 banned/suspended 用户，验证进入主页前被拦截）
- [ ] 75. 退出登录后 V2Board Profile 被正确删除、不再参与 autoUpdateProfiles 的测试
- [ ] 76. `subscribe_url` 安全拼接 `flag=meta` 的边界测试（URL 有/无 query string）
- [ ] 77. `invite/fetch` 返回 stat 位置数组的防御性解析测试
- [ ] 78. `site_config_provider` 刷新时机验证（进入注册页时刷新 guest config）

## Phase 9 -- 未来可扩展点（不在本期）
- 修改版扩展模块的 WebView 集成：`/user/redpacket/*`、`/user/emby/*`、`/user/jellyseerr/*`、`/user/subscribeRule/*`
- `/user/stat/*` 流量统计图表（独立页面）
- `/user/subscribeSecurity/info` 订阅安全详情页
- `/user/redeemgiftcard` 礼品卡兑换
- `/user/transfer` 佣金转余额
- `/user/getQuickLoginUrl` 快速登录 URL 分享
- `/user/compensateLogs` 补偿记录页面（归入用户中心子功能）
- API 版本兼容机制：监听 `guest/comm/config` 中预留的 `api_version` 字段，关键字段做 null 安全访问

**预估总工作量：14-19 天（单人全职开发）**
- 相比原方案 B（自建协议构建器，14-18 天），由于移除 600+ 行协议构建代码，订阅桥接从 4 天缩短到 1 天，多出来的工时分配给：preview 价格预览、coupon 校验、TICKET_IMAGES 解析、resetSecurity 失效重试、checkLogin 守卫、多设备会话管理等遗漏功能

---

## 附录 A：原方案 B（客户端自建协议构建器）-- 已弃用但保留作为备选

如果未来出现以下情况，可考虑回退到原方案 B：
- `subscribe_url` 不可用（如服务端关闭了订阅签名功能）
- 需要离线获取节点元数据（如做节点延迟测试 UI）
- 需要 100% 自定义客户端配置模板（不接受服务端的 SubscribeRule）

回退要点：
1. 新增 `server_api.dart`（调用 `/user/server/fetch`，处理 ETag + 304）
2. 新增 `clash_config_builder.dart`，需正确实现以下分支（参考 `D:\常用项目\v2board\app\Protocols\ClashMeta.php`）：
   - shadowsocks：含 SS2022 cipher 的 `serverKey:userKey` 密码格式 + obfs plugin（含 fallback）
   - vmess：tlsSettings/tls_settings 双命名兜底 + ECH + tcp/ws/grpc network
   - vless：Reality（tls==2）+ xhttp + encryption(mlkem768x25519plus) + ECH + flow + client-fingerprint
   - trojan：grpc + ws + ECH + sni 优先级
   - tuic：disable_sni / zero_rtt_handshake / udp_relay_mode / congestion_control / alpn=['h3']
   - hysteria：v1/v2 区分，端口逗号+横线解析（port/ports/mport），v1 的 up=down_mbps（保持服务端行为）
   - anytls：alpn=['h2','http/1.1'] + client-fingerprint='chrome'
   - v2node 内联：`item['type'] = item['protocol']` 解包后递归
   - hysteria2：独立 type，不通过 hysteria + version=2
3. 内置 ClashMeta 配置模板（从 `resources/rules/default.clash.yaml` 移植），含 proxy-groups + rules
4. 实现正则过滤的 proxy-groups 注入逻辑（不是简单追加）
5. ETag 缓存 + 304 跳过的增量更新

---

## 附录 B：22 处文档错漏修正记录（2026-04-26）

| # | 原文档错误 | 修正后 |
|---|----------|--------|
| 1 | POST /user/invite/save | **GET** /user/invite/save |
| 2 | GET /user/logout | 接口不存在，改为本地清除 + removeActiveSession |
| 3 | "撤回消息" /ticket/withdraw | 实为佣金提现，归到邀请返利模块 |
| 4 | 登录响应 `{token, auth_data}` | `{token, is_admin, auth_data}` |
| 5 | `Authorization: Bearer xxx` | `Authorization: xxx`（无 Bearer） |
| 6 | 节点 type 缺 `hysteria2` `v2node` | 已补 |
| 7 | getSubscribe 缺 subscribe_url | 已补，并改为方案 B' 核心数据源 |
| 8 | server/fetch 缺 unavailable_reason | 已补 |
| 9 | 端口范围字段名 `ports` | 应为 `mport`（hysteria 同时有 ports） |
| 10 | 工单 level 1/2/3 | 实为 0/1/2 |
| 11 | 工单消息字段 `content` | 实为 `message` |
| 12 | 工单图片直传 save | 应先 upload 再 save，且需解析 [TICKET_IMAGES] |
| 13 | invite/fetch 返回对象 | 实为 `{codes, stat[5位数组]}` |
| 14 | 缺 user/comm/config 接口 | 已补，是货币符号等的来源 |
| 15 | 缺 order/preview 接口 | 已补，购买流程必备 |
| 16 | 缺 order/rechargeInfo 接口 | 已补 |
| 17 | 缺 coupon/check 接口 | 已补 |
| 18 | 缺 checkLogin 接口 | 已补，启动时校验 token |
| 19 | 缺 resetSecurity 接口 | 已补 |
| 20 | order/save 返回订单对象 | 实为 `{data: trade_no}` |
| 21 | order/checkout 返回未说明 | 实为 `{type, data}`，type=-1 余额支付 |
| 22 | period 周期枚举 | 已列全 9 个 |

## 附录 C：二次审查补充修正记录（2026-04-28）

| # | 问题类别 | 修正内容 | 涉及章节 |
|---|---------|---------|----------|
| 1 | 架构 | `activeApiIndex` 增加持久化，避免冷启动每次先超时不可达地址 | 3.5 / Checklist #4 #5 |
| 2 | 架构 | 明确 Dio 与 `FlClashHttpOverrides` 隔离方案：独立 HttpClient + 强制 findProxy 直连 + IOHttpClientAdapter 注入 | 4.2 / Checklist #7 |
| 3 | 架构 | `application.dart` 入口守卫需先调研现有 home 赋值方式，外层包裹而非直接替换 | 5.3 / Checklist #19 |
| 4 | 流程 | `changePassword` 成功后服务端清所有 session，客户端必须立即自动登出 | 5.4 / 6.2 / Checklist #24 #31 |
| 5 | 流程 | 启动时 `checkLogin` 成功后需立即调 `getSubscribe` 检查 banned/suspended，进入主页前拦截 | 5.4 / 6.2 / Checklist #20 |
| 6 | 数据库 | Drift migration 改用 step-by-step 模式，预留后续升级口；缓存表增加 readAt 字段和失效策略 | 5.6 / Checklist #43 |
| 7 | UI | reCAPTCHA 降级方案改为：优先原生插件 -> 降级 WebView 承载注册页，不要仅提示用户去网页 | 6.1 / Checklist #17 |
| 8 | API | `order/checkout` 返回 type 值补充已知枚举（-1/0/1/2），EXECUTE 前需确认完整映射 | 6.3 / Checklist #47 #52a |
| 9 | API | `subscribe_url` 拼接 `flag=meta` 改用 `Uri.parse().replace(queryParameters:)` 安全拼接 | 6.3 / Checklist #23 |
| 10 | API | `ticket/upload` multipart 字段名需从后端确认，影响 FormData 构建方式 | 6.4 / Checklist #36 #60a |
| 11 | 数据 | 双通道流量数据明确权威源：仪表盘始终读 userProvider（主动通道），被动通道仅作 Profile 辅助 | 7.2 / Checklist #30 |
| 12 | 流程 | 退出登录时必须删除 V2Board Profile（否则仍参与 autoUpdate），已明确决策 | 7.3 / Checklist #23 |
| 13 | UI | 新公告标记逻辑：用 `last_notice_time` 持久化时间戳对比 `created_at` 判断 | 6.5 / Checklist #57 |
| 14 | 风险 | 新增风险项 13-20：changePassword session 清理、启动封禁盲区、invite/save GET 语义、getStat 位置数组、checkout type 不完整、activeApiIndex 冷启动、Dio 隔离时序、API 版本兼容 | 九 |
| 15 | 遗漏 | `compensateLogs` 标注"暂不集成"，归入 Phase 9 | API 表 / Phase 9 |
| 16 | 遗漏 | `site_config_provider` 刷新时机明确：启动一次 + 进入注册页刷新 guest + syncSubscribeInfo 顺带刷新 user | 目录结构说明 |
| 17 | 测试 | 补充 7 项测试：changePassword 自动登出、封禁检测、Profile 删除、URL 拼接、stat 解析、config 刷新 | Phase 8 Checklist #73-78 |

---

# Current Execution Step
> 尚未开始执行（已完成 RESEARCH + INNOVATE + PLAN 三阶段，等待用户确认进入 EXECUTE）

# Task Progress
（执行阶段逐步填充）

# Final Review
（审查阶段填充）
