# sunst0rm dev

`WARNING: USE AT YOUR OWN RISK! WHATEVER HAPPENS TO YOUR DEVICE IS YOUR RESPONSIBILITY.`

`NOTE: ANY ISSUES SUBMITTED USING THE DEV BRANCH NEED TO CLEARLY STATE THAT YOU'RE USING THE DEV BRANCH`

This is a rewrite of sunst0rm in bash.

MAC OS ONLY!

This is only tested on iPhone 7 (d101ap) ( no support for legacy 32-bit devices )

[SEP/BB Compatibility Chart](https://docs.google.com/spreadsheets/d/1Mb1UNm6g3yvdQD67M413GYSaJ4uoNhLgpkc7YKi3LBs/)

Requirements:
  - Installed Xcode 
  - Installed Xcode Command Line Tools `$ xcode-select --install`
  - Installed [Homebrew](https://brew.sh)
  - Downloaded IPSW (target iOS firmware) which can be found at [ipsw.me](https://ipsw.me)
  - Installed without brew: `futurerestore` `libirecovery` `Python 3`

Usage: 
  - restoring: `./sunst0rm.sh restore 'IPSW'`
  - booting: `./sunst0rm.sh boot`

## Credits / Thanks

[futurerestore contributors](https://github.com/futurerestore)

[xerub](https://github.com/xerub) - img4lib

[tihmstar](https://github.com/tihmstar) - img4tool, tsschecker

[libimobiledevice](https://github.com/libimobiledevice) - libirecovery

[0x7ff](https://github.com/0x7ff) - gaster

[Cryptiiiic](https://github.com/Cryptiiiic) - iBoot64Patcher's fork

[iSuns9](https://github.com/iSuns9) - restored_external64_patcher, Kernel64Patcher's fork

[exploit3dguy](https://github.com/exploit3dguy) - asr64_patcher

[ProcursusTeam](https://github.com/ProcursusTeam) - ldid's fork

[m1stadev](https://github.com/m1stadev) - pyimg4

[sen0rxol0](https://github.com/sen0rxol0) - all their contributions / pull requests

[mineek](https://github.com/mineek) - sunst0rm
