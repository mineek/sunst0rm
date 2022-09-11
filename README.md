![Logo](https://cdn.discordapp.com/attachments/1002450787085066250/1002533777693745182/sunst0rmgithub.png)

# sunst0rm
iOS Tether Downgrader for checkm8 devices

Based on [my guide](https://github.com/mineek/iostethereddowngrade)

## please, please, please, DO NOT ask for help in any other discord. Developers not affiliated with sunst0rm are sick of getting issue after issue due to sunst0rm and I just don't want to irritate them, instead join the discord server linked below.
## Also: please DO NOT open issues at [futurerestore](https://github.com/futurerestore/futurerestore) when using sunst0rm, they're almost always NOT the fault of futurerestore.

## See [this guide](https://github.com/Arna13/sunst0rm-guide) for help
## You can also watch [this youtube video](https://www.youtube.com/watch?v=P1m_DsoWyb0) for a video tutorial
### If you still have problems, join the [Discord](https://discord.gg/TqVH6NBwS3) server for help

### Linux version by [MCApollo](https://github.com/MCApollo): [here](https://github.com/MCApollo/sunst0rm) ( only tested on arch )

### If you want, please checkout the [dev branch](https://github.com/mineek/sunst0rm/tree/dev) where my bash rewrite lives and give feedback / report issues, it would be really useful!

## Notes
- It is a *tethered* downgrade meaning you will have to boot tethered every single time from your PC if your battery dies or if you reboot your phone.
- On A10-A11 devices crucial functionality such as the Home Button, Audio, Microphone, Vibration does NOT work at the moment.
- You should NOT be tether downgrading your main device it is only recommended to tether downgrade a second device.
- For some frequently asked fixes go [here](https://github.com/Arna13/sunst0rm-guide/blob/main/docs/misc/EXTRAS.md) for help.
## Requirements:
- [libirecovery](https://github.com/libimobiledevice/libirecovery)
- [futurerestore (fork)](https://github.com/futurerestore/futurerestore)
- futurerestore must be the nightly build. A compiled binary can be found [here](https://github.com/futurerestore/futurerestore/actions)
- [iBoot64patcher (fork)](https://github.com/Cryptiiiic/iBoot64Patcher)
- Precompiled binaries for iBoot64Patcher can be found [here](https://github.com/Cryptiiiic/iBoot64Patcher/actions)
- [Kernel64patcher (fork)](https://github.com/iSuns9/Kernel64Patcher)
- [img4tool](https://github.com/tihmstar/img4tool)
- [img4](https://github.com/xerub/img4lib)
- [ldid](https://github.com/ProcursusTeam/ldid)
- [restored_external64_patcher](https://github.com/iSuns9/restored_external64patcher)
- [asr64_patcher](https://github.com/exploit3dguy/asr64_patcher)
- [Python3](https://www.python.org/downloads)
   - Make sure you updated Python and are not using the bundled one in macOS
- Python dependencies
   - `pip3 install -r requirements.txt`
   - A device that is vulnerable to checkm8 (A7-A11 devices.), if your device is not vulnerable then you can *NOT* tether downgrade at all. 

**Make sure to use the forks listed above.**

## How to use?
| Option (short)  | Option (long)               | Description                              |
|-----------------|-----------------------------|------------------------------------------|
| `-i IPSW`       | `--ipsw IPSW`               | Path to IPSW                             |
| `-t SHSH2`      | `--blob SHSH2`              | Path to SHSH2                            |
| `-r`       | `--restore`            | Restore mode                             |
| `-b`       | `--boot`               | Boot mode                                |
| `-d BOARDCONFIG`| `--boardconfig BOARDCONFIG` | BoardConfig to use  (E.g: `d221ap`)      |
| `-kpp`     | `--kpp`                | Use KPP (A9 or lower)                    |
| `-id IDENTIFIER`| `--identifier IDENTIFIER`   | Identifier to use  (E.g: `iPhone10,6`)   |
|                 | `--legacy`             | Use Legacy Mode (iOS 11 or lower)        |
|                 | `--skip-baseband`           | Skip Baseband sending, do NOT do this if your device does have baseband this argument is only ment to be passed when your device does *not* have baseband such as WiFi only iPads.                  |
### Restoring
```py
python3 sunstorm.py -i 'IPSW' -t 'SHSH2' -r -d 'BOARDCONFIG'
```
- Use `--kpp` if you have KPP, otherwise don't add
- A10+ Devices do NOT have KPP so do not add `--kpp` if you are attempting to tether downgrade an A10+ device, A7-A9X devices does have KPP so that means you will pass `--kpp` and to clear things up having KPP or not does not change the fact if you are able to tether downgrade your device.
### Booting
```py
python3 sunstorm.py -i 'IPSW' -t 'SHSH2' -b -d 'BOARDCONFIG' -id 'IDENTIFIER'
```
- Use `--kpp` if you have KPP, otherwise don't add
```
./boot.sh
```

## Credits:
[M1n1Exploit](https://github.com/Mini-Exploit) - Some code from ra1nstorm

[Arna13](https://github.com/Arna13) - Writing an easy to understand [guide](https://github.com/Arna13/sunst0rm-guide)

[swayea](https://github.com/swayea) - Logo's
