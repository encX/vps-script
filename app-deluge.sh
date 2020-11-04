#!/bin/bash

# for Ubuntu server 16+

export RED='\033[0;31m'
export GREEN='\033[0;33m'
export WHITE='\033[1;37m'
export BLUE='\033[0;34m'
export CYAN='\033[0;36m'
export NC='\033[0m' # No Color

function printMod() {
  echo -e "[$BLUE$MODULE$NC] $1"
}

MODULE="DELUGE"
IP=$(wget -qO- ipv4.icanhazip.com)

apt-get -qq update  > /dev/null

printMod "Installing deluge daemon with web interface"
apt-get install -y -qq deluged deluge-web > /dev/null
printMod "deluged && deluge-web installed."

# config web to HTTPS on certain port
mkdir -p /root/.config/deluge/ssl/
cp delugeweb.conf /root/.config/deluge/web.conf
openssl req -x509 -nodes -days 365 \
  -newkey rsa:2048 \
  -subj "/CN=www.xxx.com/O=My Company Name LTD./C=US" \
  -keyout /root/.config/deluge/ssl/deluge.key \
  -out /root/.config/deluge/ssl/deluge.crt > /dev/null 2>&1
printMod "Deluge web interface RSA key generated at /root/.config/deluge/ssl/."
printMod "Deluge web SSL is enabled. Default password is \"deluge\""
printMod "https://$IP:8112/"

# allow that port through ufw
printMod "Deluge web interface RSA key generated at /root/.config/deluge/ssl/."
ufw allow 8112/tcp  > /dev/null 2>&1
printMod "Deluge web interface port 8112 allowed."
printMod "Deluge installation script completed."

deluged && deluge-web --fork > /dev/null 2>&1
printMod "deluged && deluge-web started."