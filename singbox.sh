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
    echo -e "${CYAN}╔════════════════════════════════════╗"
    echo -e "║   ${YELLOW}Sing-box Management Menu${CYAN}          ║"
    echo -e "╠════════════════════════════════════╣"
    echo -e "║ ${GREEN}1.${NC} Просмотр логов sing-box (режим реального времени) ║"
    echo -e "║ ${GREEN}2.${NC} Получить внешний IP через sing-box tools          ║"
    echo -e "║ ${GREEN}3.${NC} Проверить конфигурацию sing-box                  ║"
    echo -e "║ ${GREEN}4.${NC} Запустить sing-box                               ║"
    echo -e "║ ${GREEN}5.${NC} Остановить sing-box                              ║"
    echo -e "╟────────────────────────────────────╢"
    echo -e "║ ${GREEN}6.${NC} Проверить DNS на подмену                        ║"
    echo -e "║ ${GREEN}7.${NC} Установить ITDog sing-box                       ║"
    echo -e "╟────────────────────────────────────╢"
    echo -e "║ ${GREEN}0.${NC} Выход                                           ║"
    echo -e "╚════════════════════════════════════╝${NC}"
}

# Функция для паузы
pause() {
    echo -e "\n${BLUE}Нажмите Enter чтобы продолжить...${NC}"
    read -r
}

# Основной цикл меню
while true; do
    show_menu
    
    echo -e "\n${BLUE}Введите номер команды: ${NC}"
    read -r choice
    
    case $choice in
        1)
            echo -e "\n${YELLOW}╔════════════════════════════════════╗"
            echo -e "║    Просмотр логов sing-box (режим реального времени)    ║"
            echo -e "╚════════════════════════════════════╝${NC}"
            logread -f -e sing-box
            ;;
        2)
            echo -e "\n${YELLOW}╔════════════════════════════════════╗"
            echo -e "║    Получение внешнего IP через sing-box tools    ║"
            echo -e "╚════════════════════════════════════╝${NC}"
            sing-box tools fetch ifconfig.co -D /etc/sing-box/
            pause
            ;;
        3)
            echo -e "\n${YELLOW}╔════════════════════════════════════╗"
            echo -e "║    Проверка конфигурации sing-box    ║"
            echo -e "╚════════════════════════════════════╝${NC}"
            sing-box -c /etc/sing-box/config.json check
            pause
            ;;
        4)
            echo -e "\n${YELLOW}╔════════════════════════════════════╗"
            echo -e "║    Запуск sing-box    ║"
            echo -e "╚════════════════════════════════════╝${NC}"
            /etc/init.d/sing-box start
            pause
            ;;
        5)
            echo -e "\n${YELLOW}╔════════════════════════════════════╗"
            echo -e "║    Остановка sing-box    ║"
            echo -e "╚════════════════════════════════════╝${NC}"
            /etc/init.d/sing-box stop
            pause
            ;;
        6)
            echo -e "\n${YELLOW}╔════════════════════════════════════╗"
            echo -e "║    Проверка DNS на подмену    ║"
            echo -e "╚════════════════════════════════════╝${NC}"
            wget -O - https://raw.githubusercontent.com/itdoginfo/domain-routing-openwrt/master/getdomains-check.sh | sh -s dns
            pause
            ;;
        7)
            echo -e "\n${YELLOW}╔════════════════════════════════════╗"
            echo -e "║    Установка ITDog sing-box    ║"
            echo -e "╚════════════════════════════════════╝${NC}"
            sh <(wget -O - https://raw.githubusercontent.com/itdoginfo/domain-routing-openwrt/master/getdomains-install.sh)
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
