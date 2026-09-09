> Linux的另一个版本，在企业级生产环境（金融、电信、政府）中为主流

------

# RHEL

### 软件包管理 (Package Management)

```Shell
操作目的                    RHEL 10                             Ubuntu 
─────────────────────────────────────────────────────────────────────────────────
安装软件                    dnf install <package>               apt install <package>
删除软件                    dnf remove <package>                apt remove <package>
更新所有软件                dnf update                          apt update && apt upgrade
更新特定软件                dnf update <package>      apt install --only-upgrade <package>
搜索软件包                  dnf search <keyword>                apt search <keyword>
查看软件包信息              dnf info <package>                  apt show <package>
列出已安装包                dnf list installed                  apt list --installed
列出可用仓库                dnf repolist                        apt-cache policy
安装本地RPM包               rpm -ivh package.rpm                dpkg -i package.deb
查看RPM包信息               rpm -qi package                     dpkg -s package
列出RPM包文件               rpm -ql package                     dpkg -L package
安装软件组                 dnf groupinstall "Server"       apt install <package> (无组概念)
仓库配置文件                /etc/yum.repos.d/*.repo             /etc/apt/sources.list
清理缓存                    dnf clean all                       apt clean
```

### 防火墙 (Firewall）

```Shell
操作目的                    RHEL 10 (firewalld)                  Ubuntu (ufw)
─────────────────────────────────────────────────────────────────────────────────
查看当前防火墙规则         firewall-cmd --list-all             ufw status verbose
查看所有区域              firewall-cmd --get-zones            (无区域概念)
查看默认区域             firewall-cmd --get-default-zone     (无区域概念)
添加TCP端口(永久)       firewall-cmd --add-port=8080/tcp    ufw allow 8080/tcp --permanent  
添加UDP端口(永久)       firewall-cmd --add-port=53/udp      ufw allow 53/udp --permanent    
添加服务(永久)          firewall-cmd --add-service=http     ufw allow http --permanent      
移除端口(永久)    firewall-cmd --remove-port=8080/tcp  ufw delete allow 8080/tcp-permanent  
重载防火墙                  firewall-cmd --reload               ufw reload
启用防火墙                  systemctl enable firewalld          ufw enable
查看防火墙状态              systemctl status firewalld          ufw status
临时添加端口(立即生效)      firewall-cmd --add-port=80/tcp      ufw allow 80/tcp
                           (不加 --permanent)                   (默立即生效)
防火墙配置文件              /etc/firewalld/zones/*.xml          /etc/ufw/*.rules
运行时规则                  /run/firewalld/*.xml                (不适用)
```

### SELinux vs AppArmor

```Shell
操作目的                    RHEL 10 (SELinux)                   Ubuntu (AppArmor)
─────────────────────────────────────────────────────────────────────────────────
查看当前SELinux模式         getenforce                          aa-status
查看SELinux状态(详细)       sestatus                           (不适用)
临时启用SELinux(强制)       setenforce 1                       (不适用)
临时禁用SELinux(许可)       setenforce 0                       (不适用)
永久配置SELinux模式         /etc/selinux/config                (不适用)
                           SELINUX=enforcing                    
查看文件SELinux上下文       ls -Z <file>                       (不适用)
查看进程SELinux上下文       ps auxZ | grep <process>           (不适用)
恢复文件默认上下文          restorecon -Rv <directory>         (不适用)
修改文件上下文(临时)        chcon -t httpd_sys_content_t       (不适用)
                           <file>                               
修改文件上下文(永久)        semanage fcontext -a -t            (不适用)
                           httpd_sys_content_t "/web(/.*)?"    
添加端口到SELinux策略       semanage port -a -t http_port_t    (不适用)
                           -p tcp 8080                          
查看SELinux端口标签         semanage port -l                   (不适用)
修改SELinux布尔值           setsebool httpd_can_network_connect (不适用)
                           on                                   
查看SELinux布尔值           getsebool -a                       (不适用)
查看SELinux拒绝日志         ausearch -m avc -ts recent         (不适用)
查看SELinux审计日志         grep "denied" /var/log/audit/      (不适用)
                           audit.log                           
生成SELinux允许策略        audit2allow -a -M mypolicy         (不适用)
禁用SELinux(不推荐)         SELINUX=disabled in config         (不适用)
                             (需要重启)   
```

### 网络配置 (Network Configuration)

```Shell
操作目的                    RHEL 10 (NetworkManager)            Ubuntu (Netplan)
─────────────────────────────────────────────────────────────────────────────────
查看网络设备                nmcli device status                 ip link show 或
                                                               netplan get
查看网络连接                nmcli connection show               netplan get 或
                                                               ip addr show
创建静态IP连接              nmcli con add type ethernet         netplan配置文件:
                           ifname eth0 con-name static-eth0     /etc/netplan/*.yaml
                           ipv4.addresses 192.168.1.100/24      network:
                           ipv4.gateway 192.168.1.1              version: 2
                           ipv4.dns 8.8.8.8                      ethernets:
                           ipv4.method manual                     eth0:
重新加载网络配置            nmcli con reload                    netplan apply
设置主机名                  hostnamectl set-hostname           hostnamectl set-hostname
                           server10.example.com                server10.example.com
查看主机名                  hostnamectl status                  hostnamectl status
修改DNS配置                 /etc/resolv.conf (或nmcli)          /etc/resolv.conf
                           nameserver 8.8.8.8                  nameserver 8.8.8.8
设置开机自启网络            nmcli con mod static-eth0           (Netplan默认启用)
                           autoconnect yes                     
网络配置文件目录            /etc/NetworkManager/system-         /etc/netplan/*.yaml
                           connections/*.nmconnection          
传统网络脚本(已弃用)        /etc/sysconfig/network-scripts/     /etc/network/interfaces
                           ifcfg-*                             (旧版)
重启网络服务                systemctl restart NetworkManager    netplan apply
```

### 服务管理 (Service Management）

```Shell
操作目的                    RHEL 10                             Ubuntu
─────────────────────────────────────────────────────────────────────────────────
启动服务                    systemctl start httpd               systemctl start apache2
停止服务                    systemctl stop httpd                systemctl stop apache2
重启服务                    systemctl restart httpd             systemctl restart apache2
查看服务状态                systemctl status httpd              systemctl status apache2
设置开机自启                systemctl enable httpd              systemctl enable apache2
禁用开机自启                systemctl disable httpd             systemctl disable apache2
查看所有服务                systemctl list-units --type=service systemctl list-units --type=service
查看服务日志                journalctl -u httpd                 journalctl -u apache2
实时查看日志                journalctl -u httpd -f              journalctl -u apache2 -f
查看启动日志                journalctl -b                       journalctl -b
查看所有日志(时间范围)      journalctl --since "1 hour ago"    journalctl --since "1 hour ago"
设置日志保留时间            /etc/systemd/journald.conf          /etc/systemd/journald.conf
                           MaxRetentionSec=3day                MaxRetentionSec=3day
查看当前运行目标            systemctl get-default               systemctl get-default
切换运行目标                systemctl isolate multi-user.target systemctl isolate multi-user.target
设置默认运行目标            systemctl set-default               systemctl set-default
                           multi-user.target                   multi-user.target
```

### 系统救援与故障排除 (Troubleshooting）

```Shell
操作目的                    RHEL 10                             Ubuntu
─────────────────────────────────────────────────────────────────────────────────
进入救援模式(启动时)       在grub菜单按'e'，在linux行末尾添加:  recovery mode (从GRUB选择)
                           rd.break                            
进入紧急模式               systemctl rescue                    systemctl rescue
重置root密码(救援模式)     1. rd.break                        1. recovery mode -> drop to root
                          2. mount -o remount,rw /sysroot     2. mount -o remount,rw /
                          3. chroot /sysroot                  3. passwd root
                          4. passwd root                      
修复fstab错误              rd.break进入后:                      recovery mode 或
                           mount -o remount,rw /sysroot        fsck /dev/sda1
                           vim /sysroot/etc/fstab             
重新生成initramfs          dracut -f                          update-initramfs -u
更新GRUB配置               grub2-mkconfig -o /boot/grub2/      update-grub
                           grub.cfg                           
查看系统日志(启动时)       journalctl -b -p err               journalctl -b -p err
查看硬件信息               lspci, lsusb, lscpu                lspci, lsusb, lscpu
查看内存信息               free -h                             free -h
查看磁盘I/O                iostat                              iostat
查看CPU负载                top / htop                         top / htop
```

### 其他常用命令差异

```Shell
操作目的                    RHEL 10                             Ubuntu
─────────────────────────────────────────────────────────────────────────────────
查看发行版信息             cat /etc/redhat-release            cat /etc/os-release
查看内核版本               uname -r                            uname -r
查看系统架构               arch                                arch
文本编辑器                  vi (默认) 或 vim                   vi 或 vim
日志文件目录               /var/log/messages                  /var/log/syslog
                           /var/log/secure (认证日志)          /var/log/auth.log
                           /var/log/maillog                   /var/log/mail.log
                           /var/log/cron                      /var/log/cron.log (需配置)
启动脚本位置               /etc/rc.d/rc.local                 /etc/rc.local
时间同步                   chrony (默认)                       chrony 或 systemd-timesyncd
                           /etc/chrony.conf                   /etc/chrony.conf
切换到root                 su -                                su -
执行单条root命令           sudo <command>                      sudo <command>
查看命令路径               which <command>                     which <command>
查找文件                   find / -name <file>                find / -name <file>
搜索文件内容               grep -r "text" /path               grep -r "text" /path
归档压缩                   tar -czf archive.tar.gz /path      tar -czf archive.tar.gz /path
解压                       tar -xzf archive.tar.gz            tar -xzf archive.tar.gz



关键差异点                  RHEL 10 特性                       Ubuntu 不同之处
─────────────────────────────────────────────────────────────────────────────────
默认文件系统                XFS                                 ext4
默认防火墙                  firewalld                           ufw
强制访问控制                SELinux                             AppArmor
软件包格式                  RPM (.rpm)                          DEB (.deb)
包管理器                    DNF                                 APT
网络配置工具                nmcli (NetworkManager)              netplan
服务管理                    systemd (通用)                      systemd (通用)
系统日志                    journald (通用)                     journald (通用)
默认Shell                   bash (通用)                         bash (通用)
容器引擎                   Podman (无守护进程)                 Docker (有守护进程)
默认仓库                   Red Hat CDN / 订阅                 Ubuntu Archive
启动引导器                 GRUB2 (通用)                        GRUB2 (通用)
救援模式                   rd.break (内核参数)                 recovery mode (GRUB菜单)
```

# RHCSA备考

```Shell
===============================================================================
1.  理解和使用基础工具 (Understand and Use Essential Tools)
===============================================================================
    - Shell环境与命令基础
        - 访问shell提示符，使用正确语法发出命令
        - 使用输入输出重定向 (>, >>, |, 2>, &> 等)
        - 使用grep和正则表达式分析文本
        - 使用SSH访问远程系统
        - 在多用户目标中登录和切换用户
    - 文件与目录管理
        - 创建、删除、复制和移动文件与目录
        - 创建硬链接和软链接
        - 使用tar、gzip、bzip2进行文件归档与压缩
    - 文本处理与文档
        - 创建和编辑文本文件（使用vim等编辑器）
        - 查找、读取和使用系统文档 (man, info, /usr/share/doc)
    - 权限基础
        - 列出、设置和更改标准 ugo/rwx 权限

===============================================================================
2.  管理软件 (Manage Software)
===============================================================================
    - RPM包管理
        - 配置对RPM仓库的访问权限
        - 使用dnf安装和删除RPM软件包
    - Flatpak应用管理
        - 配置对Flatpak仓库的访问权限
        - 安装和删除Flatpak软件包

===============================================================================
3.  创建简单的Shell脚本 (Create Simple Shell Scripts)
===============================================================================
    - 条件执行结构 (if, test, [] 等)
    - 循环结构 (for 等) 用于处理文件或命令行输入
    - 处理脚本输入 ($1, $2 等)
    - 在脚本中处理shell命令的输出

===============================================================================
4.  运维运行中的系统 (Operate Running Systems)
===============================================================================
    - 系统启动与目标管理
        - 正常启动、重启和关闭系统
        - 手动将系统启动到不同目标（target）
        - 中断启动流程以获取系统访问权限（救援模式）
    - 进程管理
        - 识别CPU/内存密集型进程并终止进程
        - 调整进程调度优先级 (nice/renice)
    - 性能调优
        - 管理调优配置文件 (tuned)
    - 日志管理
        - 查找和解读系统日志 (journalctl)
        - 保留系统日志
    - 网络服务管理
        - 启动、停止和检查网络服务状态 (systemctl)
        - 在系统间安全地传输文件 (scp, rsync)

===============================================================================
5.  配置本地存储 (Configure Local Storage)
===============================================================================
    - 分区管理
        - 列出、创建和删除GPT磁盘上的分区 (gdisk, parted)
    - LVM逻辑卷管理
        - 创建和删除物理卷 (pvcreate, pvremove)
        - 将物理卷分配给卷组 (vgcreate, vgextend)
        - 创建和删除逻辑卷 (lvcreate, lvremove)
    - 挂载与持久化
        - 配置系统在启动时根据UUID或标签挂载文件系统 (/etc/fstab)
        - 无损地为系统添加新分区、逻辑卷和交换空间

===============================================================================
6.  创建和配置文件系统 (Create and Configure File Systems)
===============================================================================
    - 文件系统操作
        - 创建、挂载、卸载和使用 VFAT, ext4, XFS 文件系统
        - 扩展现有逻辑卷及其上的文件系统
    - 网络文件系统 (NFS)
        - 使用NFS挂载和卸载网络文件系统
        - 配置autofs自动挂载
    - 权限问题诊断
        - 诊断和修复文件权限问题
        - 创建和配置set-GID目录以实现协作

===============================================================================
7.  部署、配置和维护系统 (Deploy, Configure, and Maintain Systems)
===============================================================================
    - 任务调度
        - 使用 at 调度一次性任务
        - 使用 cron 调度周期性任务
        - 使用 systemd timer 单元调度任务
    - 服务管理
        - 配置服务在系统启动时自动启动 (systemctl enable)
        - 配置系统自动启动到特定目标
    - 系统更新与引导
        - 从CDN、远程仓库或本地文件系统安装和更新软件包
        - 修改系统引导加载程序 (grub2)
    - 时间同步
        - 配置时间服务客户端 (chrony)

===============================================================================
8.  管理基本网络 (Manage Basic Networking)
===============================================================================
    - IP地址配置
        - 配置IPv4和IPv6地址 (nmcli)
    - 名称解析
        - 配置主机名解析 (/etc/hosts, DNS)
    - 网络服务
        - 配置网络服务在系统启动时自动启动
        - 使用 firewalld 和 firewall-cmd 限制网络访问

===============================================================================
9.  管理用户和组 (Manage Users and Groups)
===============================================================================
    - 用户账户管理
        - 创建、删除和修改本地用户账户 (useradd, usermod, userdel)
        - 更改密码和调整密码老化策略 (passwd, chage)
    - 组管理
        - 创建、删除和修改本地组及组成员资格 (groupadd, groupmod)
    - 权限委派
        - 配置超级用户访问权限 (sudo)

===============================================================================
10. 管理安全 (Manage Security)
===============================================================================
    - 防火墙
        - 使用firewall-cmd/firewalld配置防火墙设置
    - SELinux
        - 将SELinux设置为强制(enforcing)和许可(permissive)模式
        - 列出和识别SELinux文件与进程上下文
        - 恢复默认文件上下文 (restorecon)
        - 管理SELinux端口标签 (semanage port)
        - 使用布尔值设置修改系统SELinux行为 (setsebool)
    - SSH安全
        - 为SSH配置基于密钥的身份验证
    - 文件权限
        - 管理默认文件权限 (umask)

===============================================================================
11. 管理容器 (Manage Containers) [根据部分考试目标包含]
===============================================================================
    - 容器管理命令 (podman, skopeo)
    - 从远程仓库查找和检索容器镜像
    - 检查容器镜像
    - 运行、启动、停止和列出容器
    - 在容器内运行服务
    - 将容器配置为systemd服务以自动启动
    - 为容器附加持久化存储
```

