#!/bin/bash
shopt -s expand_aliases
Font_Black="\033[30m"
Font_Red="\033[31m"
Font_Green="\033[32m"
Font_Yellow="\033[33m"
Font_Blue="\033[34m"
Font_Purple="\033[35m"
Font_SkyBlue="\033[36m"
Font_White="\033[37m"
Font_Suffix="\033[0m"

while getopts ":I:" optname; do
    case "$optname" in
    "I")
        iface="$OPTARG"
        useNIC="--interface $iface"
        ;;
    ":")
        echo "Неизвестная ошибка при обработке опций"
        exit 1
        ;;
    esac

done

checkOS(){
    ifCentOS=$(cat /etc/os-release | grep CentOS)
    if [ -n "$ifCentOS" ];then
        OS_Version=$(cat /etc/os-release | grep REDHAT_SUPPORT_PRODUCT_VERSION | cut -f2 -d'"')
        if [[ "$OS_Version" -lt "8" ]];then
            echo -e "${Font_Red}Этот скрипт не поддерживает CentOS${OS_Version}. Пожалуйста, обновитесь до CentOS 8 или смените ОС${Font_Suffix}"
            echo -e "${Font_Red}Выход через 3 секунды...${Font_Suffix}"
            sleep 3
            exit 1
        fi
    fi        
}
checkOS

if [ -z "$iface" ]; then
    useNIC=""
fi

if ! mktemp -u --suffix=RRC &>/dev/null; then
    is_busybox=1
fi

UA_Browser="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/80.0.3987.87 Safari/537.36"

CountRunTimes() {
    if [ "$is_busybox" == 1 ]; then
        count_file=$(mktemp)
    else
        count_file=$(mktemp --suffix=RRC)
    fi
    RunTimes=$(curl -s --max-time 10 "https://hits.seeyoufarm.com/api/count/incr/badge.svg?url=https%3A%2F%2Fgithub.com%2Flmc999%2FTikTokCheck&count_bg=%2379C83D&title_bg=%23555555&icon=&icon_color=%23E7E7E7&title=hits&edge_flat=false" >"${count_file}")
    TodayRunTimes=$(cat "${count_file}" | tail -3 | head -n 1 | awk '{print $5}')
    TotalRunTimes=$(cat "${count_file}" | tail -3 | head -n 1 | awk '{print $7}')
}
CountRunTimes

local_ipv4=$(curl $useNIC -4 -s --max-time 10 api64.ipify.org)
local_ipv4_asterisk=$(awk -F"." '{print $1"."$2".*.*"}' <<<"${local_ipv4}")
local_isp4=$(curl $useNIC -s -4 -A $UA_Browser --max-time 10 https://api.ip.sb/geoip/${local_ipv4} | grep organization | cut -f4 -d '"')

function MediaUnlockTest_Tiktok_Region() {
    echo -n -e " Регион Tiktok:\t\t\c"
    local Ftmpresult=$(curl $useNIC --user-agent "${UA_Browser}" -s --max-time 10 "https://www.tiktok.com/")

    if [[ "$Ftmpresult" = "curl"* ]]; then
        echo -n -e "\r Регион Tiktok:\t\t${Font_Red}Ошибка (Сбой сети)${Font_Suffix}\n"
        return
    fi

    local FRegion=$(echo $Ftmpresult | grep '"region":' | sed 's/.*"region"//' | cut -f2 -d'"')
    if [ -n "$FRegion" ]; then
        echo -n -e "\r Регион Tiktok:\t\t${Font_Green}【${FRegion}】${Font_Suffix}\n"
        return
    fi

    local STmpresult=$(curl $useNIC --user-agent "${UA_Browser}" -sL --max-time 10 -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9" -H "Accept-Encoding: gzip" -H "Accept-Language: en" "https://www.tiktok.com" | gunzip 2>/dev/null)
    local SRegion=$(echo $STmpresult | grep '"region":' | sed 's/.*"region"//' | cut -f2 -d'"')
    if [ -n "$SRegion" ]; then
        echo -n -e "\r Регион Tiktok:\t\t${Font_Yellow}【${SRegion}】(Возможно IP дата-центра)${Font_Suffix}\n"
        return
    else
        echo -n -e "\r Регион Tiktok:\t\t${Font_Red}Не удалось определить${Font_Suffix}\n"
        return
    fi

}

function Heading() {
    echo -e " ${Font_SkyBlue}** Ваша сеть: ${local_isp4} (${local_ipv4_asterisk})${Font_Suffix} "
    echo "******************************************"
    echo ""

}

function Goodbye() {
    echo ""
    echo "******************************************"
    echo ""
    echo -e ""
    echo -e ""
    echo -e ""
    echo -e ""
    #echo -e "${Font_Yellow}Статистика запуска скрипта за сегодня：${TodayRunTimes}; Всего запусков：${TotalRunTimes} ${Font_Suffix}"
    echo -e ""
    echo -e "${Font_SkyBlue}【Инфо о TikTok】${Font_Suffix}"
    echo -e "================================================"
    echo -e "${Font_Yellow}Разблокировка TikTok (Резидентные IP)${Font_Suffix}"
    echo ""
    echo -e "${Font_Green}✅ ${Font_Suffix} ${Font_SkyBlue}IP домашних провайдеров разных стран${Font_Suffix}"
    echo -e "${Font_Green}✅ ${Font_Suffix} ${Font_SkyBlue}Настройка в один клик${Font_Suffix}"
    echo -e "${Font_Green}✅ ${Font_Suffix} ${Font_SkyBlue}Поддержка индивидуальных заказов${Font_Suffix}"
    echo ""
    echo -e "${Font_Yellow}Контакты: https://t.me/czgno${Font_Suffix}"
    echo -e "================================================"
    echo -e ""
    echo -e ""
    echo -e ""
    echo -e ""

}

clear

function ScriptTitle() {
    echo -e "${Font_SkyBlue}【Проверка региона Tiktok】${Font_Suffix}"
    echo -e "${Font_Green}Сообщить о баге или обсудить: TG группа${Font_Suffix} ${Font_Yellow}https://t.me/tiktok_operate ${Font_Suffix}"
    echo ""
    echo -e " ** Время теста: $(date)"
    echo ""
}
ScriptTitle

function RunScript() {
    Heading
    MediaUnlockTest_Tiktok_Region
    Goodbye

}

RunScript
