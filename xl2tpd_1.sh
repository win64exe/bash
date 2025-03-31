#!/bin/bash

# Ультра-яркие цветовые коды
ULTRA_BRIGHT_GREEN='\033[1;92;5m'
ULTRA_BRIGHT_YELLOW='\033[1;93;5m'
ULTRA_BRIGHT_BLUE='\033[1;94;5m'
ULTRA_BRIGHT_RED='\033[1;91;5m'
NC='\033[0m' # Сброс цвета

# Проверка на root
if [ "<span class="math-inline">\(id \-u\)" \-ne 0 \]; then
echo \-e "</span>{ULTRA_BRIGHT_RED}Этот скрипт должен быть запущен с правами root!<span class="math-inline">\{NC\}"
exit 1
fi
\# Определение внешнего интерфейса и IP
DEFAULT\_IFACE\=</span>(ip route | grep '^default' | awk '{print <span class="math-inline">5\}' \| head \-n1\)
SERVER\_IP\=</span>(curl -s ifconfig.me || ip addr show $DEFAULT_IFACE | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)

# Функция для вывода данных подключения
show_credentials() {
    local username=$1
    local password=<span class="math-inline">2
echo \-e "\\n</span>{ULTRA_BRIGHT_GREEN}=== ДАННЫЕ ДЛЯ ПОДКЛЮЧЕНИЯ ===<span class="math-inline">\{NC\}"
echo \-e "</span>{ULTRA_BRIGHT_BLUE}IP сервера:${NC} <span class="math-inline">SERVER\_IP"
echo \-e "</span>{ULTRA_BRIGHT_BLUE}Логин:${NC} <span class="math-inline">username"
echo \-e "</span>{ULTRA_BRIGHT_BLUE}Пароль:${NC} <span class="math-inline">password"
echo \-e "</span>{ULTRA_BRIGHT_GREEN}===========================<span class="math-inline">\{NC\}"
\}
\# Функция для установки xl2tpd
function install\_xl2tpd \{
echo \-e "</span>{ULTRA_BRIGHT_BLUE}Установка xl2tpd и необходимых компонентов...<span class="math-inline">\{NC\}"
apt update \>/dev/null 2\>&1 \|\| \{
echo \-e "</span>{ULTRA_BRIGHT_RED}Ошибка при обновлении пакетов!<span class="math-inline">\{NC\}"
exit 1
\}
apt install \-y xl2tpd iptables \>/dev/null 2\>&1 \|\| \{
echo \-e "</span>{ULTRA_BRIGHT_RED}Ошибка при установке пакетов!<span class="math-inline">\{NC\}"
exit 1
\}
\# Конфигурация xl2tpd
mkdir \-p /etc/xl2tpd
cat \> /etc/xl2tpd/xl2tpd\.conf <<EOL
\[global\]
port \= 1701
auth file \= /etc/ppp/chap\-secrets
\[lns l2tp\-vpn\]
exclusive \= yes
ip range \= 10\.2\.2\.100\-10\.2\.2\.199
local ip \= 10\.2\.2\.1
lac \= 0\.0\.0\.0\-255\.255\.255\.255
hidden bit \= no
length bit \= yes
require chap \= yes
tunnel rws \= 8
name \= l2tp\-vpn
pppoptfile \= /etc/ppp/options\.xl2tpd
flow bit \= yes
EOL
\# Настройки PPP
cat \> /etc/ppp/options\.xl2tpd <<EOL
asyncmap 0
auth
mtu 1400
mru 1400
lcp\-echo\-interval 60
lcp\-echo\-failure 4
noipx
refuse\-pap
refuse\-mschap
require\-mschap\-v2
novj
noccp
ms\-dns 208\.67\.222\.222
ms\-dns 1\.1\.1\.1
EOL
\# Настройка файла аутентификации
touch /etc/ppp/chap\-secrets
chmod 600 /etc/ppp/chap\-secrets
\# Настройка NAT
echo \-e "</span>{ULTRA_BRIGHT_YELLOW}Используется интерфейс: <span class="math-inline">DEFAULT\_IFACE</span>{NC}"
    iptables -t nat -A POSTROUTING -s 10.2.2.0/24 -o <span class="math-inline">DEFAULT\_IFACE \-j MASQUERADE
\# Сохранение правил iptables
mkdir \-p /etc/iptables
iptables\-save \> /etc/iptables/rules\.v4
\# Включение переадресации IP
sysctl \-w net\.ipv4\.ip\_forward\=1
sed \-i 's/\#net\.ipv4\.ip\_forward\=1/net\.ipv4\.ip\_forward\=1/' /etc/sysctl\.conf
\# Запуск службы
systemctl restart xl2tpd
systemctl enable xl2tpd \>/dev/null 2\>&1
echo \-e "</span>{ULTRA_BRIGHT_GREEN}Установка завершена успешно!<span class="math-inline">\{NC\}"
\}
\# Функция для добавления пользователя
function add\_user \{
echo \-e "</span>{ULTRA_BRIGHT_BLUE}Добавление нового пользователя L2TP...${NC}"
    
    while true; do
        read -p "Введите имя пользователя: " username
        if [ -z "<span class="math-inline">username" \]; then
echo \-e "</span>{ULTRA_BRIGHT_RED}Имя пользователя не может быть пустым!${NC}"
            continue
        fi
        
        if grep -q "^<span class="math-inline">username " /etc/ppp/chap\-secrets; then
echo \-e "</span>{ULTRA_BRIGHT_YELLOW}Пользователь <span class="math-inline">username уже существует\!</span>{NC}"
            read -p "Хотите изменить пароль для этого пользователя? (y/n): " change
            if [[ "$change" =~ ^[YyДд] ]]; then
                sed -i "/^$username /d" /etc/ppp/chap-secrets
            else
                continue
            fi
        fi
        break
    done
    
    read -s -p "Введите пароль: " password
    echo
    
    # Добавление пользователя
    echo "$username l2tp-vpn $password *" >> /etc/ppp/chap-secrets
    systemctl restart xl2tpd
    
    # Вывод данных для подключения
    show_credentials "$username" "<span class="math-inline">password"
\}
\# Функция для удаления пользователя
function remove\_user \{
echo \-e "</span>{ULTRA_BRIGHT_BLUE}Удаление пользователя L2TP...<span class="math-inline">\{NC\}"
if \[ \! \-f /etc/ppp/chap\-secrets \] \|\| \[ \! \-s /etc/ppp/chap\-secrets \]; then
echo \-e "</span>{ULTRA_BRIGHT_RED}Файл chap-secrets пуст или не существует!<span class="math-inline">\{NC\}"
return 1
fi
echo \-e "</span>{ULTRA_BRIGHT_BLUE}Список пользователей:${NC}"
    echo "----------------------------------------"
    awk '$2 == "l2tp-vpn" {print "Имя пользователя: " $1}' /etc/ppp/chap-secrets
    echo "----------------------------------------"
    
    while true; do
        read -p "Введите имя пользователя для удаления (или 'q' для выхода): " username
        
        if [ "$username" = "q" ]; then
            return 0
        fi
        
        if grep -q "^$username " /etc/ppp/chap-secrets; then
            sed -i "/^<span class="math-inline">username /d" /etc/ppp/chap\-secrets
systemctl restart xl2tpd
echo \-e "</span>{ULTRA_BRIGHT_GREEN}Пользователь <span class="math-inline">username успешно удален\!</span>{NC}"
            return 0
        else
            echo -e "${ULTRA_BRIGHT_RED}Пользователь <span class="math-inline">username не найден\!</span>{NC}"
        fi
    done
}

# Функция для удаления xl2tpd
function remove_xl2tpd {
    echo -e "<span class="math-inline">\{ULTRA\_BRIGHT\_YELLOW\}Внимание\! Будут удалены все настройки xl2tpd\!</span>{NC}"
    read -p "Вы уверены, что хотите продолжить? (y/n): " confirm
    
    if [[ ! "<span class="math-inline">confirm" \=\~ ^\[YyДд\] \]\]; then
echo \-e "</span>{ULTRA_BRIGHT_BLUE}Удаление отменено.<span class="math-inline">\{NC\}"
return
fi
echo \-e "</span>{ULTRA_BRIGHT_BLUE}Удаление xl2tpd...${NC}"

    systemctl stop xl2tpd 2>/dev/null
    systemctl disable xl2tpd 2>/dev/null

    apt purge -y xl2tpd
