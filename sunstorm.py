#!/usr/bin/env python3
# Sunstorm.py

import sys
import os
import argparse
import zipfile
import subprocess
import shutil
import atexit
import tempfile

ROOT = os.path.dirname(__file__) # -> XXX: global variable
sys.path.append(ROOT + '/src')
os.environ['PATH'] = ((ROOT + '/bin') + ':' + os.environ.get('PATH'))

# Custom util in /src
from manifest import Manifest
import api

program_list = [
  'futurerestore',
  'img4tool',
  'Kernel64Patcher',
  'iBoot64Patcher',
  'ldid',
  'asr64_patcher',
  'restored_external64_patcher',
  'hdiutil',
]

def print_error(string):
    # TODO: color support?
    print(f'[!] Error: {string}', file=sys.stderr)

def print_info(string):
    print(f'[*] Info: {string}')

def cleanup(directory) -> None:
    """ Remove any temp-files created """
    try: 
      shutil.rmtree(directory, ignore_errors=True)
    except:
      print_error(f'Failed to remove {directory} (this is a bug)')

def check_for_command(prog) -> bool:
    """ Use the `command` shell-builtin to test for program """
    return (
      subprocess.run(f'command -v {prog} &>/dev/null', shell=True).returncode == 0
    )

def check_for_dependencies() -> None:
    """
      Loop over {program_list}, check for every command.

      Exits on error
    """
    for prog in program_list:
      if not check_for_command(prog):
        print_error(f'"{prog}" not found, please install it.')
        sys.exit(1)

def prep_restore(ipsw, blob, boardconfig, kpp, legacy, skip_baseband):
    # tempdir
    work = tempfile.mkdtemp(suffix='restore')
    # make a directory in the work directory called ramdisk
    os.mkdir(f'{work}/ramdisk')
    # register cleanup trap
    atexit.register(cleanup, work)

    # extract the IPSW to the work directory
    print_info('Extracting IPSW')
    with zipfile.ZipFile(ipsw, 'r') as z:
        z.extractall(work)
    
    # read manifest from {work}/BuildManifest.plist
    with open(f'{work}/BuildManifest.plist', 'rb') as f:
        manifest = Manifest(f.read())
    # get the ramdisk name
    ramdisk_path = manifest.get_comp(board, 'RestoreRamDisk')
    if ramdisk_path == None:
        print_error("Error: BoardConfig was not recognized")
        sys.exit(1)

    # extract it using img4
    print_info('Extracting RamDisk')
    subprocess.run(['img4', '-i', f'{work}/{ramdisk_path}', '-o', f'{work}/ramdisk.dmg'])

    # mount it using hdiutil
    print_info('Mounting RamDisk')
    subprocess.run(['hdiutil', 'attach', f'{work}/ramdisk.dmg', '-mountpoint', f'{work}/ramdisk'])

    # patch asr into the ramdisk
    print_info('Patching ASR in the RamDisk')
    subprocess.run(['asr64_patcher', f'{work}/ramdisk/usr/sbin/asr', f'{work}/patched_asr'])

    # extract the ents and save it to {work}/asr_ents.plist like:     subprocess.run(['ldid', '-e', '{work}/ramdisk/usr/sbin/asr', '>', '{work}/asr.plist'])
    print_info('Extracting ASR Ents')
    with open(f'{work}/asr.plist', 'wb') as f:
        subprocess.run(['ldid', '-e', f'{work}/ramdisk/usr/sbin/asr'], stdout=f)
    # resign it using ldid
    print_info('Resigning ASR')
    subprocess.run(['ldid', f'-S{work}/asr.plist', f'{work}/patched_asr'])
    # chmod 755 the new asr
    print_info('Chmoding ASR')
    subprocess.run(['chmod', '-R', '755', f'{work}/patched_asr'])
    # copy the patched asr back to the ramdisk
    print_info('Copying Patched ASR back to the RamDisk')
    subprocess.run(['cp', f'{work}/patched_asr', f'{work}/ramdisk/usr/sbin/asr'])

    if legacy:
        print_info('Legacy mode, skipping restored_external')
    else:
        # patch restored_external 
        print_info('Patching Restored External')
        subprocess.run(['restored_external64_patcher' ,f'{work}/ramdisk/usr/local/bin/restored_external' ,f'{work}/restored_external_patched'])
        #resign it using ldid
        print_info('Extracting Restored External Ents')
        with open(f'{work}/restored_external.plist', 'wb') as f:
            subprocess.run(['ldid', '-e', f'{work}/ramdisk/usr/local/bin/restored_external'], stdout=f)
        # resign it using ldid
        print_info('Resigning Restored External')
        subprocess.run(['ldid', f'-S{work}/restored_external.plist', f'{work}/restored_external_patched'])
        # chmod 755 the new restored_external
        print_info('Chmoding Restored External')
        subprocess.run(['chmod', '-R', '755', f'{work}/restored_external_patched'])
        # copy the patched restored_external back to the ramdisk
        print_info('Copying Patched Restored External back to the RamDisk')
        subprocess.run(['cp', f'{work}/restored_external_patched', f'{work}/ramdisk/usr/local/bin/restored_external'])

    # detach the ramdisk
    print_info('Detaching RamDisk')
    subprocess.run(['hdiutil', 'detach', f'{work}/ramdisk'])
    # create the ramdisk using pyimg4
    print_info('Creating RamDisk')
    subprocess.run([sys.executable, '-m', 'pyimg4', 'im4p', 'create', '-i', f'{work}/ramdisk.dmg', '-o', f'{work}/ramdisk.im4p', '-f', 'rdsk'])
    # get kernelcache name from manifest
    kernelcache = manifest.get_comp(board, 'RestoreKernelCache')
    # extract the kernel using pyimg4 like this: pyimg4 im4p extract -i kernelcache -o kcache.raw --extra kpp.bin 
    print_info('Extracting Kernel')

    extract_kernel_args = [sys.executable, '-m', 'pyimg4', 'im4p', 'extract', '-i', f'{work}/' + kernelcache, '-o', f'{work}/kcache.raw']

    if kpp:
        extract_kernel_args += ['--extra', f'{work}/kpp.bin']

    subprocess.run(extract_kernel_args)
    # patch the kernel using kernel64patcher like this: Kernel64Patcher kcache.raw krnl.patched -f -a
    print_info('Patching Kernel')
    subprocess.run(['kernel64patcher', f'{work}/kcache.raw', f'{work}/krnl.patched', '-f', '-a'])
    # rebuild the kernel like this: pyimg4 im4p create -i krnl.patched -o krnl.im4p --extra kpp.bin -f rkrn --lzss (leave out --extra kpp.bin if you dont have kpp)
    print_info('Rebuilding Kernel')

    rebuild_kernel_args = [sys.executable, '-m', 'pyimg4', 'im4p', 'create', '-i', f'{work}/krnl.patched', '-o', f'{work}/krnl.im4p', '-f', 'rkrn', '--lzss']

    if kpp:
      rebuild_kernel_args += ['--extra', f'{work}/kpp.bin']

    subprocess.run(rebuild_kernel_args)

    # Done, move files to root (dirname $0)
    shutil.move(work, ROOT)
    work = f'{ROOT}/{os.path.basename(os.path.dirname(work))}'
    print_info(f'Done! Files moved to "{work}"')

    futurerestore_args = ['futurerestore', '-t', blob, '--use-pwndfu', '--skip-blob', '--rdsk', f'{work}/ramdisk.im4p', '--rkrn', f'{work}/krnl.im4p', '--latest-sep', '--no-baseband' if skip_baseband else '--latest-baseband', ipsw]

    print_info('You can restore the device anytime by running the following command with the device in a pwndfu state:')
    print(futurerestore_args)

    # write to a file to help remember
    with open(f'{work}/restore.command') as f:
      print(futurerestore_args, file=f)

    # Ask user if they would like to restore the device
    ask = input('Would you like to restore now? [Yy/Nn]')
    if ask == 'y' or ask == 'Y':
      subprocess.run(futurerestore_args)

    # Remove the trap so it doesn't error out
    atexit.unregister(cleanup)

    return

def prep_boot(ipsw, blob, boardconfig, kpp, identifier, legacy):
    # tempdir
    work = tempfile.mkdtemp(suffix='boot')
    # register cleanup trap
    atexit.register(cleanup, work)

    # unzip the ipsw
    print_info('Unzipping IPSW')
    with zipfile.ZipFile(ipsw, 'r') as z:
        z.extractall(work)

    with open(f'{work}/BuildManifest.plist', 'rb') as f:
        manifest = Manifest(f.read())

    # get ProductBuildVersion from manifest
    print_info('Getting ProductBuildVersion')
    productbuildversion = manifest.getProductBuildVersion()
    ibss_iv, ibss_key, ibec_iv, ibec_key = api.get_keys(identifier, boardconfig, productbuildversion)

    # get ibec and ibss from manifest
    print_info('Getting IBSS and IBEC')
    ibss = manifest.get_comp(boardconfig, 'iBSS')
    ibec = manifest.get_comp(boardconfig, 'iBEC')

    # decrypt ibss like this:  img4 -i ibss -o ibss.dmg -k ivkey
    print_info('Decrypting IBSS')
    subprocess.run(['img4', '-i', f'{work}/' + ibss, '-o', f'{work}/ibss.dmg', '-k', ibss_iv + ibss_key])

    # decrypt ibec like this:  img4 -i ibec -o ibec.dmg -k ivkey
    print_info('Decrypting IBEC')
    subprocess.run(['img4', '-i', f'{work}/' + ibec, '-o', f'{work}/ibec.dmg', '-k', ibec_iv + ibec_key])

    # patch ibss like this:  iBoot64Patcher ibss.dmg ibss.patched
    print_info('Patching IBSS')
    subprocess.run(['iBoot64Patcher', f'{work}/ibss.dmg', f'{work}/ibss.patched'])

    # patch ibec like this:  iBoot64Patcher ibec.dmg ibec.patched -b "-v"
    print_info('Patching IBEC')
    subprocess.run(['iBoot64Patcher', f'{work}/ibec.dmg', f'{work}/ibec.patched', '-b', '-v'])

    # convert blob into im4m like this: img4tool -e -s blob -m IM4M
    print_info('Converting BLOB to IM4M')
    subprocess.run(['img4tool', '-e', '-s', blob, '-m', 'IM4M'])

    # convert ibss into img4 like this:  img4 -i ibss.patched -o ibss.img4 -M IM4M -A -T ibss
    print_info('Converting IBSS to IMG4')
    subprocess.run(['img4', '-i', f'{work}/ibss.patched', '-o', f'{work}/ibss.img4', '-M', 'IM4M', '-A', '-T', 'ibss'])

    # convert ibec into img4 like this:  img4 -i ibec.patched -o ibec.img4 -M IM4M -A -T ibec
    print_info('Converting IBEC to IMG4')
    subprocess.run(['img4', '-i', f'{work}/ibec.patched', '-o', f'{work}/ibec.img4', '-M', 'IM4M', '-A', '-T', 'ibec'])

    # get the names of the devicetree and trustcache
    print_info('Getting Device Tree and TrustCache')
    # read manifest from {work}/BuildManifest.plist
    trustcache = manifest.get_comp(boardconfig, 'StaticTrustCache') if not legacy else None
    devicetree = manifest.get_comp(boardconfig, 'DeviceTree')

    # sign them like this  img4 -i devicetree -o devicetree.img4 -M IM4M -T rdtr
    print_info('Signing Device Tree')
    subprocess.run(['img4', '-i', f'{work}/' + devicetree, '-o', f'{work}/devicetree.img4', '-M', 'IM4M', '-T', 'rdtr'])

    # sign them like this   img4 -i trustcache -o trustcache.img4 -M IM4M -T rtsc
    if not legacy:
        print_info('Signing Trust Cache')
        subprocess.run(['img4', '-i', f'{work}/' + trustcache, '-o', f'{work}/trustcache.img4', '-M', 'IM4M', '-T', 'rtsc'])

    # grab kernelcache from manifest
    print_info('Getting Kernel Cache')
    kernelcache = manifest.get_comp(boardconfig, 'KernelCache')

    # extract the kernel like this:  pyimg4 im4p extract -i kernelcache -o kcache.raw --extra kpp.bin 
    print_info('Extracting Kernel')
    extract_kernel_args = [sys.executable, '-m', 'pyimg4', 'im4p', 'extract', '-i', f'{work}/' + kernelcache, '-o', f'{work}/kcache.raw']

    if kpp:
        extract_kernel_args += ['--extra', f'{work}/kpp.bin']

    subprocess.run(extract_kernel_args)

    # patch it like this:   Kernel64Patcher kcache.raw krnlboot.patched -f
    print_info('Patching Kernel')
    subprocess.run(['Kernel64Patcher', f'{work}/kcache.raw', f'{work}/krnlboot.patched', '-f'])

    # convert it like this:   pyimg4 im4p create -i krnlboot.patched -o krnlboot.im4p --extra kpp.bin -f rkrn --lzss
    print_info('Converting Kernel')
    convert_kernel_args = [sys.executable, '-m', 'pyimg4', 'im4p', 'create', '-i', f'{work}/krnlboot.patched', '-o', f'{work}/krnlboot.im4p', '-f', 'rkrn', '--lzss']

    if kpp:
      convert_kernel_args += ['--extra', f'{work}/kpp.bin']
    
    subprocess.run(convert_kernel_args)

    # sign it like this:  pyimg4 img4 create -p krnlboot.im4p -o krnlboot.img4 -m IM4M
    print_info('Signing Kernel')
    subprocess.run([sys.executable, '-m', 'pyimg4', 'img4', 'create', '-p', f'{work}/krnlboot.im4p', '-o', f'{work}/krnlboot.img4', '-m', 'IM4M'])

    shutil.move(work, ROOT)
    work = f'{ROOT}/{os.path.basename(os.path.dirname(work))}'
    print_info(f'Done! Files moved to "{work}"')

    # done
    print_info('You can boot the restored device anytime by running the following command with the device in a pwndfu state:')
    print(f'{ROOT}/scripts/' + ('boot.sh' if kpp else 'boot-A10plus.sh'))

    # Remove the trap so it doesn't error out
    atexit.unregister(cleanup)

    return

def main():
    # Arg-parser:
    credit = """
    sunst0rm:
    Made by mineek, some code by m1n1exploit
    """

    parser = argparse.ArgumentParser(description='iOS Tethered IPSW Restore', epilog=credit)
    conflict = parser.add_mutually_exclusive_group(required=True)

    parser.add_argument('-i', '--ipsw', help='IPSW to restore', required=True)
    parser.add_argument('-t', '--blob', help='Blob (shsh2) to use', required=True)
    parser.add_argument('-d', '--boardconfig', help='BoardConfig to use', required=True)
    parser.add_argument('-kpp', '--kpp', help='Use Kernel Patch Protection (KPP)', required=False, action='store_true')
    parser.add_argument('-id', '--identifier', help='Identifier to use', required=False)
    parser.add_argument('--legacy', help='Use Legacy Mode (iOS 11 or lower)', required=False, action='store_true')
    parser.add_argument('--skip-baseband', help='Skip Cellular Baseband', required=False, action='store_true')
    # These options cannot be used together:
    conflict.add_argument('-b', '--boot', help='Create Boot files', action='store_true')
    conflict.add_argument('-r', '--restore', help='Create Restore files', action='store_true')
    # Finally, parse:
    args = parser.parse_args()
    # Arg-parser will exit for us if there's a argument error
    check_for_dependencies()

    # Cast/modify arguments here before passing
    ipsw  = str(args.ipsw)
    blob = str(args.blob)
    boardconfig = str(args.boardconfig).lower() # lowercase board to avoid missing errors
    kpp = bool(args.kpp)
    legacy = bool(args.legacy)
    skip_baseband = bool(args.skip_baseband)
    identifier = str(args.identifier)

    if args.restore:
        prep_restore(ipsw, blob, boardconfig, kpp, legacy, skip_baseband)
    elif args.boot:
        if not identifier:
            print_error('You need to specify an identifier')
            sys.exit(1)

        prep_boot(ipsw, blob, boardconfig, kpp, identifier, legacy)
    else:
        print_error('Please specify a mode')
        sys.exit(1)

    sys.exit(0)

if __name__ == '__main__':
  main()
