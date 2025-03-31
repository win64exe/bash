#!/bin/bash

# Цветовые коды
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # Сброс цвета

# Проверка на root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}Этот скрипт должен быть запущен с правами root!${NC}"
    exit 1
fi

# Определение внешнего интерфейса и IP
DEFAULT_IFACE=$(ip route | grep '^default' | awk '{print $5}' | head -n1)
SERVER_IP=$(curl -s ifconfig.me || ip addr show $DEFAULT_IFACE | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)

# Функция для вывода данных подключения
show_credentials() {
    local username=$1
    local password=$2
    
    echo -e "\n${GREEN}=== ДАННЫЕ ДЛЯ ПОДКЛЮЧЕНИЯ ===${NC}"
    echo -e "${BLUE}IP сервера:${NC} $SERVER_IP"
    echo -e "${BLUE}Логин:${NC} $username"
    echo -e "${BLUE}Пароль:${NC} $password"
    echo -e "${GREEN}===========================${NC}"
}

# Функция для установки xl2tpd
install_xl2tpd() {
    echo -e "${BLUE}Установка xl2tpd и необходимых компонентов...${NC}"
    
    if ! sudo apt update; then
        echo -e "${RED}Ошибка при обновлении пакетов!${NC}"
        exit 1
    fi
    
    if ! sudo apt install -y xl2tpd iptables; then
        echo -e "${RED}Ошибка при установке пакетов!${NC}"
        exit 1
    fi

    # Конфигурация xl2tpd
    sudo mkdir -p /etc/xl2tpd
    sudo bash -c 'cat > /etc/xl2tpd/xl2tpd.conf << EOL
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
EOL'

    # Настройки PPP
    sudo bash -c 'cat > /etc/ppp/options.xl2tpd << EOL
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
EOL'

    # Настройка файла аутентификации
    sudo touch /etc/ppp/chap-secrets
    sudo chmod 600 /etc/ppp/chap-secrets

    # Настройка NAT
    echo -e "${YELLOW}Используется интерфейс: $DEFAULT_IFACE${NC}"
    sudo iptables -t nat -A POSTROUTING -s 10.2.2.0/24 -o $DEFAULT_IFACE -j MASQUERADE
    
    # Сохранение правил iptables
    sudo mkdir -p /etc/iptables
    sudo sh -c "iptables-save > /etc/iptables/rules.v4"

    # Включение переадресации IP
    sudo sysctl -w net.ipv4.ip_forward=1
    sudo sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf

    # Запуск службы
    sudo systemctl restart xl2tpd
    sudo systemctl enable xl2tpd

    echo -e "${GREEN}Установка завершена успешно!${NC}"
}

# Функция для добавления пользователя
add_user() {
    echo -e "${BLUE}Добавление нового пользователя L2TP...${NC}"
    
    while true; do
        read -p "Введите имя пользователя: " username
        if [ -z "$username" ]; then
            echo -e "${RED}Имя пользователя не может быть пустым!${NC}"
            continue
        fi
        
        if grep -q "^$username " /etc/ppp/chap-secrets; then
            echo -e "${YELLOW}Пользователь $username уже существует!${NC}"
            read -p "Хотите изменить пароль для этого пользователя? (y/n): " change
            if [[ "$change" =~ ^[YyДд] ]]; then
                sudo sed -i "/^$username /d" /etc/ppp/chap-secrets
            else
                continue
            fi
        fi
        break
    done
    
    while true; do
        read -s -p "Введите пароль: " password
        echo
        if [ -z "$password" ]; then
            echo -e "${RED}Пароль не может быть пустым!${NC}"
            continue
        fi
        
        read -s -p "Повторите пароль: " password_confirm
        echo
        if [ "$password" != "$password_confirm" ]; then
            echo -e "${RED}Пароли не совпадают!${NC}"
            continue
        fi
        break
    done
    
    # Добавление пользователя
    sudo bash -c "echo '$username l2tp-vpn $password *' >> /etc/ppp/chap-secrets"
    sudo systemctl restart xl2tpd
    
    # Вывод данных для подключения
    show_credentials "$username" "$password"
}

# Функция для удаления пользователя
remove_user() {
    echo -e "${BLUE}Удаление пользователя L2TP...${NC}"
    
    if [ ! -f /etc/ppp/chap-secrets ] || [ ! -s /etc/ppp/chap-secrets ]; then
        echo -e "${RED}Файл chap-secrets пуст или не существует!${NC}"
        return 1
    fi
    
    echo -e "${BLUE}Список пользователей:${NC}"
    echo "----------------------------------------"
    awk '$2 == "l2tp-vpn" {print "Имя пользователя: " $1}' /etc/ppp/chap-secrets
    echo "----------------------------------------"
    
    while true; do
        read -p "Введите имя пользователя для удаления (или 'q' для выхода): " username
        
        if [ "$username" = "q" ]; then
            return 0
        fi
        
        if grep -q "^$username " /etc/ppp/chap-secrets; then
            sudo sed -i "/^$username /d" /etc/ppp/chap-secrets
            sudo systemctl restart xl2tpd
            echo -e "${GREEN}Пользователь $username успешно удален!${NC}"
            return 0
        else
            echo -e "${RED}Пользователь $username не найден!${NC}"
        fi
    done
}

# Функция для удаления xl2tpd
remove_xl2tpd() {
    echo -e "${YELLOW}Внимание! Будут удалены все настройки xl2tpd!${NC}"
    read -p "Вы уверены, что хотите продолжить? (y/n): " confirm
    
    if [[ ! "$confirm" =~ ^[YyДд] ]]; then
        echo -e "${BLUE}Удаление отменено.${NC}"
        return
    fi

    echo -e "${BLUE}Удаление xl2tpd...${NC}"

    sudo systemctl stop xl2tpd 2>/dev/null
    sudo systemctl disable xl2tpd 2>/dev/null

    sudo apt purge -y xl2tpd
    sudo apt autoremove -y

    sudo rm -f /etc/xl2tpd/xl2tpd.conf
    sudo rm -f /etc/ppp/options.xl2tpd
    sudo rm -f /etc/ppp/chap-secrets

    if iptables -t nat -C POSTROUTING -s 10.2.2.0/24 -o $DEFAULT_IFACE -j MASQUERADE 2>/dev/null; then
        sudo iptables -t nat -D POSTROUTING -s 10.2.2.0/24 -o $DEFAULT_IFACE -j MASQUERADE
        sudo sh -c "iptables-save > /etc/iptables/rules.v4"
    fi

    sudo sysctl -w net.ipv4.ip_forward=0
    sudo sed -i 's/net.ipv4.ip_forward=1/#net.ipv4.ip_forward=1/' /etc/sysctl.conf

    echo -e "${GREEN}xl2tpd успешно удален!${NC}"
}

# Главное меню
while true; do
    echo -e "\n${BLUE}Выберите действие:${NC}"
    echo -e "${GREEN}1. Установить xl2tpd${NC}           ${YELLOW}(1)${NC}"
    echo -e "${GREEN}2. Добавить пользователя L2TP${NC} ${YELLOW}(2)${NC}"
    echo -e "${GREEN}3. Удалить пользователя${NC}       ${YELLOW}(3)${NC}"
    echo -e "${GREEN}4. Удалить xl2tpd${NC}            ${YELLOW}(4)${NC}"
    echo -e "${GREEN}5. Выход${NC}                     ${YELLOW}(5)${NC}"
    read -p "Введите номер действия (1-5): " choice

    case $choice in
        1)
            install_xl2tpd
            ;;
        2)
            add_user
            ;;
        3)
            remove_user
            ;;
        4)
            remove_xl2tpd
            ;;
        5)
            echo -e "${BLUE}Выход...${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Неверный выбор! Пожалуйста, выберите 1-5.${NC}"
            ;;
    esac
done
