#!/bin/bash

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

    echo "[*] Flushing tables"
    run_cmd """$TABLES -F"""
    run_cmd """$TABLES -X"""
    run_cmd """$TABLES -t nat -F"""
    run_cmd """$TABLES -t nat -X"""
    run_cmd """$TABLES -t mangle -F"""
    run_cmd """$TABLES -t mangle -X"""
    run_cmd """$TABLES -P INPUT ACCEPT"""
    run_cmd """$TABLES -P FORWARD ACCEPT"""
    run_cmd """$TABLES -P OUTPUT ACCEPT"""

    return 0
}

echo "[*] Configuring IPv4 tables"
config_tables iptables
echo ""
echo "[*] Configuring IPv6 tables"
config_tables ip6tables


