#!/bin/bash

# Цвета для оформления
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Ловушка для выхода
trap "echo -e '\n${RED}Выход...${NC}'; exit 0" SIGINT SIGTERM

# Проверка root-прав
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${YELLOW}Внимание: Для некоторых тестов рекомендуются root-права${NC}"
        return 1
    fi
    return 0
}

# Проверка и установка зависимостей
check_dependencies() {
    local deps=("curl" "wget" "sysbench")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing+=("$dep")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo -e "${YELLOW}Необходимые компоненты отсутствуют: ${missing[*]}${NC}"
        
        if [[ $EUID -eq 0 ]]; then
            read -p "Установить автоматически? (y/n): " choice
            if [[ "$choice" =~ ^[YyДд]$ ]]; then
                if command -v apt >/dev/null 2>&1; then
                    apt update && apt install -y "${missing[@]}" || {
                        echo -e "${RED}Не удалось установить зависимости через apt${NC}"
                        return 1
                    }
                elif command -v yum >/dev/null 2>&1; then
                    yum install -y "${missing[@]}" || {
                        echo -e "${RED}Не удалось установить зависимости через yum${NC}"
                        return 1
                    }
                else
                    echo -e "${RED}Не удалось определить менеджер пакетов. Установите вручную: ${missing[*]}${NC}"
                    return 1
                fi
            else
                echo -e "${RED}Без установки зависимостей некоторые функции могут не работать.${NC}"
                return 1
            fi
        else
            echo -e "${RED}Требуются root-права для установки зависимостей${NC}"
            return 1
        fi
    fi
    
    return 0
}

# Функция меню
show_menu() {
    clear
    echo -e "${GREEN}=== Меню проверки сервера ===${NC}"
    echo "1. Проверка IP на блокировки"
    echo "2. Тест скорости (Россия)"
    echo "3. Тест скорости (Зарубежье)"
    echo "4. Проверка Instagram аудио"
    echo "5. Комплексный тест Yabs"
    echo "6. Проверка геолокации IP"
    echo "7. Тест CPU (10000)"
    echo "8. Тест CPU (20000)"
    echo "9. Выход"
    echo -e "${BLUE}Выберите опцию (1-9):${NC}"
}

# Инициализация
check_root
check_dependencies || {
    echo -e "${YELLOW}Некоторые тесты могут не работать без зависимостей${NC}"
    sleep 2
}

# Основной цикл
while true; do
    show_menu
    read -p "Ваш выбор: " choice
    
    case $choice in
        1)
            echo -e "\n${GREEN}Проверка IP на блокировки...${NC}"
            bash <(curl -Ls https://IP.Check.Place) -l en
            if [[ $? -ne 0 ]]; then
                echo -e "${RED}Ошибка проверки${NC}"
            fi
            ;;
        2)
            echo -e "\n${GREEN}Тест скорости (Россия)...${NC}"
            wget -qO- speedtest.artydev.ru | bash 2>/dev/null
            if [[ $? -ne 0 ]]; then
                echo -e "${RED}Ошибка теста${NC}"
            fi
            ;;
        3)
            echo -e "\n${GREEN}Тест скорости (Зарубежье)...${NC}"
            wget -qO- bench.sh | bash 2>/dev/null
            if [[ $? -ne 0 ]]; then
                echo -e "${RED}Ошибка теста${NC}"
            fi
            ;;
        4)
            echo -e "\n${GREEN}Проверка Instagram...${NC}"
            curl -sL https://bench.openode.xyz/checker_inst.sh | bash
            if [[ $? -ne 0 ]]; then
                echo -e "${RED}Ошибка проверки${NC}"
            fi
            ;;
        5)
            echo -e "\n${GREEN}Запуск Yabs...${NC}"
            curl -sL https://yabs.sh | bash -s -- -4
            if [[ $? -ne 0 ]]; then
                echo -e "${RED}Ошибка теста${NC}"
            fi
            ;;
        6)
            echo -e "\n${GREEN}Проверка геолокации...${NC}"
            curl -sL https://raw.gitmirror.com/vernette/ipregion/master/ipregion.sh | bash
            if [[ $? -ne 0 ]]; then
                echo -e "${RED}Ошибка проверки${NC}"
            fi
            ;;
        7)
            echo -e "\n${GREEN}Тест CPU (10000)...${NC}"
            sysbench cpu --cpu-max-prime=10000 run
            if [[ $? -ne 0 ]]; then
                echo -e "${RED}sysbench не установлен или произошла ошибка${NC}"
            fi
            ;;
        8)
            echo -e "\n${GREEN}Тест CPU (20000)...${NC}"
            sysbench cpu --cpu-max-prime=20000 run
            if [[ $? -ne 0 ]]; then
                echo -e "${RED}sysbench не установлен или произошла ошибка${NC}"
            fi
            ;;
        9)
            echo -e "\n${GREEN}Выход...${NC}"
            exit 0
            ;;
        *)
            echo -e "\n${RED}Неверный выбор!${NC}"
            ;;
    esac
    
    read -p $'\n'"Нажмите Enter, чтобы продолжить..."
done
