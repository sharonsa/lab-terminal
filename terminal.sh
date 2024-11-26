root@lab# more terminal.sh
#! /bin/bash

# disable CTRL + C
trap '' 2

# Exit on error
set -e

unset debug_mode
debug_mode="0"

client_ip=($(who am i))
client_ip=${client_ip[4]}
client_ip=${client_ip/\(/}
client_ip=${client_ip/\)/}

maint="[In maintenance]"
devices_pass="password"
i=1   ;d_name[$i]="nexus1000v-1"; d_ip[$i]="10.0.0.1";   d_conn[$i]="ssh";    d_user[$i]="admin";  d_pass[$i]="$devices_pass";  d_maint[$i]="";
i=2   ;d_name[$i]="nexus1000v-3"; d_ip[$i]="10.0.0.3";   d_conn[$i]="ssh";    d_user[$i]="admin";  d_pass[$i]="$devices_pass";  d_maint[$i]="";
i=3   ;d_name[$i]="esxi-5.1";     d_ip[$i]="10.0.0.5";   d_conn[$i]="ssh";    d_user[$i]="root";   d_pass[$i]="1234567";       d_maint[$i]="";
i=4   ;d_name[$i]="VC-appliance"; d_ip[$i]="10.0.0.8";   d_conn[$i]="ssh";    d_user[$i]="root";   d_pass[$i]="1234567";       d_maint[$i]="[ Disabled ]";


client_conn_type="SSH ";

if [ "$client_ip" == "" ] # if connected using telnet the source ip is now shown
then
        # the script finds the last telnet connection source IP address
        client_ip=$(echo $(netstat -nae | grep $(netstat -nae | grep 23 | awk  '{print $8}' | sort -n | tail -n1) | awk '{print $5}') | awk -F':' '{print $1}' )
        client_conn_type="Tlnt"
fi

function connect_device {
 unset id
 id="$1"
 read_devices_general_password
 get_password_device
 read_password_user
 # echo " xx devices_general_password=$devices_general_password, password_user=$password_user, password_device=$password_device xx "
 if [ "$password_user" == "$device_password_a" ]||[ "$password_user" == "$device_password_b" ]||[ "$password_user" == "$device_password_c" ]
 then
   add_log "Access success - ${d_name[$id]} [${d_ip[id]}]"
   echo " "
   echo "Password OK"
#   echo "If you asked for a password by the device, "
#   echo "It's because someone changed the password,"
#   echo "Configuration is reset to default every 1 hour"
   echo ""
   do_telnet
   add_log "Exit device -  ${d_name[$id]} [${d_ip[id]}]"
   echo " "
   read -n1 -r -p "Connection to  ${d_name[$id]} ended, press any key to continue" key
 else
   add_log "Access failed -  ${d_name[$id]}  [${d_ip[$id]}] - wrong password ($password_user:$device_password_a|$device_password_b|$device_password_c)"
   echo " "
   echo " "
   echo "Wrong password"
   echo " "
   read -n1 -r -p "Press any key to continue.. " key
 fi
}

function do_telnet {
  case "${d_conn[$id]}" in
    ssh)    CMD="plink ${d_user[$id]}@${d_ip[$id]} -pw ${d_pass[$id]}" ;;
    telnet) CMD="/home/lab/auto-telnet.sh ${d_ip[$id]} ${d_user[$id]} ${d_pass[$id]}" ;;
  *)    CMD="" ; echo "Can't find device in DB\n" ;;
esac

  #echo "CMD=$CMD"
  current_time=$(date +%d.%m.%Y-%H.%M)
  rand_no=$[($RANDOM%10000)+1]
  $CMD | tee /hd2/log/sessions/${d_name[$id]}_${client_ip}_${current_time}_${rand_no}.log
}

function read_devices_general_password {
 unset devices_general_password
 while read line
 do devices_general_password="$line"
 done < "/home/lab/.pass"
}

function get_password_device {
 unset device_password_1
 unset device_password_a
 unset device_password_b
 unset device_password_c
 unset the_hour
 unset the_hour_a
 unset the_hour_b
 unset the_hour_c

 # echo "debug_mode=$debug_mode"
 # if IP is 10.0.0.11 the password will be 11
 if [ "$debug_mode" == "1" ]; then echo "1. d_ip[$id]=${d_ip[$id]}"; fi
 tmp_ip=${d_ip[$id]}
 device_ip_last_octet=${tmp_ip/10.0.0./}
 if [ "$debug_mode" == "1" ]; then echo "2. device_ip_last_octet=$device_ip_last_octet"; fi
 if [ "$debug_mode" == "1" ]; then echo "3. devices_general_password=$devices_general_password"; fi
 device_password_1="$(echo ${device_ip_last_octet}*${devices_general_password}+${device_ip_last_octet} | bc)"
 if [ "$debug_mode" == "1" ]; then echo "4. device_password_1=$device_password_1"; fi
 the_hour=$(date +"%H")
 if [ "$debug_mode" == "1" ]; then echo "5. the_hour=$the_hour"; fi

 if [ "$the_hour" == "00" ]
 then
   the_hour_a="23"
 else
  the_hour_a="$(echo ${the_hour}-1 | bc)"
 fi

 the_hour_b=$the_hour

 if [ "$the_hour" == "23" ]
 then
   the_hour_c="0"
 else
  the_hour_c="$(echo ${the_hour}+1 | bc)"
 fi

 the_hour_a="$(echo ${the_hour_a}+13 | bc)"
 the_hour_b="$(echo ${the_hour_b}+13 | bc)"
 the_hour_c="$(echo ${the_hour_c}+13 | bc)"

 device_password_a="$(echo ${device_password_1}*${the_hour_a} | bc)"
 device_password_b="$(echo ${device_password_1}*${the_hour_b} | bc)"
 device_password_c="$(echo ${device_password_1}*${the_hour_c} | bc)"

 if [ "$debug_mode" == "1" ]; then echo "6. device_password=$device_password_a $device_password_b $device_password_c"; fi
}

function read_password_user {
 unset password_user
 echo " "
 prompt="${d_name[$id]} Password: "
 while IFS= read -p "$prompt" -r -s -n 1 char
 do
    if [[ $char == $'\0' ]]
    then
        break
    fi
    prompt='*'
    password_user+="$char"
 done
}

function show_access_hist {
  echo " "
#  echo "$(ls -ltr /hd2/log/sessions/ | grep $(date +%d.%m.%Y) | awk  '{print $8,$9}' |  cut -d'_' -f1 | tail -n 20)"
  echo "$(ls -ltr /hd2/log/sessions/ | awk  '{print $6,$7,$8,$9}' |  cut -d'_' -f1 | tail -n 20)"
  echo " "
  echo "Current time:"
  echo $(date '+%b %e %H:%M')
  echo " "
  read -n1 -r -p "Press any key.. " key

}

function add_log {
  temp_time=$(date +%d.%m.%Y-%H.%M.%S)
#  echo "${temp_time} (${client_conn_type}>${client_ip}): $1"  >> /hd2/log/access.log
  printf "${temp_time} (${client_conn_type}>%-15s %s: $1\n" "${client_ip})"  >> /hd2/log/access.log
}


add_log "Access the lab"

while [ 1 ]
do
 clear
 echo " "
 echo " Terminal server "
 echo " ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ "
 echo " "
 printf " %-4s %-15s %-6s   %-25s \n" "#" "Device Name" "Users" "Comments"
 echo "===  =============   =======  ========== "

 last_i=0
 for i in {1..254}
 do
   if [ ${d_name[$i]} ]
   then
     if [ "$(echo ${i}-${last_i} | bc)" -gt 1 ]  # separate between groups
     then
        echo " "
     fi
     connections=$(echo $(netstat -na | grep ${d_ip[$i]}: -c))
     printf "%-4s %-15s  %-6s %-25s \n" "$i." "${d_name[$i]}" "$connections" "${d_maint[$i]}"
    last_i=$i
   fi
 done
 echo " "
 echo     "0.   Exit"
 echo     "999. Users access history (Last 20)  ** NEW **"
 echo " "
 read  -p "Please enter your choice: " choice
 case "$choice" in
   [1-9]|[0-9][0-9]|[0-9][0-9][0-8])
        if [ "${d_maint[$choice]}" ]
           then
                echo " "
                read -n1 -r -p "Device $choice is - ${d_maint[$choice]}, Press any key.. " key
           else
                if [ "${d_name[$choice]}" ] # check if device exist
                then
                        connect_device "$choice"
                else
                        echo " "
                        read -n1 -r -p "Device $choice does not exist, Press any key.. " key
                fi
           fi
        ;;
   0)  add_log "Exit the lab"
      exit 1              ;;
 999) show_access_hist    ;;
   *)  echo " "
      read -n1 -r -p "Valid options are: 0 - 999" key ;;

  esac
done

# Enable CRL + C
trap 2
