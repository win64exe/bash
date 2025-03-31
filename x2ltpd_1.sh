#!/bin/bash

# Функция для установки xl2tpd и настройки
install_xl2tpd() {
    echo "Установка xl2tpd и необходимых компонентов..."
    sudo apt update
    sudo apt install -y xl2tpd iptables

    # Создание конфигурационного файла xl2tpd
    sudo mkdir -p /etc/xl2tpd
    sudo bash -c 'cat > /etc/xl2tpd/xl2tpd.conf << EOL
[global]
port = 1701
auth file = /etc/ppp/chap-secrets

[lns l2tp-vpn]
exclusive = yes
ip range = 10.2.2.100-10.2.2.199
local ip = 10.2.2.1
lac = 0.0.0.0-255.255.255.255
hidden bit = no
length bit = yes
require chap = yes
tunnel rws = 8
name = l2tp-vpn
pppoptfile = /etc/ppp/options.xl2tpd
flow bit = yes
EOL'

    # Создание файла опций PPP
    sudo bash -c 'cat > /etc/ppp/options.xl2tpd << EOL
asyncmap 0
auth
mtu 1400
mru 1400
lcp-echo-interval 60
lcp-echo-failure 4
noipx
refuse-pap
refuse-mschap
require-mschap-v2
novj
noccp
ms-dns 208.67.222.222
ms-dns 1.1.1.1
EOL'

    # Настройка NAT
    sudo iptables -t nat -A POSTROUTING -s 10.2.2.0/24 -o ens3 -j MASQUERADE
    
    # Сохранение правил iptables
    sudo sh -c "iptables-save > /etc/iptables/rules.v4"

    # Включение IP forwarding
    sudo sysctl -w net.ipv4.ip_forward=1
    sudo sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf

    # Перезапуск службы
    sudo systemctl restart xl2tpd
    sudo systemctl enable xl2tpd

    echo "Установка завершена!"
    add_user
}

# Функция для добавления пользователя
add_user() {
    echo "Добавление нового пользователя L2TP..."
    read -p "Введите имя пользователя: " username
    read -s -p "Введите пароль: " password
    echo ""
    
    # Добавление в chap-secrets
    sudo bash -c "echo '$username l2tp-vpn $password *' >> /etc/ppp/chap-secrets"
    echo "Пользователь $username успешно добавлен!"
}

# Функция для удаления пользователя с отображением списка
remove_user() {
    echo "Удаление пользователя L2TP..."
    echo "Список существующих пользователей:"
    
    # Проверка существования файла и вывод пользователей
    if [ -f /etc/ppp/chap-secrets ]; then
        echo "----------------------------------------"
        awk '$2 == "l2tp-vpn" {print "Имя пользователя: " $1}' /etc/ppp/chap-secrets
        echo "----------------------------------------"
    else
        echo "Файл chap-secrets пуст или не существует."
        return
    fi
    
    read -p "Введите имя пользователя для удаления: " username
    
    if grep -q "^$username " /etc/ppp/chap-secrets; then
        sudo sed -i "/^$username /d" /etc/ppp/chap-secrets
        echo "Пользователь $username успешно удален!"
    else
        echo "Пользователь $username не найден!"
    fi
}

# Функция для удаления xl2tpd и всех настроек
remove_xl2tpd() {
    echo "Удаление xl2tpd и всех связанных настроек..."

    # Остановка и отключение службы
    sudo systemctl stop xl2tpd
    sudo systemctl disable xl2tpd

    # Удаление пакета xl2tpd
    sudo apt purge -y xl2tpd
    sudo apt autoremove -y

    # Удаление конфигурационных файлов
    sudo rm -rf /etc/xl2tpd/xl2tpd.conf
    sudo rm -rf /etc/ppp/options.xl2tpd
    sudo rm -rf /etc/ppp/chap-secrets

    # Удаление правила NAT из iptables
    sudo iptables -t nat -D POSTROUTING -s 10.2.2.0/24 -o ens3 -j MASQUERADE 2>/dev/null
    sudo sh -c "iptables-save > /etc/iptables/rules.v4"

    # Отключение IP forwarding
    sudo sysctl -w net.ipv4.ip_forward=0
    sudo sed -i 's/net.ipv4.ip_forward=1/#net.ipv4.ip_forward=1/' /etc/sysctl.conf

    echo "xl2tpd и все связанные настройки успешно удалены!"
}

# Основное меню
echo "Выберите действие:"
echo "1. Установить"
echo "2. Добавить пользователя L2TP"
echo "3. Удалить пользователя"
echo "4. Удалить xl2tpd"
read -p "Введите номер действия (1-4): " choice

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
    *)
        echo "Неверный выбор! Пожалуйста, выберите 1, 2, 3 или 4."
        ;;
esac
