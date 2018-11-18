#!/bin/bash
#create vheads.sh, Andrew Renz, Sept 2017, June 2018
#Script to configure Elastifile EManage (EMS) Server, and deploy cluster of ECFS virtual controllers (vheads) in Google Compute Platform (GCE)
#Requires terraform to determine EMS address and name (Set EMS_ADDRESS and EMS_NAME to use standalone)

set -ux

#impliment command-line options
#imported from EMS /elastifile/emanage/deployment/cloud/add_hosts_google.sh

# function code from https://gist.github.com/cjus/1047794 by itstayyab
function jsonValue() {
KEY=$1
 /
 awk -F"[,:}]" '{for(i=1;i<=NF;i++){if($i~/'$KEY'\042/){print $(i+1)}}}' | tr -d '"'| tr '\n' ','
}


usage() {
  cat << E_O_F
Usage:
  -e EMS_ADDRESS: ems.elastifile.com

E_O_F
  exit 1
}

#variables
SESSION_FILE=session.txt
PASSWORD=`cat password.txt | cut -d " " -f 1`
WEB=https
LOG="create_vheads.log"

while getopts "h?:e:" opt; do
    case "$opt" in
    h|\?)
        usage
        exit 0
        ;;
    e)  EMS_ADDRESS=${OPTARG}
        ;;
    esac
done

echo "EMS_ADDRESS: $EMS_ADDRESS" | tee ${LOG}

function change_password {
  echo -e "Updating password...\n" | tee -a ${LOG}
  #update ems password
  curl -k -b ${SESSION_FILE} -H "Content-Type: application/json" -X PUT -d '{"user":{"id":1,"login":"admin","first_name":"Super","email":"admin@example.com","current_password":"changeme","password":"'${PASSWORD}'","password_confirmation":"'${PASSWORD}'"}}' https://$EMS_ADDRESS/api/users/1 >> ${LOG} 2>&1
  echo -e  "Establish new https session using updated PASSWORD...\n" | tee -a ${LOG}
  establish_session ${PASSWORD}
}

# terraform variables to store state, unused for now
PASSWORD_IS_CHANGED=`terraform show | grep metadata.setup_complete | cut -d " " -f 5`

# Main

change_password
