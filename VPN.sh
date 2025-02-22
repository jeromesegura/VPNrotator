#!/bin/bash

killservice () {
    for pid in $(ps aux | grep vpnservice.sh | grep -v grep | awk -F ' ' '{print $2}');do kill -9 $pid; wait $pid 2>/dev/null;done
}

refresh () {
    killOVPN
    echo "" > $vpn_path/refresh.log
    touch $vpn_path/refresh
    while [ -f $vpn_path/refresh ];do
        clear
        logo
        echo ""
        echo "Refreshing VPN config files, please wait..."
        cat $vpn_path/refresh.log
        sleep 1
    done
    clear
    logo
    cat $vpn_path/refresh.log
    sleep 2
    rm $vpn_path/refresh.log
}

stopVPN () {
    touch $vpn_path/stop
}

killOVPN () {
    echo "Killing OVPN..."
    for i in {1..4}; do killall openvpn;done
    if [ -f currentvpn.txt ];then rm currentvpn.txt;fi
}

logo () {
    echo "#####################################"
    echo "######## VPN ROTATOR v.$version_number  #########"
    echo "#####################################"
    echo "Current system time: $(date +%H:%M)"
    if [ -f $vpn_path/drop.txt ];then
        echo "VPN gateway range: $(cat $vpn_path/drop.txt)"
    else
        echo "IPTABLES is not configured properly!!!"
    fi
    echo "#####################################"
}

menu () {
    echo ""
    if [ -f $vpn_path/currentvpn.txt ];then
        echo "Currently connected to: $(cat currentvpn.txt | sed 's/Country_//g' | sed 's/.ovpn//gi')"
        echo "Connection established on $(cat date.log)"
    else
        echo "** Not currently connected to the VPN **"
    fi
    echo ""
    echo "1) Check VPN connection status"
    echo "2) Start VPN from favorite"
    echo "3) Start VPN in new country"
    echo "4) Start VPN in new state/city"
    echo "5) Start VPN with new provider"
    echo "6) Rotate VPN"
    echo "7) Refresh VPN .ovpn files"
    echo "8) VPN profiles management"
    echo "9) Stop VPN (no internet connection)"
    echo "10) Update VPN Rotator"
    echo "11) Quit VPN Rotator"
    echo ""
    echo -n "Enter your choice and press [ENTER]: "
}

vpnprofilemanagement () {
    clear
    logo
    echo ""
    if [ -f $vpn_path/currentvpn.txt ];then
        echo "Currently connected to: $(cat currentvpn.txt)"
    else
        echo "** Not currently connected to the VPN **"
    fi
    echo ""
    echo "1) Create a new VPN profile"
    echo "2) Edit existing VPN profile(s)"
    echo "3) Delete existing VPN profile(s)"
    echo "4) Create/edit favorites"
    echo "0) Back to main menu"
    echo ""
    echo ""
    echo -n "Enter your choice and press [ENTER]: "
    read choice
    if [ $choice -eq 1 ];then setup_profiles;fi
    if [ $choice -eq 2 ];then edit_profiles;fi
    if [ $choice -eq 3 ];then delete_profiles;fi
    if [ $choice -eq 4 ];then edit_favorites;fi
    if [ $choice -eq 0 ];then
        clear
        logo
        menu
    fi
}

countryselection () {
    clear
    logo
    echo ""
    echo "List of available countries (and nb of servers):"
    echo ""
    array_index=0
    number=1
    if [ -f $vpn_path/tempmenu.txt ];then rm $vpn_path/tempmenu.txt;fi
    for i in $(ls -d $vpn_path/ovpn_files/Country_*);do
        nbovpn=$(ls $i/*.ovpn 2>/dev/null | wc -l)
        if [ $nbovpn -gt 0 ];then
            echo "$number) $i ($nbovpn)" | sed 's@'"$vpn_path"'\/ovpn_files\/Country_@@g' >> $vpn_path/tempmenu.txt
            providers[$array_index]=$(echo $i | sed 's@'"$vpn_path"'\/ovpn_files\/@@g')
            number=$(($number + 1))
            array_index=$(($array_index + 1))
        fi
    done
    if [ -f $vpn_path/tempmenu.txt ];then
        pr -3 -t $vpn_path/tempmenu.txt
    else
        echo "######################################"
        echo "Could not read ovpn configuration files!"
        echo "Format: [2 letter country code].[State/City(optional)].[protocol](optional).ovpn"
        echo "Example: US.ILLINOIS.tcp.ovpn"
        echo "######################################"
    fi
    echo "0) Back to main menu"
    echo ""
    echo -n "Enter your choice and press [ENTER]: "
    read countrynumber
    re='^[0-9]+$'
    if ! [[ $countrynumber =~ $re ]] ; then
        echo "error: Not a number" >&2; countryselection
    fi
    if (( countrynumber >= 1 && countrynumber < number ));then
        # Selected country
        providersindex=$(($countrynumber -1))
        provider=${providers[$providersindex]}
        countryname=$(echo $provider | sed 's/Country_//g')
        # Check that the folder is not empty
        if [ $(ls $vpn_path/ovpn_files/$provider | wc -l) -eq 0 ];then
            clear
            echo "No VPN profiles in this folder!"
            sleep 2
            countrynumber=0
        else
            while [ -f $vpn_path/custom ];do
                clear
                echo "VPN currently busy, please wait..."
                sleep 2
            done
            echo $provider > $vpn_path/providers.txt
            touch $vpn_path/custom
            if [ -f $vpn_path/stop ];then rm $vpn_path/stop;fi
        fi
    elif (( countrynumber == 0 ));then
        echo "Returning to main menu..."
    else
        countryselection
    fi
}

countrylocationselection () {
    clear
    logo
    echo ""
    echo "Pick a country:"
    echo ""
    array_index=0
    number=1
    if [ -f $vpn_path/tempmenu.txt ];then rm $vpn_path/tempmenu.txt;fi
        for i in $(ls -d $vpn_path/ovpn_files/Country_*);do
            # Only count ovpn profiles that do not contain 2 digits or more
            nbovpn=$(ls $i/*.ovpn 2>/dev/null | wc -l)
            if [ $nbovpn -gt 0 ];then
                echo "$number) $i" | sed 's@'"$vpn_path"'\/ovpn_files\/Country_@@g' | sed 's/.ovpn//gi' >> $vpn_path/tempmenu.txt
                providers[$array_index]=$(echo $i | sed 's@'"$vpn_path"'\/ovpn_files\/@@g')
                number=$(($number + 1))
                array_index=$(($array_index + 1))
            fi
        done
        if [ -f $vpn_path/tempmenu.txt ];then
            pr -3 -t $vpn_path/tempmenu.txt
        else
            echo "######################################"
            echo "Could not read ovpn configuration files!"
            echo "Format: [2 letter country code].[State/City(optional)].[protocol](optional).ovpn"
            echo "Example: US.ILLINOIS.tcp.ovpn"
            echo "######################################"
        fi
        echo "0) Back to main menu"
        echo ""
        echo -n "Enter your choice and press [ENTER]: "
        read countrynumber
        re='^[0-9]+$'
        if ! [[ $countrynumber =~ $re ]] ; then
            echo "error: Not a number" >&2; countrylocationselection
        fi
        if (( countrynumber >= 1 && countrynumber < number ));then
            preciseselection
        elif (( countrynumber == 0 ));then
            echo "Returning to main menu..."
        else
        countrylocationselection
    fi
}

preciseselection () {
    # Selected country
    providersindex=$(($countrynumber -1))
    provider=${providers[$providersindex]}
    countryname=$(echo $provider | sed 's/Country_//g')
    clear
    logo
    echo ""
    echo "List of available locations in $countryname:"
    echo ""
    array_index=0
    number=1
    if [ -f $vpn_path/tempmenu.txt ];then rm $vpn_path/tempmenu.txt;fi
    # Look inside country folder
    for i in $(ls $vpn_path/ovpn_files/Country_$countryname);do
        echo "$number) $i" | sed 's/.ovpn//gi' >> $vpn_path/tempmenu.txt
        providers[$array_index]=$(echo $i | sed 's@'"$vpn_path"'\/ovpn_files\/@@g')
        number=$(($number + 1))
        array_index=$(($array_index + 1))
    done
    if [ -f $vpn_path/tempmenu.txt ];then pr -3 -t $vpn_path/tempmenu.txt;fi
    echo "0) Back"
    echo ""
    echo -n "Enter your choice and press [ENTER]: "
    read selectionnumber
    re='^[0-9]+$'
    if ! [[ $selectionnumber =~ $re ]] ; then
       echo "error: Not a number" >&2; countrylocationselection
    fi
    if (( selectionnumber >= 1 && selectionnumber < number ));then
        # Selected location
        providersindex=$(($selectionnumber -1))
        location=${providers[$providersindex]}
        echo $provider,$location > $vpn_path/providers.txt
        touch $vpn_path/custom
        if [ -f $vpn_path/stop ];then rm $vpn_path/stop;fi
    elif (( selectionnumber == 0 ));then
        countrylocationselection
    else
        countrylocationselection
    fi
}

providerselection () {
    clear
    logo
    echo ""
    echo "List of available providers (and nb of servers):"
    echo ""
    array_index=0
    number=1
    for i in $(ls -d $vpn_path/ovpn_files/* | grep -v "Country_");do
        nbovpn=$(ls $i/*.ovpn 2>/dev/null | wc -l)
        echo "$number) $(echo $i | xargs -n 1 basename) ($nbovpn)"
        providers[$array_index]=$(echo $i | xargs -n 1 basename)
        number=$(($number + 1))
        array_index=$(($array_index + 1))
    done
    echo "0) Back to main menu"
    echo ""
    echo -n "Enter your choice and press [ENTER]: "
    read providernumber
    re='^[0-9]+$'
    if ! [[ $providernumber =~ $re ]] ; then
       echo "error: Not a number" >&2; providerselection
    fi
    if (( providernumber >= 1 && providernumber < number ));then
        # Selected provider
        providersindex=$(($providernumber -1))
        provider=${providers[$providersindex]}
        providername=$(echo $provider)
        echo $provider > $vpn_path/providers.txt
        touch $vpn_path/custom
        if [ -f $vpn_path/stop ];then rm $vpn_path/stop;fi
    elif (( providernumber == 0 ));then
        echo "Returning to main menu..."
    else
        providerselection
    fi
}

status () {
    waittime=0
    while [ -f $vpn_path/rotate ] || [ -f $vpn_path/custom ] || [ -f $share_path/rotate ];do
        clear
        logo
        echo "Waiting for connection ($waittime/15)..."
        tail -5 $vpn_path/vpn.log
        sleep 1
        waittime=$((waittime +1))
        if [ $waittime -eq 15 ];then
            break
        fi
    done
}

setup_droprange () {
    clear
    logo
    echo ""
    echo "Set up IPTABLES to drop traffic"
    echo ""
    echo "Enter the IP range to drop traffic from, typically your VPN gateway range:"
    echo "i.e. 192.168.3.0/24"
    echo ""
    touch $vpn_path/drop.txt
    read -p "Press enter to continue..."
    nano $vpn_path/drop.txt
}

setup_profiles () {
    clear
    logo
    echo ""
    echo "Please enter the VPN provider's name (avoid spaces), followed by [ENTER]:"
    echo "(Example: HMA)"
    read vpn_name
    echo "Please enter the URL to OVPN files (zip), followed by [ENTER]:"
    echo "(Example: https://vpn.hidemyass.com/vpn-config/vpn-configs.zip)"
    echo "If the files are local, simply type local (place your .ovpn in: /home/vpn/local_ovpn/)"
    read vpn_configs_url
    echo "If the zip is password-protected, please enter the password, or leave blank, followed by [ENTER]:"
    read vpn_configs_password
    echo "Please enter the username you use for this VPN account, followed by [ENTER]:"
    read vpn_username
    echo "Please enter the password you use for this VPN account, followed by [ENTER]:"
    read vpn_password
    echo ""
    read -p "Is the above information correct? [Y/N]:" -n 1 -r
    if [[ ! $REPLY =~ ^[Nn]$ ]]
    then
        if [ ! -d $vpn_path/vpn_profiles ];then mkdir $vpn_path/vpn_profiles/;fi
        echo "vpn_name=$vpn_name" > $vpn_path/vpn_profiles/$vpn_name.txt
        echo "vpn_configs_url=$vpn_configs_url" >> $vpn_path/vpn_profiles/$vpn_name.txt
        echo "vpn_configs_password=$vpn_configs_password" >> $vpn_path/vpn_profiles/$vpn_name.txt
        echo "vpn_username=$vpn_username" >> $vpn_path/vpn_profiles/$vpn_name.txt
        echo "vpn_password=$vpn_password" >> $vpn_path/vpn_profiles/$vpn_name.txt
        echo ""
        echo "Profile created successfully!"
        sleep 2
    fi
    echo ""
    read -p "Would you like to create another profile? [Y/N]:" -n 1 -r
    if [[ ! $REPLY =~ ^[Nn]$ ]]
    then
        setup_profiles
    fi
    refresh
}

edit_profiles () {
    clear
    logo
    echo ""
    echo "List of existing VPN profiles:"
    echo ""
    number=1
    for i in $(ls -d $vpn_path/vpn_profiles/*);do
        nbprofiles=$(ls $i | wc -l)
        echo "$number) $i" | sed 's@'"$vpn_path"'\/vpn_profiles\/@@g' | sed 's/.txt//g'
        number=$(($number + 1))
    done
    echo "0) Back to main menu"
    echo ""
    echo -n "Choose the one you wish to edit and press [ENTER]: "
    read profilenumber
    if [ $profilenumber -eq 0 ];then
        clear
        logo
        menu
    else
        nano $(ls -d $vpn_path/vpn_profiles/* | sed -n $profilenumber\p)
        refresh
    fi
}

delete_profiles () {
    clear
    logo
    echo ""
    echo "List of existing VPN profiles:"
    echo ""
    number=1
    for i in $(ls -d $vpn_path/vpn_profiles/*);do
        nbprofiles=$(ls $i | wc -l)
        echo "$number) $i" | sed 's@'"$vpn_path"'\/vpn_profiles\/@@g' | sed 's/.txt//g'
        number=$(($number + 1))
    done
    echo "0) Back to main menu"
    echo ""
    echo -n "Choose the one you wish to delete and press [ENTER]: "
    read profilenumber
    if [ $profilenumber -eq 0 ];then
        clear
        logo
        menu
    else
        read -p "Are you sure you want to delete the $(ls -d $vpn_path/vpn_profiles/* | sed -n $profilenumber\p) profile? [Y/N]:" -n 1 -r
        if [[ ! $REPLY =~ ^[Nn]$ ]]
        then
            rm $(ls -d $vpn_path/vpn_profiles/* | sed -n $profilenumber\p)
            refresh
        fi
    fi
}

choose_favorite () {
    clear
    logo
    echo ""
    if [ -f $vpn_path/favorites.txt ];then
        echo "List of favorite VPN locations:"
        echo ""
        number=1
        cat $vpn_path/favorites.txt | while read line; do
            echo "$number) $line"
            number=$(($number + 1))
        done
        echo "0) Back to main menu"
        echo ""
        echo -n "Choose the one you wish to launch and press [ENTER]: "
        read favoritenumber
        if [ $favoritenumber -gt 0 ];then
            sed ''"$favoritenumber"'q;d' $vpn_path/favorites.txt > $vpn_path/providers.txt
            touch $vpn_path/custom
            if [ -f $vpn_path/stop ];then rm $vpn_path/stop;fi
        fi
    else
        echo "Please create some favorites first by going into the 'VPN profiles management' menu"
        echo ""
        read -p "Press enter to continue"
    fi
}

edit_favorites () {
    clear
    logo
    echo ""
    echo "** Instructions **"
    echo ""
    echo "# [VPN provider name],[.ovpn full name]"
    echo "# i.e. HMA,USA.TCP.ovpn"
    echo ""
    read -p "Press enter to continue"
    nano $vpn_path/favorites.txt
}

updatecheck () {
    clear
    logo
    # Check current version
    currentversion=$(grep '^version_number=' VPN.sh | sed 's/version_number=//g')
    # Check latest version number
    latestversion=$(curl -s https://raw.githubusercontent.com/jeromesegura/VPNrotator/master/version.info)
    if [[ ( "$currentversion" == "$latestversion" ) ]];then
            clear
                logo
        echo "You are running the latest version of the VPNrotator ($latestversion)..."
        sleep 2
    else
        read -p "An update for the VPNrotator is available, would you like to install it? [Y/N]" -n 1 -r
        if [[ ! $REPLY =~ ^[Nn]$ ]]
        then
            updateperform
        fi
    fi
}

updateperform () {
        stopVPN
        killservice
        if [ -f $vpn_path/stop ];then rm $vpn_path/stop;fi
        clear
        # Download latest core files
        declare -a CoreFiles=("VPN.sh" "countries.txt" "dn.sh" "up.sh" "vpnservice.sh" )
        echo "Downloading latest core files..."
        for val in ${CoreFiles[@]}; do
            curl https://raw.githubusercontent.com/jeromesegura/VPNrotator/master/$val --output $val
        done
        echo $latestversion > version.info
        echo "Updated VPN Rotator to version: $latestversion"
        echo "Please run VPN.sh to restart the VPN"
        exit
}

choice_actions () {
    if [ $choice -eq 1 ];then
        clear
        logo
        status
    fi

    if [ $choice -eq 2 ];then
        choose_favorite
        if [ $favoritenumber -eq 0 ];then
            clear
        else
            clear
            logo
            if [ -f $vpn_path/favorites.txt ];then
                echo "Starting VPN with $(cat $vpn_path/providers.txt)..."
                sleep 1
                status
                logo
                menu
            fi
        fi
    fi

    if [ $choice -eq 3 ];then
        countryselection
        if [ $countrynumber -eq 0 ];then
            clear
        else
            clear
            logo
            echo "Starting VPN in $countryname..."
            sleep 1
            status
            logo
            menu
        fi
    fi

    if [ $choice -eq 4 ];then
        countrylocationselection
        if [ $countrynumber -eq 0 ] || [ $selectionnumber -eq 0 ];then
            clear
        else
            clear
            logo
            echo "Starting VPN in $countryname $location..."
            sleep 1
            status
            logo
            menu
        fi
    fi

        if [ $choice -eq 5 ];then
                providerselection
        if [ $providernumber -eq 0 ];then
            clear
        else
            clear
            logo
            echo "Starting VPN with $providername..."
            sleep 1
            status
            logo
            menu
        fi
        fi

    if [ $choice -eq 6 ];then
        touch $vpn_path/rotate
        if [ -f $vpn_path ];then rm currentvpn.txt;fi
        if [ -f $share_path/currentvpn.txt ];then rm $share_path/currentvpn.txt;fi
        clear
        logo
        echo "Rotating within $(cat providers.txt | sed 's/Country_//g')..."
        sleep 1
        status
        logo
        menu
    fi

    if [ $choice -eq 7 ];then
        clear
        logo
        refresh
    fi

    if [ $choice -eq 8 ];then
        vpnprofilemanagement
    fi

    if [ $choice -eq 9 ];then
        clear
        logo
        echo "Stopping VPN..."
        stopVPN
        sleep 2
    fi

    if [ $choice -eq 10 ];then
        updatecheck
    fi

    if [ $choice -eq 11 ];then
        clear
        logo
        echo "Quitting VPN Rotator..."
        stopVPN
        sleep 2
        killservice
        clear
        if [ -f $vpn_path/stop ];then rm $vpn_path/stop;fi
        exit
    fi

}

####################################

####################################

# Kill any previously running vpnservice
killservice

# VPNrotator version number
version_number=3.5

# Adjust time
timedatectl set-ntp false
timedatectl set-ntp true

# Assign current VPN directory based on where script runs from
vpn_path=$(pwd)

# Share path
if [ -f $vpn_path/vpn.cfg ];then
    share_path=$(sed -n 's/^share_path = //p' $vpn_path/vpn.cfg )
else
    share_path=""
fi

# Check that IPTABLE and drop range exist
if [ ! -f $vpn_path/drop.txt ];then
    setup_droprange
fi

# Check for VPN profiles and go through initial setup if needed
if [ ! "$(ls -A $vpn_path/vpn_profiles)" ]; then
    mkdir $vpn_path/vpn_profiles
    setup_profiles
fi

# Clean up
if [ -f $vpn_path/currentvpn.txt ];then rm $vpn_path/currentvpn.txt;fi
if [ -f $vpn_path/rotate ];then rm $vpn_path/rotate;fi
if [ -f $vpn_path/custom ];then rm $vpn_path/custom;fi
if [ -f $vpn_path/tempmenu.txt ];then rm $vpn_path/tempmenu.txt;fi
if [ -f $share_path/rotate ];then rm $share_path/rotate;fi
clear

# Check for VPNrotator update
updatecheck

# Start vpn service
bash $vpn_path/vpnservice.sh &>/dev/null &

# Download latest VPN configs
refresh

# Menu and infinite loop
while :
do
    clear
    logo
    menu
    read -t 60 choice
    choice_actions
done
