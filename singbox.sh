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
    
    # Скачивание
    if ! wget -O /tmp/sing-box.tar.gz "$DL_URL"; then
        echo -e "${RED}Ошибка при скачивании!${NC}"
        [ -f /etc/init.d/sing-box ] && /etc/init.d/sing-box start
        return 1
    fi
    
    # Распаковка
    echo -e "${GREEN}Распаковка архива...${NC}"
    if ! tar -xzf /tmp/sing-box.tar.gz -C /tmp/; then
        echo -e "${RED}Ошибка при распаковке!${NC}"
        rm -f /tmp/sing-box.tar.gz
        [ -f /etc/init.d/sing-box ] && /etc/init.d/sing-box start
        return 1
    fi
    
    # Установка
    echo -e "${GREEN}Установка новой версии...${NC}"
    if ! mv /tmp/sing-box-${LATEST_VERSION#v}-linux-${ARCH}${PKG}/sing-box /usr/bin/; then
        echo -e "${RED}Ошибка при перемещении файла!${NC}"
        rm -f /tmp/sing-box.tar.gz
        rm -rf /tmp/sing-box-${LATEST_VERSION#v}-linux-${ARCH}${PKG}
        [ -f /etc/init.d/sing-box ] && /etc/init.d/sing-box start
        return 1
    fi
    
    chmod +x /usr/bin/sing-box
    
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
    
    # Очистка
    rm -f /tmp/sing-box.tar.gz
    rm -rf /tmp/sing-box-${LATEST_VERSION#v}-linux-${ARCH}${PKG}
}
