#!/bin/sh

# Цвета для меню
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Функция для отображения меню
show_menu() {
    clear
    echo -e "${CYAN}=== Sing-box Management Menu ==="
    echo -e "${GREEN}1.${NC} Просмотр логов sing-box (режим реального времени)"
    echo -e "${GREEN}2.${NC} Получить внешний IP через sing-box tools"
    echo -e "${GREEN}3.${NC} Проверить внешний IP через tun0 интерфейс"
    echo -e "${GREEN}4.${NC} Проверить конфигурацию sing-box"
    echo -e "${GREEN}5.${NC} Запустить sing-box"
    echo -e "${GREEN}6.${NC} Остановить sing-box"
    echo -e "${GREEN}7.${NC} Проверить версию sing-box"
    echo -e "${CYAN}-------------------------------"
    echo -e "${GREEN}8.${NC} Проверить DNS на подмену"
    echo -e "${GREEN}9.${NC} Установить ITDog sing-box"
    echo -e "${CYAN}-------------------------------"
    echo -e "${GREEN}10.${NC} Обновить sing-box"
    echo -e "${CYAN}-------------------------------"
    echo -e "${GREEN}0.${NC} Выход"
    echo -e "${CYAN}===============================${NC}"
}

# Функция для паузы
pause() {
    echo -e "\n${BLUE}Нажмите Enter чтобы продолжить...${NC}"
    read -r
}

# Функция для проверки последней версии
check_latest_version() {
    echo -e "\n${YELLOW}=== Получение информации о последней версии ==="
    LATEST_VERSION=$(curl -s https://api.github.com/repos/SagerNet/sing-box/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    CURRENT_VERSION=$(sing-box version 2>/dev/null | head -n 1 | awk '{print $3}')
    
    echo -e "${CYAN}Текущая версия: ${YELLOW}${CURRENT_VERSION:-Не установлена}${NC}"
    echo -e "${CYAN}Последняя версия: ${YELLOW}${LATEST_VERSION}${NC}"
    
    if [ "$CURRENT_VERSION" = "${LATEST_VERSION#v}" ]; then
        echo -e "${GREEN}У вас установлена последняя версия!${NC}"
    else
        echo -e "${RED}Доступно обновление!${NC}"
    fi
}

# Функция для обновления sing-box
update_sing_box() {
    check_latest_version
    
    echo -e "\n${YELLOW}=== Выберите архитектуру ==="
    echo "1. linux-amd64"
    echo "2. linux-arm64"
    echo "3. linux-armv7"
    echo "0. Отмена"
    
    read -p "Ваш выбор: " arch_choice
    
    case $arch_choice in
        1) ARCH="amd64" ;;
        2) ARCH="arm64" ;;
        3) ARCH="armv7" ;;
        0) return ;;
        *) echo -e "${RED}Неверный выбор${NC}"; return ;;
    esac
    
    echo -e "\n${YELLOW}=== Начинаем обновление ==="
    
    /etc/init.d/sing-box stop
    
    DL_URL="https://github.com/SagerNet/sing-box/releases/download/${LATEST_VERSION}/sing-box-${LATEST_VERSION#v}-linux-${ARCH}.tar.gz"
    echo -e "${CYAN}Скачивание: ${YELLOW}${DL_URL}${NC}"
    
    wget -O /tmp/sing-box.tar.gz "$DL_URL" || {
        echo -e "${RED}Ошибка при скачивании!${NC}"
        /etc/init.d/sing-box start
        return 1
    }
    
    echo -e "${GREEN}Распаковка архива...${NC}"
    tar -xzf /tmp/sing-box.tar.gz -C /tmp/ || {
        echo -e "${RED}Ошибка при распаковке!${NC}"
        /etc/init.d/sing-box start
        return 1
    }
    
    echo -e "${GREEN}Установка новой версии...${NC}"
    mv /tmp/sing-box-${LATEST_VERSION#v}-linux-${ARCH}/sing-box /usr/bin/ || {
        echo -e "${RED}Ошибка при перемещении файла!${NC}"
        /etc/init.d/sing-box start
        return 1
    }
    
    chmod +x /usr/bin/sing-box
    /etc/init.d/sing-box start
    
    echo -e "\n${GREEN}=== Проверка версии после обновления ==="
    sing-box version
    
    echo -e "\n${GREEN}✅ Sing-box успешно обновлен до версии ${LATEST_VERSION}${NC}"
    rm -rf /tmp/sing-box*
}

# Основной цикл меню
while true; do
    show_menu
    
    echo -e "\n${BLUE}Введите номер команды: ${NC}"
    read -r choice
    
    case $choice in
        1)
            echo -e "\n${YELLOW}=== Просмотр логов sing-box ==="
            logread -f -e sing-box
            ;;
        2)
            echo -e "\n${YELLOW}=== Получение внешнего IP через sing-box tools ==="
            sing-box tools fetch ifconfig.co -D /etc/sing-box/
            pause
            ;;
        3)
            echo -e "\n${YELLOW}=== Проверка внешнего IP через tun0 интерфейс ==="
            curl --interface tun0 ifconfig.me
            pause
            ;;
        4)
            echo -e "\n${YELLOW}=== Проверка конфигурации sing-box ==="
            sing-box -c /etc/sing-box/config.json check
            pause
            ;;
        5)
            echo -e "\n${YELLOW}=== Запуск sing-box ==="
            /etc/init.d/sing-box start
            pause
            ;;
        6)
            echo -e "\n${YELLOW}=== Остановка sing-box ==="
            /etc/init.d/sing-box stop
            pause
            ;;
        7)
            echo -e "\n${YELLOW}=== Текущая версия sing-box ==="
            sing-box version
            pause
            ;;
        8)
            echo -e "\n${YELLOW}=== Проверка DNS на подмену ==="
            wget -O - https://raw.githubusercontent.com/itdoginfo/domain-routing-openwrt/master/getdomains-check.sh | sh -s dns
            pause
            ;;
        9)
            echo -e "\n${YELLOW}=== Установка ITDog sing-box ==="
            sh <(wget -O - https://raw.githubusercontent.com/itdoginfo/domain-routing-openwrt/master/getdomains-install.sh)
            pause
            ;;
        10)
            echo -e "\n${YELLOW}=== Обновление sing-box ==="
            update_sing_box
            pause
            ;;
        0)
            echo -e "\n${GREEN}Выход из меню.${NC}"
            exit 0
            ;;
        *)
            echo -e "\n${RED}Неверный выбор. Попробуйте снова.${NC}"
            pause
            ;;
    esac
done
