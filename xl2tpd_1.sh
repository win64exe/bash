#!/bin/bash

# Яркие цветовые коды
BRIGHT_GREEN='\033[1;92m'
BRIGHT_YELLOW='\033[1;93m'
BRIGHT_BLUE='\033[1;94m'
BRIGHT_RED='\033[1;91m'
NC='\033[0m' # Сброс цвета

# Проверка на root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${BRIGHT_RED}Этот скрипт должен быть запущен с правами root!${NC}"
    exit 1
fi

# Определение внешнего интерфейса и IP
DEFAULT_IFACE=$(ip route | grep '^default' | awk '{print $5}' | head -n1)
SERVER_IP=$(curl -s ifconfig.me || ip addr show $DEFAULT_IFACE | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)

show_credentials() {
    local username=$1
    local password=$2
    
    echo -e "\n${BRIGHT_GREEN}=== ДАННЫЕ ДЛЯ ПОДКЛЮЧЕНИЯ ===${NC}"
    echo -e "${BRIGHT_BLUE}IP сервера:${NC} $SERVER_IP"
    echo -e "${BRIGHT_BLUE}Логин:${NC} $username"
    echo -e "${BRIGHT_BLUE}Пароль:${NC} $password"
    echo -e "${BRIGHT_GREEN}===========================${NC}"
}

install_xl2tpd() {
    echo -e "${BRIGHT_BLUE}Установка xl2tpd и необходимых компонентов...${NC}"
    
    apt update || {
        echo -e "${BRIGHT_RED}Ошибка при обновлении пакетов!${NC}"
        exit 1
    }
    
    apt install -y xl2tpd iptables || {
        echo -e "${BRIGHT_RED}Ошибка при установке пакетов!${NC}"
        exit 1
    }

    mkdir -p /etc/xl2tpd
    cat > /etc/xl2tpd/xl2tpd.conf <<EOL
[global]
port = 1701
auth file = /etc/ppp/chap-secrets

[lns l2tp-vpn]
exclusive = yes
ip range = 10.2.2.100-10.2.2.199
local ip = 10.2.2.1
lac = 0.0.0.0-255.255.255.255
hidden bit = no
length bit = yes
require chap = yes
tunnel rws = 8
name = l2tp-vpn
pppoptfile = /etc/ppp/options.xl2tpd
flow bit = yes
EOL

    cat > /etc/ppp/options.xl2tpd <<EOL
asyncmap 0
auth
mtu 1400
mru 1400
lcp-echo-interval 60
lcp-echo-failure 4
noipx
refuse-pap
refuse-mschap
require-mschap-v2
novj
noccp
ms-dns 208.67.222.222
ms-dns 1.1.1.1
EOL

    touch /etc/ppp/chap-secrets
    chmod 600 /etc/ppp/chap-secrets

    echo -e "${BRIGHT_YELLOW}Используется интерфейс: $DEFAULT_IFACE${NC}"
    iptables -t nat -A POSTROUTING -s 10.2.2.0/24 -o $DEFAULT_IFACE -j MASQUERADE
    
    mkdir -p /etc/iptables
    iptables-save > /etc/iptables/rules.v4

    sysctl -w net.ipv4.ip_forward=1
    sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf

    systemctl restart xl2tpd
    systemctl enable xl2tpd >/dev/null 2>&1

    echo -e "${BRIGHT_GREEN}Установка завершена успешно!${NC}"
}

add_user() {
    echo -e "${
