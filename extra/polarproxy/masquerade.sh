#!/bin/bash

# Setup or tear down rules
METHOD=$1
# Internet facing interface
WAN_IFACE=$2
# LAN facing interface
LAN_IFACE=$3

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

    echo "[*] Forward packets from LAN to WAN"
    run_cmd """$STUB FORWARD -i $LAN_IFACE -o $WAN_IFACE -j ACCEPT"""

    echo "[*] Forward established connections from LAN to WAN"
    run_cmd """$STUB FORWARD -i $WAN_IFACE -o $LAN_IFACE -m state --state ESTABLISHED,RELATED -j ACCEPT"""

    echo "[*] Masquerade IP of forwarded packets"
    run_cmd """$STUB POSTROUTING -t nat -o $WAN_IFACE -j MASQUERADE"""

    echo "[+] Configured!"
    return 0
}

if ([ "$METHOD" != "start" ] && [ "$METHOD" != "stop" ]) || [ -z $WAN_IFACE ] || [ -z $LAN_IFACE ]
then
    echo "[!] Usage: $0 <start|stop> <WAN_IFACE> <LAN_IFACE>"
    exit 1
fi

echo "[*] Configuring IPv4 tables"
config_tables iptables
echo ""
echo "[*] Configuring IPv6 tables"
config_tables ip6tables
