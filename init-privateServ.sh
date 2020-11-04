#!/bin/bash

# for Ubuntu server 16+

export RED='\033[0;31m'
export GREEN='\033[0;33m'
export WHITE='\033[1;37m'
export BLUE='\033[0;34m'
export CYAN='\033[0;36m'
export NC='\033[0m' # No Color

function printMod() {
  echo -e "[$WHITE$MODULE$NC] $1"
}

MODULE="init"

if [ $USER != 'root' ]; then
	echo "Sorry, you need to run this as root"
	exit
fi

echo "Plai's server initialization script. !
Start !

"

# Setting locale
printMod "Setting locale"
export LANGUAGE=en_US.UTF-8
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
locale-gen en_US.UTF-8 > /dev/null
dpkg-reconfigure locales

printMod "Updating repo."
apt-get -qq update > /dev/null
printMod "Completed."
printMod "Upgrading packages."
apt-get -qq upgrade -y > /dev/null
printMod "Completed."
echo 1 > ./appupdated.flag

printMod "Install zsh and oh my zsh. You have to exit the zsh to continue installation."

# Install ZSH and Ih My ZSH
apt-get install zsh -y -qq > /dev/null 2>&1

# Install Oh My ZSH
sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
printMod "Changed zsh theme."
sed -i "s/robbyrussell/agnoster/" ~/.zshrc

# change SSH Port to Another
printMod "Change SSH Port."
read -p "Set SSH port : " -e -i 22 SSHPORT

if [[ "$SSHPORT" == "22" ]]; then
  printMod "SSH port unchanged."
else
  sed -i "s/^#\?Port [0-9]\+$/Port $SSHPORT/" /etc/ssh/sshd_config
  printMod "SSH change $OLDPORT to Port $SSHPORT."
  service ssh restart
fi

# Install DigitalOcean monitoring agent
# curl -sSL https://insights.nyc3.cdn.digitaloceanspaces.com/install.sh | sudo bash

# Setup Deluge
printMod "Opening deluge installation script."
./app-deluge.sh

# disable ping
printMod "Opening network security script."
./secure-network.sh

# install nvm (node version manager)
printMod "Opening node installation script."
./app-node.sh

# install Docker
printMod "Opening Docker installation script."
./app-docker.sh

# Setup OVPN
./vpn-new.sh

service procps start

printMod "Remove unnecessary packages."
apt-get autoremove -y -qq > /dev/null 2>&1

printMod "Remove welcome message."
rm -f \
  /etc/update-motd.d/00* \
  /etc/update-motd.d/10* \
  /etc/update-motd.d/51* \
  /etc/update-motd.d/90*

printMod "All script done."