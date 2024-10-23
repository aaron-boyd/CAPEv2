#!/bin/bash

# Setup or tear down rules
METHOD=$1
# Internet facing interface
WAN_IFACE=$2
# LAN facing interface
LAN_IFACE=$3
# Port PolarProxy is listening on
PORT=$4

function run_cmd() {
    local CMD=$1
    if [ -z "$CMD" ]
    then
        echo "[!] Please provide command to tables()"
	return 1
    fi
    echo "[*] $CMD"
    eval "$CMD"
}


function config_tables() {
    local TABLES=$1
    local METH=$2

    if [ -z $TABLES ]
    then
        echo "[!] Please provide iptables binary to config_iptables()"
        return 1
    fi

    if [ "$METHOD" == "start" ]
    then
        STUB="$TABLES -A"
    else
        STUB="$TABLES -D"
    fi

    echo "[*] Accept packets on port 10443"
    run_cmd """$STUB INPUT -i $LAN_IFACE -p tcp --dport $PORT -m state --state NEW -j ACCEPT"""

    echo "[*] Redirect incoming packets to port 443 to port $PORT"
    run_cmd """$STUB PREROUTING -t nat -i $LAN_IFACE -p tcp --dport 443 -j REDIRECT --to $PORT"""

    echo "[+] Configured!"
    return 0
}

if ([ "$METHOD" != "start" ] && [ "$METHOD" != "stop" ]) || [ -z $WAN_IFACE ] || [ -z $LAN_IFACE ] || [ -z $PORT ]
then
    echo "[!] Usage: $0 <start|stop> <WAN_IFACE> <LAN_IFACE> <PORT>"
    exit 1
fi

echo "[*] Configuring IPv4 tables"
config_tables iptables
echo ""
echo "[*] Configuring IPv6 tables"
config_tables ip6tables
