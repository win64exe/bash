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

# Функция проверки интернет-соединения
check_internet() {
    echo -e "${BRIGHT_BLUE}Проверка интернет-соединения...${NC}"
    if ! ping -c 2 -W 3 8.8.8.8 &>/dev/null; then
        echo -e "${BRIGHT_YELLOW}Предупреждение: Нет интернет-соединения! Некоторые функции могут работать ограниченно.${NC}"
        return 1
    fi
    return 0
}

# Определение IP и интерфейса
determine_network() {
    DEFAULT_IFACE=$(ip route | grep '^default' | awk '{print $5}' | head -n1)
    
    # Проверяем несколько способов определения IP
    check_internet && {
        SERVER_IP=$(curl -s --connect-timeout 3 ifconfig.me || 
                   curl -s --connect-timeout 3 icanhazip.com || 
                   curl -s --connect-timeout 3 ifconfig.co)
    }
    
    # Если не удалось получить внешний IP или нет интернета
    if [ -z "$SERVER_IP" ] || [[ "$SERVER_IP" == *"no healthy"* ]]; then
        SERVER_IP=$(ip addr show $DEFAULT_IFACE | grep 'inet ' | awk '{print $2}' | cut -d/ -f1 | head -n1)
        [ -z "$SERVER_IP" ] && SERVER_IP=$(hostname -I | awk '{print $1}')
    fi
    
    # Если всё ещё не определили IP
    [ -z "$SERVER_IP" ] && SERVER_IP="[не удалось определить]"
}

# Инициализация сети
determine_network

show_credentials() {
    local username=$1
    local password=$2
    
    # Обновляем IP перед показом
    determine_network
    
    echo -e "\n${BRIGHT_GREEN}=== ДАННЫЕ ДЛЯ ПОДКЛЮЧЕНИЯ ===${NC}"
    echo -e "${BRIGHT_BLUE}IP сервера:${NC} $SERVER_IP"
    echo -e "${BRIGHT_BLUE}Интерфейс:${NC} $DEFAULT_IFACE"
    echo -e "${BRIGHT_BLUE}Логин:${NC} $username"
    echo -e "${BRIGHT_BLUE}Пароль:${NC} $password"
    echo -e "${BRIGHT_GREEN}===========================${NC}"
}

install_xl2tpd() {
    echo -e "${BRIGHT_BLUE}Установка xl2tpd и необходимых компонентов...${NC}"
    
    # Проверка поддержки ОС
    if ! grep -qiE "ubuntu|debian" /etc/os-release; then
        echo -e "${BRIGHT_RED}Ошибка: Этот скрипт поддерживает только Ubuntu/Debian!${NC}"
        return 1
    fi
    
    apt update || {
        echo -e "${BRIGHT_RED}Ошибка при обновлении пакетов!${NC}"
        return 1
    }
    
    # ИЗМЕНЕНО: Добавлен iptables-persistent
    apt install -y xl2tpd iptables iptables-persistent || {
        echo -e "${BRIGHT_RED}Ошибка при установке пакетов!${NC}"
        return 1
    }

    # Создаем резервную копию конфигов, если они существуют
    [ -f "/etc/xl2tpd/xl2tpd.conf" ] && cp "/etc/xl2tpd/xl2tpd.conf" "/etc/xl2tpd/xl2tpd.conf.bak"
    [ -f "/etc/ppp/options.xl2tpd" ] && cp "/etc/ppp/options.xl2tpd" "/etc/ppp/options.xl2tpd.bak"

    # ИЗМЕНЕНО: Проверка переменных перед созданием конфига
    [ -z "$DEFAULT_IFACE" ] && {
        echo -e "${BRIGHT_RED}Ошибка: Не удалось определить сетевой интерфейс!${NC}"
        return 1
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
length bit = yes
require chap = yes
require authentication = yes
tunnel rws = 8
name = l2tp-vpn
pppoptfile = /etc/ppp/options.xl2tpd
flow bit = yes
EOL

    cat > /etc/ppp/options.xl2tpd <<EOL
asyncmap 0
auth
mtu 1500
mru 1500
lcp-echo-interval 60
lcp-echo-failure 8
noipx
novj
refuse-pap
refuse-chap
refuse-mschap
require-mschap-v2
ms-dns 1.1.1.1
ms-dns 8.8.8.8
EOL

    touch /etc/ppp/chap-secrets
    chmod 600 /etc/ppp/chap-secrets

    echo -e "${BRIGHT_YELLOW}Используется интерфейс: $DEFAULT_IFACE${NC}"
    
    # ИЗМЕНЕНО: Проверка существования правила iptables
    if ! iptables -t nat -C POSTROUTING -s 10.2.2.0/24 -o $DEFAULT_IFACE -j MASQUERADE 2>/dev/null; then
        iptables -t nat -A POSTROUTING -s 10.2.2.0/24 -o $DEFAULT_IFACE -j MASQUERADE
    fi
    
    mkdir -p /etc/iptables
    iptables-save > /etc/iptables/rules.v4

    sysctl -w net.ipv4.ip_forward=1
    sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf

    systemctl restart xl2tpd
    systemctl enable xl2tpd >/dev/null 2>&1

    echo -e "${BRIGHT_GREEN}Установка завершена успешно!${NC}"
}

generate_password() {
    local length=${1:-12}
    tr -dc 'A-Za-z0-9!@#$%^&*()' </dev/urandom | head -c $length
}

add_user() {
    echo -e "${BRIGHT_BLUE}Добавление нового пользователя L2TP...${NC}"
    
    while true; do
        read -p "Введите имя пользователя: " username
        [ -z "$username" ] && {
            echo -e "${BRIGHT_RED}Имя пользователя не может быть пустым!${NC}"
            continue
        }
        
        if grep -q "^$username " /etc/ppp/chap-secrets; then
            echo -e "${BRIGHT_YELLOW}Пользователь $username уже существует!${NC}"
            read -p "Хотите изменить пароль для этого пользователя? (y/n): " change
            # ИЗМЕНЕНО: Использование awk вместо sed
            [[ "$change" =~ ^[YyДд] ]] && {
                awk -v user="$username" '$1 != user' /etc/ppp/chap-secrets > /tmp/chap_temp && 
                mv /tmp/chap_temp /etc/ppp/chap-secrets
            } || continue
        fi
        break
    done
    
    read -s -p "Введите пароль (оставьте пустым для автоматической генерации): " password
    echo
    
    [ -z "$password" ] && {
        password=$(generate_password)
        echo -e "${BRIGHT_YELLOW}Сгенерирован пароль: $password${NC}"
    }
    
    echo "$username l2tp-vpn $password *" >> /etc/ppp/chap-secrets
    systemctl restart xl2tpd
    
    show_credentials "$username" "$password"
}

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
        
        [ "$username" = "q" ] && return 0
        
        if grep -q "^$username " /etc/ppp/chap-secrets; then
            # ИЗМЕНЕНО: Использование awk вместо sed
            awk -v user="$username" '$1 != user' /etc/ppp/chap-secrets > /tmp/chap_temp && 
            mv /tmp/chap_temp /etc/ppp/chap-secrets
            systemctl restart xl2tpd
            echo -e "${BRIGHT_GREEN}Пользователь $username успешно удален!${NC}"
            return 0
        else
            echo -e "${BRIGHT_RED}Пользователь $username не найден!${NC}"
        fi
    done
}

remove_xl2tpd() {
    echo -e "${BRIGHT_YELLOW}Внимание! Будут удалены все настройки xl2tpd!${NC}"
    read -p "Вы уверены, что хотите продолжить? (y/n): " confirm
    
    [[ "$confirm" =~ ^[YyДд] ]] || {
        echo -e "${BRIGHT_BLUE}Удаление отменено.${NC}"
        return
    }

    echo -e "${BRIGHT_BLUE}Удаление xl2tpd...${NC}"

    systemctl stop xl2tpd 2>/dev/null
    systemctl disable xl2tpd 2>/dev/null

    apt purge -y xl2tpd
    apt autoremove -y

    rm -f /etc/xl2tpd/xl2tpd.conf
    rm -f /etc/ppp/options.xl2tpd
    rm -f /etc/ppp/chap-secrets

    # ИЗМЕНЕНО: Проверка существования правила перед удалением
    if iptables -t nat -C POSTROUTING -s 10.2.2.0/24 -o $DEFAULT_IFACE -j MASQUERADE 2>/dev/null; then
        iptables -t nat -D POSTROUTING -s 10.2.2.0/24 -o $DEFAULT_IFACE -j MASQUERADE
        iptables-save > /etc/iptables/rules.v4
    fi

    sysctl -w net.ipv4.ip_forward=0
    sed -i 's/net.ipv4.ip_forward=1/#net.ipv4.ip_forward=1/' /etc/sysctl.conf

    echo -e "${BRIGHT_GREEN}xl2tpd успешно удален!${NC}"
}

while true; do
    echo -e "\n${BRIGHT_BLUE}╔══════════════════════════════╗${NC}"
    echo -e "${BRIGHT_BLUE}║          МЕНЮ ВЫБОРА         ║${NC}"
    echo -e "${BRIGHT_BLUE}╠══════════════════════════════╣${NC}"
    echo -e "${BRIGHT_BLUE}║ [1] Установить xl2tpd        ║${NC}"
    echo -e "${BRIGHT_BLUE}║ [2] Добавить пользователя    ║${NC}"
    echo -e "${BRIGHT_BLUE}║ [3] Удалить пользователя     ║${NC}"
    echo -e "${BRIGHT_BLUE}║ [4] Удалить xl2tpd           ║${NC}"
    echo -e "${BRIGHT_BLUE}║ [5] Проверить подключение    ║${NC}"
    echo -e "${BRIGHT_BLUE}║ [6] Выход                    ║${NC}"
    echo -e "${BRIGHT_BLUE}╚══════════════════════════════╝${NC}"
    read -p "Выберите действие [1-6]: " choice

    case $choice in
        1) install_xl2tpd ;;
        2) add_user ;;
        3) remove_user ;;
        4) remove_xl2tpd ;;
        5) check_internet ;;
        6)
            echo -e "${BRIGHT_BLUE}Выход...${NC}"
            exit 0
            ;;
        *) echo -e "${BRIGHT_RED}Неверный выбор! Пожалуйста, выберите 1-6.${NC}" ;;
    esac
done
