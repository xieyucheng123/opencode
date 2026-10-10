# hw21 宿主机网络持久化（SNAT + pref-500 直连）

现状（2026-10-10 实测）：`POSTROUTING MASQUERADE -o tailscale0`（`172.16/12` + `192.168/16`）
与 `pref-500 … lookup main` 直连规则（快照 126 条，`ip-rules.snapshot.txt`）均为**临时规则，重启丢失**。
本目录将其收进仓库走流水线（铁律：环境变更必须进镜像/仓库流水线，禁止宿主机手改黑户）。

## 文件

- `restore-host-network.sh`：幂等恢复脚本（MASQUERADE `-C` 检查 + `ip rule` 按快照补齐 pref-500）。
- `ip-rules.snapshot.txt`：`ip rule show` 快照（2026-10-10，含 tailscale fwmark 5210/5230/5250/5270，
  脚本只重放 pref-500，系统/local 与 daemon 规则跳过）。
- `host-network.service`：systemd 开机恢复备选。
- 注意：本容器内无 `iptables` 二进制（`iptables: not found`，按铁律禁止容器内手装），
  live MASQUERADE 条目无法在此容器内 `iptables -S` 直读；SNAT 规格来自任务书
  （`-o tailscale0` + `172.16/12` + `192.168/16`），脚本在**宿主机**上有 iptables 时才执行。

## 宿主机部署（一次性，需 host shell；不碰在线 runner 容器）

```sh
# 1. 安装脚本
sudo install -m 0755 docker/host-network/restore-host-network.sh /usr/local/bin/restore-host-network.sh
# 快照同目录可查（脚本默认找自身目录下的 ip-rules.snapshot.txt；若只装单个脚本，
#  把 ip-rules.snapshot.txt 一并放到 /usr/local/bin/ 或改 SNAP 路径）
sudo cp docker/host-network/ip-rules.snapshot.txt /usr/local/bin/ip-rules.snapshot.txt

# 2a. cron @reboot（Alpine/busybox crond 通用，与现有 `*/15` reconciler 共存，别删 reconciler）
(crontab -l 2>/dev/null; echo "@reboot /usr/local/bin/restore-host-network.sh >>/var/log/host-network.log 2>&1") | crontab -

# 2b. systemd 备选（有 systemd 的机器）
sudo cp docker/host-network/host-network.service /etc/systemd/system/host-network.service
sudo systemctl daemon-reload && sudo systemctl enable --now host-network.service
```

## 与现有 reconciler 的关系

- `/root/gh-reconcile/reconcile.sh`（cron 每 15 分钟）是 API 侧 reconciler，动网络前先看其日志；
  本脚本只做**开机/兜底恢复**，不替代它，不抢它的 CIDR/规则管理权。
- `tailscale0` 设备需先 up（tailscaled 启动后），脚本由 `@reboot` + service `After=tailscaled` 保证顺序；
  MASQUERADE 依赖 `tailscale0` 存在，若设备未就绪脚本会打 WARN 日志，待 daemon 起后由 reconciler 周期补齐。

## 验证

```sh
iptables -t nat -S POSTROUTING | grep tailscale0   # 期望两条 MASQUERADE
ip rule show | grep -c "^500:"                    # 期望与快照 pref-500 条数一致
```
