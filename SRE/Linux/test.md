>  运维实战：练习，项目

------

# 文件文本

### **配置文件与日志的定位**

1. 不进入目录，使用**一条命令**查看网卡配置文件（如 `ifcfg-ens33`）的最后 10 行内容。（提示：需结合绝对路径）
2. 系统内存信息存储在哪个**虚拟文件系统**中？请用 `cat` 命令直接找出当前系统的**可用内存**数值（单位：KB）。
3. 请问 `/tmp` 和 `/var/tmp` 的核心区别是什么？如果有一个 500MB 的临时缓存文件，你更建议放在哪个目录下？

```Shell
tail -n 10 /etc/sysconfig/network-scripts/ifcfg-ens33
cat /proc/meminfo | grep MemAvailable | awk '{print $2}'
/tmp 可能使用 tmpfs，空间受内存限制，500MB 可能占用过多内存资源，影响系统性能。
/tmp 重启丢失，若缓存需长期保留或重启后仍有用，不适合。
/var/tmp 在磁盘上，空间充足且持久，适合存放较大临时文件。
```

### **权限与归属的观察**

在 `/etc/passwd` 文件中：

1. 使用 `grep` 过滤出所有 **登录 Shell 为 `/bin/bash`** 的用户行。
2. 结合 `cut` 或 `awk`，只提取这些用户的**用户名**（第一字段）和**家目录**（第六字段）。
3. 查找 `/usr/bin/` 目录下，**所有用户都有执行权限（即 `x`）** 且**文件类型为普通文件**的条目，并统计其数量。（提示：`ls -l` 配合 `grep` 的权限正则，或直接用 `find`）

```Shell
grep '/bin/bash$' /etc/passwd
awk -F: '$7=="/bin/bash" {print $1, $6}' /etc/passwd
find /usr/bin/ -type f -perm -111 | wc -l
```

### **清理与归档的原子操作**

当前目录下有一堆杂乱文件，请按顺序执行以下**单次命令**（禁止分步 `cd`）：

1. 创建一个名为 `~/project_archive/2026/` 的多级目录（父目录不存在时自动创建）。
2. 将当前目录下所有 **名称包含 `error`** 且 **大小大于 10M** 的日志文件，**移动**到上述新建的 `2026/` 目录中。
3. 进入 `2026/` 目录，将里面所有文件的扩展名从 `.log` 批量重命名为 `.bak`。（提示：使用 `rename`命令或 `for` 循环——但为符合“无脚本”要求，更建议使用 `rename` 工具；若环境无此工具，可用 `awk` 拼接 `mv` 交由 `sh` 执行，但这里仅考察思维，口述逻辑亦可）

```Shell
mkdir -p ~/project_archive/2026/
find . -maxdepth 1 -name "*error*" -size 10M+ -exec mv -t ~/project_archive/2026/ {} +
(cd ~/project_archive/2026/ && \
for f in *.log; do \ 
   [ -f "$f" ] && \
   mv "$f" "${f%.log}.bak"; \
done)
```

### **硬链接与软链接的陷阱**

1. 在 `/tmp/` 下创建一个名为 `link_test.txt` 的文件，内容写 `Hello Inode`。
2. 分别创建它的**硬链接** `/tmp/hard_link` 和**软链接** `/tmp/soft_link`。
3. 请写出**一条命令**，找出这三个文件指向的 **inode 号码**，并说明为什么硬链接和原文件的 inode 相同，而软链接不同。

```Shell
echo "Hello Inode" > /tmp/link_test.txt
ln /tmp/link_test.txt /tmp/hard_link
ln -s /tmp/link_test.txt /tmp/soft_link
ls -li /tmp/link_test.txt /tmp/hard_link /tmp/soft_link
```

### **`grep` 与正则表达式的高级过滤**

给定一段文本 `sample.txt`，内容包含 IP 地址、邮箱和 URL：

- `192.168.1.1`、`10.0.0.255`、`172.16.0.1`
- `test@company.com`、`admin@test.org`

1. 使用 `grep` 提取出**所有合法的 IPv4 地址**（只匹配数字和点，不考虑 0-255 校验）。
2. 使用 `grep -E` 提取出**所有邮箱地址**（格式：`用户名@域名.后缀`）。

```Shell
echo "192.168.1.1 10.0.0.255 172.16.0.1 test@company.com admin@test.org" > sample.txt
grep -oE '\b[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\b' sample.txt
grep -oE '\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b' sample.txt
```

### **`sed` 的流编辑实战**

假设你有配置文件 `config.ini`，内容含有若干行 `port=8080` 和 `#port=9090`。

1. 使用 `sed` 将文件中**所有未被注释**的 `port=8080` 替换为 `port=443`，并把结果输出到终端。
2. 使用 `sed` **删除**文件中所有包含 `# DEPRECATED` 的行，并统计删除后剩余的行数。（提示：`sed` 配合 `wc -l`）

```Shell
sed -n 's/^port=8080/port=443/g,p' config.ini 
sed '/# DEPRECATED/d' config.ini | wc -l
```

### **`awk` 的列处理与统计**

使用 `awk` 处理 `/proc/meminfo` 或一个自定义的 CSV 数据（假设有三列：`姓名,部门,薪资`）：

1. 打印出 `/proc/meminfo` 中以 `Mem` 开头的行，并格式化输出为 `"指标名: 数值 KB"`。
2. **挑战题**：给定一个 `access.log`（格式：`IP 时间 状态码 字节数`），不写脚本，只用一条管道命令完成：**统计状态码为 `404` 的行中，出现次数最多的前 3 个 IP**。（必用命令：`grep` → `awk` → `sort` → `uniq -c` → `sort -nr` → `head`）

```Shell
awk -F: '/^Mem/ {print $1 " " $2 " KB"}'  /proc/meminfo
grep ' 404 ' access.log | awk '{print $1}' | sort | uniq -c | sort -nr | head -3
```

### **目录与文件操作**

系统反馈磁盘空间不足，请你在 `/var/log` 目录下完成以下操作（请用命令组合，禁止逐条 `cd`）：

1. 找出最近 **3天** 内修改过、且大小超过 **100M** 的 `.log` 文件。
2. 将这些文件的**绝对路径**存入 `/tmp/cleanup_list.txt`。
3. 编写一条命令，统计该目录下各个子文件夹分别占用的磁盘大小，并按大小倒序排列（提示：`du` 与 `sort`）。

```Shell
cd var/log

find . -type f -name "*.log" -mtime -3 -size +100M -print >> /tmp/cleanup_list.txt

du -hs ./*/ | sort -hr
```

### **文本三剑客实战**

给定一个 `nginx_access.log` 日志文件（格式：`IP - - [时间] "GET /url" 状态码 字节`）：

1. 使用 `awk` 打印出 **状态码大于等于 400** 的行的请求方法（GET/POST）和 URL。
2. 使用 `sed` 将日志中所有的 `192.168.` 开头的内网 IP 替换为 `INTERNAL_IP`，并输出到新文件。
3. 统计访问量最高的 **Top 5** IP 地址（要求用一行管道命令完成）。

```Shell
awk '$9 >= 400 {gsub(/"/, "", $6); print $6, $7}' nginx_access.log

sed -E 's/^192\.168\.[0-9]+\.[0-9]+/INTERNAL_IP/' nginx_access.log >> new_nginx.log

awk '{print $1}' nginx_access.log | sort | uniq -c | sort -nr | head -n 5
```

------

# 脚本

### **交互式备份脚本**

编写一个脚本 `backup_manager.sh`，实现以下功能：

- 脚本接受两个参数：`-d 目标目录` 和 `-f 文件后缀`（如 `.conf`）。
- 若未传参，则默认备份 `/etc` 下所有 `.conf` 文件到 `~/backup/`。
- 备份文件名必须包含**当前日期**（如 `backup_20260618.tar.gz`）。
- 脚本需判断目标目录是否存在，若不存在则自动创建。
- **加分项**：脚本启动时检查是否有同名备份进程在运行，若有则提示并退出（用 `pidof` 或锁文件）。

```Shell
vim backup_manager.sh

#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "用法: $0 [-d 目标目录] [-f 文件后缀]"
    echo "示例: $0 -d /backup -f .conf"
    echo "若不传参，默认备份 /etc 下所有 .conf 文件到 ~/backup/"
    exit 1
}

# 执行备份逻辑
do_backup() {
    local src_dir="$1"
    local suffix="$2"
    local backup_dir="$3"

    # 确保目标目录存在
    mkdir -p "$backup_dir" || {
        echo "错误: 无法创建目录 $backup_dir" >&2
        exit 1
    }

    # 生成带日期的备份文件名
    local date_str=$(date +%Y%m%d)
    local backup_file="backup_${date_str}.tar.gz"
    local backup_path="${backup_dir}/${backup_file}"

    echo "开始备份: 源目录=$src_dir, 后缀=$suffix, 目标=$backup_path"

    # 统计匹配文件数量
    local file_count=$(find "$src_dir" -type f -name "*$suffix" -print | wc -l)
    if [ "$file_count" -eq 0 ]; then
        echo "错误: 在 $src_dir 下未找到任何匹配后缀 $suffix 的文件" >&2
        exit 1
    fi

    # 执行打包（处理文件名中的特殊字符）
    if find "$src_dir" -type f -name "*$suffix" -print0 | tar -czf "$backup_path" --null -T -; then
        echo "备份成功: $backup_path (包含 $file_count 个文件)"
    else
        echo "错误: 打包过程失败" >&2
        exit 1
    fi
}

# 解析命令行参数（设置默认值）
parse_args() {
    SOURCE_DIR="/etc"
    SUFFIX=".conf"
    BACKUP_DIR="$HOME/backup"

    while getopts "d:f:" opt; do
        case $opt in
            d) BACKUP_DIR="$OPTARG" ;;
            f) SUFFIX="$OPTARG" ;;
            *) usage ;;
        esac
    done

    # 若后缀不以点开头，自动添加
    if [[ "$SUFFIX" != .* ]]; then
        SUFFIX=".$SUFFIX"
    fi
}
# 解析参数
parse_args "$@"

# 执行备份
do_backup "$SOURCE_DIR" "$SUFFIX" "$BACKUP_DIR"



bash backup_manager.sh -d /dir -f .conf
```

### **系统监控脚本**

写一个脚本 `sys_check.sh`，每执行一次做以下检查：

1. 获取当前系统 **5分钟平均负载**，若大于 CPU 核心数，则记录警告日志到 `/var/log/sys_warn.log`。
2. 获取内存使用率（`free -m`），若剩余内存小于 500M，则按时间戳格式写入“内存不足”告警。
3. 将上述两个检查结果整合，若存在任意告警，则**发送邮件**（用 `mail` 命令或简单写入紧急文件即可，模拟动作）。

```Shell
vim sys_check.sh

#!/usr/bin/env bash
set -euo pipefail
LOG_FILE="/var/log/sys_warn.log"          # 告警日志文件
EMERGENCY_FILE="/var/log/emergency.txt"   # 模拟邮件发送的紧急文件
ALERT=0                                   # 告警标志（0=无，1=有）

# ========== 1. 检查5分钟平均负载 ==========
CPU_CORES=$(nproc)                        # CPU核心数
LOAD5=$(awk '{print $1}' /proc/loadavg)   # 5分钟平均负载

# 使用 awk 进行浮点数比较（LOAD5 > CPU_CORES）
if awk -v load="$LOAD5" -v cores="$CPU_CORES" 'BEGIN {exit (load > cores) ? 0 : 1}'; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') WARNING: 5-min average load = $LOAD5 exceeds CPU cores = $CPU_CORES" >> "$LOG_FILE"
    ALERT=1
fi

# ========== 2. 检查内存剩余 ==========
# 获取可用内存（优先使用 available 列，若无则使用 free + buffers + cache）
MEM_AVAIL=$(free -m | awk '/^Mem:/ {print $7}')
if [ -z "$MEM_AVAIL" ]; then
    MEM_AVAIL=$(free -m | awk '/^Mem:/ {print $4 + $6}')
fi

if [ "$MEM_AVAIL" -lt 500 ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') WARNING: Available memory = ${MEM_AVAIL}M, less than 500M" >> "$LOG_FILE"
    ALERT=1
fi

# ========== 3. 若有告警，发送邮件（模拟） ==========
if [ "$ALERT" -eq 1 ]; then
    # 方式一（实际邮件，需安装 mail 命令并配置）：取消注释即可使用
    # echo "System alert detected at $(date). Check $LOG_FILE for details." | mail -s "System Warning on $(hostname)" root

    # 方式二（模拟）：写入紧急文件
    echo "$(date '+%Y-%m-%d %H:%M:%S') EMERGENCY: System alert triggered, please check $LOG_FILE" >> "$EMERGENCY_FILE"
    
    # 同时输出提示到控制台（便于交互执行时看到）
    echo "Alert triggered. Details logged to $LOG_FILE and emergency file $EMERGENCY_FILE"
fi
```

### **任务调度与日志切割**

1. 设置 `crontab`，要求**每隔 30 分钟**执行一次模块二中写的 `sys_check.sh`。
2. 设置一个计划任务，**每周日凌晨 3:00** 执行 `logrotate`（模拟对 `access.log` 的切割，保留最近 4 个归档）。
3. **陷阱题**：你的脚本 `backup_manager.sh` 手动执行正常，但在 `cron` 中运行报错“命令未找到”。请列出 3 种可能的解决思路（无需写代码，说明原理即可）。

```Shell
systemctl start crond
crontab -e

*/30 * * * * /bin/bash /../sys_check.sh 
0 3 * * 0 logrotate
```

### **自动化日报系统**。

**你需要完成以下脚本 `daily_report.sh`：**

1. **文件定位**：读取 `/var/log/myapp/error.log` 中今天的报错记录（按日期过滤）。
2. **文本处理**：使用 `awk` 提取报错中的 `ERROR_CODE` 和 `API_PATH`，统计出 **报错次数最多的 3 个接口**。
3. **生成报告**：将统计结果格式化写入 `~/reports/$(date +%Y%m%d)_report.txt`，并附上系统负载和磁盘使用率。
4. **脚本自愈**：如果 `/var/log/myapp/` 目录不存在，脚本自动创建并输出提示。
5. **定时派发**：设置 `crontab` 在 **每天上午 9:00** 执行该脚本。
6. **进阶要求**：仅当当日报错总数 > 50 条时，才生成“紧急报告”并追加后缀 `_URGENT`，否则生成普通报告。

```Shell
#!/usr/bin/env bash
set -euo pipefail
LOG_DIR="/var/log/myapp"
LOG_FILE="$LOG_DIR/error.log"
REPORT_BASE="$HOME/reports"
TODAY=$(date +%Y-%m-%d)
REPORT_DATE=$(date +%Y%m%d)
REPORT_FILE="$REPORT_BASE/${REPORT_DATE}_report.txt"
URGENT_SUFFIX="_URGENT"

# ========== 1. 目录自愈（若不存在则创建） ==========
if [ ! -d "$LOG_DIR" ]; then
    echo "警告: 目录 $LOG_DIR 不存在，正在自动创建..." >&2
    mkdir -p "$LOG_DIR" || {
        echo "错误: 无法创建目录 $LOG_DIR" >&2
        exit 1
    }
    echo "目录已创建: $LOG_DIR"
fi

# 检查日志文件是否存在
if [ ! -f "$LOG_FILE" ]; then
    echo "错误: 日志文件 $LOG_FILE 不存在" >&2
    exit 1
fi

# ========== 2. 提取今日报错记录并统计 ==========
# 统计总报错数
TOTAL_ERRORS=$(grep -c "$TODAY" "$LOG_FILE")

# 提取 API_PATH，统计出现次数，取前3
TMP_SORTED=$(mktemp)
grep "$TODAY" "$LOG_FILE" | \
    awk '{
        # 匹配 API_PATH= 后跟非空白字符（可根据实际日志格式调整）
        if (match($0, /API_PATH=[^ ]*/)) {
            path = substr($0, RSTART+9, RLENGTH-9)
            print path
        }
    }' | \
    sort | uniq -c | sort -rn | head -3 > "$TMP_SORTED"

# ========== 3. 生成报告 ==========
# 根据报错总数决定文件名后缀
if [ "$TOTAL_ERRORS" -gt 50 ]; then
    REPORT_FILE="${REPORT_BASE}/${REPORT_DATE}_report${URGENT_SUFFIX}.txt"
    URGENT_TAG="[紧急报告]"
else
    URGENT_TAG="[普通报告]"
fi

# 创建报告目录（若不存在）
mkdir -p "$REPORT_BASE"

# 写入报告头部
{
    echo "=========================================="
    echo "自动化日报 - $TODAY $URGENT_TAG"
    echo "报错总数: $TOTAL_ERRORS"
    echo "------------------------------------------"
    echo "报错最多的 3 个接口:"
    if [ -s "$TMP_SORTED" ]; then
        cat "$TMP_SORTED" | while read count path; do
            echo "  $count 次 -> $path"
        done
    else
        echo "  今日无报错记录"
    fi
    echo "------------------------------------------"
    echo "系统负载 (1/5/15分钟):"
    uptime | awk -F'load average:' '{print $2}' | sed 's/^ //'
    echo "------------------------------------------"
    echo "磁盘使用率 (根分区):"
    df -h / | awk 'NR==2 {print "  已用: " $3 " / " $2 " (" $5 ")"}'
    echo "=========================================="
} > "$REPORT_FILE"

# 清理临时文件
rm -f "$TMP_SORTED"

# ========== 4. 输出完成信息 ==========
echo "报告已生成: $REPORT_FILE"

0 9 * * * /bin/bash /../daily_report.sh
```

### **数字彩蛋猜谜游戏**

编写一个脚本 `guess.sh`：

1. 脚本启动时，生成一个 **1-100** 之间的随机数（使用 `$RANDOM`）。
2. 提示用户“请输入一个数字：”，读取用户的输入。
3. 判断逻辑：
   - 如果输入为空，提示“输入不能为空”并退出码设为 `1`。
   - 如果数字大于随机数，输出“猜大了”；小于则输出“猜小了”；相等则输出“恭喜猜中！”并**退出循环**。
4. 仅允许用户猜 **5 次**，5 次未中则输出“机会用尽，正确答案是 X”并退出。

```Shell
#!/usr/bin/env bash
r=$((RANDOM % 100 + 1))
for i in {1..5}; do

		read -p "请输入一个数字：" $in
		if [[ -z $in ]]; then
				echo "输入不能为空"
				exit 1
		fi
		
		if [ "$in" -eq "$r" ]; then
        echo "恭喜猜中！"
        exit 0
    elif [ "$in" -gt "$r" ]; then
        echo "猜大了"
    else
        echo "猜小了"
    fi
done
exit 0
```

### **批量文件生成器**

编写一个脚本 `batch_create.sh`，接受**一个数字参数**（如 `./batch_create.sh 10`）：

1. 如果未传参或参数不是正整数，输出“用法：$0 <正整数>”并退出。
2. 在当前目录下，循环创建 `file_001.txt` 到 `file_XXX.txt`（数字位数为3，不足补0）。
3. 每个文件内写入一行内容：`这是第 N 个文件，创建时间为 $(date)`。
4. **进阶要求**：如果某个文件已存在，脚本应**跳过**该文件（不覆盖），并在屏幕上提示 `file_001.txt 已存在，跳过`。

```Shell
#!/usr/bin/env bash

if [ $# -ne 1 ]; then
    echo "用法：$0 <正整数>"
    exit 1
fi

if ! [[ "$1" =~ ^[1-9][0-9]*$ ]]; then
    echo "用法：$0 <正整数>"
    exit 1
fi

NUM="$1"

# 循环创建文件
for ((i=1; i<=NUM; i++)); do
    # 生成三位数字文件名，如 file_001.txt
    filename=$(printf "file_%03d.txt" "$i")
    
    if [ -e "$filename" ]; then
        echo "$filename 已存在，跳过"
    else
        echo "这是第 $i 个文件，创建时间为 $(date)" > "$filename"
    fi
done
```



### **服务状态巡检器**

编写一个脚本 `service_ctl.sh`，接受两个参数：`{start|stop|status}` 和 `服务名`（如 `nginx`）。

- 使用 `case` 分支处理：
  - `status`：执行 `systemctl is-active 服务名`，若返回 0 输出“运行中”，否则输出“未运行”。
  - `start`：执行 `systemctl start 服务名`，并检查 `$?`，若启动失败则输出“启动失败，请检查日志”。
  - `stop`：执行 `systemctl stop 服务名`。
- **陷阱点**：脚本需判断参数个数，少于 2 个则报错退出。

```Shell
#!/usr/bin/env bash
if [[ $# -eq 2 ]]; then
		echo "请输入两个参数"
		exit 1
fi

case $1 in
    start)
        systemctl start $2
        if ! [ $? -eq 0 ]; then
            echo "启动失败，请检查日志"
            exit 1
        fi
        ;;
    stop)
        systemctl stop $2
        ;;
    status)
        systemctl is-active $2 >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo "运行中"
        else
            echo "未运行"
        fi
        ;;
esac
```

### **Crontab 定时规则撰写**

请写出满足以下要求的 **crontab 配置行**（无需写脚本内容，只写时间调度部分）：

1. 每年 **6 月 1 日凌晨 2:30** 执行 `/root/annual_clean.sh`。
2. 每隔 **5 分钟** 检查一次 `/var/log/secure` 是否有异常登录（执行脚本 `/opt/check_login.sh`）。
3. 每个**工作日的上午 10:00 和 下午 15:00**，执行 `/home/user/report.sh`。
4. **挑战题**：每月 **1 号到 10 号** 的每天晚上 23:00，执行 `/scripts/backup.sh`。

```Shell
30 2 1 6 *      /root/annual_clean.sh
*/5 * * * *     /opt/check_login.sh /var/log/secure
0 10,15 * * 1-5 /home/user/report.sh
0 23 * 1-10 *   /scripts/backup.sh
```

### **自动重启看门狗**

公司数据库偶尔会因连接数过高而崩溃退出，你需要编写一个**智能看门狗脚本** `db_watchdog.sh`。

**脚本逻辑：**

1. **进程检查**：使用 `pgrep` 或 `ps` 检查 `mysqld` 进程是否存在。
2. **存活判定**：
   - 如果进程**不存在**，记录日志 `[ERROR] MySQL crashed at 时间`，然后执行启动命令（模拟：`systemctl start mysqld` 或 `echo "模拟重启"`）。
   - 如果进程**存在**，再检查端口 `3306` 是否处于监听状态（使用 `netstat -tlnp | grep 3306`）。如果进程存在但端口未监听，视为“假死”，执行 `kill -9 pid` 并重启。
3. **防误报机制**：如果连续 3 次检查（间隔 10 秒）都发现 MySQL 挂掉，则发送紧急告警（模拟：写入 `CRITICAL` 级别日志），不再继续重启，防止频繁重启产生更多故障。
4. **Cron 调度**：设置 crontab，**每 1 分钟**执行一次该脚本。

```Shell
#!/usr/bin/env bash

LOCK_FILE="/tmp/db_watchdog.lock"
FAIL_COUNT_FILE="/tmp/mysql_fail_count"
MAX_FAILURES=3
CHECK_INTERVAL=10   # 每次检查间隔10秒，但此脚本由cron每分钟执行，防误报机制通过文件计数实现

# 日志函数
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> /var/log/db_watchdog.log
}

# 防止脚本同时运行多个实例（cron可能重叠）
exec 200>"$LOCK_FILE"
flock -n 200 || { log "脚本已在运行，退出"; exit 0; }

# 初始化失败计数器
if [ ! -f "$FAIL_COUNT_FILE" ]; then
    echo 0 > "$FAIL_COUNT_FILE"
fi
FAIL_COUNT=$(cat "$FAIL_COUNT_FILE")

# 检查 MySQL 进程是否存在
MYSQL_PID=$(pgrep -x mysqld 2>/dev/null | head -1)
if [ -z "$MYSQL_PID" ]; then
    # 进程不存在
    log "ERROR: MySQL crashed at $(date)"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    echo $FAIL_COUNT > "$FAIL_COUNT_FILE"

    if [ $FAIL_COUNT -ge $MAX_FAILURES ]; then
        log "CRITICAL: MySQL连续失败${MAX_FAILURES}次，停止重启，请人工介入"
        # 紧急告警可写单独文件或发送邮件
        echo "$(date) CRITICAL: MySQL多次崩溃" >> /var/log/db_emergency.log
        exit 1
    else
        # 尝试重启
        log "尝试启动 MySQL..."
        systemctl start mysqld 2>&1 | tee -a /var/log/db_watchdog.log
        # 若 systemctl 不可用，可改为 /etc/init.d/mysqld start
        sleep 2
        # 检查启动后是否存活
        if pgrep -x mysqld >/dev/null; then
            log "MySQL 启动成功"
            # 重置计数器
            echo 0 > "$FAIL_COUNT_FILE"
        else
            log "MySQL 启动失败，请检查日志"
        fi
    fi
else
    # 进程存在，检查端口监听状态
    if netstat -tlnp 2>/dev/null | grep -q ":3306.*mysqld"; then
        # 一切正常，重置计数器
        if [ $FAIL_COUNT -ne 0 ]; then
            echo 0 > "$FAIL_COUNT_FILE"
            log "MySQL 恢复正常，重置失败计数"
        fi
    else
        # 进程存在但端口未监听 → 假死
        log "ERROR: MySQL 进程存在但端口3306未监听，视为假死"
        # kill 进程
        kill -9 "$MYSQL_PID" 2>/dev/null
        sleep 1
        # 重启
        systemctl start mysqld 2>&1 | tee -a /var/log/db_watchdog.log
        # 检查
        if pgrep -x mysqld >/dev/null; then
            log "MySQL 假死后重启成功"
            echo 0 > "$FAIL_COUNT_FILE"
        else
            log "MySQL 重启失败"
            FAIL_COUNT=$((FAIL_COUNT + 1))
            echo $FAIL_COUNT > "$FAIL_COUNT_FILE"
        fi
    fi
fi
```

------

# 基础

### 创建一个新用户 deploy，赋予 sudo 权限，禁止root远程SSH登录。

```Shell
# 创建用户并设置 bash 为默认 shell
sudo useradd -m -s /bin/bash deploy
# 设置密码（交互式）
sudo passwd deploy
# 将用户加入 sudo 组
sudo usermod -aG sudo deploy   # 或 wheel
# 禁止 root 远程 SSH 登录
echo "PermitRootLogin no" | sudo tee -a /etc/ssh/sshd_config
# 重启 SSH 服务
sudo systemctl restart sshd
```

### 配置防火墙，只开放 22, 80, 443 端口。

```Shell
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw enable
```

### 从源码或包管理器安装 Nginx，并配置一个虚拟主机，指向 /var/www/myapp。

```Shell
# 包管理器安装
sudo apt update && sudo apt install nginx -y
# 安装依赖
sudo apt install build-essential libpcre3 libpcre3-dev zlib1g zlib1g-dev libssl-dev -y
# 下载并解压
wget http://nginx.org/download/nginx-1.24.0.tar.gz
tar -xzf nginx-1.24.0.tar.gz
cd nginx-1.24.0
# 配置、编译、安装
./configure --prefix=/usr/local/nginx --with-http_ssl_module
make && sudo make install
# 创建站点目录
sudo mkdir -p /var/www/myapp
echo "<h1>Hello from myapp</h1>" | sudo tee /var/www/myapp/index.html
# 创建虚拟主机配置（包管理器安装路径示例）
sudo tee /etc/nginx/sites-available/myapp <<EOF
server {
listen 80;
server_name _;   # 替换为你的域名或 IP
root /var/www/myapp;
index index.html index.htm;
location / {
try_files \$uri \$uri/ =404;
}
}
EOF
# 启用站点
sudo ln -s /etc/nginx/sites-available/myapp /etc/nginx/sites-enabled/
# 删除默认站点（可选）
sudo rm /etc/nginx/sites-enabled/default
# 测试配置并重载
sudo nginx -t
sudo systemctl reload nginx
```

------

# 排查

### 模拟CPU跑满，然后用 top 和 ps 找到该进程并结束它。

```Shell
# 启动 4 个 CPU 密集型进程，持续 60 秒（后台运行）
stress --cpu 4 --timeout 60 &
# 运行 top，按 P 键（大写）按 CPU 使用率排序
top
# 找到高 CPU 的 PID，按 q 退出
# 然后杀死进程
kill -9 <PID>
# 按 CPU 降序排列进程
ps aux --sort=-%cpu | head -10
# 假设 PID 为 12345
kill -9 12345
```

### 查看系统日志，找出今天所有 Failed password for root 的记录。

```Shell
# 直接 grep（注意日期格式，如 "May 23"）
sudo grep "Failed password for root" /var/log/auth.log | grep "$(date '+%b %e')"
```

------

### 日志审计与自动归档清理系统

**背景**：公司的 `/var/log/myapp/` 目录经常写满，导致服务崩溃。你需要写一个脚本 `app_log_manager.sh`，实现“分析 -> 归档 -> 清理”的全自动闭环。

**阶段 1：文件与目录预处理（考察 `find` + 目录规范）**

1. 脚本启动时，检查 `/var/log/myapp/` 是否存在，若不存在则创建，并写入一条初始化日志。
2. 使用 `find` 找出该目录下 **7天前** 修改过的、后缀为 `.log` 的文件，将其**移动**到 `/data/archive/$(date +%Y%m)/` 目录下（年月目录需自动创建）。

**阶段 2：文本内容深度分析（考察 `awk` / `grep` / `sed`）**

1. 针对 **当前正在写入** 的 `access.log`，使用 `awk` 统计出 **状态码 500 出现次数最多** 的 Top 3 接口（URL），并将结果写入 `/tmp/top_error.txt`。
2. 使用 `sed` 将 `access.log` 中所有合法的 IPv4 地址（如 `192.168.1.1`）**替换**为 `[REDACTED]`，生成一份脱敏后的临时文件 `/tmp/access_desensitized.log`（**不修改原文件**）。

**阶段 3：脚本健壮性与防误判（考察变量与逻辑）**

1. 脚本必须带参数 `--mode={check|clean|full}`：
   - `check`：仅分析日志大小，若总大小超过 2GB 则发出警告（写入 `/var/log/myapp/warn.log`）。
   - `clean`：只执行阶段 1 的移动归档操作。
   - `full`：按顺序执行阶段 1 + 阶段 2。
2. **自愈机制**：如果归档目录 `/data/archive/` 的磁盘使用率超过 85%，则自动删除该目录下 **180天前**的 `.tar.gz` 旧包。

**阶段 4：Cron 定时调度与日志追踪**

1. 设置 Crontab，要求在 **每周日凌晨 2:30** 自动执行 `full` 模式。
2. **踩坑题**：由于脚本中使用了 `awk`、`sed` 和自定义目录，请在脚本开头用哪种方式确保 Cron 能正确找到这些命令？（写出具体代码行，比如 `export PATH=...` 或使用绝对路径）

```Shell
#!usr/bin/env bash

if [ -z /var/log/myapp/ ]; then
echo "$date,初始化日志" > /var/log/myapp/
fi

find /var/log/myapp/ -name "*.log" -mtime +7 -exec 
```

------

### 服务器配置变更“吹哨人”系统

**背景**：安全部门要求监控 `/etc/passwd` 和 `/etc/ssh/sshd_config` 是否被恶意篡改。你需要写一个脚本 `config_watch.sh`，**不用监控工具，纯靠命令组合**。

**阶段 1：基线快照与比较（考察文件差异 `diff`）**

1. 首次运行脚本时（带参数 `--init`），将 `/etc/passwd` 和 `/etc/sshd_config` 的**哈希值（md5sum）** 以及**权限（ls -l）** 保存到 `~/baseline/` 目录下。
2. 后续运行（不带参数）时，重新计算当前文件的哈希值，并与基线比对。若有变化，使用 `diff -u` 将新旧文件的差异追加到 `/var/log/config_change.log` 中。

**阶段 2：敏感行过滤（考察 `grep -v` 与正则）**

1. 在比对前，使用 `grep -v` 过滤掉 `/etc/sshd_config` 中所有的**空行**和以 `#` 开头的注释行，仅对**有效配置行**进行比对，减少误报。
2. 编写一行命令，从 `/etc/passwd` 中提取出所有 **UID 大于等于 1000** 的普通用户登录 Shell（第7字段），如果发现其中有 `/bin/bash` 或 `/bin/sh`，将其用户名记录到告警列表中（考察 `awk` 条件筛选）。

**阶段 3：定时扫描与主动告警（考察 Cron + 脚本交互）**

1. 设置 Crontab，**每隔 10 分钟**执行一次 `config_watch.sh`。
2. 若检测到变更，脚本除了写日志外，还需调用 `logger` 命令向系统日志（`/var/log/syslog`）写入一条 `[CRITICAL]` 级别的告警。
3. **进程锁**：由于每 10 分钟执行一次，如果某次 `diff` 比对卡住了（文件很大），请使用 `flock -n` 确保同一时间只有一个检查进程在跑，防止系统资源耗尽。

```Shell

```

------

### 恶意进程追踪与应急自愈（终极挑战）

**背景**：服务器疑似被入侵，CPU 经常飙高（模拟：有一个名为 `evil_miner` 的假进程）。你需要手写一套“发现 -> 定位 -> 清理 -> 固防”的应急脚本 `emergency_killer.sh`。

**阶段 1：可疑进程定位（考察 `/proc` 目录与 `ps` 组合）**

1. 使用 `ps aux` 配合 `sort -nr -k3` 找出当前占用 CPU 最高的前 3 个进程。
2. 针对 PID，进入 `/proc/[pid]/` 目录，使用 `ls -l exe` 找出该进程对应的**可执行文件绝对路径**。
3. 如果该进程的可执行文件位于 `/tmp/`、`/var/tmp/` 或 `/dev/shm/` 这些可疑临时目录，则判定为“高度可疑”。

**阶段 2：文本提取与定时任务清除（考察 `crontab` 与 `sed`）**

1. 如果判定为可疑，脚本应强制 `kill -9` 该 PID。
2. **清除持久化**：恶意软件通常会在 Crontab 里写自启动。请编写逻辑，自动检测当前用户的 Crontab（`crontab -l`）和系统 Crontab（`/etc/crontab`），使用 `sed -i` 删除包含 `evil_miner` 或可疑文件名的任务行。
3. **加固写入**：清理后，在 `/etc/hosts.deny` 中追加一行 `ALL: 恶意IP（模拟）`（此处用 `echo` 追加模拟即可）。

**阶段 3：定时高频巡检（考察 Cron 的特殊写法）**

1. 设置 Crontab，要求**每 2 分钟**执行一次该脚本。
2. **日志切割**：由于脚本每 2 分钟运行一次，`/var/log/killer.log` 会飞速膨胀。请在脚本中内置逻辑：如果该日志文件大于 50MB，则使用 `mv` 将其重命名为 `killer_$(date +%Y%m%d_%H%M%S).log`，并重新创建空日志（模拟 `logrotate` 的简陋版）。

```Shell

```

