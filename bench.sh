#!/bin/bash

# Define version
CURRENT_VERSION="2025-01-21 v1.2.7" # Latest version number
SCRIPT_URL="https://raw.githubusercontent.com/nodeloc/nodeloc_vps_test/main/Nlbench.sh"
VERSION_URL="https://raw.githubusercontent.com/nodeloc/nodeloc_vps_test/main/version.sh"
CLOUD_SERVICE_BASE="https://bench.nodeloc.cc"

# Define colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;36m'
NC='\033[0m' # No Color

# Define gradient color array
colors=(
    '\033[38;2;0;255;0m'    # Green
    '\033[38;2;64;255;0m'
    '\033[38;2;128;255;0m'
    '\033[38;2;192;255;0m'
    '\033[38;2;255;255;0m'  # Yellow
)

# Update script
update_scripts() {
    echo -e "${BLUE}┌─────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│           VPS Test Script               │${NC}"
    echo -e "${BLUE}│               Version Check             │${NC}"
    echo -e "${BLUE}└─────────────────────────────────────────┘${NC}"

    REMOTE_VERSION=$(curl -s $VERSION_URL | tail -n 1 | grep -oP '(?<=#\s)[\d-]+\sv[\d.]+(?=\s-)')
    if [ -z "$REMOTE_VERSION" ]; then
        echo -e "${RED}✖ Unable to retrieve remote version information. Please check your network connection.${NC}"
        return 1
    fi

    echo -e "${BLUE}┌─────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│               Version History           │${NC}"
    echo -e "${BLUE}├─────────────────────────────────────────┤${NC}"
    echo -e "${YELLOW}  Current Version: ${GREEN}$CURRENT_VERSION${NC}"
    echo -e "${BLUE}├─────────────────────────────────────────┤${NC}"
    echo -e "${YELLOW}  Version History:${NC}"
    curl -s $VERSION_URL | grep -oP '(?<=#\s)[\d-]+\sv[\d.]+(?=\s-)' | 
    while read version; do
        if [ "$version" = "$CURRENT_VERSION" ]; then
            echo -e "  ${GREEN}▶ $version ${NC}(Current Version)"
        else
            echo -e "    $version"
        fi
    done
    echo -e "${BLUE}└─────────────────────────────────────────┘${NC}"

    if [ "$REMOTE_VERSION" != "$CURRENT_VERSION" ]; then
        echo -e "\n${YELLOW}New version found: ${GREEN}$REMOTE_VERSION${NC}"
        echo -e "${BLUE}Updating...${NC}"
        
        if curl -s -o /tmp/NLbench.sh $SCRIPT_URL; then
            NEW_VERSION=$(grep '^CURRENT_VERSION=' /tmp/NLbench.sh | cut -d'"' -f2)
            if [ "$NEW_VERSION" != "$CURRENT_VERSION" ]; then
                sed -i "s/^CURRENT_VERSION=.*/CURRENT_VERSION=\"$NEW_VERSION\"/" "$0"
                
                if mv /tmp/NLbench.sh "$0"; then
                    chmod +x "$0"
                    echo -e "${GREEN}┌─────────────────────────────────────────┐${NC}"
                    echo -e "${GREEN}│            Script Updated Successfully! │${NC}"
                    echo -e "${GREEN}└─────────────────────────────────────────┘${NC}"
                    echo -e "${YELLOW}New Version: ${GREEN}$NEW_VERSION${NC}"
                    echo -e "${YELLOW}Restarting script to apply update...${NC}"
                    sleep 3
                    exec bash "$0"
                else
                    echo -e "${RED}✖ Unable to replace script file. Please check permissions.${NC}"
                    return 1
                fi
            else
                echo -e "${GREEN}✔ Script is already the latest version.${NC}"
            fi
        else
            echo -e "${RED}✖ Failed to download new version. Please try again later.${NC}"
            return 1
        fi
    else
        echo -e "\n${GREEN}✔ Script is already the latest version.${NC}"
    fi
    
    echo -e "${BLUE}┌─────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│            Update Check Completed       │${NC}"
    echo -e "${BLUE}└─────────────────────────────────────────┘${NC}"
}

# Check root permissions and acquire sudo privileges
check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo "This script requires root privileges to run."
        if ! sudo -v; then
            echo "Unable to acquire sudo privileges, exiting script."
            exit 1
        fi
        echo "Sudo privileges acquired."
    fi
}

# Detect operating system
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        os_type=$ID
    elif type lsb_release >/dev/null 2>&1; then
        os_type=$(lsb_release -si)
    elif [ -f /etc/lsb-release ]; then
        . /etc/lsb-release
        os_type=$DISTRIB_ID
    elif [ -f /etc/debian_version ]; then
        os_type="debian"
    elif [ -f /etc/fedora-release ]; then
        os_type="fedora"
    elif [ -f /etc/centos-release ]; then
        os_type="centos"
    else
        os_type=$(uname -s)
    fi
    os_type=$(echo $os_type | tr '[:upper:]' '[:lower:]')
    echo "Detected operating system: $os_type"
}

# Update system
update_system() {
    detect_os
    if [ $? -ne 0 ]; then
        echo -e "${RED}Unable to detect operating system.${NC}"
        return 1
    fi
    case "${os_type,,}" in
        ubuntu|debian|linuxmint|elementary|pop)
            update_cmd="apt-get update"
            upgrade_cmd="apt-get upgrade -y"
            clean_cmd="apt-get autoremove -y"
            ;;
        centos|rhel|fedora|rocky|almalinux|openeuler)
            if command -v dnf &>/dev/null; then
                update_cmd="dnf check-update"
                upgrade_cmd="dnf upgrade -y"
                clean_cmd="dnf autoremove -y"
            else
                update_cmd="yum check-update"
                upgrade_cmd="yum upgrade -y"
                clean_cmd="yum autoremove -y"
            fi
            ;;
        opensuse*|sles)
            update_cmd="zypper refresh"
            upgrade_cmd="zypper dup -y"
            clean_cmd="zypper clean -a"
            ;;
        arch|manjaro)
            update_cmd="pacman -Sy"
            upgrade_cmd="pacman -Syu --noconfirm"
            clean_cmd="pacman -Sc --noconfirm"
            ;;
        alpine)
            update_cmd="apk update"
            upgrade_cmd="apk upgrade"
            clean_cmd="apk cache clean"
            ;;
        gentoo)
            update_cmd="emerge --sync"
            upgrade_cmd="emerge -uDN @world"
            clean_cmd="emerge --depclean"
            ;;
        cloudlinux)
            update_cmd="yum check-update"
            upgrade_cmd="yum upgrade -y"
            clean_cmd="yum clean all"
            ;;
        *)
            echo -e "${RED}Unsupported Linux distribution: $os_type${NC}"
            return 1
            ;;
    esac
    
    echo -e "${YELLOW}Updating system...${NC}"
    sudo $update_cmd
    if [ $? -eq 0 ]; then
        sudo $upgrade_cmd
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}System update completed.${NC}"
            echo -e "${YELLOW}Cleaning system...${NC}"
            sudo $clean_cmd
            echo -e "${GREEN}System cleanup completed.${NC}"
            # Check if reboot is required
            if [ -f /var/run/reboot-required ]; then
                echo -e "${YELLOW}System update requires a reboot to complete. Please reboot the system when convenient.${NC}"
            fi
            return 0
        fi
    fi
    echo -e "${RED}System update failed.${NC}"
    return 1
}

# Define supported operating system types
SUPPORTED_OS=("ubuntu" "debian" "linuxmint" "elementary" "pop" "centos" "rhel" "fedora" "rocky" "almalinux" "openeuler" "opensuse" "sles" "arch" "manjaro" "alpine" "gentoo" "cloudlinux")

install_dependencies() {
    echo -e "${YELLOW}Checking and installing necessary dependencies...${NC}"
    
    # Ensure os_type is defined
    if [ -z "$os_type" ]; then
        detect_os
    fi
    
    # Update system
    update_system || echo -e "${RED}System update failed. Continuing with dependency installation.${NC}"
    
    # Install dependencies
    local dependencies=("curl" "wget" "iperf3" "bc")
    
    # Check if it's a supported operating system
    if [[ ! " ${SUPPORTED_OS[@]} " =~ " ${os_type} " ]]; then
        echo -e "${RED}Unsupported operating system: $os_type${NC}"
        return 1
    fi
    
    case "${os_type,,}" in
        debian|ubuntu)
            export DEBIAN_FRONTEND=noninteractive 
            echo "iperf3 iperf3/autostart boolean false" | sudo debconf-set-selections
            install_cmd="apt-get install -yq"
            sudo apt-get update -yq
            ;;
        centos|rhel|fedora)
            install_cmd="dnf install -y"
            sudo dnf makecache
            ;;
        alpine)
            install_cmd="apk add --no-cache"
            ;;
        gentoo)
            install_cmd="emerge --quiet"
            ;;
        arch|manjaro)
            install_cmd="pacman -S --noconfirm"
            sudo pacman -Sy --noconfirm
            ;;
        *)
            echo -e "${RED}Unknown package manager. Please manually install dependencies.${NC}"
            return 1
            ;;
    esac

    # Install dependencies
    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            echo -e "${YELLOW}Installing $dep...${NC}"
            if ! sudo $install_cmd "$dep"; then
                echo -e "${RED}Unable to install $dep. Please manually install this dependency.${NC}"
            fi
        else
            echo -e "${GREEN}$dep is already installed.${NC}"
        fi
    done
    
    echo -e "${GREEN}Dependency check and installation completed.${NC}"
}



# Get IP address and ISP information
ip_address_and_isp() {
    ipv4_address=$(curl -s --max-time 5 ipv4.ip.sb)
    if [ -z "$ipv4_address" ]; then
        ipv4_address=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -n1)
    fi

    ipv6_address=$(curl -s --max-time 5 ipv6.ip.sb)
    if [ -z "$ipv6_address" ]; then
        ipv6_address=$(ip -6 addr show | grep -oP '(?<=inet6\s)[\da-f:]+' | grep -v '^::1' | grep -v '^fe80' | head -n1)
    fi

    # Get ISP information
    isp_info=$(curl -s ipinfo.io/org)

    # Check if it's WARP or Cloudflare
    is_warp=false
    if echo "$isp_info" | grep -iq "cloudflare\|warp\|1.1.1.1"; then
        is_warp=true
    fi

    # Determine whether to use IPv6 or IPv4
    use_ipv6=false
    if [ "$is_warp" = true ] || [ -z "$ipv4_address" ]; then
        use_ipv6=true
    fi

    echo "IPv4: $ipv4_address"
    echo "IPv6: $ipv6_address"
    echo "ISP: $isp_info"
    echo "Is WARP: $is_warp"
    echo "Use IPv6: $use_ipv6"
}

# Detect VPS geographic location
detect_region() {
    local country
    country=$(curl -s ipinfo.io/country)
    case $country in
        "TW") echo "1" ;;          # Taiwan
        "HK") echo "2" ;;          # Hong Kong
        "JP") echo "3" ;;          # Japan
        "US" | "CA") echo "4" ;;   # North America
        "BR" | "AR" | "CL") echo "5" ;;  # South America
        "GB" | "DE" | "FR" | "NL" | "SE" | "NO" | "FI" | "DK" | "IT" | "ES" | "CH" | "AT" | "BE" | "IE" | "PT" | "GR" | "PL" | "CZ" | "HU" | "RO" | "BG" | "HR" | "SI" | "SK" | "LT" | "LV" | "EE") echo "6" ;;  # Europe
        "AU" | "NZ") echo "7" ;;   # Oceania
        "KR") echo "8" ;;          # South Korea
        "SG" | "MY" | "TH" | "ID" | "PH" | "VN") echo "9" ;;  # Southeast Asia
        "IN") echo "10" ;;         # India
        "ZA" | "NG" | "EG" | "KE" | "MA" | "TN" | "GH" | "CI" | "SN" | "UG" | "ET" | "MZ" | "ZM" | "ZW" | "BW" | "MW" | "NA" | "RW" | "SD" | "DJ" | "CM" | "AO") echo "11" ;;  # Africa
        *) echo "0" ;;             # Transnational platform
    esac
}

# Count usage times
sum_run_times() {
    local COUNT=$(wget --no-check-certificate -qO- --tries=2 --timeout=2 "https://hits.seeyoufarm.com/api/count/incr/badge.svg?url=https%3A%2F%2Fgithub.com%2Fnodeloc%2Fnodeloc_vps_test%2Fblob%2Fmain%2FNlbench.sh" 2>&1 | grep -m1 -oE "[0-9]+[ ]+/[ ]+[0-9]+")
    if [[ -n "$COUNT" ]]; then
        daily_count=$(cut -d " " -f1 <<< "$COUNT")
        total_count=$(cut -d " " -f3 <<< "$COUNT")
    else
        echo "Failed to fetch usage counts."
        daily_count=0
        total_count=0
    fi
}

# Run a single script and output results to a file
run_script() {
    local script_number=$1
    local output_file=$2
    local temp_file=$(mktemp)
    # Call ip_address_and_isp function to get IP address and ISP information
    ip_address_and_isp
    case $script_number in
        # YABS
        1)
            echo -e "Running ${YELLOW}YABS...${NC}"
            curl -sL yabs.sh | bash -s -- -i -5 | tee "$temp_file"
            sed -i 's/\x1B\[[0-9;]*[JKmsu]//g' "$temp_file"
            sed -i 's/\.\.\./\.\.\.\n/g' "$temp_file"
            sed -i '/\.\.\./d' "$temp_file"
            sed -i '/^\s*$/d'   "$temp_file"
            cp "$temp_file" "${output_file}_yabs" 
            ;;
        # IP Quality
        2)
            echo -e "Running ${YELLOW}IP Quality Test...${NC}"
            echo y | bash <(curl -Ls IP.Check.Place) | tee "$temp_file"
            sed -i 's/\x1B\[[0-9;]*[JKmsu]//g' "$temp_file"
            sed -i -r 's/(⠋|⠙|⠹|⠸|⠼|⠴|⠦|⠧|⠇|⠏)/\n/g' "$temp_file"
            sed -i -r '/Checking/d' "$temp_file"
            sed -i -n '/########################################################################/,${s/^.*\(########################################################################\)/\1/;p}' "$temp_file"
            sed -i '/^$/d' "$temp_file"
            cp "$temp_file" "${output_file}_ip_quality"
            ;;
        # Streaming Unlock
        3)
            echo -e "Running ${YELLOW}Streaming Unlock Test...${NC}"
            local region=$(detect_region)
            bash <(curl -L -s media.ispvps.com) <<< "$region" | tee "$temp_file"
            sed -i 's/\x1B\[[0-9;]*[JKmsu]//g' "$temp_file"
            sed -i -n '/Streaming Platform and Game Region Restriction Test/,$p' "$temp_file"
            sed -i '1d' "$temp_file"
            sed -i '/^$/d' "$temp_file"
            cp "$temp_file" "${output_file}_streaming"
            ;;
        # Response Test
        4)
            echo -e "Running ${YELLOW}Response Test...${NC}"
            bash <(curl -sL https://nodebench.mereith.com/scripts/curltime.sh) | tee "$temp_file"
            sed -i 's/\x1B\[[0-9;]*[JKmsu]//g' "$temp_file"
            cp "$temp_file" "${output_file}_response"
            ;;
        # Multi-threaded Speed Test
        5)
            echo -e "Running ${YELLOW}Multi-threaded Speed Test...${NC}"
            if [ "$use_ipv6" = true ]; then
            echo "Using IPv6 test option"
            bash <(curl -sL https://raw.githubusercontent.com/i-abc/Speedtest/main/speedtest.sh) <<< "3" | tee "$temp_file"
            else
            echo "Using IPv4 test option"
            bash <(curl -sL https://raw.githubusercontent.com/i-abc/Speedtest/main/speedtest.sh) <<< "1" | tee "$temp_file"
            fi
            sed -r -i 's/\x1B\[[0-9;]*[JKmsu]//g' "$temp_file"
            sed -i -r '1,/Number\:/d' "$temp_file"
            sed -i -r 's/(⠋|⠙|⠹|⠸|⠼|⠴|⠦|⠧|⠇|⠏)/\n/g' "$temp_file"
            sed -i -r '/Test in progress/d' "$temp_file"
            sed -i '/^$/d' "$temp_file"
            cp "$temp_file" "${output_file}_multi_thread"
            ;;
        # Single-threaded Speed Test
        6)
            echo -e "Running ${YELLOW}Single-threaded Speed Test...${NC}"
            if [ "$use_ipv6" = true ]; then
            echo "Using IPv6 test option"
            bash <(curl -sL https://raw.githubusercontent.com/i-abc/Speedtest/main/speedtest.sh) <<< "17" | tee "$temp_file"
            else
            echo "Using IPv4 test option"
            bash <(curl -sL https://raw.githubusercontent.com/i-abc/Speedtest/main/speedtest.sh) <<< "2" | tee "$temp_file"
            fi
            sed -r -i 's/\x1B\[[0-9;]*[JKmsu]//g' "$temp_file"
            sed -i -r '1,/Number\:/d' "$temp_file"
            sed -i -r 's/(⠋|⠙|⠹|⠸|⠼|⠴|⠦|⠧|⠇|⠏)/\n/g' "$temp_file"
            sed -i -r '/Test in progress/d' "$temp_file"
            sed -i '/^$/d' "$temp_file"
            cp "$temp_file" "${output_file}_single_thread"
            ;;
        # Return Route
        7)
            echo -e "Running ${YELLOW}Return Route Test...${NC}"
            if [ "$use_ipv6" = true ]; then
            echo "Using IPv6 test option"
            wget -N --no-check-certificate https://raw.githubusercontent.com/Chennhaoo/Shell_Bash/master/AutoTrace.sh && chmod +x AutoTrace.sh && bash AutoTrace.sh <<< "4" | tee "$temp_file"
            else
            echo "Using IPv4 test option"
            wget -N --no-check-certificate https://raw.githubusercontent.com/Chennhaoo/Shell_Bash/master/AutoTrace.sh && chmod +x AutoTrace.sh && bash AutoTrace.sh <<< "1" | tee "$temp_file"
            fi
            sed -i -e 's/\x1B\[[0-9;]*[JKmsu]//g' -e '/No:1\/9 Traceroute to/,$!d' -e '/Test item/,+9d' -e '/Information/d' -e '/^\s*$/d' "$temp_file"
            cp "$temp_file" "${output_file}_route"
            ;;
    esac
    rm "$temp_file"
    echo -e "${GREEN}Test completed.${NC}"
}

# Generate final Markdown output
generate_markdown_output() {
    local base_output_file=$1
    local temp_output_file="${base_output_file}.md"
    local sections=("YABS" "IP Quality" "Streaming" "Response" "Multi-threaded Speed Test" "Single-threaded Speed Test" "Return Route")
    local file_suffixes=("yabs" "ip_quality" "streaming" "response" "multi_thread" "single_thread" "route")
    local empty_tabs=("Outbound Route" "Ping.pe" "Nezha ICMP" "Other")

    # Modified here to add UTF-8 encoding setting
    echo "[tabs]" | iconv -f UTF-8 -t UTF-8//IGNORE > "$temp_output_file"

    # Output tabs with content
    for i in "${!sections[@]}"; do
        section="${sections[$i]}"
        suffix="${file_suffixes[$i]}"
        if [ -f "${base_output_file}_${suffix}" ]; then
            echo "[tab=\"$section\"]" | iconv -f UTF-8 -t UTF-8//IGNORE >> "$temp_output_file"
            echo "\`\`\`" >> "$temp_output_file"
            cat "${base_output_file}_${suffix}" | iconv -f UTF-8 -t UTF-8//IGNORE >> "$temp_output_file"
            echo "\`\`\`" >> "$temp_output_file"
            echo "[/tab]" >> "$temp_output_file"
            rm "${base_output_file}_${suffix}"
        fi
    done

    # Add reserved empty tabs
    #for tab in "${empty_tabs[@]}"; do
    #    echo "[tab=\"$tab\"]" >> "$temp_output_file"
    #    echo "[/tab]" >> "$temp_output_file"
    #done

    echo "[/tabs]" >> "$temp_output_file"

    # Upload file and get callback
    local plain_uploaded_file=$(cat "${temp_output_file}" | curl -s -X POST --data-binary @- "${CLOUD_SERVICE_BASE}")
    local plain_uploaded_file_path=$(echo "$plain_uploaded_file" | grep -oP "(?<=${CLOUD_SERVICE_BASE}).*") 
    local plain_uploaded_file_filename=$(basename "${plain_uploaded_file_path}")

    if [ -n "$plain_uploaded_file" ]; then
        local base_url=$(echo "${CLOUD_SERVICE_BASE}" | sed 's:/*$::')
        local remote_url="${base_url}/result${plain_uploaded_file_path}"
        echo -e "${remote_url}\r\nPlain ${plain_uploaded_file}" > "${plain_uploaded_file_filename}.url"
        echo "Test results have been uploaded, you can view them at the following link:"
        echo "${remote_url}"
        echo "Plain ${plain_uploaded_file}"
        echo "Result link saved to ${plain_uploaded_file_filename}.url"
    else
        echo "Upload failed. Results saved to local file ${temp_output_file}"
    fi


    rm "$temp_output_file"
    read -p "Press Enter to continue..."  < /dev/tty
    clear
}

# Run all scripts
run_all_scripts() {
    local base_output_file="NLvps_results_$(date +%Y%m%d_%H%M%S)"
    echo "Starting to execute all test scripts..."
    for i in {1..10}; do
        run_script $i "$base_output_file"
    done
    generate_markdown_output "$base_output_file"
    clear
}

run_selected_scripts() {
    clear
    local base_output_file="NLvps_results_$(date +%Y%m%d_%H%M%S)"
    echo -e "${YELLOW}VPS Automatic Test Script $VERSION${NC}"
    echo "1. Yabs"
    echo "2. IP Quality"
    echo "3. Streaming Unlock"
    echo "4. Response Test"
    echo "5. Multi-threaded Test"
    echo "6. Single-threaded Test"
    echo "7. Return Route"
    echo "0. Return"

    while true; do
        read -p "Please enter the script numbers to execute (separated by commas, e.g., 1,2,3):" script_numbers < /dev/tty
        if [[ "$script_numbers" =~ ^(0|10|[1-7])(,(0|10|[1-7]))*$ ]]; then
            break
        else
            echo -e "${RED}Invalid input, please enter numbers between 0-7, separated by commas.${NC}"
        fi
    done

    if [[ "$script_numbers" == "0" ]]; then
        clear
        show_welcome
        return  # Ensure exit from function, no further execution
    fi

    # Split user input into array
    IFS=',' read -ra selected_scripts <<< "$script_numbers"

    echo "Starting to execute selected test scripts..."
    for number in "${selected_scripts[@]}"; do
        clear
        run_script "$number" "$base_output_file"
    done

    # Generate Markdown output after all scripts are executed
    generate_markdown_output "$base_output_file"
}


# Main menu
main_menu() {
    echo -e "${GREEN}Test Items:${NC} Yabs, IP Quality, Streaming Unlock, Response Test, Multi-threaded Test, Single-threaded Test, Return Route."
    echo -e "${YELLOW}1. Execute all test scripts${NC}"
    echo -e "${YELLOW}2. Select specific test scripts${NC}"
    echo -e "${YELLOW}0. Exit${NC}"
    
    # Prompt for input and read from terminal
    read -p "Please select an option [0-2]: " choice < /dev/tty

    # Ensure input is not empty
    if [[ -z "$choice" ]]; then
        echo -e "${RED}Input is empty, please try again.${NC}"
        sleep 2s
        clear
        main_menu
        return
    fi

    # Check if input is valid
    case $choice in
        1)
            run_all_scripts
            ;;
        2)
            run_selected_scripts
            ;;
        0)
            echo -e "${RED}Thank you for using the Aggregate Test Script. Exiting now, looking forward to your next use!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid selection, please try again.${NC}"
            sleep 2s
            clear
            main_menu
            ;;
    esac
}



# Display welcome message
show_welcome() {
    echo ""
    echo -e "${RED}---------------------------------By'Xe9omorph---------------------------------${NC}"
    echo ""
    echo -e "${GREEN}ITDog Aggregate Test Script $CURRENT_VERSION ${NC}"
    echo -e "${GREEN}GitHub Address: https://github.com/itdoginfo/podkop${NC}"
    echo -e "${GREEN}ITDog Community: https://t.me/itdogchat${NC}"
    echo ""
    echo -e "${colors[0]}  _____   _______   _____               ${NC}"
    echo -e "${colors[1]} |_   _| |__   __| |  __ \              ${NC}"
    echo -e "${colors[2]}   | |      | |    | |  | | ___   __ _  ${NC}"
    echo -e "${colors[3]}   | |      | |    | |  | |/ _ \\ / _  | ${NC}"
    echo -e "${colors[4]}  _| |_     | |    | |__| | (_) | (_| | ${NC}"
    echo -e "${colors[5]} |_____|    |_|    |_____/ \___/ \__, | ${NC}"
    echo -e "${colors[6]}                                  __/ | ${NC}"
    echo -e "${colors[7]}                                 |___/  ${NC}"
    echo ""
    echo "Supports Ubuntu/Debian"
    echo ""
    echo -e "Today's Run Count: ${RED}$daily_count${NC} times, Total Run Count: ${RED}$total_count${NC} times"
    echo ""
    echo -e "${RED}---------------------------------By'Xe9omorph---------------------------------${NC}"
    echo ""
}

# Main function
main() {

    # Update script
    update_scripts
    
    # Check if it's root user
    check_root
    
    # Check and install dependencies
    install_dependencies
    
    # Call function to get statistics
    sum_run_times

    # Main loop
    while true; do
        show_welcome
        main_menu
    done
}

# Run main function
main
