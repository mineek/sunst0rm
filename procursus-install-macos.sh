#! /usr/bin/env bash

error_exit() {
  echo "Error: $1"
  exit 1
}

macOSversion=$(sw_vers | head -n2 | tail -n1 | cut -c 17-)
verscheck=$(bc <<<"${macOSversion} < 10.14")

if [ "$verscheck" -eq 1 ]; then
  echo "[!] Procursus is not compatible with your macOS version."
  exit 2
fi

trap clean INT

function clean() {
  echo "[!] Cleaning files..."
  if [[ -f bootstrap.tar.zst ]]; then
    rm bootstrap.tar.zst
  fi
  if [[ -f bootstrap.tar ]]; then
    rm bootstrap.tar
  fi
  if [[ -f zstd ]]; then
    rm zstd
  fi
  exit
}

if command -v curl >/dev/null; then
  echo "[*] Downloading zstd binary..."
  curl -sLO https://cameronkatri.com/zstd || error_exit "[!] Download failed."
else
  echo "cURL not found."
  exit 1
fi

if [[ $(sysctl -n machdep.cpu.brand_string) =~ "Apple" ]]; then
  echo "[!] Apple Silicon detected"
  echo "[*] Downloading bootstrap..."
  curl -sLO https://cdn.discordapp.com/attachments/763074782220517467/819588605999317022/bootstrap.tar.zst || error_exit "[!] Download failed."
elif [[ $(uname -m) == 'x86_64' ]]; then
  echo "[!] Intel mac detected"
  echo "[*] Downloading bootstrap..."
  curl -sL https://apt.procurs.us/bootstrap_darwin-amd64.tar.zst -o bootstrap.tar.zst || error_exit "[!] Download failed."
fi

chmod +x zstd
./zstd -d bootstrap.tar.zst
echo "[*] You will be asked for your password to deploy the bootstrap."
sudo tar -xpkf bootstrap.tar -C /
printf 'export PATH="/opt/procursus/bin:/opt/procursus/sbin:/opt/procursus/games:$PATH"\nexport CPATH="$CPATH:/opt/procursus/include"\nexport LIBRARY_PATH="$LIBRARY_PATH:/opt/procursus/lib"\n' | sudo tee -a /etc/zprofile /etc/profile
export PATH="/opt/procursus/bin:/opt/procursus/sbin:/opt/procursus/games:$PATH"
export CPATH="$CPATH:/opt/procursus/include"
export LIBRARY_PATH="$LIBRARY_PATH:/opt/procursus/lib"

if [[ -f "/opt/procursus/bin/apt" ]]; then
  echo "apt has been installed, PATH has been set"
else
  echo "[!] An error occured..."
  exit 1
fi
clean

echo "[*] Running apt update and upgrade (password required)"
sudo apt update
sudo apt full-upgrade

# Build deps option is commented out as users won't be using them.

#echo "Would you like to install build dependencies for Procursus? (Yes/no)"
#read -r ask
#case $ask in
#[Yy]*)
# sudo apt install autoconf automake autopoint bash bison cmake curl docbook-xml docbook-xsl fakeroot findutils flex gawk git gnupg groff gzip ldid libtool make ncurses-bin openssl patch pkg-config po4a python3 sed tar triehash xz-utils zstd
#if [[ $? -ne 0 ]]; then
# echo "[!] An error occured when installing procursus build dependencies"
#else
echo "[*] Installation complete."
exit
#fi
#;;
#*)
# echo "[*] Non-yes option entered. Exiting."
#exit
#;;
#esac
