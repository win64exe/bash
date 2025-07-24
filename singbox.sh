#!/bin/bash

# Установка кодировки UTF-8
export LC_ALL=C.UTF-8

# Цвета для меню
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Проверка прав суперпользователя
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}Этот скрипт должен быть запущен с правами root!${NC}"
    exit 1
fi

# Проверка наличия необходимых утилит
check_requirements() {
    local required_commands=("curl" "wget" "tar")
    local optional_commands=("sing-box" "logread")
    
    # Проверка обязательных команд
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            echo -e "${RED}Ошибка: Команда $cmd не найдена. Пожалуйста, установите её.${NC}"
            exit 1
        fi
    done
    
    # Проверка опциональных команд (для некоторых функций)
    for cmd in "${optional_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            echo -e "${YELLOW}Предупреждение: Команда $cmd не найдена. Некоторые функции могут быть недоступны.${NC}"
        fi
    done
}

# Функция для определения архитектуры
detect_architecture() {
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)  echo "amd64" ;;
        aarch64) echo "arm64" ;;
        armv7l)  echo "armv7" ;;
        *)       echo "unknown" ;;
    esac
}

# Функция для проверки последней версии
check_latest_version() {
    echo -e "\n${YELLOW}=== Получение информации о последней версии ==="
    
    # Используем более безопасный способ получения версии с таймаутом
    LATEST_VERSION=$(curl -s --max-time 10 --retry 2 https://api.github.com/repos/SagerNet/sing-box/releases/latest | 
        grep '"tag_name":' | head -n1 | sed -E 's/.*"([^"]+)".*/\1/')
    
    if [ -z "$LATEST_VERSION" ] || [ "$LATEST_VERSION" = "null" ]; then
        echo -e "${RED}Ошибка: Не удалось получить информацию о последней версии!${NC}"
        echo -e "${YELLOW}Проверьте подключение к интернету.${NC}"
        return 1
    fi
    
    # Проверка формата версии
    if ! echo "$LATEST_VERSION" | grep -qE '^v[0-9]+\.[0-9]+\.[0-9]+'; then
        echo -e "${RED}Ошибка: Получен некорректный формат версии: $LATEST_VERSION${NC}"
        return 1
    fi
    
    if command -v sing-box >/dev/null 2>&1; then
        CURRENT_VERSION=$(sing-box version 2>/dev/null | grep -oP 'version \K\S+' || echo "Не установлена")
    else
        CURRENT_VERSION="Не установлена"
    fi
    
    echo -e "${CYAN}Текущая версия: ${YELLOW}${CURRENT_VERSION}${NC}"
    echo -e "${CYAN}Последняя версия: ${YELLOW}${LATEST_VERSION}${NC}"
    
    if [ "$CURRENT_VERSION" = "${LATEST_VERSION#v}" ]; then
        echo -e "${GREEN}У вас установлена последняя версия!${NC}"
    else
        echo -e "${RED}Доступно обновление!${NC}"
    fi
}

# Функция для проверки доступных пакетов
check_available_packages() {
    echo -e "\n${YELLOW}=== Доступные пакеты для вашей архитектуры ==="
    ARCH=$(detect_architecture)
    echo -e "${CYAN}Определена архитектура: ${YELLOW}${ARCH}${NC}"
    
    case "$ARCH" in
        amd64)
            echo "1. sing-box (linux-amd64)"
            echo "2. sing-box-musl (linux-amd64-musl)"
            ;;
        arm64)
            echo "1. sing-box (linux-arm64)"
            echo "2. sing-box-musl (linux-arm64-musl)"
            ;;
        armv7)
            echo "1. sing-box (linux-armv7)"
            echo "2. sing-box-musl (linux-armv7-musl)"
            ;;
        *)
            echo -e "${RED}Архитектура не поддерживается!${NC}"
            return 1
            ;;
    esac
}

# Функция для обновления sing-box
update_sing_box() {
    check_latest_version || return 1
    
    # Проверка архитектуры
    ARCH=$(detect_architecture)
    if [ "$ARCH" = "unknown" ]; then
        echo -e "${RED}Не удалось определить архитектуру процессора!${NC}"
        echo -e "${YELLOW}Пожалуйста, выберите вручную:${NC}"
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
            *) echo -e "${RED}Неверный выбор архитектуры!${NC}"; return ;;
        esac
    else
        echo -e "${CYAN}Автоматически определена архитектура: ${YELLOW}${ARCH}${NC}"
    fi
    
    # Проверка доступных пакетов
    check_available_packages || return 1
    read -p "Выберите пакет (1 или 2): " pkg_choice
    case "$pkg_choice" in
        1) PKG="" ;;
        2) PKG="-musl" ;;
        *) echo -e "${RED}Неверный выбор пакета. Пожалуйста, выберите 1 или 2.${NC}"; return ;;
    esac
    
    echo -e "\n${YELLOW}=== Начинаем обновление ==="
    
    # Остановка сервиса
    if [ -f /etc/init.d/sing-box ]; then
        /etc/init.d/sing-box stop || {
            echo -e "${RED}Ошибка при остановке сервиса sing-box!${NC}"
            return 1
        }
    else
        echo -e "${YELLOW}Сервис sing-box не найден, пропускаем остановку.${NC}"
    fi
    
    # Формирование URL для скачивания
    DL_URL="https://github.com/SagerNet/sing-box/releases/download/${LATEST_VERSION}/sing-box-${LATEST_VERSION#v}-linux-${ARCH}${PKG}.tar.gz"
    echo -e "${CYAN}Скачивание: ${YELLOW}${DL_URL}${NC}"
    
    # Создаем временную директорию
    TEMP_DIR=$(mktemp -d) || {
        echo -e "${RED}Ошибка: Не удалось создать временную директорию!${NC}"
        [ -f /etc/init.d/sing-box ] && /etc/init.d/sing-box start
        return 1
    }
    
    # Скачивание с проверкой целостности
    echo -e "${GREEN}Скачивание архива...${NC}"
    if ! wget --timeout=30 --tries=3 -O "$TEMP_DIR/sing-box.tar.gz" "$DL_URL"; then
        echo -e "${RED}Ошибка при скачивании!${NC}"
        rm -rf "$TEMP_DIR"
        [ -f /etc/init.d/sing-box ] && /etc/init.d/sing-box start
        return 1
    fi
    
    # Проверка размера файла
    FILE_SIZE=$(stat -c%s "$TEMP_DIR/sing-box.tar.gz" 2>/dev/null || echo "0")
    if [ "$FILE_SIZE" -lt 1000000 ]; then  # Меньше 1MB - подозрительно
        echo -e "${RED}Ошибка: Скачанный файл слишком мал ($FILE_SIZE байт)!${NC}"
        rm -rf "$TEMP_DIR"
        [ -f /etc/init.d/sing-box ] && /etc/init.d/sing-box start
        return 1
    fi
    
    # Распаковка
    echo -e "${GREEN}Распаковка архива...${NC}"
    if ! tar -xzf "$TEMP_DIR/sing-box.tar.gz" -C "$TEMP_DIR/"; then
        echo -e "${RED}Ошибка при распаковке!${NC}"
        rm -rf "$TEMP_DIR"
        [ -f /etc/init.d/sing-box ] && /etc/init.d/sing-box start
        return 1
    fi
    
    # Проверка наличия исполняемого файла
    EXTRACTED_DIR="$TEMP_DIR/sing-box-${LATEST_VERSION#v}-linux-${ARCH}${PKG}"
    if [ ! -f "$EXTRACTED_DIR/sing-box" ]; then
        echo -e "${RED}Ошибка: Исполняемый файл не найден в архиве!${NC}"
        rm -rf "$TEMP_DIR"
        [ -f /etc/init.d/sing-box ] && /etc/init.d/sing-box start
        return 1
    fi
    
    # Создание резервной копии текущей версии
    if [ -f /usr/bin/sing-box ]; then
        echo -e "${GREEN}Создание резервной копии...${NC}"
        cp /usr/bin/sing-box /usr/bin/sing-box.backup.$(date +%Y%m%d_%H%M%S) || {
            echo -e "${YELLOW}Предупреждение: Не удалось создать резервную копию${NC}"
        }
    fi
    
    # Установка
    echo -e "${GREEN}Установка новой версии...${NC}"
    if ! cp "$EXTRACTED_DIR/sing-box" /usr/bin/sing-box; then
        echo -e "${RED}Ошибка при копировании файла!${NC}"
        rm -rf "$TEMP_DIR"
        [ -f /etc/init.d/sing-box ] && /etc/init.d/sing-box start
        return 1
    fi
    
    chmod +x /usr/bin/sing-box
    
    # Проверка установки
    if ! /usr/bin/sing-box version >/dev/null 2>&1; then
        echo -e "${RED}Ошибка: Установленная версия не работает!${NC}"
        # Восстановление из резервной копии если возможно
        BACKUP_FILE=$(ls -t /usr/bin/sing-box.backup.* 2>/dev/null | head -n1)
        if [ -n "$BACKUP_FILE" ]; then
            echo -e "${YELLOW}Восстановление из резервной копии...${NC}"
            cp "$BACKUP_FILE" /usr/bin/sing-box
            chmod +x /usr/bin/sing-box
        fi
        rm -rf "$TEMP_DIR"
        [ -f /etc/init.d/sing-box ] && /etc/init.d/sing-box start
        return 1
    fi
    
    # Запуск сервиса
    if [ -f /etc/init.d/sing-box ]; then
        if /etc/init.d/sing-box start; then
            echo -e "${GREEN}Сервис sing-box успешно запущен!${NC}"
        else
            echo -e "${RED}Ошибка при запуске сервиса sing-box!${NC}"
            return 1
        fi
    fi
    
    echo -e "\n${GREEN}=== Проверка версии после обновления ==="
    sing-box version
    
    echo -e "\n${GREEN}✅ Sing-box успешно обновлен до версии ${LATEST_VERSION}${NC}"
    
    # Очистка временных файлов
    rm -rf "$TEMP_DIR"
    
    # Очистка старых резервных копий (оставляем только 3 последние)
    find /usr/bin -name "sing-box.backup.*" -type f | sort -r | tail -n +4 | xargs rm -f 2>/dev/null || true
}

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
    echo -e "${GREEN}10.${NC} Обновить sing-box (автоопределение)"
    echo -e "${CYAN}-------------------------------"
    echo -e "${GREEN}0.${NC} Выход"
    echo -e "${CYAN}===============================${NC}"
}

# Функция для паузы
pause() {
    echo -e "\n${BLUE}Нажмите Enter чтобы продолжить...${NC}"
    read -r
}

# Проверка зависимостей перед началом
check_requirements

# Основной цикл меню
while true; do
    show_menu
    
    echo -e "\n${BLUE}Введите номер команды: ${NC}"
    read -r choice
    if [ -z "$choice" ]; then
        echo -e "\n${RED}Пожалуйста, выберите опцию.${NC}"
        pause
        continue
    fi
    
    case $choice in
        1)
            echo -e "\n${YELLOW}=== Просмотр логов sing-box ==="
            logread -f -e sing-box
            ;;
        2)
            echo -e "\n${YELLOW}=== Получение внешнего IP через sing-box tools ==="
            if [ -d /etc/sing-box ]; then
                sing-box tools fetch ifconfig.co -D /etc/sing-box/
            else
                echo -e "${RED}Директория /etc/sing-box не найдена!${NC}"
            fi
            pause
            ;;
        3)
            echo -e "\n${YELLOW}=== Проверка внешнего IP через tun0 интерфейс ==="
            if ip link show tun0 >/dev/null 2>&1; then
                curl --interface tun0 ifconfig.me
            else
                echo -e "${RED}Интерфейс tun0 не найден!${NC}"
            fi
            pause
            ;;
        4)
            echo -e "\n${YELLOW}=== Проверка конфигурации sing-box ==="
            if [ -f /etc/sing-box/config.json ]; then
                sing-box -c /etc/sing-box/config.json check
            else
                echo -e "${RED}Конфигурационный файл /etc/sing-box/config.json не найден!${NC}"
            fi
            pause
            ;;
        5)
            echo -e "\n${YELLOW}=== Запуск sing-box ==="
            if [ -f /etc/init.d/sing-box ]; then
                /etc/init.d/sing-box start || echo -e "${RED}Ошибка при запуске сервиса sing-box!${NC}"
            else
                echo -e "${RED}Сервис /etc/init.d/sing-box не найден!${NC}"
            fi
            pause
            ;;
        6)
            echo -e "\n${YELLOW}=== Остановка sing-box ==="
            if [ -f /etc/init.d/sing-box ]; then
                /etc/init.d/sing-box stop || echo -e "${RED}Ошибка при остановке сервиса sing-box!${NC}"
            else
                echo -e "${RED}Сервис /etc/init.d/sing-box не найден!${NC}"
            fi
            pause
            ;;
        7)
            echo -e "\n${YELLOW}=== Текущая версия sing-box ==="
            sing-box version
            pause
            ;;
        8)
            echo -e "\n${YELLOW}=== Проверка DNS на подмену ==="
            echo -e "${YELLOW}Скачивание и выполнение скрипта проверки DNS...${NC}"
            SCRIPT_URL="https://raw.githubusercontent.com/itdoginfo/domain-routing-openwrt/master/getdomains-check.sh"
            if wget --timeout=10 -q -O - "$SCRIPT_URL" | sh -s dns; then
                echo -e "${GREEN}Проверка DNS завершена${NC}"
            else
                echo -e "${RED}Ошибка при выполнении проверки DNS!${NC}"
            fi
            pause
            ;;
        9)
            echo -e "\n${YELLOW}=== Установка ITDog sing-box ==="
            echo -e "${YELLOW}Скачивание и выполнение скрипта установки ITDog...${NC}"
            INSTALL_URL="https://raw.githubusercontent.com/itdoginfo/domain-routing-openwrt/master/getdomains-install.sh"
            if wget --timeout=10 -q -O - "$INSTALL_URL" | sh; then
                echo -e "${GREEN}Установка ITDog завершена${NC}"
            else
                echo -e "${RED}Ошибка при установке ITDog sing-box!${NC}"
            fi
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