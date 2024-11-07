#!/bin/bash
# Check version number
latestversion=$(curl https://raw.githubusercontent.com/jeromesegura/VPNrotator/master/version.info)
# Download latest core files
declare -a CoreFiles=("VPN.sh" "countries.txt" "dn.sh" "up.sh" "vpnservice.sh" )
for val in ${CoreFiles[@]}; do
   curl https://raw.githubusercontent.com/jeromesegura/VPNrotator/master/$val --output $val
done
echo $latestversion > version.info
echo "Updated VPN Rotator to version: $latestversion"
echo "Please run VPN.sh to restart the VPN"
