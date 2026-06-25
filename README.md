# Phanpy · Recursion-Link

[![构建状态](https://crow-ci.goba.ip-dynamic.org/api/v1/badges/8/status.svg?branch=pages)](https://crow-ci.goba.ip-dynamic.org/kwfcfc/phanpy)

本仓库用于自托管部署 [Phanpy](https://github.com/cheeaun/phanpy) ——一个优雅的 Mastodon / GoToSocial 网页客户端。

本分支不包含应用源码:Crow CI 会从上游克隆源码、注入本站配置后用 npm 构建,再通过 wrangler 上传到 Cloudflare Pages。

## 部署信息

| 项目 | 值 |
|------|-----|
| 上游项目 | [`cheeaun/phanpy`](https://github.com/cheeaun/phanpy)(`production` 分支) |
| 后端实例 | `social.recursion-link.eu.org`(GoToSocial) |
| 客户端地址 | <https://phanpy.recursion-link.eu.org> |
| 登录方式 | 默认直连本站实例,认证由实例侧 Rauthy (OIDC) 处理 |
| 界面语言 | 跟随浏览器,回落英语 |

## 构建流程

构建配置见 [`.crow.jsonnet`](./.crow.jsonnet),步骤为:

1. `clone-upstream` — 浅克隆上游 Phanpy 指定分支
2. `build` — `npm ci && npm run build`,注入 `PHANPY_*` 环境变量
3. `deploy` — `wrangler pages deploy` 上传 `dist/` 到 Cloudflare Pages

升级到新版本时,只需修改 `.crow.jsonnet` 里的 `upstreamRef` 一行。
