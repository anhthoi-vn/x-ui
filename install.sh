#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Chú ý：${plain} Tập lệnh này phải được chạy với tư cách người dùng gốc(root)！\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    echo -e "${red}Phiên bản hệ thống không được phát hiện, vui lòng liên hệ với tác giả！${plain}\n" && exit 1
fi

arch=$(arch)

if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
    arch="amd64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
    arch="arm64"
elif [[ $arch == "s390x" ]]; then
    arch="s390x"
else
    arch="amd64"
  echo -e "${red}Không phát hiện được, hãy sử dụng mặc định : ${arch}${plain}"
fi

echo "架构: ${arch}"

if [ $(getconf WORD_BIT) != '32' ] && [ $(getconf LONG_BIT) != '64' ]; then
    echo "Phần mềm này không hỗ trợ hệ thống 32-bit (x86), vui lòng sử dụng hệ thống 64-bit (x86_64). Nếu phát hiện sai, vui lòng liên hệ với tác giả"
    exit -1
fi

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}Vui lòng sử dụng hệ điều hành CentOS 7 trở lên！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}ui lòng sử dụng hệ điều hành Ubuntu 16 trở lên！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}ui lòng sử dụng hệ điều hành Debian 8 trở lên！${plain}\n" && exit 1
    fi
fi

install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install wget curl tar -y
    else
        apt install wget curl tar -y
    fi
}

#This function will be called when user installed x-ui out of sercurity
config_after_install() {
    echo -e "${yellow}出于安全考虑，安装/更新完成后需要强制修改端口与账户密码${plain}"
    read -p "确认是否继续?[y/n]": config_confirm
    if [[ x"${config_confirm}" == x"y" || x"${config_confirm}" == x"Y" ]]; then
        read -p "请设置您的账户名:" config_account
        echo -e "${yellow}您的账户名将设定为:${config_account}${plain}"
        read -p "请设置您的账户密码:" config_password
        echo -e "${yellow}您的账户密码将设定为:${config_password}${plain}"
        read -p "请设置面板访问端口:" config_port
        echo -e "${yellow}您的面板访问端口将设定为:${config_port}${plain}"
        echo -e "${yellow}确认设定,设定中${plain}"
        /usr/local/x-ui/x-ui setting -username ${config_account} -password ${config_password}
        echo -e "${yellow}账户密码设定完成${plain}"
        /usr/local/x-ui/x-ui setting -port ${config_port}
        echo -e "${yellow}面板端口设定完成${plain}"
    else
        echo -e "${red}已取消,所有设置项均为默认设置,请及时修改${plain}"
    fi
}

install_x-ui() {
    systemctl stop x-ui
    cd /usr/local/

    if [ $# == 0 ]; then
        last_version=$(curl -Ls "https://api.github.com/repos/anhthoi-vn/x-ui/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            echo -e "${red}Không phát hiện được phiên bản x-ui, phiên bản này có thể vượt quá giới hạn API Github. Vui lòng thử lại sau hoặc chỉ định phiên bản x-ui để cài đặt theo cách thủ công${plain}"
            exit 1
        fi
        echo -e "Đã phát hiện phiên bản mới nhất của x-ui：${last_version}，bắt đầu cài đặt"
        wget -N --no-check-certificate -O /usr/local/x-ui-linux-${arch}.tar.gz https://github.com/anhthoi-vn/x-ui/releases/download/${last_version}/x-ui-linux-${arch}.tar.gz
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Tải xuống x-ui không thành công, vui lòng đảm bảo máy chủ của bạn có thể tải xuống tệp Github${plain}"
            exit 1
        fi
    else
        last_version=$1
        url="https://github.com/anhthoi-vn/x-ui/releases/download/${last_version}/x-ui-linux-${arch}.tar.gz"
        echo -e "Bắt đầu cài đặt x-ui v$1"
        wget -N --no-check-certificate -O /usr/local/x-ui-linux-${arch}.tar.gz ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Tải xuống x-ui v$1 Không thành công, hãy đảm bảo rằng phiên bản này tồn tại ${plain}"
            exit 1
        fi
    fi

    if [[ -e /usr/local/x-ui/ ]]; then
        rm /usr/local/x-ui/ -rf
    fi

    tar zxvf x-ui-linux-${arch}.tar.gz
    rm x-ui-linux-${arch}.tar.gz -f
    cd x-ui
    chmod +x x-ui bin/xray-linux-${arch}
    cp -f x-ui.service /etc/systemd/system/
    wget --no-check-certificate -O /usr/bin/x-ui https://raw.githubusercontent.com/anhthoi-vn/x-ui/main/x-ui.sh
    chmod +x /usr/local/x-ui/x-ui.sh
    chmod +x /usr/bin/x-ui
    config_after_install
    #echo -e "如果是全新安装，默认网页端口为 ${green}54321${plain}，用户名和密码默认都是 ${green}admin${plain}"
    #echo -e "请自行确保此端口没有被其他程序占用，${yellow}并且确保 54321 端口已放行${plain}"
    #    echo -e "若想将 54321 修改为其它端口，输入 x-ui 命令进行修改，同样也要确保你修改的端口也是放行的"
    #echo -e ""
    #echo -e "如果是更新面板，则按你之前的方式访问面板"
    #echo -e ""
    systemctl daemon-reload
    systemctl enable x-ui
    systemctl start x-ui
    echo -e "${green}x-ui v${last_version}${plain} Quá trình cài đặt hoàn tất và bảng điều khiển đã bắt đầu，"
    echo -e ""
    echo -e "Nếu đó là cài đặt mới, cổng web mặc định là ${green}54321${plain}，Tên người dùng và mật khẩu đều theo mặc định ${green}admin${plain}"
    echo -e "Hãy đảm bảo rằng cổng(port) này không bị các chương trình khác chiếm giữ，${yellow}Và chắc rằng 54321 Cổng(port) đã được mở${plain}"
#    echo -e "Nếu bạn muốn sửa đổi 54321 thành một cổng khác, hãy nhập lệnh x-ui để sửa đổi và đảm bảo rằng cổng đã sửa đổi đã được mở"
    echo -e ""
    echo -e "Nếu đó là để cập nhật bảng điều khiển, hãy truy cập bảng điều khiển như bạn đã làm trước đây "
    echo -e ""
    echo -e "x-ui Cách sử dụng lệnh để quản lý : "
    echo -e "----------------------------------------------"
    echo -e "x-ui              - Menu quản lý màn hình (nhiều chức năng hơn) "
    echo -e "x-ui start        - Khởi chạy bảng điều khiển x-ui"
    echo -e "x-ui stop         - Dừng bảng điều khiển x-ui"
    echo -e "x-ui restart      - Khởi động lại bảng điều khiển x-ui"
    echo -e "x-ui status       - Xem trạng thái x-ui"
    echo -e "x-ui enable       - Đặt x-ui tự động khởi động"
    echo -e "x-ui disable      - Hủy x-ui tự khởi động"
    echo -e "x-ui log          - Xem nhật ký x-ui"
    echo -e "x-ui v2-ui        - Di chuyển dữ liệu tài khoản từ bản v2-ui sang x-ui"
    echo -e "x-ui update       - Cập nhật bảng điều khiển x-ui"
    echo -e "x-ui install      - Cài đặt bảng điều khiển x-ui"
    echo -e "x-ui uninstall    - Gỡ cài đặt bảng điều khiển x-ui"
    echo -e "----------------------------------------------"
}

echo -e "${green}Bắt đầu cài đặt${plain}"
install_base
install_x-ui $1
