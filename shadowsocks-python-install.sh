#!/usr/bin/env bash

#===================================================================#
#   System Required:  CentOS 7                                      #
#   Description: Install Shadowsocks server for CentOS 7            #
#   Author: ZSQ                                                     #
#   Thanks: @madeye <https://github.com/madeye>                     #
#===================================================================#

# Make sure only root can run our script
[[ $EUID -ne 0 ]] && echo -e "[${red}Error${plain}] This script must be run as root!" && exit 1

# Stream Ciphers define
ciphers=(
aes-256-gcm
aes-192-gcm
aes-128-gcm
aes-256-ctr
aes-192-ctr
aes-128-ctr
aes-256-cfb
aes-192-cfb
aes-128-cfb
camellia-128-cfb
camellia-192-cfb
camellia-256-cfb
xchacha20-ietf-poly1305
chacha20-ietf-poly1305
chacha20-ietf
chacha20
salsa20
rc4-md5
)

# Color define
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

# Disable selinux
disable_selinux(){
    if [ -s /etc/selinux/config ] && grep 'SELINUX=enforcing' /etc/selinux/config; then
        sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
        setenforce 0
    fi
}

# receive the user key
get_char(){
    SAVEDSTTY=`stty -g`
    stty -echo
    stty cbreak
    dd if=/dev/tty bs=1 count=1 2> /dev/null
    stty -raw
    stty echo
    stty $SAVEDSTTY
}

pre_install_shadowsocks(){
	# Set shadowsocks-libev config password
	echo "Please enter password for shadowsocks-libev:"
	read -p "(Default password: teddysun.com):" shadowsockspwd
	[ -z "${shadowsockspwd}" ] && shadowsockspwd="592541"
	echo
	echo "---------------------------"
	echo "password = ${shadowsockspwd}"
	echo "---------------------------"
	echo

	# Set shadowsocks-libev config port
	while true
	do
	echo -e "Please enter a port for shadowsocks-libev [1-65535]:"
	read -p "(Default port: 8989):" shadowsocksport
	[ -z "$shadowsocksport" ] && shadowsocksport="8989"
	expr ${shadowsocksport} + 1 &>/dev/null
	if [ $? -eq 0 ]; then
		if [ ${shadowsocksport} -ge 1 ] && [ ${shadowsocksport} -le 65535 ] && [ ${shadowsocksport:0:1} != 0 ]; then
			echo
			echo "---------------------------"
			echo "port = ${shadowsocksport}"
			echo "---------------------------"
			echo
			break
		fi
	fi
	echo -e "[${red}Error${plain}] Please enter a correct number [1-65535]"
	done

	# Set shadowsocks config stream ciphers
	while true
	do
	echo -e "Please select stream cipher for shadowsocks-libev:"
	for ((i=1;i<=${#ciphers[@]};i++ )); do
		hint="${ciphers[$i-1]}"
		echo -e "${green}${i}${plain}) ${hint}"
	done
	read -p "Which cipher you'd select(Default: ${ciphers[0]}):" pick
	[ -z "$pick" ] && pick=1
	expr ${pick} + 1 &>/dev/null
	if [ $? -ne 0 ]; then
		echo -e "[${red}Error${plain}] Please enter a number"
		continue
	fi
	if [[ "$pick" -lt 1 || "$pick" -gt ${#ciphers[@]} ]]; then
		echo -e "[${red}Error${plain}] Please enter a number between 1 and ${#ciphers[@]}"
		continue
	fi
	shadowsockscipher=${ciphers[$pick-1]}
	echo
	echo "---------------------------"
	echo "cipher = ${shadowsockscipher}"
	echo "---------------------------"
	echo
	break
	done

	echo
	echo "Press any key to start install...or press Ctrl+C to cancel"
	char=`get_char`
}

# Install Shadowsocks
install_shadowsocks(){
	yum install python-setuptools && easy_install pip
	pip install shadowsocks
}

# Config shadowsocks
config_shadowsocks(){
    local server_value="\"0.0.0.0\""

    if [ ! -d /etc ]; then
        mkdir -p /etc
    fi
    cat > /etc/shadowsocks.json<<-EOF
{
    "server":${server_value},
    "server_port":${shadowsocksport},
    "local_address":"127.0.0.1",
    "local_port":1080,
    "password":"${shadowsockspwd}",
    "timeout":600,
    "method":"${shadowsockscipher}"
}
EOF
}

# Firewall set
firewall_set(){
    echo -e "[${green}Info${plain}] firewall set start..."
    systemctl status firewalld > /dev/null 2>&1
	if [ $? -eq 0 ]; then
		firewall-cmd --permanent --zone=public --add-port=${shadowsocksport}/tcp
		firewall-cmd --permanent --zone=public --add-port=${shadowsocksport}/udp
		firewall-cmd --reload
	else
		echo -e "[${yellow}Warning${plain}] firewalld looks like not running or not installed, please enable port ${shadowsocksport} manually if necessary."
	fi
    echo -e "[${green}Info${plain}] firewall set completed..."
}

# start shadowsocks
start_shadowsocks(){
	ssserver -c /etc/shadowsocks.json -d start # Æô¶¯
}

# begin install
disable_selinux
pre_install_shadowsocks
install_shadowsocks
config_shadowsocks
firewall_set
start_shadowsocks