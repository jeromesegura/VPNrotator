#!/bin/bash

refreshVPN () {

    # Clean up
    rm -r $vpn_path/ovpn_files/
    mkdir $vpn_path/ovpn_files

    # Create local ovpn directory if it does not exist
    if [ ! -d $vpn_path/local_ovpn/ ];then
        mkdir $vpn_path/local_ovpn
    fi

    for profile in $(ls $vpn_path/vpn_profiles/*);do

        # Grab variable names
        vpn_name=$(grep 'vpn_name' $profile | awk -F '=' '{print $2}')
        echo "Configuring profile for $vpn_name..." >> $vpn_path/refresh.log
        vpn_configs_url=$(grep 'vpn_configs_url' $profile | awk -F '=' '{print $2}')
        vpn_username=$(grep 'vpn_username' $profile | awk -F '=' '{print $2}')
        vpn_password=$(grep 'vpn_password' $profile | awk -F '=' '{print $2}')

        # Create ovpn_files directory if it does not exist
        if [ ! -d $vpn_path/ovpn_files/$vpn_name ];then
            echo "Creating directory for $vpn_name..." >> $vpn_path/refresh.log
            mkdir $vpn_path/ovpn_files/$vpn_name
        else
            # Clean up
            echo "Cleaning up old ovpn files for $vpn_name..." >> $vpn_path/refresh.log
            rm $vpn_path/ovpn_files/$vpn_name/*.ovpn
        fi

        # Create local ovpn sub directory if it does not exist
        if [ ! -d $vpn_path/local_ovpn/$vpn_name ];then
            mkdir $vpn_path/local_ovpn/$vpn_name
        fi
 
        # Cleanup and setup temp directory
        echo "Delete temp folder..." >> $vpn_path/refresh.log
        rm -r $vpn_path/ovpn_tmp/
        echo "Create temp folder..." >> $vpn_path/refresh.log
        mkdir $vpn_path/ovpn_tmp
        
        # We have VPN credentials
        if [ ! -z "$vpn_username" ] && [ ! -z "$vpn_password" ];then
            if [ $vpn_configs_url = "local" ];then
                # Local ovpn files
                cp $vpn_path/local_ovpn/$vpn_name/*.ovpn $vpn_path/ovpn_files/$vpn_name/
            else 
                # Download ovpn config files
                echo "Downloading $vpn_name configs..." >> $vpn_path/refresh.log
                wget --no-check-certificate -O $vpn_path/openvpn.zip $vpn_configs_url
                # Unzip files
                echo "Unzipping $vpn_name..." >> $vpn_path/refresh.log
                unzip -q $vpn_path/openvpn.zip -d $vpn_path/ovpn_tmp
                # Clean up and move ovpn files
                echo "Cleaning up and moving $vpn_name ovpn files..." >> $vpn_path/refresh.log
                rm $vpn_path/openvpn.zip
                # Check if ovpn files are in current folder
                success=0
                if ls $vpn_path/ovpn_tmp/*.ovpn >/dev/null 2>&1;then
                    echo "ovpn files in main folder"
                    success=1
                else
                    # Check for TCP folder
                    echo "Checking for TCP folder to find ovpn files..."
                    tcp_folder_exists=$(ls -d $vpn_path/ovpn_tmp/*/ | grep -c -i tcp)
                    if [ $tcp_folder_exists -eq 1 ];then
                        cp $(ls -d $vpn_path/ovpn_tmp/*/ | grep -i tcp)/*.ovpn $vpn_path/ovpn_tmp/
                        success=1
                    fi
                fi
                if [ $success -eq 1 ];then
                    echo "Renaming files with spaces..."
                    for f in $vpn_path/ovpn_tmp/*\ *; do mv "$f" "${f// /_}" >/dev/null 2>&1; done
                    echo "Moving ovpn files to $vpn_name folder..."
                    mv $vpn_path/ovpn_tmp/*.ovpn $vpn_path/ovpn_files/$vpn_name/
                    rm -r $vpn_path/ovpn_tmp/
                else
                    echo "Failed importing $vpn_name profile!" >> $vpn_path/refresh.log
                    echo "" >> $vpn_path/refresh.log
                fi
            fi
            # Store user name and password
            echo "Creating user.txt files with creds for $vpn_name..." >> $vpn_path/refresh.log
            echo $vpn_username > $vpn_path/ovpn_files/$vpn_name/user.txt
            echo $vpn_password >> $vpn_path/ovpn_files/$vpn_name/user.txt

            # Edit ovpn files with creds
            echo "Editing $vpn_name files..." >> $vpn_path/refresh.log
            for i in $(ls $vpn_path/ovpn_files/$vpn_name/*.ovpn);do sed -i "s@auth-user-pass@auth-user-pass $vpn_path\/ovpn_files\/$vpn_name\/user.txt@g" $i;done
            for i in $(ls $vpn_path/ovpn_files/$vpn_name/*.ovpn);do echo "" >> $i;done
            for i in $(ls $vpn_path/ovpn_files/$vpn_name/*.ovpn);do echo "log $vpn_path/vpn.log" >> $i;done

            echo "Successfully imported $vpn_name profile!" >> $vpn_path/refresh.log
            echo "" >> $vpn_path/refresh.log

        # We don't have VPN credentials
        else
            echo "Downloading CSV file..." >> $vpn_path/refresh.log
            curl $vpn_configs_url | dos2unix | tail -n +3 > $vpn_path/ovpn_tmp/configs.csv
            uniqueid=$(date +%s)
            echo "Parsing CSV file..." >> $vpn_path/refresh.log
            while IFS='' read -r line || [[ -n "$line" ]];do
                country=$(echo "$line" | awk -F ',' '{print $7}')
                echo "$line" | awk -F ',' '{print $NF}' | base64 -d > $vpn_path/ovpn_tmp/$country-$uniqueid.ovpn 
                echo "log /home/vpn/vpn.log" >> $vpn_path/ovpn_tmp/$country-$uniqueid.ovpn
                uniqueid=$((uniqueid+1))
            done < $vpn_path/ovpn_tmp/configs.csv
            mv $vpn_path/ovpn_tmp/*.ovpn $vpn_path/ovpn_files/$vpn_name/
            rm -r $vpn_path/ovpn_tmp/
        fi
    done

    # Adding countries
    echo "Sorting ovpn files by country..." >> $vpn_path/refresh.log
    for country in $(cat $vpn_path/countries.txt | awk -F ',' '{print $1}');do
        # Create folder if it does not exist
        if [ ! -d $vpn_path/ovpn_files/Country_$country ];then mkdir $vpn_path/ovpn_files/Country_$country;fi
        # Cleanup folder if it already exists
        if ls $vpn_path/ovpn_files/Country_$country/*.ovpn >/dev/null 2>&1; then rm $vpn_path/ovpn_files/Country_$country/*.ovpn; fi
        # Copy ovpn files
        line=$(cat $vpn_path/countries.txt | grep $country)
        for i in ${line//,/ };do
            # Loop through VPN provider folders
            for folder in $( ls -I Country_* $vpn_path/ovpn_files/);do
                find $vpn_path/ovpn_files/$folder -iname "$i*" -exec cp {} $vpn_path/ovpn_files/Country_$country/ \;
            done
        done
    done
    # Clean up country mismatch
    find $vpn_path/ovpn_files/Country_UK -type f -iname ukraine* -exec rm -f {} \;

    echo "" >> $vpn_path/refresh.log
    echo "" >> $vpn_path/refresh.log
    echo "All done!" >> $vpn_path/refresh.log

    rm $vpn_path/refresh
    if [ -f $vpn_path/stop ];then rm $vpn_path/stop;fi

}

killOVPN () {
    echo "Killing OVPN..."
    for i in {1..4}; do killall openvpn;done
    if [ -f currentvpn.txt ];then rm currentvpn.txt;fi
}

stopVPN () {
    echo "Disconnecting VPN..."
    for i in {1..4}; do killall openvpn;done
    if [ -f currentvpn.txt ];then rm currentvpn.txt;fi
    rm currentvpn.txt
    rm stop
    increment
}

currentprovider () {
    # get current VPN provider
    provider=${providers[$providersindex]}
    # count number of ovpn files for VPN provider
    providertotal=$provider\total
    providertotal=$(ls $vpn_path/ovpn_files/$provider/*.ovpn | sed 's/^.*\///g' | wc -l)
    # get current .conf file
    providerindex=$provider\index
    eval $provider\index=$((1 + RANDOM % $providertotal))
    location=$(ls $vpn_path/ovpn_files/$provider/*.ovpn | sed 's/^.*\///g' | sed -n ${!providerindex}\p)
}

startVPN () {
    echo "Starting $provider with access point $location"
    if [ -f vpn.log ];then echo "" > vpn.log;fi
    if [ -f $vpn_path/refresh ];then rm $vpn_path/refresh;fi
    echo "$provider $location" > currentvpn.txt
    openvpn --config "$vpn_path/ovpn_files/$provider/$location" --script-security 2 --float --route-up $vpn_path/up.sh --down $vpn_path/dn.sh --daemon 2>&1
    echo "$location"
    echo $(date) > date.log
}

increment () {
    # increment providers array
    providersindex=$((providersindex + 1))
    echo "$providersindex total provider: $totalproviders providerindex ${!providerindex} out of $providertotal"
    if [ $providersindex -gt $((totalproviders - 1)) ];then providersindex=0;fi
    # increment index within specific provider
    let eval $provider\index++
    if [ ${!providerindex} -gt $providertotal ];then eval $provider\index=1;fi
}

checkVPN () {
    if [ -f $vpn_path/refresh ] || [ -f $vpn_path/start ];then
        echo "VPN being refreshed or restarted..."
    else
        echo "Checking VPN status..."
        errors=$(tail -1 vpn.log | egrep -c '(Sequence Completed)')
        pingcheck=$(ping -c 1 -I tun0 -q google.com 2>&1 | grep -c '1 packets transmitted')
        echo "##############"
        echo "Pingcheck results= $pingcheck (0 means down, 1 means up)"
        echo "##############"
        if [ $errors -eq 0 ] || [ $pingcheck -eq 0 ];then
            echo "VPN DOWN!!!!!!, rotating now...."
            echo "Error with $location on $(date) errors=$errors pingcheck=$pingcheck" >> error.log
            killOVPN
            rm vpn.log
            currentprovider
            startVPN
            #increment
            sleep 20
            if [ -f $vpn_path/stop ];then
                break
            else
                checkVPN
            fi
        else
            echo "VPN connected OK"
            echo "$provider $location" > currentvpn.txt
        fi
    fi
}

readproviders () {
    # Unset array
    unset providers

    # array of VPN providers
    index=0
    while read line; do providers[$index]="$line";index=$(($index+1));done < $vpn_path/providers.txt

    # variables initialization
    providersindex=0
    totalproviders=${#providers[@]}
    for i in $(cat $vpn_path/providers.txt);do let eval $i\index=1;done
}

###################
###################

# Assign current VPN directory based on where script runs from
vpn_path=$(pwd)

# Set PATH variable
export PATH="/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/root/bin"

# Disable traffic from victim to VPN
/sbin/iptables -A INPUT -s $(cat $vpn_path/drop.txt) -j DROP

# Downcheck
downcheck=0

if [ -f custom ];then rm custom;fi
killOVPN
if [ -vpn.log ];then rm vpn.log;fi


# infinite loop
while :
do
    echo "-----"
    echo "$provider $location"
    echo "-----"
    if [ -f vpn.log ];then tail -5 vpn.log;fi

    if [ -f refresh ];then
        echo "Refreshing ovpn files..."
        killOVPN
        refreshVPN
    fi

    if [ -f rotate ];then
        echo "Rotating IP address..."
        killOVPN
        rm off
        rm vpn.log
        if [ -f currentvpn.txt ];then rm currentvpn.txt;fi
        currentprovider
        startVPN
        #increment
        rm rotate
                sleep 15
        checkVPN
    fi

    if [ -f custom ];then
        echo "Starting new VPN connection..."
        killOVPN
        rm off
        rm vpn.log
        if [ -f currentvpn.txt ];then rm currentvpn.txt;fi
        if [ -f start ];then rm start;fi
        provider=$(cat $vpn_path/providers.txt | awk -F ',' '{print $1}')
        location=$(cat $vpn_path/providers.txt | awk -F ',' '{print $2}')
        if [ -z $location ];then
            readproviders
            currentprovider
            startVPN
            #increment
            sleep 15
            checkVPN
        else
            startVPN
            sleep 15
            checkVPN
                fi
        rm custom
        if [ -f start ];then rm start;fi
    fi

    if [ -f stop ];then
        stopVPN
        touch off
    fi

    # Check if VPN is down
    if [ -f off ];then
        echo "VPN has not started or is off"
    else
        if [ $downcheck -eq 60 ];then
            echo "Checking VPN at $(date)" >> error.log
            downcheck=0
            checkVPN
        else
            downcheck=$((downcheck+1))
        fi
    fi
    
    sleep 2

done
