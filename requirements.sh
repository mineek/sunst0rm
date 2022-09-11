#!/bin/bash

# x86_64=$(uname -p | grep -c "i386")

if [ ! -e "/usr/local/bin/brew" ]; then
echo "Homebrew not found. Installer at https://brew.sh"
open https://brew.sh
exit
fi

if [ ! -e "/usr/local/bin/futurerestore" ]; then
echo "futurerestore not found. Download at https://github.com/futurerestore/futurerestore"
open https://github.com/futurerestore/futurerestore
exit
fi

if [ ! -e "/usr/local/bin/irecovery" ]; then
cat <<EOF
irecovery not found. Install from https://github.com/libimobiledevice/libirecovery
Or use these following commands to install:

  brew install autoconf automake libtool pkg-config cmake libzip openssl libplist libpng
  sudo cp -r $(brew --prefix openssl)/lib/pkgconfig/* /usr/local/lib/pkgconfig/
  git clone https://github.com/libimobiledevice/libirecovery.git
  cd libirecovery
  ./autogen.sh --without-cython --enable-static --disable-shared CFLAGS="-fPIC" CXXFLAGS="-fPIC"
  make
  rm -rf src/.libs/*.dylib #there is not such thing as no-dynamic on macOS
  sudo make install
  cd ..
  rm -rf libirecovery

EOF
exit
fi

if [ ! -e "/usr/bin/curl" ]; then
echo "curl not found. Installing..."
brew install curl
fi

if [[ $(git -v) != *"git version"* ]]; then
echo "git not found. Installing..."
brew install git
fi

if [[ $(python3 --version) != *"Python 3."* ]]; then
echo "python3 not found. Installing..."
brew install python3
fi

if [ $(python3 -m pip list | grep -c "pyimg4") == 0 ]; then
echo "pyimg4 not found. Installing..."
python3 -m pip install pyimg4
fi

if [ ! -e "/usr/local/bin/img4" ]; then
echo "img4 not found. Downloading..."
curl --progress-bar -o img4lib.tar.gz -L https://github.com/xerub/img4lib/releases/download/1.0/img4lib-2020-10-27.tar.gz
tar -xvf img4lib.tar.gz
mv -v img4lib/apple/img4 /usr/local/bin/
mv -v img4lib/apple/libimg4.a /usr/local/lib/
rm -rf img4lib/
rm img4lib.tar.gz
chmod 755 /usr/local/bin/img4
xattr -d com.apple.quarantine /usr/local/bin/img4
fi

if [ ! -e "/usr/local/bin/img4tool" ]; then
echo "img4tool not found. Downloading..."
curl --progress-bar -OL https://github.com/tihmstar/img4tool/releases/download/197/buildroot_macos-latest.zip
unzip buildroot_macos-latest.zip
usr_local=buildroot_macos-latest/usr/local
mv -v $usr_local/bin/img4tool /usr/local/bin/
mv -v $usr_local/include/img4tool /usr/local/include/
mv -v $usr_local/lib/libimg4tool.* /usr/local/lib/
mv -v $usr_local/lib/pkgconfig/libimg4tool.pc /usr/local/lib/pkgconfig/
rm -rf buildroot_macos-latest/
rm buildroot_macos-latest.zip
chmod 755 /usr/local/bin/img4tool
xattr -d com.apple.quarantine /usr/local/bin/img4tool
fi

if [ ! -d bin ]; then
mkdir bin
fi

cd bin

if [ ! -e "./gaster" ]; then
echo "gaster not found. Downloading..."
git clone https://github.com/0x7ff/gaster.git gaster_git
cd gaster_git
make
mv -v gaster ../
cd ../
rm -rf gaster_git/
chmod 755 gaster
xattr -d com.apple.quarantine gaster
fi

# @FIX: move iBoot64Patcher into ./bin/
# if [ ! -e "./iBoot64Patcher" ]; then
# echo "iBoot64Patcher not found. Downloading..."
# curl --progress-bar -OL https://nightly.link/Cryptiiiic/iBoot64Patcher/workflows/ci/main/iBoot64Patcher-macOS-x86_64-RELEASE.zip
# unzip iBoot64Patcher-macOS-x86_64-RELEASE.zip
# mv iBoot64Patcher-macOS-x86_64-RELEASE/iBoot64Patcher .
# rm -rf iBoot64Patcher-*
# chmod 755 iBoot64Patcher
# xattr -d com.apple.quarantine iBoot64Patcher
# fi

if [ ! -e "./iBoot64Patcher" ]; then
echo "iBoot64Patcher not found. Downloading ..."
curl --progress-bar -OL https://nightly.link/Cryptiiiic/iBoot64Patcher/workflows/ci/main/iBoot64Patcher-macOS-x86_64-RELEASE.zip
unzip iBoot64Patcher-macOS-x86_64-RELEASE.zip
mv -v iBoot64Patcher-macOS-x86_64-RELEASE/iBoot64Patcher ../
rm -rf iBoot64Patcher-macOS-x86_64-RELEASE/
rm iBoot64Patcher-macOS-x86_64-RELEASE.zip
chmod 755 iBoot64Patcher
xattr -d com.apple.quarantine iBoot64Patcher
fi

if [ ! -e "./Kernel64Patcher" ]; then
echo "Kernel64Patcher not found. Downloading..."
git clone https://github.com/iSuns9/Kernel64Patcher.git Kernel64Patcher_git
cd Kernel64Patcher_git
gcc Kernel64Patcher.c -o Kernel64Patcher
mv -v Kernel64Patcher ../
cd ../
rm -rf Kernel64Patcher_git/
chmod 755 Kernel64Patcher
xattr -d com.apple.quarantine Kernel64Patcher
fi

if [ ! -e "./asr64_patcher" ]; then
echo "asr64_patcher not found. Downloading..."
git clone https://github.com/exploit3dguy/asr64_patcher.git asr64_patcher_git
cd asr64_patcher_git
gcc asr64_patcher.c -o asr64_patcher
mv -v asr64_patcher ../
cd ../
rm -rf asr64_patcher_git/
chmod 755 asr64_patcher
xattr -d com.apple.quarantine asr64_patcher
fi

if [ ! -e "./restored_external64_patcher" ]; then
echo "restored_external64_patcher not found. Downloading..."
git clone https://github.com/iSuns9/restored_external64patcher.git restored_external64patcher_git
cd restored_external64patcher_git
gcc restored_external64_patcher.c -o restored_external64_patcher
mv -v restored_external64_patcher ../
cd ../
rm -rf restored_external64patcher_git/
chmod 755 restored_external64_patcher
xattr -d com.apple.quarantine restored_external64_patcher
fi

if [ ! -e "./ldid2" ]; then
# @TODO: add support for macos_arm64
echo "ldid2 not found. Downloading..."
curl --progress-bar -o ldid2 -L https://github.com/ProcursusTeam/ldid/releases/download/v2.1.5-procursus5/ldid_macos_x86_64
chmod 755 ldid2
xattr -d com.apple.quarantine ldid2
fi

if [ ! -e "./tsschecker" ]; then
echo "tsschecker not found. Downloading..."
curl --progress-bar -o tsschecker.zip -L https://github.com/tihmstar/tsschecker/releases/download/304/tsschecker_macOS_v304.zip
unzip tsschecker.zip
rm tsschecker.zip
chmod 755 tsschecker
xattr -d com.apple.quarantine tsschecker
fi

cd ../
touch .requirements_done
