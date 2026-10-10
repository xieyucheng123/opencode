#!/bin/sh
# hw21 宿主机网络持久化恢复脚本（开机恢复 + reconciler 兜底可调用）
# 覆盖：1) POSTROUTING MASQUERADE -o tailscale0（172.16/12 + 192.168/16）
#       2) pref-500 直连规则（ip rule），来源 ip-rules.snapshot.txt（126 条，2026-10-10 实测快照）
# 幂等：已存在则跳过；iptables 缺失则按 nft/提示降级，绝不报错中断 boot。
# 部署（宿主机一次性，需 host shell；本仓库只收录脚本，不含 secrets）：
#   sudo install -m 0755 restore-host-network.sh /usr/local/bin/restore-host-network.sh
#   # cron @reboot（Alpine busybox crond / OpenRC 均可）：
#   #   @reboot /usr/local/bin/restore-host-network.sh >>/var/log/host-network.log 2>&1
#   # systemd 备选见 host-network.service（同目录）
set -eu
LOG="${LOG:-/var/log/host-network.log}"
SNAP_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
SNAP="${SNAP_DIR}/ip-rules.snapshot.txt"

log() { echo "$(date -u +%FT%TZ) $*" | tee -a "$LOG" 2>/dev/null || echo "$*"; }

# --- 1) SNAT MASQUERADE（幂等：-C 存在则跳过） ---
if command -v iptables >/dev/null 2>&1; then
  for SRC in 172.16.0.0/12 192.168.0.0/16; do
    if iptables -t nat -C POSTROUTING -s "$SRC" -o tailscale0 -j MASQUERADE 2>/dev/null; then
      log "masq exists: $SRC -> tailscale0"
    else
      iptables -t nat -A POSTROUTING -s "$SRC" -o tailscale0 -j MASQUERADE
      log "masq added: $SRC -> tailscale0"
    fi
  done
else
  log "WARN: iptables not found on host, skip MASQUERADE (need iptables package on host, NOT in containers)"
fi

# --- 2) pref-500 直连 ip rule（幂等：逐条 `ip rule add` 前先查快照行是否已存在） ---
if [ -f "$SNAP" ]; then
  # 快照首列为 pref（如 500:），去掉冒号后重放 `ip rule add pref <prio> ...`
  # 0/local、32766/32767、tailscale fwmark（5210/5230/5250/5270）为系统/daemon 自带，跳过只补 500。
  grep -E '^500:' "$SNAP" | sed 's/^500:[[:space:]]*//' | while IFS= read -r SPEC; do
    [ -z "$SPEC" ] && continue
    # 已存在则跳过（按目标前缀匹配，避免重复）
    DST="$(echo "$SPEC" | sed -n 's/.*to \([^ ]*\).*/\1/p')"
    if [ -n "$DST" ] && ip rule show | grep -q "to $DST .*lookup main"; then
      : # exists
    else
      # shellcheck disable=SC2086
      ip rule add pref 500 $SPEC 2>>"$LOG" || log "rule add failed: $SPEC"
    fi
  done
  log "ip rules reconciled from snapshot ($(grep -c -E '^500:' "$SNAP") pref-500 entries)"
else
  log "WARN: snapshot not found: $SNAP, skip ip rules"
fi

log "restore done"
