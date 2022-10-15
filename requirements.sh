#!/bin/bash
trap exit INT

cecho() {
  RED="\033[0;31m"
  GREEN="\033[0;32m"  # <-- [0 means not bold
  YELLOW="\033[0;33m" # <-- [1 means bold
  CYAN="\033[0;36m"
  # ... Add more colors if you like

  NC="\033[0m" # No Color

  # printf "${(P)1}${2} ${NC}\n" # <-- zsh
  printf "${!1}${2} ${NC}\n" # <-- bash
}

error_exit() {
  cecho "RED" "Error: $1"
  exit 1
}

macOSversion=$(sw_vers | head -n2 | tail -n1 | cut -c 17-)
verscheck=$(bc <<<"${macOSversion} < 10.14")

if [ "$(uname)" = "Darwin" ]; then
  cecho "CYAN" "[!] macOS detected!"
  if [[ $(sysctl -n machdep.cpu.brand_string) =~ "Apple" ]]; then
    cecho "CYAN" "[!] Apple Silicon detected"
    OS="macOS-arm64"
  elif [[ $(sysctl -n machdep.cpu.brand_string) =~ "Intel" ]]; then
    cecho "CYAN" "[!] Intel mac detected!"
    OS="macOS-x86_64"
  fi
else
  cecho "RED" "Not running on macOS... exiting..."
  exit 2
fi

if command -v brew >/dev/null && [ -f /opt/procursus/bin/apt ]; then
  cecho "GREEN" "[!] Homebrew and Procursus were found."
  echo "Choose a package manager for your dependencies."
  PS3='Please enter your choice: '
  options=("Procursus (apt)" "Homebrew" "Quit")
  select opt in "${options[@]}"; do
    case $opt in
    "Procursus (apt)")
      cecho "CYAN" "[!] Procursus selected."
      pkg="sudo apt"
      break
      ;;
    "Homebrew")
      cecho "CYAN" "[!] Homebrew selected."
      pkg="brew"
      break
      ;;
    "Quit")
      exit
      ;;
    *) cecho "RED" "invalid option $REPLY" ;;
    esac
  done
elif [ -f /opt/procursus/bin/apt ]; then
  cecho "GREEN" "[!] Procursus is installed"
  pkg="sudo apt"
elif command -v brew >/dev/null; then
  cecho "GREEN" "[!] Homebrew is installed!"
  pkg="brew"
else
  cecho "YELLOW" "[!] Procursus nor Homebrew were found."
  if [ "$verscheck" -eq 1 ]; then
    cecho "RED" "[!] Procursus is not compatible with your macOS version."
  else
    echo "Would you like to install Procursus?"
    read -p "[y/n]" installpro
    if echo "$installpro" | grep '^[Yy]\?$'; then
      ./procursus-install-macOS.sh
      pkg="sudo apt"
    fi
  fi
  cecho "YELLOW" "[!] Homebrew not found. Install instructions can be found at https://brew.sh"
  exit 3
fi

if [ ! "$(command -v futurerestore)" ] && [ ! -e "$HOME/FutureRestoreGUI/extracted/futurerestore" ]; then
  cecho "YELLOW" "futurerestore not found. Download at https://github.com/futurerestore/futurerestore"
  sleep 5
  open https://github.com/futurerestore/futurerestore
  exit 3
elif command -v futurerestore; then
  cecho "GREEN" "[!] futurerestore is installed!"
elif [ -e "$HOME/FutureRestoreGUI/extracted/futurerestore" ]; then
  cecho "GREEN" "[!] Located futurerestore downloaded by FutureRestoreGUI."
fi

if command -v irecovery >/dev/null &&  irecovery --version | grep 1.0.1 > /dev/null ; then
  cecho "GREEN" "[!] irecovery is installed!"
else
  if [ "$pkg" = "sudo apt" ]; then
  cecho "YELLOW" "[!] irecovery not found. Installing..."
    $pkg install libirecovery-utils
  elif [ "$pkg" = "brew" ]; then
    cat <<EOF
[!] brew's version of irecovery is outdated and incompatible with sunst0rm.
Install from https://github.com/libimobiledevice/libirecovery
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
error_exit "[!] irecovery version mismatch."

  fi
fi

if command -v git >/dev/null; then
  cecho "GREEN" "[!] git is installed!"
else
  cecho "YELLOW" "[!] git not found. Installing..."
  $pkg install git
fi

if command -v clang >/dev/null; then
  cecho "GREEN" "[!] clang is installed!"
else
  if [ "$pkg" = "sudo apt" ]; then
    $pkg install clang
  elif [ "$pkg" = "brew" ]; then
    $pkg install llvm
  fi
fi

if ! command -v python3 >/dev/null; then
  cecho "YELLOW" "[!] python3 not found. Installing..."
  $pkg install python3
else
  cecho "GREEN" "[!] python3 is installed!"
fi

if python3 -m pip | grep "No module named pip"; then
  cecho "YELLOW" "[!] pip not found. installing"
  python3 -m ensurepip
else
  cecho "GREEN" "[!] pip is installed!."
fi

if [ "$(python3 -m pip list | grep -c "pyimg4")" == 0 ]; then
  cecho "YELLOW" "[!] pyimg4 not found. Installing..."
  python3 -m pip install pyimg4 || error_exit "[!] pyimg4 failed to install"
else
  cecho "GREEN" "[!] pyimg4 is installed!"
fi

if [[ ! -d "/usr/local/bin" ]]; then
  echo "[!] /usr/local/bin does not exist, creating it now... (please enter your password)"
  sudo mkdir -p /usr/local/bin
fi

if [ ! -e "/usr/local/bin/img4" ]; then
  cecho "YELLOW" "[!] img4 not found. Downloading..."
  curl --progress-bar -o img4lib.tar.gz -L https://github.com/xerub/img4lib/releases/download/1.0/img4lib-2020-10-27.tar.gz || error_exit "[!] Download failed."
  tar -xvf img4lib.tar.gz
  sudo mkdir -p /usr/local/bin
  mv -v img4lib/apple/img4 /usr/local/bin/
  mv -v img4lib/apple/libimg4.a /usr/local/lib/
  rm -rf img4lib/
  rm img4lib.tar.gz
  chmod 755 /usr/local/bin/img4
  xattr -d com.apple.quarantine /usr/local/bin/img4
fi

if ! command -v img4tool > /dev/null; then
if [ "$pkg" = "sudo apt" ]; then
  cecho "YELLOW" "[!] img4tool not found. Installing using apt..."
$pkg install img4tool
  else
  cecho "YELLOW" "[!] img4tool not found. Downloading..."
  curl --progress-bar -OL https://github.com/tihmstar/img4tool/releases/download/197/buildroot_macos-latest.zip || error_exit "[!] Download failed."
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
fi

if [ ! -d bin ]; then
  mkdir bin
fi

cd bin

if [ ! -e "./gaster" ]; then
  cecho "YELLOW" "[!] gaster not found. Downloading..."
  git clone https://github.com/0x7ff/gaster.git gaster_git
  cd gaster_git
  make
  mv -v gaster ../
  cd ../
  rm -rf gaster_git/
  chmod 755 gaster
  xattr -d com.apple.quarantine gaster
else
  cecho "GREEN" "[!] gaster found!"
fi

if [ ! -e "./iBoot64Patcher" ]; then
  cecho "YELLOW" "[!] iBoot64Patcher not found. Downloading..."
  curl --progress-bar -OL https://nightly.link/Arna13/iBoot64Patcher/actions/runs/3176527177/iBoot64Patcher-${OS}-RELEASE.zip
  unzip iBoot64Patcher-${OS}-RELEASE.zip
  tar -xvf iBoot64Patcher-${OS}-*-RELEASE.tar.xz
  rm -rf iBoot64Patcher-*
  chmod 755 iBoot64Patcher
  xattr -d com.apple.quarantine iBoot64Patcher
else
  cecho "GREEN" "[!] iBoot64Patcher found!"
fi

if [ ! -e "./Kernel64Patcher" ]; then
  cecho "YELLOW" "[!] Kernel64Patcher not found. Downloading..."
  git clone https://github.com/iSuns9/Kernel64Patcher.git Kernel64Patcher_git
  cd Kernel64Patcher_git
  clang Kernel64Patcher.c -o Kernel64Patcher
  mv -v Kernel64Patcher ../
  cd ../
  rm -rf Kernel64Patcher_git/
  chmod 755 Kernel64Patcher
  xattr -d com.apple.quarantine Kernel64Patcher
else
  cecho "GREEN" "[!] Kernel64Patcher found!"
fi

if [ ! -e "./asr64_patcher" ]; then
  cecho "YELLOW" "[!] asr64_patcher not found. Downloading..."
  git clone https://github.com/exploit3dguy/asr64_patcher.git asr64_patcher_git
  cd asr64_patcher_git
  clang asr64_patcher.c -o asr64_patcher
  mv -v asr64_patcher ../
  cd ../
  rm -rf asr64_patcher_git/
  chmod 755 asr64_patcher
  xattr -d com.apple.quarantine asr64_patcher
else
  cecho "GREEN" "[!] asr64_patcher found!"
fi

if [ ! -e "./restored_external64_patcher" ]; then
  cecho "YELLOW" "[!] restored_external64_patcher not found. Downloading..."
  git clone https://github.com/iSuns9/restored_external64patcher.git restored_external64patcher_git
  cd restored_external64patcher_git
  clang restored_external64_patcher.c -o restored_external64_patcher
  mv -v restored_external64_patcher ../
  cd ../
  rm -rf restored_external64patcher_git/
  chmod 755 restored_external64_patcher
  xattr -d com.apple.quarantine restored_external64_patcher
else
  cecho "GREEN" "[!] restored_external64_patcher found!"
fi

if [ ! -e "./ldid" ] && [ "$(command -v ldid)" != "/opt/procursus/bin/ldid" ]; then
  cecho "YELLOW" "[!] ldid not found. Downloading..."
  if [ "$OS" = "macOS-x86_64" ]; then
    OS=macos_x86_64
  elif [ "$OS" = "macOS-arm64" ]; then
    OS=macos_arm64
  fi

  if [ "$pkg" = "sudo apt" ]; then
    $pkg install ldid
  else
    curl --progress-bar -o ldid -L https://github.com/ProcursusTeam/ldid/releases/download/v2.1.5-procursus5/ldid_${OS} || error_exit "[!] Download failed."
    chmod 755 ldid
    xattr -d com.apple.quarantine ldid
  fi
else
  cecho "GREEN" "[!] ldid found!"
fi

if [ ! -e "./tsschecker" ]; then
  cecho "YELLOW" "tsschecker not found. Downloading..."
  curl --progress-bar -o tsschecker.zip -L https://github.com/tihmstar/tsschecker/releases/download/304/tsschecker_macOS_v304.zip || error_exit "[!] Download failed."
  unzip tsschecker.zip
  rm tsschecker.zip
  chmod 755 tsschecker
  xattr -d com.apple.quarantine tsschecker
else
  cecho "GREEN" "[!] tsschecker found!"
fi

cd ../

cecho "GREEN" "### Dependency installation finished ###"
touch .requirements_done
