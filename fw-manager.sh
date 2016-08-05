#!/bin/bash

#
# fw-manager - manager of iptables configurations.
#
# Sevryugin Kirill (kirill@sevryugin.ru)

  
# Thanks to the developers MySQL Tuning Primer Script (cecho and cechon).
# Colors variables
export BLACK="\033[0m"
export BOLDBLACK="\033[1;0m"
export RED="\033[31m"
export BOLDRED="\033[1;31m"
export GREEN="\033[32m"
export BOLDGREEN="\033[1;32m"
export YELLOW="\033[33m"
export BOLDYELLOW="\033[1;33m"
export BLUE="\033[34m"
export BOLDBLUE="\033[1;34m"
export MAGENTA="\033[35m"
export BOLDMAGENTA="\033[1;35m"
export CYAN="\033[36m"
export BOLDCYAN="\033[1;36m"
export WHITE="\033[37m"
export BOLDWHITE="\033[1;37m"

# Definition color output.
function cecho-color () {
    COLOR=${1:-BLACK}

    case $COLOR in
        black)
            printf "$BLACK"
            ;;
        boldblack)
            printf "$BOLDBLACK"
            ;;
        red)
            printf "$RED"
            ;;
        boldred)
            printf "$BOLDRED"
            ;;
        green)
            printf "$GREEN"
            ;;
        boldgreen)
            printf "$BOLDGREEN"
            ;;
        yellow)
            printf "$YELLOW"
            ;;
        boldyellow)
            printf "$BOLDYELLOW"
            ;;
        blue)
            printf "$BLUE"
            ;;
        boldblue)
            printf "$BOLDBLUE"
            ;;
        magenta)
            printf "$MAGENTA"
            ;;
        boldmagenta)
            printf "$BOLDMAGENTA"
            ;;
        cyan)
            printf "$CYAN"
            ;;
        boldcyan)
            printf "$BOLDCYAN"
            ;;
        white)
            printf "$WHITE"
            ;;
        boldwhite)
            printf "$BOLDWHITE"
            ;;
    esac
}

# Output message with a line break.
function cecho () {
    local DEFAULT_MESSAGE="No message passed."
    MESSAGE=${1:-$DEFAULT_MESSAGE}

    cecho-color $2
    
    printf "%s\n" "$MESSAGE"
    tput sgr0
    printf "$BLACK"

    return
}

# Output message without line break.
function cechon () {
    local DEFAULT_MESSAGE="No message passed."
    MESSAGE=${1:-$DEFAULT_MESSAGE}

    cecho-color $2
    
    printf "%s" "$MESSAGE"
    tput sgr0
    printf "$BLACK"

    return
}

# Show help information.
function help () {
    cecho "fw-manager - manager to control iptables rules.
    Usage:
        fw-manager command [arguments]
    The commands are:
        help             show help information
        build-rules      safe applying the rules"
    exit
}

# Checking root privileges.
function check-root () {
    if [[ "$UID" != "0" ]]; then
        cecho "You must have root privileges!" red
        exit 0
    fi
}

# Determine run directory and import configuration.
function get-config () {
    SOURCE="${BASH_SOURCE[0]}"

    while [[ -h "$SOURCE" ]]; do
        SCRIPT_DIRECTORY=$(cd -P $(dirname $SOURCE) && pwd)
        SOURCE=$(readlink $SOURCE)
        [[ $SOURCE != /* ]] && SOURCE=$SCRIPT_DIRECTORY/$SOURCE
    done

    SCRIPT_DIRECTORY=$(cd -P $(dirname $SOURCE) && pwd)
    SCRIPT_NAME=${SCRIPT_DIRECTORY##*/}

    if [[ -f "$SCRIPT_DIRECTORY/$SCRIPT_NAME.conf" ]]; then
        . $SCRIPT_DIRECTORY/$SCRIPT_NAME.conf
    else
        cecho "Configuration file is not found. Please copy the configuration file from the example." red
        exit 1
    fi
}

# Build rules for the application.
function build-rules () {
    check-root

    cechon "Import configuration file..."
    get-config
    PUBLIC_IP=$(ifconfig $PUBLIC_IF | awk '{if($0~/inet addr/){print substr($2,6)}}')
    DATE=$(date +%F_%H-%M-%S)
    cecho "done" green

    save-current-rules

    get-main-rule reset
    get-main-rule default
    get-main-rule local
    get-main-rule active
    get-main-rule ping
    get-main-rule traceroute

    get-trusted-rule
    get-custom-rule
    get-nat-rule

    show-rules
    confirm
}

# Save current firewall rules.
function save-current-rules () {
    cechon "Saving current rules..."
    iptables-save > $SCRIPT_DIRECTORY/saves/$DATE.save
    cecho "done" green
}

# Get main rules.
function get-main-rule () {
    cechon "Application of $1 rules..."

    if [[ -f "$SCRIPT_DIRECTORY/rules/main/$1.rule" ]]; then
        . $SCRIPT_DIRECTORY/rules/main/$1.rule
        cecho "done" green
    else
        cecho "Rules file is not found." red
    fi
}

# Get custom rules.
function get-custom-rule () {
    cechon "Application of custom rules."

    if [[ "$CUSTOM_RULES" == "YES" ]]; then
        . $SCRIPT_DIRECTORY/rules/custom/*.rule
    fi

    if ! [[ -z "$TCP_CUSTOM_PORTS" ]]; then
        for PORT in $TCP_CUSTOM_PORTS; do
            PROTO="tcp"
            . $SCRIPT_DIRECTORY/rules/main/input.rule
        done
    fi

    if ! [[ -z "$UDP_CUSTOM_PORTS" ]]; then
        for PORT in $UDP_CUSTOM_PORTS; do
            PROTO="udp"
            . $SCRIPT_DIRECTORY/rules/main/input.rule
        done
    fi

    cecho "done" green
}

# Get nat rules.
function get-nat-rule () {
    if [[ "$NAT" == "YES" ]]; then
        cechon "Application of nat rules."

        if [[ -z "$VNETS" || -z "$PUBLIC_IP" || -z "$PUBLIC_IF" ]]; then
            cecho "\nYou did not specify VNETS and(or) PUBLIC_IP and(or) PUBLIC_IF !" red
            cecho "PUBLIC_IF: $PUBLIC_IF" red
            cecho "PUBLIC_IP: $PUBLIC_IP" red
            cecho "VNETS: $VNETS\n" red
        else
            for VNET in $VNETS; do
                . $SCRIPT_DIRECTORY/rules/main/nat.rule
            done
            cecho "done" green
        fi
    fi
}

# Get trusted rules.
function get-trusted-rule () {
    cechon "Application of trusted rules."

    if [[ -z "$TRUSTED_IPS" ]]; then
        cecho "You did not specify TRUSTED_IPS!" red
        cecho "TRUSTED_IPS: $TRUSTED_IPS" red
    else
        for ADDR in $TRUSTED_IPS; do
            . $SCRIPT_DIRECTORY/rules/main/trusted.rule
        done
        cecho "done" green
    fi
}

# Print current firewall rules.
function show-rules () {
    cecho "Print current firewall rules..."
    iptables -nxvL --line-numbers
}

# Confirmation of application of the new configuration.
function confirm () {
    read -t 30 -p "Save the rules? (Wait 30 seconds) [yes/NO]" CONFIRMATION

    case "$CONFIRMATION" in
        yes|YES)
            save-new-rules
            ;;
        *)
            restore-rules
            ;;
    esac
}

# Save new rules.
function save-new-rules () {
    if [[ -f "/etc/init.d/iptables" ]]; then
        cechon "Saving new rules..."
        service iptables save
        cecho "done" green
    fi
}

# Restoring rules.
function restore-rules () {
    SAVE_FILENAME=$(cd $SCRIPT_DIRECTORY/saves/ && ls -t | head -n1)

    cechon "Restoring rules $SAVE_FILENAME ..."
    iptables-restore < $SCRIPT_DIRECTORY/saves/$SAVE_FILENAME
    cecho "done" green

    show-rules
}

# Checking input parameters.
case $1 in
    build-rules)
        build-rules
        ;;
    *)
        help
        ;;
esac
