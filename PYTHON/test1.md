





### 巡检脚本

```py
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
文件名: system_check.py
用途  : Linux 服务器基础资源巡检（CPU / 内存 / 磁盘 / inode / 负载）
依赖  : 仅使用 Python3 标准库，无需 pip 安装任何包
用法  :
    python3 system_check.py                      # 巡检一次并打印结果
    python3 system_check.py --json               # 以 JSON 输出，方便对接监控平台
    python3 system_check.py --log /var/log/syscheck.log   # 同时写日志文件
退出码:
    0 = 全部正常
    1 = 存在超过阈值的告警项（方便配合 cron / 告警平台使用）

Crontab 示例（每 5 分钟巡检一次，有告警才发邮件）:
    */5 * * * * /usr/bin/python3 /opt/scripts/system_check.py \
        || echo "服务器资源告警，请登录检查" | mail -s "告警" ops@example.com
"""

import argparse
import json
import logging
import os
import shutil
import socket
import sys
import time

# ==================== 配置区：按需修改 ====================
THRESHOLDS = {
    "cpu": 80.0,          # CPU 使用率告警阈值（%）
    "mem": 85.0,          # 内存使用率告警阈值（%）
    "disk": 85.0,         # 磁盘使用率告警阈值（%）
    "inode": 85.0,        # inode 使用率告警阈值（%）
    "load_per_core": 1.5, # 单核负载告警阈值（load1 / 核数）
}
CPU_SAMPLE_INTERVAL = 1.0          # CPU 采样间隔（秒），太短不准，太长变慢
DISK_MOUNTS = ["/", "/data"]       # 需要巡检的挂载点，不存在的会自动跳过
# =========================================================

logger = logging.getLogger("syscheck")


def color(text, code, enable=True):
    """给终端输出加颜色，非 TTY（如写文件/管道）时自动不加，避免乱码。"""
    return f"\033[{code}m{text}\033[0m" if enable else str(text)


# ---------------------- 采集函数 ----------------------

def read_cpu_times():
    """读取 /proc/stat 第一行，返回 (CPU 累计总时间片, 空闲时间片)。"""
    with open("/proc/stat", "r") as f:
        line = f.readline()  # 形如: cpu  12345 678 9012 345678 ...
    parts = [int(x) for x in line.split()[1:]]
    # 字段依次为: user nice system idle iowait irq softirq steal ...
    idle = parts[3] + (parts[4] if len(parts) > 4 else 0)  # idle + iowait
    return sum(parts), idle


def get_cpu_usage(interval=CPU_SAMPLE_INTERVAL):
    """两次采样求差值，算出这段时间内的 CPU 使用率（%）。"""
    total1, idle1 = read_cpu_times()
    time.sleep(interval)                       # 间隔采样才能反映"当前"使用率
    total2, idle2 = read_cpu_times()
    total_delta = total2 - total1
    if total_delta <= 0:
        return 0.0
    idle_delta = idle2 - idle1
    return round((1 - idle_delta / total_delta) * 100, 2)


def get_mem_usage():
    """读取 /proc/meminfo，返回 (使用率%, 总内存MB, 已用MB)。"""
    info = {}
    with open("/proc/meminfo", "r") as f:
        for line in f:
            key, val = line.split(":", 1)
            info[key.strip()] = int(val.split()[0])   # 单位 KB

    total = info["MemTotal"]
    # MemAvailable 是内核评估的"可用内存"（3.14+），比 MemFree 准确得多
    available = info.get("MemAvailable") or (
        info.get("MemFree", 0) + info.get("Buffers", 0) + info.get("Cached", 0)
    )
    used = total - available
    percent = round(used / total * 100, 2) if total else 0.0
    return percent, round(total / 1024, 1), round(used / 1024, 1)


def get_disk_usage(mounts):
    """遍历挂载点，返回每个挂载点的容量使用率与 inode 使用率。"""
    results = []
    for mnt in mounts:
        if not os.path.exists(mnt):     # 挂载点不存在就跳过（兼容不同机器）
            continue
        usage = shutil.disk_usage(mnt)
        disk_pct = round(usage.used / usage.total * 100, 2) if usage.total else 0.0

        st = os.statvfs(mnt)            # 用 statvfs 拿 inode 信息
        inode_pct = (
            round((st.f_files - st.f_ffree) / st.f_files * 100, 2) if st.f_files else 0.0
        )

        results.append({
            "mount": mnt,
            "disk_percent": disk_pct,
            "total_gb": round(usage.total / 1024 ** 3, 2),
            "used_gb": round(usage.used / 1024 ** 3, 2),
            "inode_percent": inode_pct,
        })
    return results


def get_load():
    """获取系统负载，并换算成"单核负载"便于跨机器比较。"""
    load1, load5, load15 = os.getloadavg()
    cores = os.cpu_count() or 1
    return {
        "load1": round(load1, 2),
        "load5": round(load5, 2),
        "load15": round(load15, 2),
        "cores": cores,
        "load_per_core": round(load1 / cores, 2),
    }


# ---------------------- 主流程 ----------------------

def main():
    parser = argparse.ArgumentParser(description="Linux 服务器基础资源巡检")
    parser.add_argument("--json", action="store_true", help="以 JSON 格式输出")
    parser.add_argument("--log", metavar="FILE", help="把巡检结果写入日志文件")
    parser.add_argument("--interval", type=float, default=CPU_SAMPLE_INTERVAL,
                        help="CPU 采样间隔秒数，默认 1.0")
    args = parser.parse_args()

    # 日志只写文件，避免污染 --json 的标准输出
    if args.log:
        logging.basicConfig(
            filename=args.log,
            level=logging.INFO,
            format="%(asctime)s [%(levelname)s] %(message)s",
            encoding="utf-8",
        )

    hostname = socket.gethostname()
    alerts = []   # 收集所有告警描述，最后据此决定退出码

    # ---- 采集 ----
    cpu_pct = get_cpu_usage(args.interval)
    mem_pct, mem_total, mem_used = get_mem_usage()
    disks = get_disk_usage(DISK_MOUNTS)
    load = get_load()

    # ---- 阈值判断 ----
    if cpu_pct >= THRESHOLDS["cpu"]:
        alerts.append(f"CPU 使用率 {cpu_pct}% 超过阈值 {THRESHOLDS['cpu']}%")

    if mem_pct >= THRESHOLDS["mem"]:
        alerts.append(f"内存使用率 {mem_pct}% 超过阈值 {THRESHOLDS['mem']}%")

    for d in disks:
        if d["disk_percent"] >= THRESHOLDS["disk"]:
            alerts.append(
                f"磁盘 {d['mount']} 使用率 {d['disk_percent']}% 超过阈值 {THRESHOLDS['disk']}%"
            )
        if d["inode_percent"] >= THRESHOLDS["inode"]:
            alerts.append(
                f"inode {d['mount']} 使用率 {d['inode_percent']}% 超过阈值 {THRESHOLDS['inode']}%"
            )

    if load["load_per_core"] >= THRESHOLDS["load_per_core"]:
        alerts.append(
            f"单核负载 {load['load_per_core']} 超过阈值 {THRESHOLDS['load_per_core']}"
        )

    # ---- 输出 ----
    if args.json:
        # JSON 模式：结构化输出，方便被 Zabbix / 自研平台解析
        print(json.dumps({
            "hostname": hostname,
            "timestamp": int(time.time()),
            "cpu_percent": cpu_pct,
            "mem_percent": mem_pct,
            "mem_total_mb": mem_total,
            "mem_used_mb": mem_used,
            "disks": disks,
            "load": load,
            "alerts": alerts,
            "status": "ALERT" if alerts else "OK",
        }, ensure_ascii=False, indent=2))
    else:
        # 人类可读模式
        is_tty = sys.stdout.isatty()

        def mark(ok):
            return color("[OK]  ", "32", is_tty) if ok else color("[ALERT]", "31", is_tty)

        print(f"===== {hostname} 巡检报告 {time.strftime('%Y-%m-%d %H:%M:%S')} =====")
        print(f"CPU 使用率 : {cpu_pct:>6.2f}%  {mark(cpu_pct < THRESHOLDS['cpu'])}")
        print(f"内存使用率 : {mem_pct:>6.2f}%  "
              f"(已用 {mem_used}MB / 共 {mem_total}MB)  {mark(mem_pct < THRESHOLDS['mem'])}")
        for d in disks:
            print(f"磁盘 {d['mount']:<6}: {d['disk_percent']:>6.2f}%  "
                  f"(已用 {d['used_gb']}GB / 共 {d['total_gb']}GB)  "
                  f"inode {d['inode_percent']:.2f}%  "
                  f"{mark(d['disk_percent'] < THRESHOLDS['disk'] and d['inode_percent'] < THRESHOLDS['inode'])}")
        print(f"系统负载   : {load['load1']} / {load['load5']} / {load['load15']} "
              f"({load['cores']} 核, 单核 {load['load_per_core']})  "
              f"{mark(load['load_per_core'] < THRESHOLDS['load_per_core'])}")

        if alerts:
            print("-" * 50)
            for a in alerts:
                print(color(f"⚠ 告警: {a}", "31", is_tty))

    # ---- 写日志 ----
    if args.log:
        for a in alerts:
            logger.warning(a)
        logger.info(
            f"巡检完成: cpu={cpu_pct}% mem={mem_pct}% load1={load['load1']} "
            f"disks={[d['disk_percent'] for d in disks]} alerts={len(alerts)}"
        )

    # 有告警返回 1，让 cron / 监控平台能感知异常
    return 1 if alerts else 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as e:      # 脚本自身出错（如 /proc 读不到）用退出码 2 区分
        print(f"脚本执行异常: {e}", file=sys.stderr)
        sys.exit(2)
```

