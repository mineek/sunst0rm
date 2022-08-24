#!/bin/bash

device_dfu=$(irecovery -m | grep -c "DFU")

if [ $device_dfu = 0 ]; then
    echo "No device found in DFU mode!"
    exit
fi

if [ -z "$1" ]; then
    echo "No argument provided."
    echo "USAGE:"
    echo "  RESTORING: $0 <path_to_ipsw> <boardconfig>"
    echo "  BOOTING: $0 boot"
    exit
fi

gaster pwn

if [ "$1" == "boot" ]; then
    if [ ! -d boot ]; then
        echo "Run $0 <path_to_ipsw> <boardconfig> first!"
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
    else
        echo "Required files not found, run script again!"
    fi
    echo "Done!"
    exit
fi

if [ -d work ]; then
    rm -rf work/
fi

if [ -d boot ]; then
    rm -rf boot/
fi

mkdir work
mkdir boot

# if [ -z "$2" ]; then
#  echo "You forgot an boardconfig :P"
#  exit
# fi

# ipsw=$1
# boardconfig=$2

# if [ -e $ipsw ] || [ ${ipsw: -5} == ".ipsw" ]; then
# echo "Continuing..."
# else
# echo "You forgot an ipsw :P"
# echo "ipsw is required to continue!"
# exit
# fi

if [[ "$1" == "" ]]; then
 echo "You forgot an ipsw :P"
 exit
fi
if [[ "$2" == "" ]]; then
 echo "You forgot an boardconfig :P"
 exit
fi
ipsw=$1
boardconfig=$2
unzip -q $ipsw -d work
buildmanifest=$(cat work/BuildManifest.plist)
firmware=$(/usr/libexec/PlistBuddy -c "Print :ProductVersion" /dev/stdin <<< "$buildmanifest")
device=$(/usr/libexec/PlistBuddy -c "Print :SupportedProductTypes" /dev/stdin <<< "$buildmanifest")
device=$(echo $device | grep -oEi "iPod[0-9],1|iPhone[0-9],1|iPad[0-9],1")
echo "Firmware version: $firmware"
echo "Device: $device"
tsschecker -d $device -e $ecid --boardconfig $boardconfig -s -l
shsh=$(ls *.shsh2)
echo "Found shsh: $shsh"
boardconfig_without_ap=$(echo $boardconfig | sed 's/ap//g')
ibss=$(awk "/"${boardconfig_without_ap}"/{x=1}x&&/iBSS[.]/{print;exit}" work/BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | sed 's/Firmware[/]dfu[/]//')
ibec=$(awk "/"${boardconfig_without_ap}"/{x=1}x&&/iBEC[.]/{print;exit}" work/BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | sed 's/Firmware[/]dfu[/]//')
echo "Found iBEC: $ibec"
echo "Found iBSS: $ibss"
if [[ -e boot/ibss.img4 ]]; then
 echo "Skipped making boot files."
else
 gaster decrypt work/Firmware/dfu/$ibec work/decrypted_ibec
 gaster decrypt work/Firmware/dfu/$ibss work/decrypted_ibss
 iBoot64Patcher work/decrypted_ibss work/ibss.patched
 iBoot64Patcher work/decrypted_ibec work/ibec.patched -b "-v"
 img4tool -e -s $shsh -m IM4M
 img4 -i work/ibss.patched -o boot/ibss.img4 -M IM4M -A -T ibss
 img4 -i work/ibec.patched -o boot/ibec.img4 -M IM4M -A -T ibec
 devicetree=$(awk "/"${boardconfig_without_ap}"/{x=1}x&&/DeviceTree[.]/{print;exit}" work/BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | sed 's/Firmware[/]dfu[/]//')
 img4 -i work/$devicetree -o boot/devicetree.img4 -M IM4M -T rdtr
 trustcache="$(/usr/libexec/PlistBuddy work/BuildManifest.plist -c "Print BuildIdentities:0:Manifest:StaticTrustCache:Info:Path" | sed 's/"//g')"
 img4 -i work/$trustcache -o boot/trustcache.img4 -M IM4M -T rtsc 
 if [[ $device == "iPhone8,"* || $device == "iPhone7,"* || $device == "iPhone6,"* ]]; then
  echo "Device has kpp"
  kpp=1
 else
  echo "Device does not have kpp"
  kpp=0
 fi
 kernelcache=$(/usr/libexec/PlistBuddy work/BuildManifest.plist -c "Print BuildIdentities:0:Manifest:KernelCache:Info:Path" | sed 's/"//g')
 if [[ $kpp == 1 ]]; then
  pyimg4 im4p extract -i work/$kernelcache -o work/kcache.raw --extra work/kpp.bin 
 fi
 if [[ $kpp == 0 ]]; then
  pyimg4 im4p extract -i work/$kernelcache -o work/kcache.raw
 fi
 Kernel64Patcher work/kcache.raw work/krnl.patched -f
 if [[ $kpp == 1 ]]; then
  pyimg4 im4p create -i work/krnl.patched -o boot/krnl.im4p --extra work/kpp.bin -f rkrn --lzss
 fi
 if [[ $kpp == 0 ]]; then
  pyimg4 im4p create -i work/krnl.patched -o boot/krnl.im4p -f rkrn --lzss
 fi
  pyimg4 img4 create -p boot/krnl.im4p -o boot/krnl.img4 -m IM4M
fi
if [[ -e restore/krnl.im4p ]]; then
 echo "Skipped making restore files."
else
 ramdisk=$(/usr/libexec/PlistBuddy work/BuildManifest.plist -c "Print BuildIdentities:0:Manifest:RestoreRamDisk:Info:Path" | sed 's/"//g')
 echo "Found ramdisk: $ramdisk"
 img4 -i work/$ramdisk -o work/ramdisk.dmg
 mkdir work/ramdisk
 hdiutil attach work/ramdisk.dmg -mountpoint work/ramdisk
 asr64_patcher work/ramdisk/usr/sbin/asr work/patched_asr
 ldid -e work/ramdisk/usr/sbin/asr > work/asr.plist
 ldid -Swork/asr.plist work/patched_asr
 cp work/ramdisk/usr/local/bin/restored_external work/restored_external
 restored_external64_patcher work/restored_external work/patched_restored_external
 ldid -e work/restored_external > work/restored_external.plist
 ldid -Swork/restored_external.plist work/patched_restored_external
 chmod -R 755 work/patched_restored_external
 chmod -R 755 work/patched_asr
 rm work/ramdisk/usr/sbin/asr
 rm work/ramdisk/usr/local/bin/restored_external
 cp work/patched_asr work/ramdisk/usr/sbin/asr
 cp work/patched_restored_external work/ramdisk/usr/local/bin/restored_external
 hdiutil detach work/ramdisk
 mkdir restore
 pyimg4 im4p create -i work/ramdisk.dmg -o restore/ramdisk.im4p -f rdsk
 if [[ $device == "iPhone8,"* || $device == "iPhone7,"* || $device == "iPhone6,"* ]]; then
  echo "Device has kpp"
  kpp=1
 else
  echo "Device does not have kpp"
  kpp=0
 fi
 # get kernelcache from buildmanifest
 kernelcache=$(/usr/libexec/PlistBuddy work/BuildManifest.plist -c "Print BuildIdentities:0:Manifest:KernelCache:Info:Path" | sed 's/"//g')
 if [[ $kpp == 1 ]]; then
  pyimg4 im4p extract -i work/$kernelcache -o work/kcache.raw --extra work/kpp.bin 
 fi
 if [[ $kpp == 0 ]]; then
  pyimg4 im4p extract -i work/$kernelcache -o work/kcache.raw
 fi
 Kernel64Patcher work/kcache.raw work/krnl.patched -f -a
 if [[ $kpp == 1 ]]; then
  pyimg4 im4p create -i work/krnl.patched -o restore/krnl.im4p --extra work/kpp.bin -f rkrn --lzss
 fi
 if [[ $kpp == 0 ]]; then
  pyimg4 im4p create -i work/krnl.patched -o restore/krnl.im4p -f rkrn --lzss
 fi
 echo "Continuing to futurerestore..."
fi
echo "Please use this command to restore your device: ( may need to reboot into pwndfu )"
echo "futurerestore -t $shsh --use-pwndfu --skip-blob --rdsk restore/ramdisk.im4p --rkrn restore/krnl.im4p --latest-sep --latest-baseband $ipsw"
echo "Then, run the following command to boot your device:"
echo "./sunstorm.sh boot"
