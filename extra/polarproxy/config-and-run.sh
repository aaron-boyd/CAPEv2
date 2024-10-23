#!/bin/bash

THIS_DIR=$(realpath $(dirname $0))
# PolarProxy directory
POLAR_DIR=$1
# Internet facing interface
WAN_IFACE=$2
# LAN facing interface
LAN_IFACE=$3
# Port PolarProxy is listening on
PORT=$4

if [ -z $WAN_IFACE ] || [ -z $LAN_IFACE ] || [ -z $PORT ] || [ -z $POLAR_DIR]
then
    echo "[!] Usage: $0 <POLAR_DIR> <WAN_IFACE> <LAN_IFACE> <PORT>"
    exit 1
fi

$THIS_DIR/masquerade.sh start $WAN_IFACE $LAN_IFACE
$THIS_DIR/port-forward.sh start $WAN_IFACE $LAN_IFACE $PORT
$THIS_DIR/run-proxy.sh $POLAR_DIR $PORT $POLAR_DIR/PolarProxy-key-crt.p12 SuperPuperSecret
$THIS_DIR/port-forward.sh stop $WAN_IFACE $LAN_IFACE $PORT
$THIS_DIR/masquerade.sh stop $WAN_IFACE $LAN_IFACE
