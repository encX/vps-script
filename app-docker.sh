export RED='\033[0;31m'
export GREEN='\033[0;33m'
export WHITE='\033[1;37m'
export BLUE='\033[0;34m'
export CYAN='\033[0;36m'
export NC='\033[0m' # No Color

function printMod() {
  echo -e "[$CYAN$MODULE$NC] $1"
}

MODULE="DOCKER"

apt-get -qq update > /dev/null;

printMod "Install some dependencies."
apt-get -qq install \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common \
    > /dev/null;

printMod "Add Docker's GPG key."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

printMod "Add Docker's repo."
add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"

printMod "Updating repo."
apt-get -qq update > /dev/null;
apt-get -qq -y install docker-ce docker-compose > /dev/null;
printMod "Done."