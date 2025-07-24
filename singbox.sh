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

# Функция обновления sing-box с curl и ожиданием сети
update_sing_box() {
    echo -e "\n\033[0;33m=== Получение информации о последней версии ===\033[0m"
    LATEST_VERSION=$(curl -s https://api.github.com/repos/SagerNet/sing-box/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    CURRENT_VERSION=$(sing-box version 2>/dev/null | head -n 1 | awk '{print $3}')
    
    echo -e "\033[0;36mТекущая версия: \033[0;33m${CURRENT_VERSION:-Не установлена}\033[0m"
    echo -e "\033[0;36mПоследняя версия: \033[0;33m${LATEST_VERSION}\033[0m"
    
    if [ "$CURRENT_VERSION" = "${LATEST_VERSION#v}" ]; then
        echo -e "\033[0;32mУ вас установлена последняя версия!\033[0m"
        return 0
    else
        echo -e "\033[0;31mДоступно обновление!\033[0m"
    fi
    
    # Автоматическое определение архитектуры
    ARCH=$(detect_architecture)
    if [ "$ARCH" = "unknown" ]; then
        echo -e "\033[0;31mНе удалось определить архитектуру процессора!\033[0m"
        echo -e "\033[0;33mПожалуйста, выберите вручную:\033[0m"
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
            *) 
                echo -e "\033[0;31mНеверный выбор\033[0m"
                return
                ;;
        esac
    else
        echo -e "\033[0;36mАвтоматически определена архитектура: \033[0;33m${ARCH}\033[0m"
    fi
    
    # Вывод доступных пакетов
    echo -e "\n\033[0;33m=== Доступные пакеты для вашей архитектуры ===\033[0m"
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
    esac
    read -p "Выберите пакет (1 или 2): " pkg_choice
    
    case "$pkg_choice" in
        1) PKG="" ;;
        2) PKG="-musl" ;;
        *) 
            echo -e "\033[0;31mНеверный выбор пакета\033[0m"
            return
            ;;
    esac

    # Ожидаем готовности сети и DNS
    echo -e "\033[0;36mОжидание доступности DNS...\033[0m"
    while ! nslookup github.com 8.8.8.8 >/dev/null 2>&1; do
      echo " DNS недоступен, жду 3 секунды..."
      sleep 3
    done

    echo -e "\n\033[0;33m=== Начинаем обновление ===\033[0m"
    /etc/init.d/sing-box stop

    DL_URL="https://github.com/SagerNet/sing-box/releases/download/${LATEST_VERSION}/sing-box-${LATEST_VERSION#v}-linux-${ARCH}${PKG}.tar.gz"
    echo -e "\033[0;36mСкачивание: \033[0;33m${DL_URL}\033[0m"
    
    # Используем curl вместо wget
    curl -fL -o /tmp/sing-box.tar.gz "$DL_URL" || {
        echo -e "\033[0;31mОшибка при скачивании!\033[0m"
        /etc/init.d/sing-box start
        return 1
    }
    
    echo -e "\033[0;32mРаспаковка архива...\033[0m"
    tar -xzf /tmp/sing-box.tar.gz -C /tmp/ || {
        echo -e "\033[0;31mОшибка при распаковке!\033[0m"
        /etc/init.d/sing-box start
        return 1
    }
    
    echo -e "\033[0;32mУстановка новой версии...\033[0m"
    mv /tmp/sing-box-${LATEST_VERSION#v}-linux-${ARCH}${PKG}/sing-box /usr/bin/ || {
        echo -e "\033[0;31mОшибка при перемещении файла!\033[0m"
        /etc/init.d/sing-box start
        return 1
    }
    
    chmod +x /usr/bin/sing-box
    /etc/init.d/sing-box start
    
    echo -e "\n\033[0;32m=== Проверка версии после обновления ===\033[0m"
    sing-box version
    
    echo -e "\n\033[0;32m✅ Sing-box успешно обновлен до версии ${LATEST_VERSION}\033[0m"
    
    # Очистка временных файлов
    rm -rf /tmp/sing-box*
}
