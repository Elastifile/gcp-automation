#!/bin/bash
#create vheads.sh, (c) Andrew Renz, Sept 2017, Jan 2018
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
PASSWORD=`cat password.txt | cut -d " " -f 1`
SETUP_COMPLETE="false"
DISKTYPE=local
NUM_OF_VMS=3
NUM_OF_DISKS=1
WEB=https
LOG="create_vheads.log"
#LOG=/dev/null
#DISK_SIZE=

#capture computed variables
EMS_ADDRESS=`terraform show | grep assigned_nat_ip | cut -d " " -f 5`
EMS_NAME=`terraform show | grep reference_name | cut -d " " -f 5`
EMS_HOSTNAME="${EMS_NAME}.local"
echo "EMS_ADDRESS: $EMS_ADDRESS" | tee $LOG
echo "EMS_NAME: $EMS_NAME" | tee -a $LOG
echo "EMS_HOSTNAME: $EMS_HOSTNAME" | tee -a $LOG

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

echo "DISKTYPE: $DISKTYPE" | tee -a $LOG
echo "NUM_OF_VMS: $NUM_OF_VMS" | tee -a $LOG
echo "NUM_OF_DISKS: $NUM_OF_DISKS" | tee -a $LOG

#set -x

#establish https session
function establish_session {
echo -e "\nEstablishing https session..\n" | tee -a $LOG
curl -k -D $SESSION_FILE -H "Content-Type: application/json" -X POST -d '{"user": {"login":"admin","password":"'$1'"}}' https://$EMS_ADDRESS/api/sessions >> $LOG 2>&1
}

# Login, accept EULA, and set password
function first_run {
  #wait 90 seconds for EMS to complete loading
  echo -e "Wait for EMS init...\n" | tee -a $LOG
  i=0
  while [ "$i" -lt 10 ]; do
    sleep 10
    echo -e "Still waiting for EMS init...\n" | tee -a $LOG
    let i+=1
  done
  echo -e "\nEstablishing session..\n" | tee -a $LOG
  curl -k -D $SESSION_FILE -H "Content-Type: application/json" -X POST -d '{"user": {"login":"admin","password":"changeme"}}' https://$EMS_ADDRESS/api/sessions
  echo -e "\nAccepting EULA.. \n" | tee -a $LOG
  curl -k -b $SESSION_FILE -H "Content-Type: application/json" -X POST -d '{"id":1}' https://$EMS_ADDRESS/api/systems/1/accept_eula >> $LOG 2>&1

  echo -e "\nUpdating password...\n" | tee -a $LOG
  #change the password
  curl -k -b $SESSION_FILE -H "Content-Type: application/json" -X PUT -d '{"user":{"id":1,"login":"admin","first_name":"Super","email":"admin@example.com","current_password":"changeme","password":"'$PASSWORD'","password_confirmation":"'$PASSWORD'"}}' https://$EMS_ADDRESS/api/users/1 >> $LOG 2>&1


}

# Configure ECFS storage type

function set_storage_type {
  if [[ $1 == "local" ]]; then
    echo -e "Setting storage type: $1, num of disks: $2\n" | tee -a $LOG
    curl -k -b $SESSION_FILE -H "Content-Type: application/json" -X PUT -d '{"storage_type":"'$DISKTYPE'","local_num_of_disks":'$NUM_OF_DISKS',"local_disk_size":{"gigabytes":375}}' https://$EMS_ADDRESS/api/cloud_providers/1 >> $LOG 2>&1
  elif [[ $1 == "persistent" ]]; then
    echo -e "Setting storage type: $1, num of disks: $2\n" | tee -a $LOG
    curl -k -b $SESSION_FILE -H "Content-Type: application/json" -X PUT -d '{"id":1,"storage_type":"persistent","persistent_num_of_disks":'$NUM_OF_DISKS',"persistent_disk_size":{"gigabytes":2000}}' https://$EMS_ADDRESS/api/cloud_providers/1 >> $LOG 2>&1
  fi
}

function setup_ems {
  echo -e  "\n Establish new https session using updated PASSWORD...\n" | tee -a $LOG
  establish_session $PASSWORD

  #configure EMS
  echo -e "\nConfigure EMS...\n" | tee -a $LOG
  curl -k -b $SESSION_FILE -H "Content-Type: application/json" -X PUT -d '{"name":"'$EMS_NAME'","replication_level":2,"show_wizard":false,"name_server":"'$EMS_HOSTNAME'","eula":true}' https://$EMS_ADDRESS/api/systems/1 >> $LOG 2>&1

  curl -k -b $SESSION_FILE -H "Content-Type: application/json" -X POST -d '{"system_id":1,"notification_type":"email","severity":"error","enabled":false}' https://$EMS_ADDRESS/api/notification_targets >> $LOG 2>&1

  curl -k -b $SESSION_FILE -H "Content-Type: application/json" -X POST -d '{"system_id":1,"notification_type":"snmp","severity":"error","enabled":false}' https://$EMS_ADDRESS/api/notification_targets >> $LOG 2>&1

  echo -e "\nSet storage type\n" | tee -a $LOG
  set_storage_type $DISKTYPE $NUM_OF_DISKS

  #update terraform state with SETUP_COMPLETE
  #terraform apply -var 'SETUP_COMPLETE=true'
}

# Kickoff a create vhead instances job
function create_instances {
  echo -e "\nCreating $NUM_OF_VMS ECFS instances\n" | tee -a $LOG
  curl -k -b $SESSION_FILE -H "Content-Type: application/json" -X POST -d '{"instances":'$1',"async":true}' https://$EMS_ADDRESS/api/hosts/create_instances >> $LOG 2>&1
}

# Function to check running job status
function job_status {
  while true; do
    STATUS=`curl -k -s -b $SESSION_FILE --request GET --url "https://$EMS_ADDRESS/api/control_tasks/recent?task_type=$1" | grep status | cut -d , -f 7 | cut -d \" -f 4`
    echo -e  "$1 : $STATUS " | tee -a $LOG
    if [[ $STATUS == "success" ]]; then
      echo -e "$1 Complete! \n" | tee -a $LOG
      sleep 5
      break
    fi
    if [[ $STATUS == "error" ]]; then
      echo -e "$1 Failed. Exiting..\n" | tee -a $LOG
      exit 1
    fi
    sleep 10
  done
}

# Create data containers
function create_data_container {
  echo -e "Create data container & 200GB NFS export /my_fs0/root\n" | tee -a $LOG
  curl -k -b $SESSION_FILE -H "Content-Type: application/json" -X POST -d '{"name":"fs_0","dedup":0,"compression":1,"soft_quota":{"bytes":200000000000},"hard_quota":{"bytes":200000000000},"policy_id":1,"dir_uid":0,"dir_gid":0,"dir_permissions":"755","data_type":"general_purpose","namespace_scope":"global","exports_attributes":[{"name":"root","path":"/","user_mapping":"remap_all","uid":0,"gid":0,"access_permission":"read_write","client_rules_attributes":[],"namespace_scope":"global","data_type":"general_purpose"}]}' https://$EMS_ADDRESS/api/data_containers >> $LOG 2>&1
  echo -e "Create export dir /my_fs0/src\n" | tee -a $LOG
  curl -k -b $SESSION_FILE -H "Content-Type: application/json" -X POST -d '{"id":1,"path":"src","uid":0,"gid":0,"permissions":"755"}' https://$EMS_ADDRESS/api/data_containers/1/create_dir >> $LOG 2>&1
  curl -k -b $SESSION_FILE -H "Content-Type: application/json" -X POST -d '{"name":"src","path":"src","user_mapping":"remap_all","uid":0,"gid":0,"access_permission":"read_write","client_rules_attributes":[],"namespace_scope":"global","data_type":"general_purpose","data_container_id":1}' https://$EMS_ADDRESS/api/exports >> $LOG 2>&1
  echo -e "Create export dir /my_fs0/target\n" | tee -a $LOG
  curl -k -b $SESSION_FILE -H "Content-Type: application/json" -X POST -d '{"id":2,"path":"target","uid":0,"gid":0,"permissions":"755"}' https://$EMS_ADDRESS/api/data_containers/1/create_dir >> $LOG 2>&1
  curl -k -b $SESSION_FILE -H "Content-Type: application/json" -X POST -d '{"name":"target","path":"target","user_mapping":"remap_all","uid":0,"gid":0,"access_permission":"read_write","client_rules_attributes":[],"namespace_scope":"global","data_type":"general_purpose","data_container_id":1}' https://$EMS_ADDRESS/api/exports >> $LOG 2>&1
  echo -e "Create data container & 200GB NFS export /DC01/root\n" | tee -a $LOG
  curl -k -b $SESSION_FILE -H "Content-Type: application/json" -X POST -d '{"name":"DC01","dedup":0,"compression":1,"soft_quota":{"bytes":200000000000},"hard_quota":{"bytes":200000000000},"policy_id":1,"dir_uid":0,"dir_gid":0,"dir_permissions":"755","data_type":"general_purpose","namespace_scope":"global","exports_attributes":[{"name":"root","path":"/","user_mapping":"remap_all","uid":0,"gid":0,"access_permission":"read_write","client_rules_attributes":[],"namespace_scope":"global","data_type":"general_purpose"}]}' https://$EMS_ADDRESS/api/data_containers >> $LOG 2>&1
  echo -e "Create data container & 200GB NFS export /DC02/root\n" | tee -a $LOG
  curl -k -b $SESSION_FILE -H "Content-Type: application/json" -X POST -d '{"name":"DC02","dedup":0,"compression":1,"soft_quota":{"bytes":200000000000},"hard_quota":{"bytes":200000000000},"policy_id":1,"dir_uid":0,"dir_gid":0,"dir_permissions":"755","data_type":"general_purpose","namespace_scope":"global","exports_attributes":[{"name":"root","path":"/","user_mapping":"remap_all","uid":0,"gid":0,"access_permission":"read_write","client_rules_attributes":[],"namespace_scope":"global","data_type":"general_purpose"}]}' https://$EMS_ADDRESS/api/data_containers >> $LOG 2>&1

}

function deploy_cluster {
  curl -k -b $SESSION_FILE -H "Content-Type: application/json" -X POST -d '{"auto_start":true}' https://$EMS_ADDRESS/api/systems/1/setup >> $LOG 2>&1
}

# Provision  and deploy
function add_capacity {
  establish_session $PASSWORD
  create_instances $NUM_OF_VMS
  job_status "create_instances_job"
  #Deploy cluster
  # read -p "Press any key to continue Cluster deployment... " -n1 -s
  deploy_cluster
  echo "Start cluster deployment\n" | tee -a $LOG
  job_status "activate_emanage_job"
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
  add_capacity
fi
