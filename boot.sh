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
#irecovery -c "bootx"
#sleep 5
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
echo "Flashing rainbow because it's fun..."
sleep 3
#Rainbow flash sequence
for i in 1 2 3 4 5
do
    irecovery -c "bgcolor 255 0 0"
    sleep 0.1
    irecovery -c "bgcolor 255 165 0"
    sleep 0.1
    irecovery -c "bgcolor 255 255 0"
    sleep 0.1
    irecovery -c "bgcolor 0 255 0"
    sleep 0.1
    irecovery -c "bgcolor 0 0 255"
    sleep 0.1
    irecovery -c "bgcolor 160 32 240"
    sleep 0.1
done
#Set background color back to black and finish booting
irecovery -c "bgcolor 0 0 0"
echo "Funtime over! Booting..."
sleep 1
irecovery -c "bootx"
