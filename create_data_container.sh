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

# Create data containers
function create_data_container {
  echo -e "Create data container & 1000GB NFS export /DC01/root\n" | tee -a ${LOG}
  curl -k -b ${SESSION_FILE} -H "Content-Type: application/json" -X POST -d '{"name":"DC01","dedup":0,"compression":1,"soft_quota":{"bytes":1073741824000},"hard_quota":{"bytes":1073741824000},"policy_id":1,"dir_uid":0,"dir_gid":0,"dir_permissions":"755","data_type":"general_purpose","namespace_scope":"global","exports_attributes":[{"name":"root","path":"/","user_mapping":"remap_all","uid":0,"gid":0,"access_permission":"read_write","client_rules_attributes":[],"namespace_scope":"global","data_type":"general_purpose"}]}' https://${EMS_ADDRESS}/api/data_containers >> ${LOG} 2>&1
}

# Main

create_data_container
