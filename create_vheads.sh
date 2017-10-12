#/bin/bash
#create vheads.sh, (c) Andrew Renz, Sept 2017
#Script to configure Elastifile EManage (EMS) Server, and deploy cluster of ECFS virtual controllers (vheads) in Google Compute Platform (GCE)
#Requires terraform to determine EMS address and name (Set EMS_ADDRESS and EMS_NAME to use standalone)

set -u

#impliment command-line options
#imported from EMS /elastifile/emanage/deployment/cloud/add_hosts_google.sh

usage() {
  cat << E_O_F
Usage:
  -t  disk type, local or persistent
  -n  number of elfs instances, max is 10
  -m  number of disks
  -p  password [DISABLED] use password.txt to set password
  -s  [DISABLED] Size of each disk. defaults: persistent 2TB, local: 375GB (fixed)
E_O_F
  exit 1
}

#variables
#LOGIN=admin
SESSION_FILE=session.txt
PASSWORD=`cat password.txt`
SETUP_COMPLETE="false"
DISKTYPE=local
NUM_OF_VMS=3
NUM_OF_DISKS=1
#DISK_SIZE=

#capture computed variables
EMS_ADDRESS=`terraform show | grep assigned_nat_ip | cut -d " " -f 5`
EMS_NAME=`terraform show | grep reference_name | cut -d " " -f 5`
EMS_HOSTNAME="${EMS_NAME}.local"
echo "EMS_ADDRESS: $EMS_ADDRESS"
echo "EMS_NAME: $EMS_NAME"
echo "EMS_HOSTNAME: $EMS_HOSTNAME"

while getopts "h?:t:n:m:" opt; do
    case "$opt" in
    h|\?)
        usage
        exit 0
        ;;
    t)  DISKTYPE=${OPTARG}
        [ "${DISKTYPE}" = "persistent" -o "${DISKTYPE}" = "local" ] || usage
        ;;
    n)  NUM_OF_VMS=${OPTARG}
        [ ${NUM_OF_VMS} -le 0 -o ${NUM_OF_VMS} -gt 10 ] && usage
        [ ${NUM_OF_VMS} -eq ${NUM_OF_VMS} ] 2>/dev/null || usage
        ;;
    m)  NUM_OF_DISKS=${OPTARG}
        ;;
#    p)  PASSWORD=${OPTARG}
#        ;;
#add s: back to getopts if impliment DISK_SIZE
#    s)  DISK_SIZE=${OPTARG}
#        ;;
    esac
done

echo "DISKTYPE: $DISKTYPE"
echo "NUM_OF_VMS: $NUM_OF_VMS"
echo "NUM_OF_DISKS: $NUM_OF_DISKS"

#set -x

#establish http session
function establish_session {
echo -e "Establish http session \n"
curl -D $SESSION_FILE -H "Content-Type: application/json" -X POST -d '{"user": {"login":"admin","password":"'$1'"}}' http://$EMS_ADDRESS/api/sessions &>/dev/null
}

# Login, accept EULA, and set password
function first_run {
  #wait 90 seconds for EMS to complete loading
  echo -e "Wait for EMS init.. \n"
  i=0
  while [ "$i" -lt 9 ]; do
    sleep 10
    echo -e "Still waiting for EMS init.. \n"
    let i+=1
  done
  establish_session "changeme"
  echo -e "Accept EULA. \n"
  curl -b $SESSION_FILE -H "Content-Type: application/json" -X POST -d '{"id":1}' http://$EMS_ADDRESS/api/systems/1/accept_eula &>/dev/null

  echo -e "Update password \n"
  #change the password
  curl -b $SESSION_FILE -H "Content-Type: application/json" -X PUT -d '{"user":{"id":1,"login":"admin","first_name":"Super","email":"admin@example.com","current_password":"changeme","password":"'$PASSWORD'","password_confirmation":"'$PASSWORD'"}}' http://$EMS_ADDRESS/api/users/1 &>/dev/null
}

# Configure ECFS storage type

function set_storage_type {
  if [[ $1 == "local" ]]; then
    echo -e "Setting storage type: $1, num of disks: $2 \n"
    curl -b $SESSION_FILE -H "Content-Type: application/json" -X PUT -d '{"storage_type":"'$DISKTYPE'","local_num_of_disks":"'$NUM_OF_DISKS'","local_disk_size":{"gigabytes":375}}' http://$EMS_ADDRESS/api/cloud_providers/1 &>/dev/null
  elif [[ $1 == "persistent" ]]; then
    echo -e "Setting storage type: $1, num of disks: $2 \n"
    curl -b $SESSION_FILE -H "Content-Type: application/json" -X PUT -d '{"storage_type":"'$DISKTYPE'","persistent_num_of_disks":'$NUM_OF_DISKS',"persistent_disk_size":{"gigabytes":2000}}' http://$EMS_ADDRESS/api/cloud_providers/1 &>/dev/null
  fi
}

function setup_ems {
  echo -e  "Establish http session using PASSWORD... \n"
  establish_session $PASSWORD

  #configure EMS
  echo -e "Configure EMS.. \n"
  curl -b $SESSION_FILE -H "Content-Type: application/json" -X PUT -d '{"name":"'$EMS_NAME'","show_wizard":false,"name_server":"'$EMS_HOSTNAME'","eula":true}' http://$EMS_ADDRESS/api/systems/1 &>/dev/null

  set_storage_type $DISKTYPE $NUM_OF_DISKS

  #update terraform state with SETUP_COMPLETE
  #terraform apply -var 'SETUP_COMPLETE=true'
}

# Kickoff a create vhead instances job
function create_instances {
  echo -e "Creating $NUM_OF_VMS ECFS instances\n"
  curl -b $SESSION_FILE -H "Content-Type: application/json" -X POST -d '{"instances":'$1',"async":true}' http://$EMS_ADDRESS/api/hosts/create_instances &>/dev/null
}

# Function to check running job status
function job_status {
  while true; do
    STATUS=`curl -s -b $SESSION_FILE --request GET --url "http://$EMS_ADDRESS/api/control_tasks/recent?task_type=$1" | grep status | cut -d , -f 7 | cut -d \" -f 4`
    echo -e  "$1: in progress.. \n"
    if [[ $STATUS == "success" ]]; then
      echo -e "$1 Complete! \n"
      sleep 5
      break
    fi
    if [[ $STATUS == "error" ]]; then
      echo -e "$1 Failed. Exiting.. \n"
      exit 1
    fi
    sleep 10
  done
}

# Create data container & 200GB NFS export /my_fs0/
function create_data_container {
  echo -e "Create data container & 200GB NFS export /my_fs0/"
  curl -b session.txt -H "Content-Type: application/json" -X POST -d '{"name":"fs_0","dedup":0,"compression":1,"soft_quota":{"bytes":200000000000},"hard_quota":{"bytes":200000000000},"policy_id":1,"dir_uid":0,"dir_gid":0,"dir_permissions":"755","data_type":"general_purpose","namespace_scope":"global","exports_attributes":[{"name":"root","path":"/","user_mapping":"remap_all","uid":65534,"gid":65534,"access_permission":"read_write","client_rules_attributes":[],"namespace_scope":"global","data_type":"general_purpose"}]}' http://$EMS_ADDRESS/api/data_containers &>/dev/null
}

# Provision  and deploy
function add_capacity {
  establish_session $PASSWORD
  create_instances $NUM_OF_VMS
  job_status create_instances_job
  #Deploy cluster
  #read -p "Press any key to continue Cluster deployment... " -n1 -s
  echo "Start cluster deployment"
  curl -b $SESSION_FILE -H "Content-Type: application/json" -X POST -d '{"auto_start":true}' http://$EMS_ADDRESS/api/systems/1/setup &>/dev/null &
  job_status activate_emanage_job
}

# terraform variables to store state, unused for now
PASSWORD_IS_CHANGED=`terraform show | grep metadata.setup_complete | cut -d " " -f 5`
SETUP_COMPLETE=`terraform show | grep metadata.setup_complete | cut -d " " -f 5`

# Main
if [ "$PASSWORD_IS_CHANGED" = "false" ]; then
  first_run
fi
if [ "$SETUP_COMPLETE" = "false" ]; then
  setup_ems
  add_capacity
  create_data_container
else
  establish_session $PASSWORD
  add_capacity
fi
