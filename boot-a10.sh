echo 'Ensure that device is in pwnDFU mode with sigcheck patches applied.'
sleep 5

irecovery -f boot/iBSS.img4
# send iBSS again.
irecovery -f boot/iBSS.img4
irecovery -f boot/iBEC.img4
# execute irecovery -c go to load iBEC image on A10+
irecovery -c 'go'

irecovery -f boot/devicetree.img4
irecovery -c devicetree
irecovery -f boot/trustcache.img4
irecovery -c firmware
irecovery -f boot/krnlboot.img4
irecovery -c bootx
