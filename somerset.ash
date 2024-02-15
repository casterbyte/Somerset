#!/bin/ash

# banner
echo "Somerset: Offensive OpenWRT router for Windows Pivoting"
echo "Author: Caster, <caster@exploit.org>"


# install dependencies
echo -e "\n [+] Installing necessary tools"
opkg update
opkg install ss
opkg install kmod-tun
opkg install ip-full
opkg install openssh-server

# Disabling DNS and HTTP services
echo -e "\n [+] Disabling DNS and HTTP services"
/etc/init.d/dnsmasq stop
/etc/init.d/uhttpd stop

# Replacing dropbear by openssh-server (for SSH tunneling)
echo -e "\n [+] Replacing dropbear..."
uci set dropbear.@dropbear[0].Port=2222
uci commit dropbear
/etc/init.d/dropbear restart
/etc/init.d/dropbear stop
/etc/init.d/dropbear disable
echo -e "\n [+] Configuring sshd daemon for authentication & tunneling"
sed -i -e 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/g' /etc/ssh/sshd_config
sed -i -e 's/#PermitTunnel no/PermitTunnel yes/g' /etc/ssh/sshd_config
/etc/init.d/sshd enable
/etc/init.d/sshd start
/etc/init.d/sshd restart

# Interfaces processing, TAP bridging
echo -e "\n [+] Interfaces processing, TAP bridging"
ip tuntap add tap0 mode tap
ip link set tap0 promisc on
ip link set eth0 promisc on
ip link set br-lan promisc on
ip link set dev tap0 up
brctl addif br-lan tap0
echo -e "\n [*] Current bridge:"
brctl show

# Outro
echo -e "\n [*] The script has completed its work. Now initiate an SSH tunnel from the attacker's side"
