#!/bin/bash
#ramsal

# Global variables

# ANSI colors
c_black='\u001b[30m'
c_red='\u001b[31m'
c_green='\u001b[32m'
c_yellow='\u001b[33m'
c_blue='\u001b[34m'
c_magenta='\u001b[35m'
c_cyan='\u001b[36m'
c_white='\u001b[37m'
c_no='\u001b[0m'

# config
CFG_SSID="tor"
CFG_PWD=""
CFG_GW_IP="192.168.42.1"
CFG_GW_MASK="255.255.255.0"
CFG_GW_PREFIX="24"
CFG_GW_NETWORK="192.168.42.0"
CFG_GW_BROADCAST="192.168.42.255"
CFG_DHCP_START="100"
CFG_DHCP_END="200"

# config files
CFG_INTERFACES="/etc/network/interfaces"
CFG_DNSMASQ_CONF="/etc/dnsmasq.conf"
CFG_DHCPCD_CONF="/etc/dhcpcd.conf"
CFG_HOSTAPD_CONF="/etc/hostapd/hostapd.conf"
CFG_HOSTAPD="/etc/default/hostapd"
CFG_SYSCTL_CONF="/etc/sysctl.conf"
CFG_TORRC="/etc/tor/torrc"
CFG_RC_LOCAL="/etc/rc.local"

# config templates
INTERFACES_CONFIG='###THSStart\
auto lo\
iface lo inet loopback\
\
auto eth0\
iface eth0 inet dhcp\
\
allow-hotplug wlan0\
iface wlan0 inet static\
    address IP_ADDR\
    netmask MASK\
    network NETWORK\
    broadcast BROADCAST\
###THSEnd'

DNSMASQ_CONFIG='###THSStart\
interface=wlan0\
    listen-address=IP_ADDR\
    bind-interfaces\
    domain-needed\
    bogus-priv\
    dhcp-range=IP_START,IP_END,24h\
###THSEnd'

DHCPCONF_CONFIG='###THSStart\
denyinterfaces wlan0\
###THSEnd'

HOSTAPDCONF_CONFIG='###THSStart\
interface=wlan0\
driver=nl80211\
ssid=SSID\
hw_mode=g\
channel=7\
wmm_enabled=0\
macaddr_acl=0\
auth_algs=1\
ignore_broadcast_ssid=0\
wpa=2\
wpa_passphrase=PWD\
wpa_key_mgmt=WPA-PSK\
wpa_pairwise=TKIP\
rsn_pairwise=CCMP\
###THSEnd'

HOSTAPD_CONFIG='###THSStart\
DAEMON_CONF="\/etc\/hostapd\/hostapd.conf"\
###THSEnd'

SYSCTL_CONFIG='###THSStart\
net.ipv4.ip_forward=1\
###THSEnd'

TORRC_CONFIG='###THSStart\
Log notice file \/var\/log\/tor\/notices.log\
VirtualAddrNetwork 10.192.0.0\/10\
AutomapHostsSuffixes .onion,.exit\
AutomapHostsOnResolve 1\
TransPort 9040\
TransListenAddress IP_ADDR\
DNSPort 53\
DNSListenAddress IP_ADDR\
###THSEnd'

RCLOCAL_CONFIG='iptables-restore < \/etc\/iptables.ipv4.nat'


# Global functions

msg() {
echo -e "$1"
}

msgInfo() {
echo -e "${c_magenta}$1${c_no}"
}

msgComment() {
echo -e "${c_cyan}$1${c_no}"
}

msgSuccess() {
echo -e "${c_green}$1${c_no}"
}

msgWarning() {
echo -e "${c_yellow}$1${c_no}"
}

msgError() {
echo -e "${c_red}$1${c_no}"
}

readDefault() {
read -p "$(echo -e $1 [${c_green}${!2}${c_no}]: )" INPUT
eval $2="${INPUT:-${!2}}"
}

readPassword() {
IS_PWD_CORRECT=0
while [ $IS_PWD_CORRECT != 1 ]
do
    read -s -p "$1: " IN_PWD1
    echo
    read -s -p "Retype password: " IN_PWD2
    echo
    if [ "$IN_PWD1" != "$IN_PWD2" ]; then
        msgError "Passwords are not equal!!!"
    elif [ -z $IN_PWD1 ]; then
        msgError "Password must not be empty!!!"
    elif [ ${#IN_PWD1} -le 7 ]; then
        msgError "Password must be at least 8 characters!!!"
    else
        IS_PWD_CORRECT=1
    fi
done
eval $2=$IN_PWD1
}

getNetworkInfo() {
declare -n ret=$2
firstByte=$(echo $1 | sed -r 's/\..*//')
ret[MASK]="255.255.255.0"
ret[PREFIX]="24"
ret[NETWORK]=$(echo $1 | sed -r "s/[0-9]+$/0/")
ret[BROADCAST]=$(echo $1 | sed -r "s/[0-9]+$/255/")
case $firstByte in
  192)
  ret[MASK]="255.255.255.0"
  ret[PREFIX]="24"
  ret[NETWORK]=$(echo $1 | sed -r "s/[0-9]+$/0/")
  ret[BROADCAST]=$(echo $1 | sed -r "s/[0-9]+$/255/")
  ;;
  172)
  ret[MASK]="255.255.0.0"
  ret[PREFIX]="16"
  ret[NETWORK]=$(echo $1 | sed -r "s/[0-9]+\.[0-9]+$/0.0/")
  ret[BROADCAST]=$(echo $1 | sed -r "s/[0-9]+\.[0-9]+$/255.255/")
  ;;
  10)
  ret[MASK]="255.0.0.0"
  ret[PREFIX]="8"
  ret[NETWORK]=$(echo $1 | sed -r "s/[0-9]+\.[0-9]+\.[0-9]+$/0.0.0/")
  ret[BROADCAST]=$(echo $1 | sed -r "s/[0-9]+\.[0-9]+\.[0-9]+$/255.255.255/")
  ;;
esac
}

# Main code

msgInfo "TorPi Hotspot Installer - https://torpi.me"

msgComment "First, let's collect some information about how you want to configure your TorPi..."
readDefault "Choose TorPi WiFi SSID" CFG_SSID
readPassword "Choose TorPi WiFi password" CFG_PWD
readDefault "Choose TorPi IP address for default gateway and SSH admin" CFG_GW_IP
declare -A NETWORK_INFO
getNetworkInfo $CFG_GW_IP NETWORK_INFO
CFG_GW_MASK=${NETWORK_INFO[MASK]}
CFG_GW_PREFIX=${NETWORK_INFO[PREFIX]}
CFG_GW_NETWORK=${NETWORK_INFO[NETWORK]}
CFG_GW_BROADCAST=${NETWORK_INFO[BROADCAST]}
msgError "MASK: $CFG_GW_MASK PREFIX: $CFG_GW_PREFIX NETWORK: $CFG_GW_NETWORK BROADCAST: $CFG_GW_BROADCAST"

CFG_DHCP_START=$(echo $CFG_GW_IP | sed -r "s/[^.+]$/$CFG_DHCP_START/")
CFG_DHCP_END=$(echo $CFG_GW_IP | sed -r "s/[^.+]$/$CFG_DHCP_END/")

readDefault "TorPi DHCP start address " CFG_DHCP_START
readDefault "TorPi DHCP end address " CFG_DHCP_END
msgSuccess "That's all the info we need! Commencing installation..."

msgComment "Updating system repo and installing TorPi packages..."
sudo apt-get update
sudo apt-get -y upgrade
msgComment "Installing required packages"
sudo apt-get -y install hostapd dnsmasq tor unattended-upgrades
msgSuccess "Required packages installed!"

msgComment "Configuring TorPi..."

msgComment "Stopping services"
sudo systemctl stop dnsmasq
sudo systemctl stop hostapd
sudo systemctl stop tor

TIMESTAMP=$(date +".%Y%m%d%H%M%S.bak")

msgComment "Configuring interfaces"
INTERFACES_CONFIG=$(echo "$INTERFACES_CONFIG" | sed "s/IP_ADDR/$CFG_GW_IP/;s/MASK/$CFG_GW_MASK/;s/NETWORK/$CFG_GW_NETWORK/;s/BROADCAST/$CFG_GW_BROADCAST/")
sudo sed -i$TIMESTAMP "/###THSStart/,/###THSEnd/{h;/###THSEnd/s/.*/$INTERFACES_CONFIG/;t;d;};$ {x;/^$/{s//$INTERFACES_CONFIG/;H};x}" $CFG_INTERFACES

msgComment "Configuring dnsmasq.conf"
DNSMASQ_CONFIG=$(echo "$DNSMASQ_CONFIG" | sed "s/IP_ADDR/$CFG_GW_IP/;s/IP_START/$CFG_DHCP_START/;s/IP_END/$CFG_DHCP_END/")
sudo sed -i$TIMESTAMP "/###THSStart/,/###THSEnd/{h;/###THSEnd/s/.*/$DNSMASQ_CONFIG/;t;d;};$ {x;/^$/{s//$DNSMASQ_CONFIG/;H};x}" $CFG_DNSMASQ_CONF

msgComment "Configuring dhcpcd.conf"
DHCPCONF_CONFIG=$(echo "$DHCPCONF_CONFIG" | sed "s/IP_ADDR/$CFG_GW_IP/;s/PREFIX/$CFG_GW_PREFIX/")
sudo sed -i$TIMESTAMP "/###THSStart/,/###THSEnd/{h;/###THSEnd/s/.*/$DHCPCONF_CONFIG/;t;d;};$ {x;/^$/{s//$DHCPCONF_CONFIG/;H};x}" $CFG_DHCPCD_CONF

msgComment "Configuring hostapd.conf"
sudo echo "" > $CFG_HOSTAPD_CONF
HOSTAPDCONF_CONFIG=$(echo "$HOSTAPDCONF_CONFIG" | sed "s/SSID/$CFG_SSID/;s/PWD/$CFG_PWD/")
sudo sed -i$TIMESTAMP "/###THSStart/,/###THSEnd/{h;/###THSEnd/s/.*/$HOSTAPDCONF_CONFIG/;t;d;};$ {x;/^$/{s//$HOSTAPDCONF_CONFIG/;H};x}" $CFG_HOSTAPD_CONF

msgComment "Configuring hostapd"
sudo sed -i$TIMESTAMP "/###THSStart/,/###THSEnd/{h;/###THSEnd/s/.*/$HOSTAPD_CONFIG/;t;d;};$ {x;/^$/{s//$HOSTAPD_CONFIG/;H};x}" $CFG_HOSTAPD

msgComment "Configuring sysctl.conf"
sudo sed -i$TIMESTAMP "/###THSStart/,/###THSEnd/{h;/###THSEnd/s/.*/$SYSCTL_CONFIG/;t;d;};$ {x;/^$/{s//$SYSCTL_CONFIG/;H};x}" $CFG_SYSCTL_CONF

msgComment "Configuring torrc"
TORRC_CONFIG=$(echo "$TORRC_CONFIG" | sed "s/IP_ADDR/$CFG_GW_IP/")
sudo sed -i$TIMESTAMP "/###THSStart/,/###THSEnd/{h;/###THSEnd/s/.*/$TORRC_CONFIG/;t;d;};$ {x;/^$/{s//$TORRC_CONFIG/;H};x}" $CFG_TORRC

msgComment "Configuring iptables: Enable forwarding"
sudo sudo sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward"

msgComment "Configuring iptables: Flushing rules"
sudo iptables -F && sudo iptables -t nat -F
msgComment "Configuring iptables: Setting up NAT"
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE  
sudo iptables -A FORWARD -i eth0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -i wlan0 -o eth0 -j ACCEPT
msgComment "Configuring iptables: Dropping SSH at eth0"
sudo iptables -A INPUT -i eth0 -p tcp --dport 22 -j DROP
msgComment "Configuring iptables: Opening SSH on wlan0"
sudo iptables -t nat -A PREROUTING -i wlan0 -p tcp --dport 22 -j REDIRECT --to-ports 22
msgComment "Configuring iptables: Opening tor ports on wlan0"
sudo iptables -t nat -A PREROUTING -i wlan0 -p udp --dport 53 -j REDIRECT --to-ports 53
sudo iptables -t nat -A PREROUTING -i wlan0 -p tcp --syn -j REDIRECT --to-ports 9040
msgComment "Configuring iptables: Saving iptables"
sudo sh -c "iptables-save > /etc/iptables.ipv4.nat"

msgComment "Configuring rc.local"
sudo grep -q "$RCLOCAL_CONFIG" $CFG_RC_LOCAL || sed -i$TIMESTAMP "/^exit 0/i $RCLOCAL_CONFIG" $CFG_RC_LOCAL

msgComment "Starting wlan0"
sudo ifup wlan0

msgComment "Starting services"
sudo systemctl start hostapd
sudo systemctl start dnsmasq
sudo systemctl start tor

msgSuccess "Done! The system will now reboot."
sudo reboot now
