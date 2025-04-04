#!/bin/bash

# Цвета для оформления
GREEN='\033[0;32m'
BLUE='\033[0;34m'
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

# Основной цикл
while true; do
    show_menu
    read -p "Ваш выбор: " choice
    
    case $choice in
        1)
            echo "Проверка IP на блокировки зарубежными сервисами..."
            bash <(curl -Ls IP.Check.Place) -l en
            read -p "Нажмите Enter для продолжения..."
            ;;
        2)
            echo "Проверка скорости к российским провайдерам..."
            wget -qO- speedtest.artydev.ru | bash
            read -p "Нажмите Enter для продолжения..."
            ;;
        3)
            echo "Проверка скорости к зарубежным провайдерам..."
            wget -qO- bench.sh | bash
            read -p "Нажмите Enter для продолжения..."
            ;;
        4)
            echo "Проверка блокировки аудио в Instagram..."
            bash <(curl -L -s https://bench.openode.xyz/checker_inst.sh)
            read -p "Нажмите Enter для продолжения..."
            ;;
        5)
            echo "Запуск теста Yabs..."
            curl -sL yabs.sh | bash -s -- -4
            read -p "Нажмите Enter для продолжения..."
            ;;
        6)
            echo "Запуск IPRegion Script..."
            curl -s "https://raw.githubusercontent.com/vernette/ipregion/refs/heads/master/ipregion.sh" | bash
            read -p "Нажмите Enter для продолжения..."
            ;;
        7)
            echo "Запуск Sysbench CPU test (max-prime=10000)..."
            sysbench --test=cpu --cpu-max-prime=10000 run
            read -p "Нажмите Enter для продолжения..."
            ;;
        8)
            echo "Запуск Sysbench CPU test (max-prime=20000)..."
            sysbench --test=cpu --cpu-max-prime=20000 run
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
