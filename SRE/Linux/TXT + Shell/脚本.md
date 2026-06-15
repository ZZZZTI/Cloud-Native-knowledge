-- 任务调度，shell脚本




# 批量创建用户
#!/bin/bash          
    # ↑ Shebang，告诉系统用 bash 执行
while read username; do        
    # ↑ 逐行读取 users.txt 文件，每行存到 username 变量
sudo useradd -m -s /bin/bash "$username"
    # ↑ 创建用户
    # -m：创建家目录 /home/username
    # -s /bin/bash：指定登录 shell
    # sudo：需要 root 权限
echo "$username:TempPass123" | sudo chpasswd
    # ↑ 设置初始密码为 TempPass123
    # chpasswd 接收 "用户名:密码" 格式
sudo passwd -e "$username"
    # ↑ -e 参数：强制用户首次登录时修改密码
done < users.txt
    # ↑ 重定向：从 users.txt 文件读取输入


# crond 定时任务调度器

-- 开启关闭crond服务
sudo systemctl start/stop/restart/enable crond

-- crond语句语法
          * * * * * /path/to/command
          ─ ─ ─ ─ ─
          │ │ │ │ │
          │ │ │ │ └─── 星期几 (0-7, 0和7都代表周日)       *:代表"每"       * * * * *       = 每分钟执行一次
          │ │ │ └───── 月份 (1-12)                     ,  :列举多个值    1,15,30 * * * * = 每小时的第1、15、30分钟执行
          │ │ └─────── 日期 (1-31)                     -  :范围           0 9-17 * * *    = 每天9点到17点的每个整点执行
          │ └───────── 小时 (0-23)                     /n:每隔n个单位    */5 * * * *      = 每隔5分钟执行一次
          └─────────── 分钟 (0-59)

-- 常用实例
每天凌晨 2:30 执行备份脚本
30 2 * * * /home/user/backup.sh
每周一上午 9:00 执行
0 9 * * 1 /usr/bin/echo "Monday morning meeting"
每月1号凌晨 0:00 清理日志
0 0 1 * * /usr/bin/find /var/log -name "*.log" -mtime +30 -delete
每隔10分钟检查某个服务状态
*/10 * * * * /usr/bin/systemctl status nginx > /dev/null 2>&1
工作日的每小时（9点到18点）执行
0 9-18 * * 1-5 /path/to/script.sh
每年1月1日凌晨0点01分执行新年任务
1 0 1 1 * /usr/bin/echo "Happy New Year!"



# at（仅一次的任务）

-- 语法
at [选项] (时间)
选项:
-f 文件       从指定文件中读取命令，而非交互式输入
-l          列出当前用户的所有 at 任务（等同于 atq 命令）
-d 任务ID 删除指定任务（等同于 atrm 命令）
-m          任务执行后，即使没有输出也发送邮件通知
-c 任务ID 查看指定任务的具体内容
q           查看任务列表
时间:
at 14:30
at 14:30 2026-05-01
at 2:30pm
at 23:59 12/25/26
at noon        # 中午12:00
at midnight    # 午夜00:00
at teatime     # 下午16:00
at now + 5 minutes   # 5分钟后
at now + 2 hours     # 2小时后
at now + 3 days      # 3天后
at now + 1 weeks     # 1周后
at now + 2 months    # 2个月后（now可省略）
at 15:30 + 2 days    # 两天后的15:30

-- 常用
场景1：延迟重启服务（5分钟后重启）
echo "systemctl restart nginx" | at now + 5 minutes
场景2：下班后执行长时间任务（今天18:00）
echo "/home/user/large_report.sh" | at 18:00
场景3：明天早上提醒
echo "echo 'Meeting at 10:00' | mail -s 'Reminder' user@example.com" | at 09:30 tomorrow
场景4：系统维护（凌晨3点）
at -f /scripts/maintenance.sh 03:00
场景5：临时关闭服务器（2小时后关机）
echo "/usr/sbin/shutdown -h now" | at now + 2 hours


# 管道

符号    作用                示例
'|'   传递数据给另一个命令    cat file | grep error
'>'   输出到文件（覆盖）     cat file > output.txt
'>>'  输出到文件（追加）  cat file >> output.txt
'<'   从文件输入             grep error < file.txt
'2>'  重定向错误输出       command 2> error.log
'&>'  重定向所有输出        command &> output.log

-- 日志：统计 + 排序 + TOP N
cat log | awk '{print $N}' | sort | uniq -c | sort -rn | head -10


# shell

-- 变量

-- 定义使用
name="张三"                 # 定义（等号两边不能有空格）
count=100
date=$(date +%Y%m%d)       # 命令替换
echo "姓名: ${name}"        # 使用
echo "数量: ${count}"
echo "日期: ${date}"
readonly PATH="/opt/data"  # 只读变量
unset temp_var             # 删除变量

-- 特殊变量
$0      # 脚本名称
$1-$9   # 位置参数（第1-9个参数）
$#      # 参数个数
$@      # 所有参数（每个参数独立）
$*      # 所有参数（当作一个字符串）
$?      # 上一条命令的退出码（0=成功）
$$      # 当前 Shell 进程 PID
$!      # 最后一个后台进程的 PID

-- 变量默认
echo ${var:-default}    # var 为空，输出 default
echo ${var:=default}    # var 为空，赋值为 default
echo ${var:+not_empty}  # var 不为空，输出 not_empty
echo ${var:?error_msg}  # var 为空，输出 error_msg 并退出

-- 条件判断

-- if
if [ condition ]; then
// 执行语句
elif [ condition2 ]; then
// 执行语句
else
// 执行语句
fi

[ condition1 ] && [ condition2 ]   # 与（两个都成立）
[ condition1 ] || [ condition2 ]   # 或（至少一个成立）
[ ! condition ]                    # 非（取反）

-- (condition)
[ -f "$file" ]     # 是否为普通文件
[ -d "$dir" ]      # 是否为目录
[ -e "$path" ]     # 文件/目录是否存在
[ -s "$file" ]     # 文件存在且不为空
[ -r "$file" ]     # 是否可读
[ -w "$file" ]     # 是否可写
[ -x "$file" ]     # 是否可执行
[ $a -eq $b ]      # 等于
[ $a -ne $b ]      # 不等于
[ $a -gt $b ]      # 大于
[ $a -lt $b ]      # 小于
[ $a -ge $b ]      # 大于等于
[ $a -le $b ]      # 小于等于
[ "$s1"="$s2" ]    # 等于
[ "$s1"!="$s2" ]   # 不等于
[ -z "$str" ]      # 字符串为空
[ -n "$str" ]      # 字符串不为空

-- 循环

-- 逐行读取文件
while read line; do
echo "读到: $line"
done < file.txt

-- 读取 CSV（指定分隔符）
while IFS=',' read -r col1 col2 col3; do
echo "列1: $col1, 列2: $col2"
done < data.csv

-- 带计数
count=0
while read line; do
((count++))
echo "$count: $line"
done < file.txt

-- 无限循环
while true; do
echo "运行中..."
sleep 60
done

break       # 跳出循环
continue    # 跳过本次循环
exit        # 退出脚本
return      # 退出函数

for i/letter in {1..10}/{a..z}; do
echo "$i/$letter"
done

-- 函数

get_date() {
echo $(date +%Y%m%d)         # 带返回值
}
today=$(get_date)            # 赋值

my_func() {
echo "参数个数: $#"
echo "所有参数: $@"
echo "第一个参数: $1"
echo "第二个参数: $2"
}
my_func "hello" "world"      # 输出

check_file() {
if [ -f "$1" ]; then
return 0   # 成功          # 返回退出码（0-255）
else
return 1   # 失败
fi
}
check_file "/etc/passwd"
if [ $? -eq 0 ]; then
echo "文件存在"
fi

-- 错误

set -e           # 任何命令失败立即退出（最常用）
set -u           # 使用未定义变量时报错
set -x           # 打印每条执行的命令（调试用）
set -o pipefail  # 管道中任何命令失败都返回失败
set -euxo pipefail   # 组合使用

temp_file=$(mktemp)       # 创建临时文件
temp_dir=$(mktemp -d)
trap "rm -rf $temp_file $temp_dir" EXIT   # 使用完后删除

-- getopts

while getopts "ab:c:" opt; do
case $opt in
a)echo "选项 -a 被触发";;
b)echo "选项 -b 被触发，参数值: $OPTARG";;
c)echo "选项 -c 被触发，参数值: $OPTARG";;
\?)echo "无效选项: -$OPTARG"
exit 1 ;;
esac
done
shift $((OPTIND-1))     # 移除已处理的选项
echo "剩余参数: $@"      # 处理剩余的位置参数
./脚本名 -a -b hello -c world file1.txt file2.txt   # 使用

-- 模版

-- ========== 配置 ==========
#!/bin/bash
set -euo pipefail
readonly SCRIPT_NAME=$(basename $0)
readonly SCRIPT_DIR=$(cd $(dirname $0) && pwd)
readonly DATE=${1:-$(date +%Y%m%d)}
readonly LOG_DIR="/var/log/etl"
readonly LOG_FILE="${LOG_DIR}/${SCRIPT_NAME%.sh}_${DATE}.log"

-- ========== 函数 ==========
log() {
local level=$1
shift
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [${level}] $*" | tee -a "$LOG_FILE"
}
log_info() { log "INFO" "$@"; }
log_error() { log "ERROR" "$@"; }
cleanup() {
log_info "清理临时文件"
rm -rf /tmp/etl_$$_*
}

-- ========== 主流程 ==========
trap cleanup EXIT
log_info "开始执行 ETL，日期: $DATE"
-- 1. 检查输入数据
INPUT_PATH="/data/raw/dt=${DATE}"
if ! hdfs dfs -test -e "$INPUT_PATH"; then
log_error "输入路径不存在: $INPUT_PATH"
exit 1
fi
-- 2. 执行处理
log_info "开始数据清洗"
hive -f /opt/etl/sql/clean.sql --hivevar DATE=$DATE
-- 3. 检查输出
OUTPUT_PATH="/data/dwd/dt=${DATE}"
OUTPUT_COUNT=$(hive -e "SELECT COUNT(*) FROM dwd.table WHERE dt='$DATE'" 2>/dev/null)
if [ "$OUTPUT_COUNT" -eq 0 ]; then
log_error "输出表为空"
exit 1
fi
log_info "ETL 完成，输出记录数: $OUTPUT_COUNT"