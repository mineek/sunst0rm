#!/usr/bin/env bash

pwnd=$(irecovery -q | grep -c "PWND")
if [ $pwnd = 0 ]; then
    echo "Ensure device is in pwned DFU mode with signature checks removed."
    exit
fi
sleep 1
cpid=$(irecovery -q | grep "CPID" | sed "s/CPID: //")

irecovery -f boot/iBSS.img4
sleep 2
# send iBSS again.
irecovery -f boot/iBSS.img4
sleep 3
irecovery -f boot/iBEC.img4
sleep 2

if [[ "$cpid" == *"0x80"* ]]; then
    irecovery -f boot/iBEC.img4
    sleep 2
    irecovery -c "go"
    sleep 5
fi

irecovery -f boot/bootlogo.img4
sleep 1
irecovery -c "setpicture 0x1"
sleep 1
irecovery -f boot/devicetree.img4
sleep 1
irecovery -c "devicetree"
sleep 1
irecovery -f boot/trustcache.img4
sleep 1
irecovery -c "firmware"
sleep 1
irecovery -f boot/krnlboot.img4
sleep 1
irecovery -c "bootx"
