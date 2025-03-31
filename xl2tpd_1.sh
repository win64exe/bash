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

# Функция для вывода данных подключения
show_credentials() {
    local username=$1
    local password=$2
    
    echo -e "\n${BRIGHT_GREEN}=== ДАННЫЕ ДЛЯ ПОДКЛЮЧЕНИЯ ===${NC}"
    echo -e "${BRIGHT_BLUE}IP сервера:${NC} $SERVER_IP"
    echo -e "${BRIGHT_BLUE}Логин:${NC} $username"
    echo -e "${BRIGHT_BLUE}Пароль:${NC} $password"
    echo -e "${BRIGHT_GREEN}===========================${NC}"
}

# Функция для установки xl2tpd
install_xl2tpd() {
    echo -e "${BRIGHT_BLUE}Установка xl2tpd и необходимых компонентов...${NC}"
    
    if ! sudo apt update; then
        echo -e "${BRIGHT_RED}Ошибка при обновлении пакетов!${NC}"
        exit 1
    fi
    
    if ! sudo apt install -y xl2tpd iptables; then
        echo -e "${BRIGHT_RED}Ошибка при установке пакетов!${NC}"
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
    echo -e "${BRIGHT_YELLOW}Используется интерфейс: $DEFAULT_IFACE${NC}"
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

    echo -e "${BRIGHT_GREEN}Установка завершена успешно!${NC}"
}

# Функция для добавления пользователя
add_user() {
    echo -e "${BRIGHT_BLUE}Добавление нового пользователя L2TP...${NC}"
    
    while true; do
        read -p "Введите имя пользователя: " username
        if [ -z "$username" ]; then
            echo -e "${BRIGHT_RED}Имя пользователя не может быть пустым!${NC}"
            continue
        fi
        
        if grep -q "^$username " /etc/ppp/chap-secrets; then
            echo -e "${BRIGHT_YELLOW}Пользователь $username уже существует!${NC}"
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
            echo -e "${BRIGHT_RED}Пароль не может быть пустым!${NC}"
            continue
        fi
        
        read -s -p "Повторите пароль: " password_confirm
        echo
        if [ "$password" != "$password_confirm" ]; then
            echo -e "${BRIGHT_RED}Пароли не совпадают!${NC}"
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
    echo -e "${BRIGHT_BLUE}Удаление пользователя L2TP...${NC}"
    
    if [ ! -f /etc/ppp/chap-secrets ] || [ ! -s /etc/ppp/chap-secrets ]; then
        echo -e "${BRIGHT_RED}Файл chap-secrets пуст или не существует!${NC}"
        return 1
    fi
    
    echo -e "${BRIGHT_BLUE}Список пользователей:${NC}"
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
            echo -e "${BRIGHT_GREEN}Пользователь $username успешно удален!${NC}"
            return 0
        else
            echo -e "${BRIGHT_RED}Пользователь $username не найден!${NC}"
        fi
    done
}

# Функция для удаления xl2tpd
remove_xl2tpd() {
    echo -e "${BRIGHT_YELLOW}Внимание! Будут удалены все настройки xl2tpd!${NC}"
    read -p "Вы уверены, что хотите продолжить? (y/n): " confirm
    
    if [[ ! "$confirm" =~ ^[YyДд] ]]; then
        echo -e "${BRIGHT_BLUE}Удаление отменено.${NC}"
        return
    fi

    echo -e "${BRIGHT_BLUE}Удаление xl2tpd...${NC}"

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

    echo -e "${BRIGHT_GREEN}xl2tpd успешно удален!${NC}"
}

# Главное меню
while true; do
    echo -e "\n${BRIGHT_BLUE}Выберите действие:${NC}"
    echo -e "${BRIGHT_GREEN}1. Установить xl2tpd${NC}           ${BRIGHT_YELLOW}(1)${NC}"
    echo -e "${BRIGHT_GREEN}2. Добавить пользователя L2TP${NC} ${BRIGHT_YELLOW}(2)${NC}"
    echo -e "${BRIGHT_GREEN}3. Удалить пользователя${NC}       ${BRIGHT_YELLOW}(3)${NC}"
    echo -e "${BRIGHT_GREEN}4. Удалить xl2tpd${NC}            ${BRIGHT_YELLOW}(4)${NC}"
    echo -e "${BRIGHT_GREEN}5. Выход${NC}                     ${BRIGHT_YELLOW}(5)${NC}"
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
            echo -e "${BRIGHT_BLUE}Выход...${NC}"
            exit 0
            ;;
        *)
            echo -e "${BRIGHT_RED}Неверный выбор! Пожалуйста, выберите 1-5.${NC}"
            ;;
    esac
done
