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

# Функция для вывода информации о подключении
show_connection_info() {
    local username=$1
    local password=$2
    
    echo -e "\n${GREEN}=== ДАННЫЕ ДЛЯ ПОДКЛЮЧЕНИЯ ===${NC}"
    echo -e "${BLUE}IP сервера:${NC} $SERVER_IP"
    echo -e "${BLUE}Логин:${NC} $username"
    echo -e "${BLUE}Пароль:${NC} $password"
    echo -e "${GREEN}===========================${NC}"
}

# [Остальные функции остаются без изменений: install_xl2tpd, add_user, remove_user, remove_xl2tpd]

# Основное меню
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
