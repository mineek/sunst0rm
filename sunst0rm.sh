#!/bin/bash

if [ "$(uname)" != "Darwin" ]; then
    echo "Only macOS is supported."
    exit
fi

if [ ! -x requirements.sh ]; then
    chmod +x requirements.sh
fi

./requirements.sh

if [ -a .requirements_done ]; then
    clear
else
    echo "Run \$ ./requirements.sh"
    exit
fi

arg2="<ipsw path>"

_usage() 
{
    cat <<EOF
================================================================================
Usage:
    Restoring: sunst0rm.sh restore $arg2
    Booting: sunst0rm.sh boot
================================================================================
EOF
}

if [ -z "$1" ]; then
    echo "No argument provided."
    _usage
    exit
fi

device_dfu=$(irecovery -m | grep -c "DFU")

if [ $device_dfu == 0 ]; then
    echo "No device found in DFU mode."
    exit
fi

# @TODO: ensure correct irecovery version is installed
cpid=$(irecovery -q | grep "CPID" | sed "s/CPID: //")
device=$(irecovery -q | grep "PRODUCT" | sed "s/PRODUCT: //")
ecid=$(irecovery -q | grep "ECID" | sed "s/ECID: //")
model=$(irecovery -q | grep "MODEL" | sed "s/MODEL: //")
echo "Found device: |$device|$cpid|$model|$ecid|"

_pwnDevice() 
{
    echo "Starting exploit, device should be in pwnd DFU mode after this."
    ./bin/gaster pwn
}

if [ "$1" == "boot" ]; then
    if [ ! -d boot ]; then
        echo "Run 'sunst0rm.sh restore $arg2' command first."
        exit
    fi
    
    _pwnDevice
    cd boot
    
    if [ -e ibss.img4 ]; then
        echo "Found boot required files, continuing..."
        irecovery -f ibss.img4
        irecovery -f ibss.img4
        sleep 3
        irecovery -f ibec.img4
        sleep 2

        if [[ $cpid == "0x8010" ]] || [[ $cpid == "0x8015" ]];then
            irecovery -f ibec.img4
            sleep 2
            irecovery -c "go"
            sleep 5
        fi

        irecovery -c "bootx"
        sleep 5
        irecovery -c "bgcolor 0 255 100"
        sleep 1
        irecovery -f devicetree.img4
        sleep 2
        irecovery -c "devicetree"
        sleep 2
	
        irecovery -f trustcache.img4
        sleep 2
        irecovery -c "firmware"
        sleep 2
        # irecovery -f aop.img4
        # sleep 2
        # irecovery -c "firmware"
        # sleep 2
	
        irecovery -f krnl.img4
        sleep 2
        irecovery -c "bootx"
        echo "Device should be booting now."
        sleep 5
    fi
    
    echo "Done!"
    exit
fi

if [ "$1" != "restore" ]; then
    echo "Use either 'sunst0rm.sh restore' or 'sunst0rm.sh boot' command."
    _usage
    exit
fi

_runFuturerestore() 
{
    echo "================================================================================"
    echo "                      Starting 'futurerestore' command"
    echo "If futurerestore fails, reboot into DFU mode."
    echo "Then, run '$0 restore' to try again."
    echo ""
    echo "If futurerestore succeeds, reboot into DFU mode."
    echo "Then, run '$0 boot' to boot the device."
    echo "================================================================================"
    read -p "Press ENTER to continue <-"
    rm -rf /tmp/futurerestore/
    futurerestore -t tickets/blob.shsh2 --use-pwndfu --skip-blob --rdsk restore/ramdisk.im4p --rkrn restore/krnl.im4p --latest-sep --latest-baseband $(cat restore/ipsw)
    exit
}

if [ -d restore ]; then
    echo "Restore from previous run ? (y/n):"
    read yn
    
    if [ "$yn" == "y" ]; then
    	_pwnDevice
        echo "Continuing to futurerestore..."
        _runFuturerestore
    fi
    
    rm -rf restore/
fi

if [ -d work ]; then
    rm -rf work/
fi

if [ -d boot ]; then
    rm -rf boot/
fi

mkdir work
mkdir boot

ipsw=$2

if [ -z "$ipsw" ]; then
  echo "$arg2 is required to continue."
  exit
fi

if [ -a $ipsw ] || [ ${ipsw: -5} == ".ipsw" ]; then
echo "Continuing..."
else
echo "$arg2 is not a valid ipsw file."
exit
fi

unzip -q $ipsw -x *.dmg -d work
firmware=$(plutil -extract 'ProductVersion' xml1 -o - work/BuildManifest.plist | xmllint -xpath '/plist/string/text()' -)
echo "Firmware version: $firmware"

if [ ! -d tickets ]; then
    mkdir tickets
else
    rm -f tickets/*
fi

./bin/tsschecker -d $device -e $ecid --boardconfig $model -s -l --save-path tickets/
shsh=$(ls tickets/*.shsh2)
echo "SigningTicket: $shsh"

# @FIX: parse correct filename, BuildIdentities is of type array which makes finding device manifest complex to deal with
manifest_index=0
ret=0
until [ $ret != 0 ]; do
    manifest=$(plutil -extract "BuildIdentities.$manifest_index.Manifest" xml1 -o - work/BuildManifest.plist)
    ret=$?
    count_manifest=$(echo $manifest | grep -c "$model")
    if [ $count_manifest == 0 ]; then
	((manifest_index++))
    else
	ret=1
    fi
done

_extractFromManifest() 
{
    echo $(plutil -extract "BuildIdentities.$manifest_index.Manifest.$1.Info.Path" xml1 -o - work/BuildManifest.plist | xmllint -xpath '/plist/string/text()' -)
}

ibss=$(_extractFromManifest "iBSS")
ibec=$(_extractFromManifest "iBEC")
echo "iBSS: $ibss"
echo "iBEC: $ibec"

echo "Making boot files..."
./bin/gaster decrypt work/$ibss work/ibss.dec
./bin/gaster decrypt work/$ibec work/ibec.dec
./bin/iBoot64Patcher work/ibss.dec work/ibss.patched
./bin/iBoot64Patcher work/ibec.dec work/ibec.patched -b "-v"

if [ -e IM4M ]; then
    rm IM4M
fi

img4tool -e -s $shsh -m IM4M
img4 -i work/ibss.patched -o boot/ibss.img4 -M IM4M -A -T ibss
img4 -i work/ibec.patched -o boot/ibec.img4 -M IM4M -A -T ibec
devicetree=$(_extractFromManifest "DeviceTree")
echo "DeviceTree: $devicetree"
img4 -i work/$devicetree -o boot/devicetree.img4 -M IM4M -T rdtr
# restore_trustcache=$(_extractFromManifest "RestoreTrustCache")
trustcache=$(_extractFromManifest "StaticTrustCache")
echo "StaticTrustCache: $trustcache"
img4 -i work/$trustcache -o boot/trustcache.img4 -M IM4M -T rtsc 
kernelcache=$(_extractFromManifest "KernelCache")
echo "KernelCache: $kernelcache"

kpp=0
# @TODO: and where is kpp.bin
# @TODO: add kpp for legacy devices support
#  if [[ "$device" == *"iPhone8,"* ]] || [[ "$device" == *"iPhone7,"* ]] || [[ "$device" == *"iPhone6,"* ]]; then
#   echo "Device has kpp"
#   kpp=1
#  else
#   echo "Device does not have kpp"
#   kpp=0
#  fi

if [ $kpp == 1 ]; then
pyimg4 im4p extract -i work/$kernelcache -o work/kcache.dec --extra work/kpp.bin 
else
pyimg4 im4p extract -i work/$kernelcache -o work/kcache.dec
fi

./bin/Kernel64Patcher work/kcache.dec work/kcache.patched -f

if [ $kpp == 1 ]; then
pyimg4 im4p create -i work/kcache.patched -o work/krnl.im4p --extra work/kpp.bin -f rkrn --lzss
else
pyimg4 im4p create -i work/kcache.patched -o work/krnl.im4p -f rkrn --lzss
fi

pyimg4 img4 create -p work/krnl.im4p -o boot/krnl.img4 -m IM4M
rm work/kcache.* work/krnl.*
echo "Done with boot files, making restore files..."
ramdisk=$(_extractFromManifest "RestoreRamDisk")
echo "RestoreRamDisk: $ramdisk"
unzip -q $ipsw $ramdisk -d work
img4 -i work/$ramdisk -o work/ramdisk.dmg
mkdir work/ramdisk
hdiutil attach work/ramdisk.dmg -mountpoint work/ramdisk
sleep 5
./bin/asr64_patcher work/ramdisk/usr/sbin/asr work/patched_asr
./bin/ldid2 -e work/ramdisk/usr/sbin/asr > work/asr.plist
./bin/ldid2 -Swork/asr.plist work/patched_asr
cp work/ramdisk/usr/local/bin/restored_external work/restored_external
./bin/restored_external64_patcher work/restored_external work/patched_restored_external
./bin/ldid2 -e work/restored_external > work/restored_external.plist
./bin/ldid2 -Swork/restored_external.plist work/patched_restored_external
chmod 755 work/patched_restored_external
chmod 755 work/patched_asr
rm work/ramdisk/usr/sbin/asr
rm work/ramdisk/usr/local/bin/restored_external
mv work/patched_asr work/ramdisk/usr/sbin/asr
mv work/patched_restored_external work/ramdisk/usr/local/bin/restored_external
hdiutil detach -force work/ramdisk
sleep 5

mkdir restore
pyimg4 im4p create -i work/ramdisk.dmg -o restore/ramdisk.im4p -f rdsk

restore_kernelcache=$(_extractFromManifest "RestoreKernelCache")

if [ $kpp == 1 ]; then
pyimg4 im4p extract -i work/$restore_kernelcache -o work/kcache.dec --extra work/kpp.bin
else
pyimg4 im4p extract -i work/$restore_kernelcache -o work/kcache.dec
fi

./bin/Kernel64Patcher work/kcache.dec work/kcache.patched -f -a

if [ $kpp == 1 ]; then
pyimg4 im4p create -i work/kcache.patched -o restore/krnl.im4p --extra work/kpp.bin -f rkrn --lzss
else
pyimg4 im4p create -i work/kcache.patched -o restore/krnl.im4p -f rkrn --lzss
fi

rm -rf work/
cp $shsh tickets/blob.shsh2
echo $ipsw > restore/ipsw
_pwnDevice
echo "Continuing to futurerestore..."
_runFuturerestore
