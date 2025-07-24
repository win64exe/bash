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
    
    # Проверяем сетевое соединение сначала
    echo -e "${CYAN}Проверка сетевого соединения...${NC}"
    if ! ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1; then
        echo -e "${RED}Ошибка: Нет соединения с интернетом!${NC}"
        echo -e "${YELLOW}Проверьте сетевые настройки и попробуйте снова.${NC}"
        return 1
    fi
    
    # Используем curl с улучшенными параметрами
    echo -e "${CYAN}Получение информации о релизах...${NC}"
    LATEST_VERSION=$(curl -s --max-time 15 --retry 3 --retry-delay 2 \
        --connect-timeout 10 --user-agent "sing-box-updater/1.0" \
        https://api.github.com/repos/SagerNet/sing-box/releases/latest | \
        grep '"tag_name":' | head -n1 | sed 's/.*"tag_name":\s*"\([^"]*\)".*/\1/')
    
    if [ -z "$LATEST_VERSION" ] || [ "$LATEST_VERSION" = "null" ]; then
        # Пробуем альтернативный способ через GitHub
        echo -e "${YELLOW}Пробуем альтернативный способ получения версии...${NC}"
        LATEST_VERSION=$(wget --timeout=15 --tries=3 -qO- \
            https://github.com/SagerNet/sing-box/releases/latest 2>/dev/null | \
            grep -o 'tag/v[0-9]\+\.[0-9]\+\.[0-9]\+' | head -n1 | sed 's/tag\///')
    fi
    
    if [ -z "$LATEST_VERSION" ] || [ "$LATEST_VERSION" = "null" ]; then
        echo -e "${RED}Ошибка: Не удалось получить информацию о последней версии!${NC}"
        echo -e "${YELLOW}Возможные причины:${NC}"
        echo -e "${YELLOW}- Проблемы с DNS (попробуйте изменить DNS на 8.8.8.8)${NC}"
        echo -e "${YELLOW}- Блокировка GitHub в вашей сети${NC}"
        echo -e "${YELLOW}- Временные проблемы с GitHub API${NC}"
        return 1
    fi
    
    # Проверка формата версии с улучшенной совместимостью
    if ! echo "$LATEST_VERSION" | grep -q '^v[0-9]\+\.[0-9]\+\.[0-9]\+'; then
        echo -e "${RED}Ошибка: Получен некорректный формат версии: $LATEST_VERSION${NC}"
        return 1
    fi
    
    # Получение текущей версии с улучшенной совместимостью для OpenWRT
    if command -v sing-box >/dev/null 2>&1; then
        # Проверяем разные возможные варианты вывода версии
        VERSION_OUTPUT=$(sing-box version 2>/dev/null)
        if [ -n "$VERSION_OUTPUT" ]; then
            # Первый способ: ищем версию в формате vX.X.X
            CURRENT_VERSION=$(echo "$VERSION_OUTPUT" | grep -o 'v[0-9]\+\.[0-9]\+\.[0-9]\+' | head -n1)
            
            # Второй способ: если не нашли, пробуем найти просто числовую версию
            if [ -z "$CURRENT_VERSION" ]; then
                CURRENT_VERSION=$(echo "$VERSION_OUTPUT" | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -n1)
                # Добавляем префикс v если найдена версия без него
                if [ -n "$CURRENT_VERSION" ]; then
                    CURRENT_VERSION="v$CURRENT_VERSION"
                fi
            fi
            
            # Третий способ: парсим через awk по ключевому слову
            if [ -z "$CURRENT_VERSION" ]; then
                CURRENT_VERSION=$(echo "$VERSION_OUTPUT" | awk '/version/{for(i=1;i<=NF;i++) if($i ~ /[0-9]+\.[0-9]+\.[0-9]+/) {print "v" $i; exit}}')
            fi
        fi
        
        # Если все методы не сработали
        if [ -z "$CURRENT_VERSION" ]; then
            CURRENT_VERSION="Не определена"
        fi
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
    
    # Скачивание с проверкой целостности и улучшенными настройками
    echo -e "${GREEN}Скачивание архива...${NC}"
    echo -e "${CYAN}URL: ${YELLOW}$DL_URL${NC}"
    
    # Проверяем доступность файла более надежным способом
    echo -e "${CYAN}Проверка доступности файла...${NC}"
    if ! curl -s --head --max-time 10 "$DL_URL" | grep -q "200 OK\|302 Found\|301 Moved"; then
        # Если curl не сработал, пробуем wget с коротким таймаутом
        if ! wget --spider --timeout=5 --tries=1 "$DL_URL" 2>/dev/null; then
            echo -e "${RED}Ошибка: Файл недоступен по указанному URL!${NC}"
            echo -e "${YELLOW}Проверьте:${NC}"
            echo -e "${YELLOW}- Правильность версии: $LATEST_VERSION${NC}"
            echo -e "${YELLOW}- Доступность GitHub${NC}"
            echo -e "${YELLOW}Попробуем все равно скачать файл...${NC}"
        fi
    else
        echo -e "${GREEN}Файл доступен для скачивания${NC}"
    fi
    
    # Основное скачивание с расширенными опциями
    if ! wget --timeout=60 --tries=3 --retry-connrefused --waitretry=5 \
        --progress=bar:force --show-progress \
        --user-agent="sing-box-updater/1.0" \
        -O "$TEMP_DIR/sing-box.tar.gz" "$DL_URL"; then
        echo -e "${RED}Ошибка при скачивании!${NC}"
        echo -e "${YELLOW}Возможные причины:${NC}"
        echo -e "${YELLOW}- Нестабильное соединение с интернетом${NC}"
        echo -e "${YELLOW}- Блокировка GitHub в вашей сети${NC}"
        echo -e "${YELLOW}- Временные проблемы с GitHub${NC}"
        rm -rf "$TEMP_DIR"
        [ -f /etc/init.d/sing-box ] && /etc/init.d/sing-box start
        return 1
    fi
    
    # Проверка размера файла с улучшенной совместимостью
    if command -v stat >/dev/null 2>&1; then
        FILE_SIZE=$(stat -c%s "$TEMP_DIR/sing-box.tar.gz" 2>/dev/null || echo "0")
    else
        # Альтернативный способ для систем без stat
        FILE_SIZE=$(ls -l "$TEMP_DIR/sing-box.tar.gz" 2>/dev/null | awk '{print $5}' || echo "0")
    fi
    
    echo -e "${CYAN}Размер скачанного файла: ${YELLOW}$FILE_SIZE${NC} байт"
    
    if [ "$FILE_SIZE" -lt 1000000 ]; then  # Меньше 1MB - подозрительно
        echo -e "${RED}Ошибка: Скачанный файл слишком мал ($FILE_SIZE байт)!${NC}"
        echo -e "${YELLOW}Ожидается размер не менее 1MB для архива sing-box${NC}"
        rm -rf "$TEMP_DIR"
        [ -f /etc/init.d/sing-box ] && /etc/init.d/sing-box start
        return 1
    fi
    
    echo -e "${GREEN}Файл успешно скачан и проверен${NC}"
    
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
    echo -e "${GREEN}11.${NC} Диагностика сети"
    echo -e "${CYAN}-------------------------------"
    echo -e "${GREEN}0.${NC} Выход"
    echo -e "${CYAN}===============================${NC}"
}

# Функция диагностики сети
network_diagnostics() {
    echo -e "\n${YELLOW}=== Диагностика сетевого подключения ==="
    
    # Проверка базового подключения
    echo -e "${CYAN}1. Проверка подключения к интернету...${NC}"
    if ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Базовое подключение работает${NC}"
    else
        echo -e "${RED}✗ Нет базового подключения к интернету${NC}"
        return 1
    fi
    
    # Проверка DNS
    echo -e "${CYAN}2. Проверка DNS...${NC}"
    if nslookup github.com >/dev/null 2>&1 || host github.com >/dev/null 2>&1; then
        echo -e "${GREEN}✓ DNS работает${NC}"
    else
        echo -e "${RED}✗ Проблемы с DNS${NC}"
        echo -e "${YELLOW}Попробуйте изменить DNS на 8.8.8.8${NC}"
    fi
    
    # Проверка доступа к GitHub
    echo -e "${CYAN}3. Проверка доступа к GitHub...${NC}"
    if wget --spider --timeout=10 https://github.com 2>/dev/null; then
        echo -e "${GREEN}✓ GitHub доступен${NC}"
    else
        echo -e "${RED}✗ GitHub недоступен${NC}"
        echo -e "${YELLOW}Возможна блокировка или проблемы с провайдером${NC}"
    fi
    
    # Проверка GitHub API
    echo -e "${CYAN}4. Проверка GitHub API...${NC}"
    if curl -s --max-time 10 https://api.github.com/rate_limit >/dev/null 2>&1; then
        echo -e "${GREEN}✓ GitHub API доступен${NC}"
    else
        echo -e "${RED}✗ GitHub API недоступен${NC}"
    fi
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
        11)
            network_diagnostics
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