#!/bin/bash

# Цветовые коды
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # Сброс цвета

# Функция для получения IP-адреса сервера
get_server_ip() {
    ip addr | grep -oE "inet [0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}" | grep -oE "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}" | head -n 1
}

# Функция для установки xl2tpd и настройки
install_xl2tpd() {
    echo -e "${BLUE}Установка xl2tpd и необходимых компонентов...${NC}"
    sudo apt update
    if [ $? -ne 0 ]; then
        echo -e "${RED}Ошибка при обновлении пакетов!${NC}"
        return 1
    fi

    sudo apt install -y xl2tpd iptables
    if [ $? -ne 0 ]; then
        echo -e "${RED}Ошибка при установке xl2tpd и iptables!${NC}"
        return 1
    fi

    # Создание конфигурационного файла xl2tpd
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
    if [ $? -ne 0 ]; then
        echo -e "${RED}Ошибка при создании конфигурационного файла xl2tpd!${NC}"
        return 1
    fi

    # Создание файла опций PPP
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
    if [ $? -ne 0 ]; then
        echo -e "${RED}Ошибка при создании файла опций PPP!${NC}"
        return 1
    fi

    # Настройка NAT
    INTERFACE=$(ip route get 8.8.8.8 | awk '{print $5; exit}')
    sudo iptables -t nat -A POSTROUTING -s 10.2.2.0/24 -o "$INTERFACE" -j MASQUERADE
    if [ $? -ne 0 ]; then
        echo -e "${RED}Ошибка при настройке NAT!${NC}"
        return 1
    fi

    # Создание директории /etc/iptables/
    sudo mkdir -p /etc/iptables/

    # Сохранение правил iptables
    sudo sh -c "iptables-save > /etc/iptables/rules.v4"
    if [ $? -ne 0 ]; then
        echo -e "${RED}Ошибка при сохранении правил iptables!${NC}"
        return 1
    fi

    # Включение IP forwarding
    sudo sysctl -w net.ipv4.ip_forward=1
    if [ $? -ne 0 ]; then
        echo -e "${RED}Ошибка при включении IP forwarding!${NC}"
        return 1
    fi
    sudo sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
    if [ $? -ne 0 ]; then
        echo -e "${RED}Ошибка при изменении /etc/sysctl.conf!${NC}"
        return 1
    fi

    # Перезапуск службы
    sudo systemctl restart xl2tpd
    if [ $? -ne 0 ]; then
        echo -e "${RED}Ошибка при перезапуске службы xl2tpd!${NC}"
        return 1
    fi
    sudo systemctl enable xl2tpd
    if [ $? -ne 0 ]; then
        echo -e "${RED}Ошибка при включении автозагрузки службы xl2tpd!${NC}"
        return 1
    fi

    echo -e "${BLUE}Установка завершена!${NC}"
    add_user
    echo -e "${BLUE}IP-адрес сервера: $(get_server_ip)${NC}"
}

# Функция для добавления пользователя
add_user() {
    echo -e "${BLUE}Добавление нового пользователя L2TP...${NC}"
    read -p "Введите имя пользователя: " username
    read -s -p "Введите пароль: " password
    echo ""

    # Добавление в chap-secrets
    sudo bash -c "echo '$username l2tp-vpn $password *' >> /etc/ppp/chap-secrets"
    if [ $? -ne 0 ]; then
        echo -e "${RED}Ошибка при добавлении пользователя в chap-secrets!${NC}"
        return 1
    fi
    echo -e "${BLUE}Пользователь $username успешно добавлен!${NC}"
    echo -e "${BLUE}Логин: $username, Пароль: $password${NC}"
}

# Функция для удаления пользователя с отображением списка
remove_user() {
    echo -e "${BLUE}Удаление пользователя L2TP...${NC}"
    echo -e "${BLUE}Список существующих пользователей:${NC}"

    # Проверка существования файла и вывод пользователей
    if [ -f /etc/ppp/chap-secrets ]; then
        echo "----------------------------------------"
        awk '$2 == "l2tp-vpn" {print "Имя пользователя: " $1}' /etc/ppp/chap-secrets
        echo "----------------------------------------"
    else
        echo -e "${RED}Файл chap-secrets пуст или не существует.${NC}"
        return 1
    fi

    read -p "Введите имя пользователя для удаления: " username

    if grep -q "^$username " /etc/ppp/chap-secrets; then
        sudo sed -i "/^$username /d" /etc/ppp/chap-secrets
        if [ $? -ne 0 ]; then
            echo -e "${RED}Ошибка при удалении пользователя из chap-secrets!${NC}"
            return 1
        fi
        echo -e "${BLUE}Пользователь $username успешно удален!${NC}"
    else
        echo -e "${RED}Пользователь $username не найден!${NC}"
    fi
}

# Функция для удаления xl2tpd и всех настроек
remove_xl2tpd() {
    echo -e "${BLUE}Удаление xl2tpd и всех связанных настроек...${NC}"

    # Остановка и отключение службы
    sudo systemctl stop xl2tpd
    if [ $? -ne 0 ]; then
        echo -e "${RED}Ошибка при остановке службы xl2tpd!${NC}"
        return 1
    fi
    sudo systemctl disable xl2tpd
    if [ $? -ne 0 ]; then
        echo -e "${RED}Ошибка при отключении службы xl2tpd!${NC}"
        return 1
    fi

    # Удаление пакета xl2tpd
    sudo apt purge -y xl2tpd
    if [ $? -ne 0 ]; then
        echo -e "${RED}Ошибка при удалении пакета xl2tpd!${NC}"
        return 1
    fi
    sudo apt autoremove -y
    if [ $? -ne 0 ]; then
        echo -e "${RED}Ошибка при удалении зависимостей xl2tpd!${NC}"
        return 1
    fi

    # Удаление конфигурационных файлов
    sudo rm -rf /etc/xl2tpd/xl2tpd.conf
    sudo rm -rf /etc/ppp/options.xl2tpd
    sudo rm -rf /etc/ppp/chap-secrets

    # Удаление правила NAT из iptables
    INTERFACE=$(ip route get 8.8.8.8 | awk '{print $5; exit}')
    sudo iptables -t nat -D POSTROUTING -s 10.2.2.0/24 -o "$INTERFACE" -j MASQUERADE 2>/dev/null
    sudo sh -c "iptables-save > /etc/iptables/rules.v4"
    if [ $? -ne 0 ]; then
        echo -e "${RED}Ошибка при сохранении правил iptables!${NC}"
        return 1
    fi

    # Отключение IP forwarding
    sudo sysctl -w net.ipv4.ip_forward=0
    if [ $? -ne 0 ]; then
        echo -e "${RED}Ошибка при отключении IP forwarding!${NC}"
        return 1
    fi
    sudo sed -i 's/net.ipv4.ip_forward=1/#net.ipv4.ip_forward=1/' /etc/sysctl.conf
    if [ $? -ne 0 ]; then
        echo -e "${RED}Ошибка при изменении /etc/sysctl.conf!${NC}"
        return 1
    fi

    echo -e "${BLUE}xl2tpd и все связанные настройки успешно удалены!${NC}"
}

# Основное меню
echo -e "${BLUE}Выберите действие:${NC}"
echo -e "${GREEN}1. Установить${NC}    ${YELLOW}(1)${NC}"
echo -e "${GREEN}2. Добавить пользователя L2TP${NC} ${YELLOW}(2)${NC}"
echo -e "${GREEN}3. Удалить пользователя${NC}    ${YELLOW}(3)${NC}"
echo -e "${GREEN}4. Удалить xl2tpd${NC}      ${YELLOW}(4)${NC}"
read -p "Введите номер действия (1-4): " choice

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
    *)
        echo -e "${RED}Неверный выбор! Пожалуйста, выберите 1, 2, 3 или 4.${NC}"
        ;;
esac
