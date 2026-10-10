# gh-runners compose 切换（digest pin，不动在线容器）

铁律：改 compose 前先备份 live 文件；不要 `docker exec` 进在线的 3 个 runner 容器；
不要 `docker compose down` 重建在线容器——新镜像就绪后由宿主机维护窗口逐个重建，
本仓库只给 pin 片段。

## 备份（宿主机执行）

```sh
cp /root/stacks/gh-runners/compose.yml /root/stacks/gh-runners/compose.yml.bak-$(date +%F-%H%M)
```

## 切换（把 `image:` 从 stock/旧 tag 改为本次 CI 产出的 digest）

CI（`runner-image` workflow）每次推送 `:<version>` + `:stable` + `:latest` 三 tag 同 digest，
Summary 里会给出 digest。compose 里三处 service 统一改为：

```yaml
services:
  gh-runner-linkseek:
    image: swr.cn-north-9.myhuaweicloud.com/xieyucheng123/gh-runner@sha256:<runner-image workflow Summary 中的 digest>
  gh-runner-guard:
    image: swr.cn-north-9.myhuaweicloud.com/xieyucheng123/gh-runner@sha256:<同上>
  gh-runner-oci:
    image: swr.cn-north-9.myhuaweicloud.com/xieyucheng123/gh-runner@sha256:<同上>
# GHCR 同 digest 备选（需先 docker login ghcr.io）：
#   image: ghcr.io/xieyucheng123/gh-runner@sha256:<同上>
```

`stable` 标签只在 `test-runner` 回归 + guard/oci 真实 job 绿灯后手动前移（与 opencode-tools 同流程）。

## 重建（维护窗口，逐个来）

```sh
docker compose pull && docker compose up -d <name>
gh api repos/xieyucheng123/oci-ops/actions/runners --jq '.runners[] | "\(.name) \(.status)"'
gh api repos/link-seek/guard-rules/actions/runners --jq '.runners[] | "\(.name) \(.status)"'
```
