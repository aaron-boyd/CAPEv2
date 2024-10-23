#!/bin/bash

POLAR_DIR=$1
POLAR_PORT=$2
POLAR_P12_CERT=$3
POLAR_CERT_PASSWD=$4

if [ -z $POLAR_DIR ]
then
    echo "[!] Usage: $0 <POLAR_DIR> <POLAR_PORT> [POLAR_P12_CERT] [POLAR_CERT_PASSWD]"
    exit 1
fi

if [ ! -z $POLAR_P12_CERT ]
then
    if [ -z $POLAR_CERT_PASSWD ]
    then
        echo "[!] Usage: $0 <POLAR_DIR> <POLAR_PORT> [POLAR_P12_CERT] [POLAR_CERT_PASSWD]"
        exit 1
    fi
    STUB="$POLAR_DIR/PolarProxy --cacert load:$POLAR_P12_CERT:$POLAR_CERT_PASSWD"
else
    STUB="$POLAR_DIR/PolarProxy"
fi
CMD="$STUB -v --nontls allow -p $POLAR_PORT,80,443 --certhttp 8888 --leafcert sign"
echo "[*] $CMD"
eval $CMD
