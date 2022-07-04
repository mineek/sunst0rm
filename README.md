# sunst0rm
iOS Tether Downgrader for checkm8 devices

## Note: Make sure to use the dependencies listed below, the automatic checker is not finished yet!

# REQUIREMENTS:
- irecovery
- futurerestore ( NIGHTLY BUILD! )
- pyimg4 (pip3 install pyimg4) (**MAKE SURE YOU UPDATED PYTHON AND NOT USING THE BUNDLED ONE!**)
- iBoot64patcher (https://github.com/Cryptiiiic/iBoot64Patcher)
- Kernel64patcher (https://github.com/iSuns9/Kernel64Patcher)
- img4tool (https://github.com/tihmstar/img4tool)
- img4 (https://github.com/xerub/img4lib)
- ldid (https://github.com/ProcursusTeam/ldid)
- restored_external64_patcher (https://github.com/iSuns9/restored_external64patcher)
- asr64_patcher (https://github.com/exploit3dguy/asr64_patcher)

**Make sure to use the forks listed above.**

## how to use?
### Restoring
python3 sunstorm.py -i ipsw.ipsw -t shsh.shsh2 -r true -d DEVICEBOARD ( use --kpp true if you have kpp, otherwise dont add --kpp )

### booting
python3 sunstorm.py -i ipsw.ipsw -t shsh.shsh2 -b true -d DEVICEBOARD ( use --kpp true if you have kpp, otherwise dont add --kpp ) -id IDENTIFIER

./boot.sh

# CREDITS:
[M1n1Exploit](https://github.com/Mini-Exploit) - Some code from ra1nstorm
