#!/usr/bin/env bash

export RETRY=3

read -t 5 -p "Enter DFU to pwn & boot: (enter to continue)";

try () {
    let i=0;

    echo "Trying '${@}'";

    while ! sudo ${@}; do
        if [[ ${i} > ${RETRY} ]]; then
            echo "Failed to run '${@}'";
            exit 1
        fi;

        let i++;
    done;
}

set -v

try gaster pwn
try irecovery -f boot/ibss.img4
try irecovery -f boot/ibss.img4
try irecovery -f boot/ibec.img4
try irecovery -f boot/bootlogo.img4
try irecovery -c "setpicture 0"
try irecovery -c "bgcolor 255 255 255"
sleep 5
try irecovery -f boot/devicetree.img4
try irecovery -c devicetree
try irecovery -f boot/trustcache.img4
try irecovery -c firmware
try irecovery -f boot/krnlboot.img4
try irecovery -c bootx
