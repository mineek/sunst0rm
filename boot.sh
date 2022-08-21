check=$(irecovery -q | grep CPID | sed 's/CPID: //')

echo 'Ensure device is in pwnDFU mode with sigchecks removed.'
sleep 1

irecovery -f boot/iBSS.img4
# send iBSS again.
irecovery -f boot/iBSS.img4
irecovery -f boot/iBEC.img4
if [[ "$check" == '0x8010' ]] || [[ "$check" == '0x8015' ]] || [[ "$check" == '0x8011' ]] || [[ "$check" == '0x8012' ]]; then
irecovery -c go
fi
irecovery -f boot/devicetree.img4
irecovery -c devicetree
irecovery -f boot/trustcache.img4
irecovery -c firmware
irecovery -f boot/krnlboot.img4
irecovery -c bootx
