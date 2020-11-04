#!/bin/bash

# VPN Auto script by me 
# Ubuntu 18+

export RED='\033[0;31m'
export GREEN='\033[0;33m'
export WHITE='\033[1;37m'
export BLUE='\033[0;34m'
export CYAN='\033[0;36m'
export NC='\033[0m' # No Color
MODULE="VPN"
function printMod() {
  echo -e "[$WHITE$MODULE$NC] $1"
}

# https://www.digitalocean.com/community/tutorials/how-to-set-up-an-openvpn-server-on-ubuntu-18-04
if [ $USER != 'root' ]; then
	printMod "Sorry, you need to run this as root"
	exit
fi


if [ ! -e /dev/net/tun ]; then
	printMod "TUN/TAP is not available"
	exit
fi


if [ ! -e /etc/debian_version ]; then
	printMod "Looks like you aren't running this installer on a Debian-based system"
	exit
fi

printMod "Preloading settings"
read -p "** Client name: " -e -i client CLIENT
read -p "** Server name: " -e -i server SERVER
read -p "** Port: " -e -i 1194 PORT
read -p "** Alternate port [y/n]: " -e -i y ISALTPORT
if [ $ISALTPORT = 'y' ]; then
	read -p "** Alternate port : " -e -i 53 ALTPORT
fi


printMod "######################################################################"
printMod "Step 1 — Installing OpenVPN and EasyRSA"
printMod "######################################################################"
wget -q -O - https://swupdate.openvpn.net/repos/repo-public.gpg | apt-key add -
echo "deb http://build.openvpn.net/debian/openvpn/stable bionic main" > /etc/apt/sources.list.d/openvpn-aptrepo.list
printMod "Added OpenVPN repo"

apt-get update -qq > /dev/null
apt-get install -qq -y openvpn > /dev/null
printMod "Installed OpenVPN"

wget -q --no-check-certificate -O ~/easy-rsa.tar.gz https://github.com/OpenVPN/easy-rsa/releases/download/v3.0.6/EasyRSA-unix-v3.0.6.tgz
printMod "Downloaded EasyRSA"

tar xzf ~/easy-rsa.tar.gz -C ~/
mv EasyRSA-v3.0.6 easy-rsa

printMod "######################################################################"
printMod "Step 2 — Configuring the EasyRSA Variables and Building the CA"
printMod "######################################################################"
export EASYRSA="$(pwd)/easy-rsa"
export EASYRSA_PKI="$EASYRSA/pki"
export EASYRSA_EXEC="$EASYRSA/easyrsa"
export EASYRSA_DN="cn_only"
export EASYRSA_REQ_COUNTRY="SG"
export EASYRSA_REQ_PROVINCE="Singapore"
export EASYRSA_REQ_CITY="Singapore"
export EASYRSA_REQ_ORG="Custom CA"
export EASYRSA_REQ_EMAIL="custom_ca@myhost.com"
export EASYRSA_REQ_OU="Custom CA"
export EASYRSA_REQ_CN="VPSN"
export EASYRSA_KEY_SIZE=2048
export EASYRSA_ALGO=rsa
export EASYRSA_CA_EXPIRE=7500
export EASYRSA_CERT_EXPIRE=365
export EASYRSA_NS_SUPPORT="no"
export EASYRSA_NS_COMMENT="Custom CA"
export EASYRSA_EXT_DIR="$EASYRSA/x509-types"
export EASYRSA_SSL_CONF="$EASYRSA/openssl-easyrsa.cnf"
export EASYRSA_DIGEST="sha256"
export EASYRSA_BATCH="yes"
export IP=$(ifconfig | grep 'inet addr:' | grep -v inet6 | grep -vE '127\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | cut -d: -f2 | awk '{ print $1}' | head -1)
if [ "$IP" = "" ]; then
        export IP=$(wget -qO- ipv4.icanhazip.com)
fi
export NET_INTERFACE=`ip route | grep default | awk '{print $5}'`

printMod "Set environment variable for EasyRSA key generation"

cd $EASYRSA

$EASYRSA_EXEC init-pki
printMod "Init-ed PKI"

$EASYRSA_EXEC build-ca nopass
printMod "Built CA"

printMod "######################################################################"
printMod "Step 3 — Creating the Server Certificate, Key, and Encryption Files"
printMod "######################################################################"
$EASYRSA_EXEC gen-req server nopass
printMod "Generated server key and cert"

cp $EASYRSA_PKI/private/server.key /etc/openvpn/
printMod "Copied server key to OpenVPN config"

$EASYRSA_EXEC sign-req server $SERVER
printMod "Signed server key"

cp $EASYRSA_PKI/issued/$SERVER.crt /etc/openvpn/
printMod "Copied server cert to OpenVPN config"

cp $EASYRSA_PKI/ca.crt /etc/openvpn/
printMod "Copied CA cert to OpenVPN config"

$EASYRSA_EXEC gen-dh
printMod "Generated exchange key"

openvpn --genkey --secret $EASYRSA/ta.key
printMod "Generated key's HMAC"

cp $EASYRSA/ta.key /etc/openvpn/
cp $EASYRSA_PKI/dh.pem /etc/openvpn/
printMod "Copied key and HMAC to OpenVPN config"

printMod "######################################################################"
printMod "Step 4 — Generating a Client Certificate and Key Pair"
printMod "######################################################################"

mkdir -p ~/client-configs/keys
printMod "Created client config directory"

chmod -R 700 ~/client-configs
printMod "Set permission"

$EASYRSA_EXEC gen-req $CLIENT nopass
printMod "Generate client key"

cp $EASYRSA_PKI/private/$CLIENT.key ~/client-configs/keys/
printMod "Copied to client configs"

$EASYRSA_EXEC sign-req client $CLIENT
printMod "Signed client key"

cp $EASYRSA_PKI/issued/$CLIENT.crt ~/client-configs/keys/
printMod "Copied client cert to client config"

cp $EASYRSA/ta.key ~/client-configs/keys/
printMod "Copied server HMAC to client config"

cp /etc/openvpn/ca.crt ~/client-configs/keys/
printMod "Copied CA to client config"

printMod "######################################################################"
printMod "Step 5 — Configuring the OpenVPN Service"
printMod "######################################################################"

cat << EOF > /etc/openvpn/server.conf
port $PORT
proto udp
dev tun
ca ca.crt
cert $SERVER.crt
key $SERVER.key
dh dh.pem
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist /var/log/openvpn/ipp.txt
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"
keepalive 10 120
tls-auth ta.key 0
key-direction 0
cipher AES-256-CBC
auth SHA256
user nobody
group nogroup
persist-key
persist-tun
status /var/log/openvpn/openvpn-status.log
verb 3
explicit-exit-notify 1
EOF
printMod "Created server.conf file"
# cp /usr/share/doc/openvpn/examples/sample-config-files/server.conf.gz /etc/openvpn/
# printMod "Copied sample OpenVPN config to actual config directory"
# gzip -q -d /etc/openvpn/server.conf.gz
# printMod "Unzipped it"
# sed -Ei "s/^;?cipher.+/cipher AES-256-CBC/" /etc/openvpn/server.conf
# sed -i "/cipher AES-256-CBC/a\auth SHA256" /etc/openvpn/server.conf
# sed -Ei "s/^dh dh2048.pem$/dh dh.pem/" /etc/openvpn/server.conf
# sed -Ei "s/^;(user|group)\s(nobody|nogroup)$/\1 \2/" /etc/openvpn/server.conf
# sed -i 's|;push "redirect-gateway def1 bypass-dhcp"|push "redirect-gateway def1 bypass-dhcp"|' /etc/openvpn/server.conf
# sed -i 's|;push "dhcp-option DNS 208.67.222.222"|push "dhcp-option DNS 8.8.8.8"|' /etc/openvpn/server.conf
# sed -i 's|;push "dhcp-option DNS 208.67.220.220"|push "dhcp-option DNS 8.8.4.4"|' /etc/openvpn/server.conf
# sed -Ei "s/^(cert|key) \w+\.(crt|key)$/\1 $SERVER\.\2/" /etc/openvpn/server.conf
# printMod "Edited server.conf file"

printMod "######################################################################"
printMod "Step 6 — Adjusting the Server Networking Configuration"
printMod "######################################################################"

sed -i 's|#net.ipv4.ip_forward=1|net.ipv4.ip_forward=1|' /etc/sysctl.conf
echo 1 > /proc/sys/net/ipv4/ip_forward
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -j SNAT --to $IP
echo "#!/bin/bash" > /etc/rc.local
if [ $ISALTPORT = 'y' ]; then
  iptables -t nat -A PREROUTING -p udp -d $IP --dport $ALTPORT -j REDIRECT --to-port $PORT
  echo "iptables -t nat -A PREROUTING -p udp -d $IP --dport $ALTPORT -j REDIRECT --to-port $PORT" >> /etc/rc.local
fi
echo "iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -j SNAT --to $IP" >> /etc/rc.local
chmod 755 /etc/rc.local
/etc/init.d/openvpn restart

printMod "######################################################################"
printMod "Step 7 — Starting and Enabling the OpenVPN Service"
printMod "######################################################################"

systemctl start openvpn@$SERVER
printMod "Started OpenVPN@$SERVER service"

systemctl enable openvpn@$SERVER
printMod "Enabled OpenVPN@$SERVER service at startup"

printMod "######################################################################"
printMod "Step 8 — Creating the Client Configuration Infrastructure"
printMod "######################################################################"
export KEY_DIR=~/client-configs/keys
export OUTPUT_DIR=~/client-configs/files
export BASE_CONFIG=~/client-configs/base.conf

mkdir -p ~/client-configs/files
cat << EOF > $BASE_CONFIG
client
dev tun
proto udp
remote $IP $PORT
resolv-retry infinite
nobind
user nobody
group nogroup
persist-key
persist-tun
remote-cert-tls server
key-direction 1
cipher AES-256-CBC
auth SHA256
verb 3
EOF

printMod "Created base configs"
# cp /usr/share/doc/openvpn/examples/sample-config-files/client.conf ~/client-configs/base.conf
# sed -Ei "s/^(remote ).+( [0-9]{4})$/\1$IP\2/" ~/client-configs/base.conf
# sed -Ei "s/^;(user|group)\s(nobody|nogroup)$/\1 \2/" ~/client-configs/base.conf
# sed -Ei "s/^(ca|cert|key|tls-auth)(.+)/# \1\2/" ~/client-configs/base.conf
# sed -Ei "s/^;?cipher.+/cipher AES-256-CBC/" ~/client-configs/base.conf
# sed -i "/cipher AES-256-CBC/a\auth SHA256" ~/client-configs/base.conf
# sed -i "/tls-auth ta.key/a\key-direction 1" ~/client-configs/base.conf
# printMod "Updated base.conf"

cat ${BASE_CONFIG} \
    <(echo -e '<ca>') \
    ${KEY_DIR}/ca.crt \
    <(echo -e '</ca>\n<cert>') \
    ${KEY_DIR}/${CLIENT}.crt \
    <(echo -e '</cert>\n<key>') \
    ${KEY_DIR}/${CLIENT}.key \
    <(echo -e '</key>\n<tls-auth>') \
    ${KEY_DIR}/ta.key \
    <(echo -e '</tls-auth>') \
    > ${OUTPUT_DIR}/${CLIENT}.ovpn

printMod "Created $CLIENT.ovpn"
printMod "DONE!"

cd -