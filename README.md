## VPN ROTATOR ##

This project is intended for security researchers and offers the following benefits:

- Add multiple machines (virtual and/or physical) behind the same VPN(s)
- Prevent exposing your private IP address in case of VPN disconnection/failure
- Combine multiple VPN providers without having to install their proprietary software
- Easily rotate VPN locations for malicious traffic replays

The VPN rotator is a VM (or physical machine) that sends and receives all the traffic going through your network. In other words, the devices that are behind it are isolated from the Internet. This provides a safe environment not exposing your (residential) ISP connection.

This project found its name (VPN Rotator) in the act of rotating or cycling through VPN locations to reproduce malware traffic. As such, it is easy to rotate within countries for the same or multiple VPN providers. This allows you to add accounts for several different providers and seamlessly rotate within access points, without having to use their proprietary software.

## Virtual rotator

![alt text](https://github.com/malwareinfosec/vpnrotator/blob/master/img/rotator_diagram.png)

## Physical rotator

![alt text](https://github.com/malwareinfosec/vpnrotator/blob/master/img/pi.png)

## Requirements

- Virtual or bare metal machine (can be done on a Raspberry Pi w/ 2 ethernet ports running Raspbian OS)
- One or more commercial VPN accounts

## 1) Create new VM

- Type: Linux
- Version: Debian (64-bit)
- Memory size: 512 MB (or more)
- Hard disk: VDI, Dynamic, 8 GB

- Before starting the VM, change its Network Settings:
-> Adapter 1: Bridged Adapter (Promiscuous Mode: Deny)
-> Adapter 2: Internal Network (Promiscuous Mode: Allow VMs)

## 2) Install Debian with the following options

- Download Debian ISO (debian-10.1.0-amd64-xfce-CD-1.iso)
- Choose Install (second option)

- Primary network interface
-> Chose the first one

- Hostname: vpn
- Domain: Leave blank

- User name and passwords: (your choice)

- Software to install:
-> uncheck everything and check:
SSH server
Standard System utilities

## 3) Get updates

- Get root (type su and enter)

`apt-get update`

`apt-get install psmisc unzip openvpn curl dos2unix iptables-persistent`

## 4) Configure /etc/network/interfaces

`nano /etc/network/interfaces`

**Note: to go for an easy configuration, you can simply set your first network interface to dhcp (instead of static).**

**Edit with the name of your ethernet cards and IP range**
(type `ip link show` to reveal the name of your ethernet cards)

        # The loopback network interface
        auto lo
        iface lo inet loopback

        # The bridged network interface
        allow-hotplug enp0s3
        iface enp0s3 inet static
        address 192.168.1.168
        netmask 255.255.255.0
        gateway 192.168.1.1
        network 192.168.1.0
        broadcast 192.168.1.255
        dns-nameservers 1.1.1.1 1.0.0.1

        # the internal-only network interface
        allow-hotplug enp0s8
        iface enp0s8 inet static
        address 192.168.3.1
        netmask 255.255.255.0
        network 192.168.3.0
        broadcast 192.168.3.255
        dns-nameservers 1.1.1.1 1.0.0.1


## 5) Configure additional network settings

`nano /etc/resolv.conf`

Add `nameserver 192.168.0.1` (or whatever your local gateway is)

`nano /etc/sysctl.conf`

Uncomment `net.ipv4.ip_forward=1`

Uncomment (if you want to enable IPv6) `net.ipv6.conf.all.forwarding=1`

Add the following at the end of the file if you want to disable IPV6

        # These edits EXPLICITLY disable IPV6
        net.ipv6.conf.all.disable_ipv6 = 1
        net.ipv6.conf.default.disable_ipv6 = 1
        net.ipv6.conf.lo.disable_ipv6 = 1
        net.ipv6.conf.eth0.disable_ipv6 = 1

## 6) Copy necessary files

(individually or simply ZIP them and then SCP)

        scp countries.txt vpn@192.168.1.168:/home/vpn/
        scp dn.sh vpn@192.168.1.168:/home/vpn/
        scp up.sh vpn@192.168.1.168:/home/vpn/
        scp VPN.sh vpn@192.168.1.168:/home/vpn/
        scp vpnservice.sh vpn@192.168.1.168:/home/vpn/

Make scripts executable

`chmod +x *.sh`

## 7) Reboot VM

`/sbin/reboot`

## 8) Launch VPN rotator

Login as root then, run `./VPN.sh`

On first setup, you will need to create profiles to add new VPN providers. This requires the URL to a ZIP for .ovpn files and your username and password for that VPN provider. The script will then download and sort all the .ovpn files automatically into folders by country and provider.

# OVPN files configuration

The naming convention for the ovpn files is: ``[2 letter country code].[State/City(optional)].[protocol](optional).ovpn``

Example: ``US.ILLINOIS.tcp.ovpn``

You may wish to use one of the existing VPN provider configurations located [here](https://github.com/jeromesegura/VPNrotator/tree/master/configs) (please note you will need to purchase a subscription from the respective providers).

![alt text](https://github.com/malwareinfosec/vpnrotator/blob/master/img/rotator.gif)
