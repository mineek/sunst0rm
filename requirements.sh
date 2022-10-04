#!/bin/bash
error_exit()
{
    echo "Error: $1"
    exit 1
}



macOSversion=$(sw_vers | head -n2 | tail -n1 | cut -c 17-)
verscheck=$(bc <<<"${macOSversion} < 10.14")

if [ "$(uname)" = "Darwin" ]; then
  echo "[!] macOS detected!"
  if [[ $(sysctl -n machdep.cpu.brand_string) =~ "Apple" ]]; then
    echo "[!] Apple Silicon detected"
    OS="macOS-arm64"
  elif [[ $(sysctl -n machdep.cpu.brand_string) =~ "Intel" ]]; then
    echo [!] "Intel mac detected!"
    OS="macOS-x86_64"
  fi
else
  echo "Not running on macOS... exiting..."
  exit 2
fi

if command -v brew >/dev/null && [ -f /opt/procursus/bin/apt ]; then
  echo "[!] Homebrew and Procursus were found."
  echo "Choose a package manager for your dependencies."
  PS3='Please enter your choice: '
  options=("Procursus (apt)" "Homebrew" "Quit")
  select opt in "${options[@]}"; do
    case $opt in
    "Procursus (apt)")
      echo "[!] Procursus selected."
      pkg="sudo apt"
      break
      ;;
    "Homebrew")
      echo "[!] Homebrew selected."
      pkg="brew"
      break
      ;;
    "Quit")
      break
      exit
      ;;
    *) echo "invalid option $REPLY" ;;
    esac
  done
elif [ -f /opt/procursus/bin/apt ]; then
  echo "Procursus found."
  pkg="sudo apt"
elif command -v brew >/dev/null; then
  echo "[!] Homebrew found!"
  pkg="brew"
else
  echo "[!] Procursus nor Homebrew were found."
  if [ "$verscheck" -eq 1 ]; then
    echo "[!] Procursus is not compatible with your macOS version."
  else
    echo "Would you like to install Procursus?"
    read -p "[y/n]" installpro
    if echo "$installpro" | grep '^[Yy]\?$'; then
      exec ./procursus-install-macOS.sh
    fi
  fi
  echo "Homebrew not found. Install instructions can be found at https://brew.sh"
  exit 3
fi

if [ ! "$(command -v futurerestore)" ] && [ -z "$HOME/FutureRestoreGUI/.extracted/futurerestore" ]; then
  echo "futurerestore not found. Download at https://github.com/futurerestore/futurerestore"
  sleep 5
  open https://github.com/futurerestore/futurerestore
  exit 3
elif command -v futurerestore; then
  echo "[!] futurerestore found."
elif [ -z "$HOME/FutureRestoreGUI/.extracted/futurerestore" ]; then
  echo "[!] Located futurerestore downloaded by FutureRestoreGUI."
fi

if command -v irecovery >/dev/null; then
  echo "[!] irecovery found."
else
  echo "[!] irecovery not found. Installing..."
  if [ "$pkg" = "sudo apt" ]; then
    $pkg install libirecovery-utils
  elif [ "$pkg" = "brew" ]; then
    brew install libirecovery
  fi
fi

if command -v git > /dev/null; then
  echo "[!] git found!"
else
  echo "[!] git not found. Installing..."
  $pkg install git
fi

if command -v clang; then
  echo "[!] clang found!"
else
    if [ "$pkg" = "sudo apt" ]; then
    $pkg install clang
  elif [ "$pkg" = "brew" ]; then
    $pkg install llvm
  fi
fi

if [[ $(python3 --version) != *"Python 3."* ]]; then
  echo "python3 not found. Installing..."
  $pkg install python3
fi

if python3 -m pip | grep "No module named pip"; then
  echo "pip not found. installing"
  python3 -m ensurepip
else
  echo "[!] pip found."
fi

if [ $(python3 -m pip list | grep -c "pyimg4") == 0 ]; then
  echo "pyimg4 not found. Installing..."
  python3 -m pip install pyimg4 || error_exit "[!] pyimg4 failed to install"
fi

if [ ! -e "/usr/local/bin/img4" ]; then
  echo "img4 not found. Downloading..."
  curl --progress-bar -o img4lib.tar.gz -L https://github.com/xerub/img4lib/releases/download/1.0/img4lib-2020-10-27.tar.gz || error_exit "Download failed."
  tar -xvf img4lib.tar.gz
  sudo mkdir -p /usr/local/bin
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

if [ ! -e "./iBoot64Patcher" ]; then
  echo "iBoot64Patcher not found. Downloading..."
  curl --progress-bar -OL https://nightly.link/Arna13/iBoot64Patcher/actions/runs/3176527177/iBoot64Patcher-${OS}-RELEASE.zip
  unzip iBoot64Patcher-${OS}-RELEASE.zip
  tar -xvf iBoot64Patcher-${OS}-*-RELEASE.tar.xz
  rm -rf iBoot64Patcher-*
  chmod 755 iBoot64Patcher
  xattr -d com.apple.quarantine iBoot64Patcher
fi

if [ ! -e "./Kernel64Patcher" ]; then
  echo "Kernel64Patcher not found. Downloading..."
  git clone https://github.com/iSuns9/Kernel64Patcher.git Kernel64Patcher_git
  cd Kernel64Patcher_git
  clang Kernel64Patcher.c -o Kernel64Patcher
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
  clang asr64_patcher.c -o asr64_patcher
  mv -v asr64_patcher ../
  cd ../
  rm -rf asr64_patcher_git/
  chmod 755 asr64_patcher
  xattr -d com.apple.quarantine asr64_patcher
fi

if [ ! -e "./restored_external64_patcher" ]; then
  echo "[!] restored_external64_patcher not found. Downloading..."
  git clone https://github.com/iSuns9/restored_external64patcher.git restored_external64patcher_git
  cd restored_external64patcher_git
  clang restored_external64_patcher.c -o restored_external64_patcher
  mv -v restored_external64_patcher ../
  cd ../
  rm -rf restored_external64patcher_git/
  chmod 755 restored_external64_patcher
  xattr -d com.apple.quarantine restored_external64_patcher
fi

if [ ! -e "./ldid2" ]; then
  echo "ldid2 not found. Downloading..."
  if [ "$OS" = "macOS-x86_64" ]; then 
  OS=macos_x86_64
  elif [ "$OS" = "macOS-arm64" ]; then
  OS=macos_arm64
  fi
  curl --progress-bar -o ldid2 -L https://github.com/ProcursusTeam/ldid/releases/download/v2.1.5-procursus5/ldid_${OS} || error_exit "Download failed."
  chmod 755 ldid2
  xattr -d com.apple.quarantine ldid2
fi

if [ ! -e "./tsschecker" ]; then
  echo "tsschecker not found. Downloading..."
  curl --progress-bar -o tsschecker.zip -L https://github.com/tihmstar/tsschecker/releases/download/304/tsschecker_macOS_v304.zip || error_exit "Download failed."
  unzip tsschecker.zip
  rm tsschecker.zip
  chmod 755 tsschecker
  xattr -d com.apple.quarantine tsschecker
fi

cd ../
touch .requirements_done
