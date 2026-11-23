> 运维常用 Shell 脚本
> 建议先 `chmod +x script.sh`，在测试环境验证后再上生产。
------

## 1. 系统巡检脚本

**用途**：一条命令查看负载、内存、磁盘、CPU Top 进程和失败服务。
**用法**：`./sys_check.sh`

```bash
#!/bin/bash
set -euo pipefail

echo "===== $(date '+%F %T') ====="
echo "--- uptime ---"
uptime

echo "--- memory ---"
free -h

echo "--- disk ---"
df -hT -x tmpfs -x devtmpfs

echo "--- top cpu ---"
ps -eo pid,comm,%cpu,%mem --sort=-%cpu | head -n 6

echo "--- failed services ---"
systemctl --failed --no-pager || true
```

**注意**：`df -hT` 在不同发行版输出列略有差异；只做人工巡检，不适合作为严格监控。

------

## 2. 磁盘使用率告警

**用途**：检查本地文件系统，使用率超过阈值时输出告警并写日志。
**用法**：`./disk_alert.sh [阈值]`，默认 80。

```bash
#!/bin/bash
set -euo pipefail

THRESHOLD=${1:-80}
LOG=/var/log/disk_alert.log

if ! [[ "$THRESHOLD" =~ ^[0-9]+$ ]]; then
    echo "Usage: $0 [threshold]" >&2
    exit 2
fi

df -P -l | awk -v t="$THRESHOLD" 'NR > 1 {
    usage = $5
    gsub("%", "", usage)
    if (usage + 0 >= t) print $6, usage
}' | while read -r mount usage; do
    echo "$(date '+%F %T') ALERT: $mount usage=${usage}%" | tee -a "$LOG"
done
```

**注意**：阈值建议 80～90；只检查本地文件系统，NFS 等网络挂载需单独处理。

------

## 3. 服务健康检查与重启

**用途**：检查 systemd 服务是否 active，未运行则尝试重启并记录日志。
**用法**：`./check_service.sh nginx`

```bash
#!/bin/bash
set -euo pipefail

SERVICE=${1:?Usage: $0 <service>}
LOG=/var/log/check_service.log

if systemctl is-active --quiet "$SERVICE"; then
    echo "$(date '+%F %T') $SERVICE is running" >> "$LOG"
    exit 0
fi

echo "$(date '+%F %T') $SERVICE is down, restarting" >> "$LOG"
if systemctl restart "$SERVICE"; then
    echo "$(date '+%F %T') $SERVICE restarted" >> "$LOG"
else
    echo "$(date '+%F %T') $SERVICE restart failed" >> "$LOG"
    exit 1
fi
```

**注意**：不要对数据库等有状态服务盲目自动重启；建议先做健康检查，再决定是否重启。

------

## 4. 端口存活检查

**用途**：用 `nc` 连续探测目标端口，三次都失败才判定不可达。
**用法**：`./check_port.sh 192.168.1.20 3306`

```bash
#!/bin/bash
set -euo pipefail

HOST=${1:?Usage: $0 <host> <port>}
PORT=${2:?Usage: $0 <host> <port>}
LOG=/var/log/check_port.log

for i in 1 2 3; do
    if nc -z -w 2 "$HOST" "$PORT" >/dev/null 2>&1; then
        echo "$(date '+%F %T') $HOST:$PORT ok" >> "$LOG"
        exit 0
    fi
    sleep 1
done

echo "$(date '+%F %T') $HOST:$PORT unreachable" >> "$LOG"
exit 1
```

**注意**：`nc` 需要支持 `-z`；没有该命令时可用 `bash /dev/tcp` 或 `telnet` 替代。

------

## 5. 目录备份与清理

**用途**：把指定目录打包到备份目录，并删除 7 天前的同名备份。
**用法**：`./backup_dir.sh /data/app /backup`

```bash
#!/bin/bash
set -euo pipefail

SRC=${1:?Usage: $0 <src-dir> [dest-dir]}
DST=${2:-/backup}
KEEP=7
ts=$(date '+%F_%H%M%S')
name=$(basename "$SRC")
archive="$DST/${name}_${ts}.tar.gz"

mkdir -p "$DST"
tar -czf "$archive" -C "$(dirname "$SRC")" "$name"
find "$DST" -type f -name "${name}_*.tar.gz" -mtime +"$KEEP" -delete

echo "backup ok: $archive"
```

**注意**：备份前确认磁盘空间；重要数据建议异地保存，并定期做恢复演练。

------

## 6. 过期日志清理

**用途**：删除指定目录下超过 N 天的 `.log` 文件，并记录删除数量。
**用法**：`./clean_logs.sh /var/log/app 7`

```bash
#!/bin/bash
set -euo pipefail

DIR=${1:?Usage: $0 <log-dir> [days]}
DAYS=${2:-7}
LOG=/var/log/clean_logs.log

[ -d "$DIR" ] || { echo "no such dir: $DIR" >&2; exit 1; }

count=$(find "$DIR" -type f -name '*.log' -mtime +"$DAYS" -print -delete | wc -l)
echo "$(date '+%F %T') dir=$DIR days=$DAYS deleted=$count" >> "$LOG"
```

**注意**：第一次执行建议先去掉 `-delete` 只看列表；不要对 `/` 直接跑无差别删除。

------

## 7. 批量创建用户

**用途**：从文件逐行读取用户名，批量创建用户并生成随机密码。
**用法**：`./create_users.sh users.txt`

```bash
#!/bin/bash
set -euo pipefail

INPUT=${1:?Usage: $0 <user-list-file>}
PASS_FILE=/root/user_passwords.txt

[ -r "$INPUT" ] || { echo "cannot read $INPUT" >&2; exit 1; }

while IFS= read -r user || [ -n "$user" ]; do
    [ -z "$user" ] && continue

    if id "$user" >/dev/null 2>&1; then
        echo "skip: $user exists"
        continue
    fi

    pass=$(openssl rand -base64 12)
    useradd -m -s /bin/bash "$user"
    echo "$user:$pass" | chpasswd
    echo "$user $pass" >> "$PASS_FILE"
done < "$INPUT"

chmod 600 "$PASS_FILE"
```

**注意**：密码文件权限必须是 `600`；生产环境建议接入 LDAP/SSO，并强制首次登录改密。

------

## 8. 目录同步

**用途**：用 `rsync` 把源目录同步到本地或远程目标，排除常见目录。
**用法**：`./sync_files.sh /data/web /backup/web` 或 `./sync_files.sh /data/web user@host:/backup/web`

```bash
#!/bin/bash
set -euo pipefail

SRC=${1:?Usage: $0 <src-dir> <dest>}
DST=${2:?Usage: $0 <src-dir> <dest>}
LOG=/var/log/sync_files.log

rsync -avz --delete \
    --exclude='.git' \
    --exclude='node_modules' \
    "$SRC"/ "$DST"/ >> "$LOG" 2>&1

echo "$(date '+%F %T') sync ok: $SRC -> $DST" >> "$LOG"
```

**注意**：`--delete` 会删除目标端多余文件；远程同步前先配置 SSH 免密，并确认目标路径。

------

## 9. 进程监控与拉起

**用途**：检查指定进程是否存在，不存在时尝试通过 systemd 拉起。
**用法**：`./monitor_process.sh nginx`

```bash
#!/bin/bash
set -euo pipefail

NAME=${1:?Usage: $0 <process-name>}
LOG=/var/log/monitor_process.log

if pgrep -x "$NAME" >/dev/null 2>&1; then
    exit 0
fi

echo "$(date '+%F %T') $NAME not running" >> "$LOG"
if systemctl restart "$NAME" 2>/dev/null; then
    echo "$(date '+%F %T') $NAME restarted by systemd" >> "$LOG"
else
    echo "$(date '+%F %T') $NAME restart failed" >> "$LOG"
    exit 1
fi
```

**注意**：`pgrep -x` 匹配进程名，不一定等于 systemd 服务名；两者不一致时改用 `systemctl is-active`。

------

## 10. HTTPS 证书过期检查

**用途**：读取目标站点证书到期时间，剩余天数低于阈值时告警。
**用法**：`./check_cert.sh www.example.com [端口]`

```bash
#!/bin/bash
set -euo pipefail

HOST=${1:?Usage: $0 <host> [port]}
PORT=${2:-443}
WARN_DAYS=30

cert=$(echo | timeout 5 openssl s_client -connect "$HOST:$PORT" -servername "$HOST" 2>/dev/null)
end_date=$(echo "$cert" | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)

[ -n "$end_date" ] || { echo "cannot get certificate from $HOST:$PORT" >&2; exit 1; }

end_ts=$(date -d "$end_date" +%s)
now_ts=$(date +%s)
days=$(( (end_ts - now_ts) / 86400 ))

echo "$HOST:$PORT expires in $days days ($end_date)"
if [ "$days" -lt "$WARN_DAYS" ]; then
    echo "WARNING: certificate expires soon" >&2
    exit 1
fi
```

**注意**：`date -d` 是 GNU 写法；证书链不完整时先补全中间证书，再排查客户端信任问题。

-----

## 11. 日志关键字告警

**用途**：实时跟踪日志，匹配 `ERROR`、`Exception` 等关键字并记录。
**用法**：`./log_alert.sh /var/log/app.log 'ERROR|Exception'`

```bash
#!/bin/bash
set -euo pipefail

LOG_FILE=${1:?Usage: $0 <log-file> [pattern]}
PATTERN=${2:-'ERROR|Exception'}
OUT=/var/log/log_alert.out

[ -r "$LOG_FILE" ] || { echo "cannot read $LOG_FILE" >&2; exit 1; }

tail -F -n 0 "$LOG_FILE" \
    | grep --line-buffered -E "$PATTERN" \
    | while IFS= read -r line; do
        echo "$(date '+%F %T') $line" | tee -a "$OUT"
    done
```

**注意**：该脚本会一直前台运行，生产上建议用 `nohup` 或 systemd 托管；日志轮转后用 `tail -F` 可以继续跟踪。

------

## 12. HTTP 健康检查

**用途**：检查 URL 的 HTTP 状态码和响应耗时，非 2xx/3xx 时退出 1。
**用法**：`./http_check.sh https://example.com [超时秒数]`

```bash
#!/bin/bash
set -euo pipefail

URL=${1:?Usage: $0 <url> [timeout-seconds]}
TIMEOUT=${2:-5}

result=$(curl -sS -o /dev/null -w '%{http_code} %{time_total}' --max-time "$TIMEOUT" "$URL" || true)
[ -n "$result" ] || { echo "request failed: $URL" >&2; exit 1; }

code=${result%% *}
cost=${result##* }
echo "$(date '+%F %T') $URL code=$code time=${cost}s"

if [ "$code" -lt 200 ] || [ "$code" -ge 400 ]; then
    echo "WARNING: bad status $code" >&2
    exit 1
fi
```

**注意**：3xx 视为正常；如果需要跟随跳转，给 `curl` 加 `-L`。证书问题可临时加 `-k`，但生产不建议。

------

## 13. 配置备份

**用途**：打包 `/etc`，校验压缩包完整性，并清理 7 天前的旧备份。
**用法**：`./backup_etc.sh [备份目录]`

```bash
#!/bin/bash
set -euo pipefail

DST=${1:-/backup/etc}
KEEP=7
ts=$(date '+%F_%H%M%S')
archive="$DST/etc_${ts}.tar.gz"

mkdir -p "$DST"
tar -czf "$archive" -C / etc
tar -tzf "$archive" >/dev/null

find "$DST" -type f -name 'etc_*.tar.gz' -mtime +"$KEEP" -delete
echo "backup ok: $archive"
```

**注意**：`/etc` 里可能包含密钥、密码和证书，备份文件要限制权限并加密存放。

------

## 14. 安全基线巡检

**用途**：快速检查 UID 0 账户、空口令、SUID 文件、SSH 配置和监听端口。
**用法**：`./security_audit.sh`

```bash
#!/bin/bash
set -euo pipefail

echo "===== security audit $(date '+%F %T') ====="

echo "--- UID 0 accounts ---"
awk -F: '$3 == 0 {print $1}' /etc/passwd

echo "--- empty password accounts ---"
awk -F: '($2 == "") {print $1}' /etc/shadow 2>/dev/null || true

echo "--- SUID files ---"
find / -xdev -perm -4000 -type f 2>/dev/null | head -n 30

echo "--- SSH config ---"
sshd -T 2>/dev/null | grep -Ei 'permitrootlogin|passwordauthentication|pubkeyauthentication' || true

echo "--- listening ports ---"
ss -tulnp

echo "--- last failed logins ---"
lastb -n 10 2>/dev/null || true
```

**注意**：这是轻量巡检，不替代 Lynis/OpenSCAP；`/etc/shadow` 和 `ss` 的进程信息通常需要 root 才能看全。

------

## 15. 发布与回滚

**用途**：基于 `current`/`previous` 软链做简单发布，健康检查失败自动回滚。
**用法**：
```bash
APP_DIR=/opt/app SERVICE=myapp HEALTH_URL=http://127.0.0.1:8080/health \
  ./deploy.sh deploy /opt/app/releases/20261118
APP_DIR=/opt/app SERVICE=myapp ./deploy.sh rollback
```

```bash
#!/bin/bash
set -euo pipefail

APP_DIR=${APP_DIR:-/opt/app}
SERVICE=${SERVICE:-app}
HEALTH_URL=${HEALTH_URL:-http://127.0.0.1:8080/health}
CURRENT="$APP_DIR/current"
PREVIOUS="$APP_DIR/previous"

rollback() {
    [ -L "$PREVIOUS" ] || { echo "no previous release" >&2; exit 1; }
    ln -sfn "$(readlink -f "$PREVIOUS")" "$CURRENT"
    systemctl restart "$SERVICE"
    echo "rollback ok -> $(readlink -f "$CURRENT")"
}

case ${1:-} in
    deploy)
        RELEASE=${2:?Usage: $0 deploy <release-dir>}
        [ -d "$RELEASE" ] || { echo "no such release: $RELEASE" >&2; exit 1; }

        if [ -L "$CURRENT" ]; then
            ln -sfn "$(readlink -f "$CURRENT")" "$PREVIOUS"
        fi
        ln -sfn "$(readlink -f "$RELEASE")" "$CURRENT"
        systemctl restart "$SERVICE"
        sleep 2

        if ! curl -fsS --max-time 5 "$HEALTH_URL" >/dev/null; then
            echo "health check failed, rolling back" >&2
            rollback
            exit 1
        fi
        echo "deploy ok -> $(readlink -f "$CURRENT")"
        ;;
    rollback)
        rollback
        ;;
    *)
        echo "Usage: $0 <deploy|rollback> [release-dir]" >&2
        exit 2
        ;;
esac
```

**注意**：这是最小发布模型，适合单机/小规模；正式环境要加制品校验、数据库变更、灰度、审批和回滚记录。

------

## 16. 定时任务包装脚本

**用途**：给脚本加文件锁、超时和统一日志，避免重复执行或卡死。
**用法**：`./run_with_lock.sh /var/lock/backup.lock 3600 /opt/scripts/backup.sh`

```bash
#!/bin/bash
set -euo pipefail

LOCK_FILE=${1:?Usage: $0 <lock-file> <timeout-seconds> <command...>}
TIMEOUT=${2:?Usage: $0 <lock-file> <timeout-seconds> <command...>}
shift 2

LOG=/var/log/run_with_lock.log
exec 9>"$LOCK_FILE"

if ! flock -n 9; then
    echo "$(date '+%F %T') another instance is running" >> "$LOG"
    exit 1
fi

echo "$(date '+%F %T') start: $*" >> "$LOG"
if timeout "$TIMEOUT" "$@"; then
    echo "$(date '+%F %T') done: $*" >> "$LOG"
else
    rc=$?
    echo "$(date '+%F %T') failed rc=$rc: $*" >> "$LOG"
    exit "$rc"
fi
```

**注意**：锁文件路径要按任务区分；`timeout` 到期返回 124，需要和业务失败区分处理。
