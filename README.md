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

- Download Debian ISO
- Choose Install

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

## 4) Configure network settings

### `/etc/network/interfaces`

**Note: to go for an easy configuration, you can simply set your first network interface to dhcp (instead of static).**

**Edit with the name of your ethernet cards and IP range**
(type `ip link show` to reveal the name of your ethernet cards)

        # The loopback network interface
        auto lo
        iface lo inet loopback

        # The bridged network interface
        allow-hotplug enp0s1
        iface enp0s1 inet static
        address 192.168.1.168
        netmask 255.255.255.0
        gateway 192.168.1.1
        network 192.168.1.0
        broadcast 192.168.1.255
        dns-nameservers 1.1.1.1 1.0.0.1

        # the internal-only network interface
        allow-hotplug enp0s2
        iface enp0s2 inet static
        address 192.168.2.1
        netmask 255.255.255.0
        network 192.168.2.0
        broadcast 192.168.2.255
        dns-nameservers 1.1.1.1 1.0.0.1

### `/etc/resolv.conf`

Add `nameserver 192.168.1.1` (or whatever your local gateway is)

### `/etc/sysctl.conf`

Uncomment `net.ipv4.ip_forward=1`

Uncomment (if you want to enable IPv6) `net.ipv6.conf.all.forwarding=1`

Add the following at the end of the file if you want to disable IPV6

        # These edits EXPLICITLY disable IPV6
        net.ipv6.conf.all.disable_ipv6 = 1
        net.ipv6.conf.default.disable_ipv6 = 1
        net.ipv6.conf.lo.disable_ipv6 = 1
        net.ipv6.conf.eth0.disable_ipv6 = 1

## 5) Reboot VM

`/sbin/reboot`

## 6) Quick install

ssh into the VPNrotator VM/machine (replace with your own IP address)

``ssh vpn@192.168.1.168``

Download update script and rename it as install.sh

``curl - o install.sh https://raw.githubusercontent.com/jeromesegura/VPNrotator/refs/heads/master/update.sh``

Make script executable

``chmod +x install.sh``

Run script

``./install.sh``

Make all scripts executable

``chmod +x *.sh``

Become admin

``su``

Run main script

``./VPN.sh``

## 7) First time use

On first setup, you will need to create profiles to add new VPN providers. This requires the URL to a ZIP for .ovpn files and your username and password for that VPN provider. The script will then download and sort all the .ovpn files automatically into folders by country and provider.

The naming convention for the ovpn files is: ``[2 letter country code].[State/City(optional)].[protocol](optional).ovpn``

Example: ``US.ILLINOIS.tcp.ovpn``

![alt text](https://github.com/malwareinfosec/vpnrotator/blob/master/img/rotator.gif)
