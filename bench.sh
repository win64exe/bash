#!/bin/bash

# Цвета для оформления
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Функция отображения меню
show_menu() {
    clear
    echo -e "${GREEN}=== Меню проверки сервера ===${NC}"
    echo "1. Проверка IP на блокировки зарубежными сервисами"
    echo "2. Проверка скорости к российским провайдерам"
    echo "3. Проверка скорости к зарубежным провайдерам"
    echo "4. Проверка блокировки аудио в Instagram"
    echo "5. Тест Yabs"
    echo "6. IPRegion Script"
    echo "7. Sysbench CPU test (max-prime=10000)"
    echo "8. Sysbench CPU test (max-prime=20000)"
    echo "9. Выход"
    echo -e "${BLUE}Выберите опцию (1-9):${NC}"
}

# Функция проверки загрузки скрипта
check_download() {
    local url=$1
    local content=$(curl -Ls "$url")
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}Ошибка: Не удалось загрузить скрипт с $url${NC}"
        return 1
    fi
    if [[ $content =~ "<!DOCTYPE html>" || -z "$content" ]]; then
        echo -e "${RED}Ошибка: Загружен HTML или пустой ответ вместо скрипта с $url${NC}"
        return 1
    fi
    echo "$content"
    return 0
}

# Основной цикл
while true; do
    show_menu
    read -p "Ваш выбор: " choice
    
    case $choice in
        1)
            echo "Проверка IP на блокировки зарубежными сервисами..."
            script=$(check_download "IP.Check.Place")
            if [[ $? -eq 0 ]]; then
                echo "$script" | bash -s -- -l en
            fi
            read -p "Нажмите Enter для продолжения..."
            ;;
        2)
            echo "Проверка скорости к российским провайдерам..."
            wget -qO- speedtest.artydev.ru | bash 2>/dev/null || echo -e "${RED}Ошибка при выполнении теста${NC}"
            read -p "Нажмите Enter для продолжения..."
            ;;
        3)
            echo "Проверка скорости к зарубежным провайдерам..."
            wget -qO- bench.sh | bash 2>/dev/null || echo -e "${RED}Ошибка при выполнении теста${NC}"
            read -p "Нажмите Enter для продолжения..."
            ;;
        4)
            echo "Проверка блокировки аудио в Instagram..."
            script=$(check_download "https://bench.openode.xyz/checker_inst.sh")
            if [[ $? -eq 0 ]]; then
                echo "$script" | bash
            fi
            read -p "Нажмите Enter для продолжения..."
            ;;
        5)
            echo "Запуск теста Yabs..."
            script=$(check_download "https://yabs.sh")
            if [[ $? -eq 0 ]]; then
                echo "$script" | bash -s -- -4
            fi
            read -p "Нажмите Enter для продолжения..."
            ;;
        6)
            echo "Запуск IPRegion Script..."
            script=$(check_download "https://raw.githubusercontent.com/vernette/ipregion/refs/heads/master/ipregion.sh")
            if [[ $? -eq 0 ]]; then
                echo "$script" | bash
            fi
            read -p "Нажмите Enter для продолжения..."
            ;;
        7)
            echo "Запуск Sysbench CPU test (max-prime=10000)..."
            if command -v sysbench >/dev/null 2>&1; then
                sysbench --test=cpu --cpu-max-prime=10000 run
            else
                echo -e "${RED}Ошибка: sysbench не установлен${NC}"
            fi
            read -p "Нажмите Enter для продолжения..."
            ;;
        8)
            echo "Запуск Sysbench CPU test (max-prime=20000)..."
            if command -v sysbench >/dev/null 2>&1; then
                sysbench --test=cpu --cpu-max-prime=20000 run
            else
                echo -e "${RED}Ошибка: sysbench не установлен${NC}"
            fi
            read -p "Нажмите Enter для продолжения..."
            ;;
        9)
            echo "Выход из скрипта..."
            exit 0
            ;;
        *)
            echo "Неверный выбор! Пожалуйста, выберите число от 1 до 9"
            read -p "Нажмите Enter для продолжения..."
            ;;
    esac
done
