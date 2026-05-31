#!/bin/bash

# 颜色定义
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

# 检查root权限
[[ $EUID -ne 0 ]] && echo -e "${red}Fatal error: Please run this script with root privilege${plain}" && exit 1

arch() {
    case "$(uname -m)" in
    x86_64 | x64 | amd64) echo 'amd64' ;;
    aarch64) echo 'arm64' ;;
    *) echo 'amd64' ;;
    esac
}

install_base() {
    apt-get update && apt-get install -y -q wget curl tar sqlite3
}

config_after_install() {
    # 统一设置面板端口及账户
    /usr/local/x-ui/x-ui setting -username "1399" -password "1399" -port 1399
    /usr/local/x-ui/x-ui migrate
    
    # 清理旧数据并重启
    systemctl restart x-ui
    
    server_ip=$(curl -s https://api.ipify.org)
    
    echo -e "###############################################"
    echo -e "${green}面板安装完毕！${plain}"
    echo -e "${green}管理地址: http://${server_ip}:1399${plain}"
    echo -e "${yellow}请手动在网页端点击“添加入站”创建 Reality 节点。${plain}"
    echo -e "${cyan}创建后记得在节点编辑页底部点击“获取新证书”和“获取新 Seed”！${plain}"
    echo -e "###############################################"
}

install_x-ui() {
    cd /usr/local/
    tag_version=$(curl -Ls "https://api.github.com/repos/MHSanaei/3x-ui/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    wget -N -O /usr/local/x-ui-linux-$(arch).tar.gz https://github.com/MHSanaei/3x-ui/releases/download/${tag_version}/x-ui-linux-$(arch).tar.gz
    
    [[ -d /usr/local/x-ui/ ]] && rm -rf /usr/local/x-ui/
    tar zxvf x-ui-linux-$(arch).tar.gz && rm x-ui-linux-$(arch).tar.gz
    cd x-ui && chmod +x x-ui bin/xray-linux-*
    
    # 复制服务文件
    cp -f x-ui.service /etc/systemd/system/
    
    # 确保命令脚本存在
    wget -O /usr/bin/x-ui https://raw.githubusercontent.com/qq1205362008/sunbin/refs/heads/main/x-ui.sh
    chmod +x /usr/bin/x-ui
    
    config_after_install
    systemctl daemon-reload && systemctl enable x-ui && systemctl start x-ui
}

install_base
install_x-ui
