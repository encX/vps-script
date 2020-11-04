#!/bin/bash

# for Ubuntu server 16+

export RED='\033[0;31m'
export GREEN='\033[0;33m'
export WHITE='\033[1;37m'
export BLUE='\033[0;34m'
export CYAN='\033[0;36m'
export NC='\033[0m' # No Color

function printMod() {
  echo -e "[$GREEN$MODULE$NC] $1"
}

MODULE="NODEJS"

if [[ `command -v nvm` == "" ]]; then
  printMod "nvm is not installed."
  printMod "installing nvm ..."
  curl -o- https://raw.githubusercontent.com/creationix/nvm/master/install.sh | bash > /dev/null
else
  printMod "nvm is already installed."
fi
. ~/.nvm/nvm.sh
. ~/.bashrc
cat .bashrc | grep NVM >> ~/.zshrc
printMod "Reloaded rc file"
nvm install stable > /dev/null 2>&1
printMod "Installed latest stable nodejs runtime."
nvm use stable