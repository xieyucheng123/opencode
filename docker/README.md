# opencode-prod 部署（生产）

自研 opencode-tools 镜像（`stable` 标签，验证后手动前移），`serve --port 4097`，host 网络，`restart: unless-stopped`。

`opencode.jsonc` / `AGENTS.md` 已烘进镜像（见 `Dockerfile.tools`），部署目录只需涉密文件。

## 部署目录结构

```
deploy/
├── compose.yml          # 本模板
├── .env                 # 从 .env.example 复制后填值（600 权限，不进仓库）
└── config/
    └── home/
        ├── .aliyun/     # 阿里云凭证（只读挂载）
        └── .oci/        # OCI 凭证 + 私钥（只读挂载）
```

数据在命名卷 `prod-data`（会话 DB）、`prod-work`（/workspace）里，由 compose 自动创建。

## 启动 / 停止

```
cp docker/.env.example .env   # 填值，chmod 600 .env
docker compose up -d
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:4097/
docker compose down   # 停机（卷保留，数据不丢）
```

## .env（7 个 key）

- `LITELLM_BASE_URL` / `LITELLM_API_KEY`：模型网关
- `GH_TOKEN`：GitHub
- `OPENCODE_SERVER_PASSWORD`：Web 登录密码
- `CLOUDFLARE_API_TOKEN`
- `HCLOUD_AK` / `HCLOUD_SK`：华为云（entrypoint 内自动 configure）

## 备份 / 恢复（带历史）

```
docker compose down
docker run --rm -v opencode-prod_prod-data:/d -v ./backup:/b alpine tar czf /b/prod-data-$(date +%F).tgz -C /d .
docker run --rm -v opencode-prod_prod-work:/w -v ./backup:/b alpine tar czf /b/prod-work-$(date +%F).tgz -C /w .
# 恢复：先 up -d 建空卷，再解包进去，最后 restart
docker run --rm -v opencode-prod_prod-data:/d -v ./backup:/b alpine tar xzf /b/prod-data-XXX.tgz -C /d
docker compose restart
```

## 本机差异（compose.override.yml）

仓库是唯一源：`compose.yml` 与仓库保持完全一致，本机只用不改。机器特有的东西放同目录的 `compose.override.yml`（compose 自动合并），例如 digest pin、宿主机业务目录映射：

```
services:
  opencode-prod:
    image: swr.cn-north-9.myhuaweicloud.com/xieyucheng123/opencode-tools@sha256:<digest>
    volumes:
      - /root/workspace:/old-workspace
```

## 跟版

- 日常：`compose.yml` 用 `stable` 标签，`docker compose pull && docker compose up -d`。
- 生产 pin：在 `image:` 后加 `@sha256:<digest>`，`up -d` 即可。`stable` 标签只在验证后手动前移。
