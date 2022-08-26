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
    rm .requirements_done
    clear
else
    echo "Run \$ ./requirements.sh"
    exit
fi

_usage() {
    cat <<EOF
================================================================================
USAGE:
    RESTORING: sunst0rm.sh restore <boardconfig> <ipsw path> 
    BOOTING: sunst0rm.sh boot
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

echo "Starting exploit, device should be in pwnd DFU mode after this."
./bin/gaster pwn

if [ "$1" == "boot" ]; then
    if [ ! -d boot ]; then
        echo "Run 'sunst0rm.sh restore <boardconfig> <ipsw path>' command first."
        exit
    fi
    
    cd boot
    
    if [ -e ibss.img4 ]; then
        echo "Found boot required files, continuing..."
        irecovery -f ibss.img4
        irecovery -f ibss.img4
        irecovery -f ibec.img4
        irecovery -f devicetree.img4
        irecovery -c "devicetree"
        irecovery -f aop.img4
        irecovery -c "firmware"
        irecovery -f trustcache.img4
        irecovery -c "firmware"
        irecovery -f krnl.img4
        irecovery -c "bootx"
        echo "Device should be booting now."
    fi
    
    echo "Done!"
    exit
fi

if [ "$1" != "restore" ]; then
    echo "Use either 'sunst0rm.sh restore' or 'sunst0rm.sh boot' command."
    _usage
    exit
fi

_runFuturerestore() {
    echo "================================================================================"
    echo "                      Starting 'futurerestore' command"
    echo "If futurerestore fails, reboot into DFU mode."
    echo "Then, run '$0 restore' again."
    echo ""
    echo "If futurerestore succeeds, reboot into DFU mode."
    echo "Then, run '$0 boot' to boot the device."
    echo "================================================================================"
    read -p "Press ENTER to continue <-"
    restore_ipsw=$(cat restore/ipsw_path)
    futurerestore -t $shsh --use-pwndfu --skip-blob --rdsk restore/ramdisk.im4p --rkrn restore/krnl.im4p --latest-sep --latest-baseband $restore_ipsw
    exit
}

if [ -d restore ]; then
    echo "Restore from previous run ? (y/n):"
    read yn
    
    if [ "$yn" == "y" ]; then
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

boardconfig=$2
ipsw=$3

if [ -z "$boardconfig" ]; then
 echo "You forgot an boardconfig :P"
 exit
fi

if [ -e $ipsw ] || [ ${ipsw: -5} == ".ipsw" ]; then
echo "Continuing..."
else
echo "You forgot an ipsw :P"
exit
fi

unzip -q $ipsw -x *.dmg -d work

# buildmanifest=$(cat work/BuildManifest.plist)
# firmware=$(/usr/libexec/PlistBuddy -c "Print :ProductVersion" /dev/stdin <<< "$buildmanifest")

# @NOTE: because SupportedProductTypes is of type array device cannot be retreived from buildmanifest 
# device=$(/usr/libexec/PlistBuddy -c "Print :SupportedProductTypes" /dev/stdin <<< "$buildmanifest")
# device=$(echo $device | grep -oEi "iPod[0-9],1|iPhone[0-9],1|iPad[0-9],1")

firmware=$(plutil -extract 'ProductVersion' xml1 -o - work/BuildManifest.plist | xmllint -xpath '/plist/string/text()' -)
# @TODO: ensure correct irecovery version is installed
device=$(irecovery -q | grep "PRODUCT" | cut -f 2 -d ":" | cut -c 2-)
ecid=$(irecovery -q | grep "ECID" | sed 's/ECID: //')
echo "Firmware version: $firmware"
echo "Found device: $device"

if [ ! -d tickets ]; then
    mkdir tickets
else
    rm -f tickets/*
fi

./bin/tsschecker -d $device -e $ecid --boardconfig $boardconfig -s -l --save-path tickets/
shsh=$(ls tickets/*.shsh2)
echo "Found shsh: $shsh"

boardconfig_without_ap=$(echo $boardconfig | sed 's/ap//g')

ibss=$(plutil -extract 'BuildIdentities.0.Manifest.iBSS.Info.Path' xml1 -o - BuildManifest.plist | xmllint -xpath '/plist/string/text()' -)
ibec=$(plutil -extract 'BuildIdentities.0.Manifest.iBEC.Info.Path' xml1 -o - BuildManifest.plist | xmllint -xpath '/plist/string/text()' -)
echo "iBSS: $ibss"
echo "iBEC: $ibec"

if [ -e boot/ibss.img4 ]; then
 echo "Skipped making boot files."
else
 ./bin/gaster decrypt work/$ibss work/ibss.dec
 ./bin/gaster decrypt work/$ibec work/ibec.dec
 ./bin/iBoot64Patcher work/ibss.dec work/ibss.patched
 ./bin/iBoot64Patcher work/ibec.dec work/ibec.patched -b "-v"
 img4tool -e -s $shsh -m IM4M
 img4 -i work/ibss.patched -o boot/ibss.img4 -M IM4M -A -T ibss
 img4 -i work/ibec.patched -o boot/ibec.img4 -M IM4M -A -T ibec
 devicetree=$(awk "/"${boardconfig_without_ap}"/{x=1}x&&/DeviceTree[.]/{print;exit}" work/BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | sed 's/Firmware[/]dfu[/]//')
 img4 -i work/$devicetree -o boot/devicetree.img4 -M IM4M -T rdtr
 trustcache="$(/usr/libexec/PlistBuddy work/BuildManifest.plist -c "Print BuildIdentities:0:Manifest:StaticTrustCache:Info:Path" | sed 's/"//g')"
 img4 -i work/$trustcache -o boot/trustcache.img4 -M IM4M -T rtsc 
 
 # @TODO: and where is kpp.bin
 # @TODO: add kpp for legacy devices support
#  if [[ "$device" == *"iPhone8,"* ]] || [[ "$device" == *"iPhone7,"* ]] || [[ "$device" == *"iPhone6,"* ]]; then
#   echo "Device has kpp"
#   kpp=1
#  else
#   echo "Device does not have kpp"
#   kpp=0
#  fi
 
 kpp=0
 
 kernelcache=$(/usr/libexec/PlistBuddy work/BuildManifest.plist -c "Print BuildIdentities:0:Manifest:KernelCache:Info:Path" | sed 's/"//g')
 
 if [ $kpp == 1 ]; then
  pyimg4 im4p extract -i work/$kernelcache -o work/kcache.raw --extra work/kpp.bin 
 else
  pyimg4 im4p extract -i work/$kernelcache -o work/kcache.raw
 fi
 
 ./bin/Kernel64Patcher work/kcache.raw work/krnl.patched -f
 
 if [ $kpp == 1 ]; then
  pyimg4 im4p create -i work/krnl.patched -o boot/krnl.im4p --extra work/kpp.bin -f rkrn --lzss
 else
  pyimg4 im4p create -i work/krnl.patched -o boot/krnl.im4p -f rkrn --lzss
 fi
  pyimg4 img4 create -p boot/krnl.im4p -o boot/krnl.img4 -m IM4M
fi

if [ -e restore/krnl.im4p ]; then
 echo "Skipped making restore files."
else
 ramdisk=$(/usr/libexec/PlistBuddy work/BuildManifest.plist -c "Print BuildIdentities:0:Manifest:RestoreRamDisk:Info:Path" | sed 's/"//g')
 echo "Found ramdisk: $ramdisk"
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
 chmod -R 755 work/patched_restored_external
 chmod -R 755 work/patched_asr
 rm work/ramdisk/usr/sbin/asr
 rm work/ramdisk/usr/local/bin/restored_external
 cp work/patched_asr work/ramdisk/usr/sbin/asr
 cp work/patched_restored_external work/ramdisk/usr/local/bin/restored_external
 hdiutil detach -force work/ramdisk
 sleep 5
 mkdir restore
 pyimg4 im4p create -i work/ramdisk.dmg -o restore/ramdisk.im4p -f rdsk
 
 # get kernelcache from buildmanifest
 kernelcache=$(/usr/libexec/PlistBuddy work/BuildManifest.plist -c "Print BuildIdentities:0:Manifest:KernelCache:Info:Path" | sed 's/"//g')
 
 if [ $kpp == 1 ]; then
  pyimg4 im4p extract -i work/$kernelcache -o work/kcache.raw --extra work/kpp.bin 
 else
  pyimg4 im4p extract -i work/$kernelcache -o work/kcache.raw
 fi
 
 ./bin/Kernel64Patcher work/kcache.raw work/krnl.patched -f -a
 
 if [ $kpp == 1 ]; then
  pyimg4 im4p create -i work/krnl.patched -o restore/krnl.im4p --extra work/kpp.bin -f rkrn --lzss
 else
  pyimg4 im4p create -i work/krnl.patched -o restore/krnl.im4p -f rkrn --lzss
 fi
 
 echo "Continuing to futurerestore..."
 echo $ipsw > restore/ipsw_path
 _runFuturerestore
fi
