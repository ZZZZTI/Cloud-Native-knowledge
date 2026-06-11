```
-- 用户，基础，vim



# 用户管理

    查看用户信息
whoami          # 显示当前用户名
id              # 显示用户ID、组ID、所属组
id username     # 查看指定用户信息
who             # 查看当前登录的用户
w               # 更详细的登录用户信息（含运行命令）
last            # 查看历史登录记录
lastlog         # 查看所有用户最后登录时间
cat /etc/passwd         # 查看所有用户列表
cut -d: -f1 /etc/passwd # 只显示用户名
getent passwd           # 使用getent命令（包含LDAP等）
groups username         # 查看指定用户所属组

    创建用户
sudo adduser username
sudo useradd (-?) username
-m        创建并生成家目录
-u (xxx)  指定uid
-c "xxx"  用户描述
-r        系统用户
-m -s /bin/bash
-G groupname

    密码修改
sudo passwd (-?) username
-l    锁定用户
-u    解锁用户

    修改用户信息
sudo usermod (-?) username
-l newname oldname          修改用户名
-d /home/newhome username   修改家目录
-aG groupname username      添加用户到附加组
-- 删除用户
sudo userdel username

    用户组
sudo groupadd (-g 2000)(-r) groupname                 #创建组(指定GID)(创建系统组)
sudo groupmod -n newname oldname/-g 2500 groupname    #修改组名/GID
sudo groupdel groupname                               # 删除组（确保组内无用户）
sudo gpasswd -M user1,user2 group                     # 设置组成员列表
sudo gpasswd -d user group                            # 从组中移除用户
gpasswd groupname                                     # 设置组密码

    文件权限
chown (user)(:group) file.txt    # 修改文件所有者和组
chmod [权限] file.txt            # 用户添加执行权限
chmod g-w file.txt              # 组移除写权限
chmod o=r file.txt              # 其他人只读
chmod a+x file.txt              # 所有用户添加执行权限
chmod u=rwx,g=rx,o=r file.txt   # 精确设置
u:用户   g:组    o:其他人   a:所有人
+:添加权限（不影响已有权限）
-:移除权限
=:精确赋权（覆盖原有权限）
r:允许查看文件内容
w:允许修改、添加、覆盖或删除文件内容
x:允许将文件作为程序或脚本运行

    切换用户
su - username


# 切换运行级别
init 0          # 关机
init 1          # 单用户模式（维护）：只有 root 用户
init 2          # 默认：完整的系统服务（网络、数据库等）
init 3          # 切换到文本模式
init 5          # 切换到图形模式
init 6          # 重启
telinit 3       # 同 init（某些系统）


# 帮助命令
man command/命令/-k keyword    # 查看所有命令手册
命令 --help/--h                # 查看不同命令的命令用法
whatis 命令                    # 查看命令作用


# date

--自定义格式
date +"%Y-%m-%d"        # 只显示日期：2026-04-20
date +"%H:%M:%S"        # 只显示时间：15:30:45
date -d "特定时间" +"%x%x%x:x"
sleep "指定时间"         # 延迟时间（脚本执行）


# vim基础

    启动vim
vim filename.txt        # 打开/创建文件
vim +10 filename.txt    # 打开并定位到第10行
vim +/search filename   # 打开并搜索关键词
vim file1 file2 file3   # 同时打开多个文件

    退出vim
:wq/:x      保存并退出
:q!         强制退出

    vim模式
┌─────────────┐      i/a/o      ┌─────────────┐
│   普通模式   │ ──────────────→ │   插入模式   │
│  (Normal)   │ ←────────────── │   (Insert)  │
└─────────────┘      Esc        └─────────────┘
移动光标、删除复制粘贴                 输入文本
│
│ :
↓
┌─────────────┐
│   命令模式   │
│  (Command)  │
└─────────────┘
保存、退出、搜索、替换


# vim操作

-- 普通模式

-- 光标移动
0     行首
$     行尾
^     行首第一个非空字符
gg    文件首行
G     文件末行
:n    跳转到第 n 行
w     下一个单词

-- 修改查找
x/X       删除光标处/前字符
ndd       删除n行
d?        删除到?(光标移动的字符)
nyy       复制n行
y?        复制到?
p/P       在光标前/后粘贴
u         撤销上一步操作
Ctrl+r    恢复撤销
.         重复上一次操作
/keyword  向下搜索 keyword
?keyword  向上搜索 keyword
n/N       跳转到下/上一个匹配

-- 插入模式
i   光标前插入
a   光标后插入
o   下方新开一行

-- 命令模式
:w                 保存
:e filename        打开另一个文件
:new               新建文件（分屏）
:s/old/new/g       替换当前行所有 oldword
:%s/old/new/g      替换整个文件所有 oldword
:set nu/nonu       显示行数
:syntax on/off     设置语法高亮
:sp/vsp            水平/垂直分屏
set autoindent     自动缩进
```