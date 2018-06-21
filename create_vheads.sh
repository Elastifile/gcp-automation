#!/bin/bash
#create vheads.sh, Andrew Renz, Sept 2017, Jan 2018
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

while getopts "h?:c:t:n:d:v:" opt; do
    case "$opt" in
    h|\?)
        usage
        exit 0
        ;;
    c)  CONFIGTYPE=${OPTARG}
        [ "${CONFIGTYPE}" = "small" -o "${CONFIGTYPE}" = "medium" -o "${CONFIGTYPE}" = "hdd" -o "${CONFIGTYPE}" = "custom" ] || usage
        ;;
    t)  DISKTYPE=${OPTARG}
        [ "${DISKTYPE}" = "ssd" -o "${DISKTYPE}" = "hdd" -o "${DISKTYPE}" = "local" ] || usage
        ;;
    n)  NUM_OF_VMS=${OPTARG}
        [ ${NUM_OF_VMS} -eq ${NUM_OF_VMS} ] || usage
        ;;
    d)  DISK_CONFIG=${OPTARG}
        ;;
    v)  VM_CONFIG=${OPTARG}
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

#curl -k -D session.txt -H "Content-Type: application/json" -X POST -d '{"user": {"login":"admin","password":"changed_me"}}' https://$EMS_ADDRESS/api/sessions

# Login, accept EULA, and set password
function first_run {
  #wait 90 seconds for EMS to complete loading
  echo -e "Wait for EMS init...\n" | tee -a $LOG
  i=0
  while [ "$i" -lt 8 ]; do
    sleep 10
    echo -e "Still waiting for EMS init...\n" | tee -a $LOG
    let i+=1
  done
  echo -e "\nEstablishing session..\n" | tee -a $LOG
  curl -k -D $SESSION_FILE -H "Content-Type: application/json" -X POST -d '{"user": {"login":"admin","password":"changeme"}}' https://$EMS_ADDRESS/api/sessions >> $LOG 2>&1
  echo -e "\nAccepting EULA.. \n" | tee -a $LOG
  curl -k -b $SESSION_FILE -H "Content-Type: application/json" -X POST -d '{"id":1}' https://$EMS_ADDRESS/api/systems/1/accept_eula >> $LOG 2>&1

  echo -e "\nUpdating password...\n" | tee -a $LOG
  #change the password
  curl -k -b $SESSION_FILE -H "Content-Type: application/json" -X PUT -d '{"user":{"id":1,"login":"admin","first_name":"Super","email":"admin@example.com","current_password":"changeme","password":"'$PASSWORD'","password_confirmation":"'$PASSWORD'"}}' https://$EMS_ADDRESS/api/users/1 >> $LOG 2>&1

}

# Configure ECFS storage type

function set_storage_type {
  if [[ $1 == "small" ]]; then
    echo -e "Setting storage type: $1" | tee -a $LOG
    curl -k -b $SESSION_FILE -H "Content-Type: application/json" -X PUT -d '{"id":1,"load_balancer_use":true,"cloud_configuration_id":1}' https://$EMS_ADDRESS/api/cloud_providers/1 >> $LOG 2>&1
  elif [[ $1 == "medium" ]]; then
    echo -e "Setting storage type: $1" | tee -a $LOG
    curl -k -b $SESSION_FILE -H "Content-Type: application/json" -X PUT -d '{"id":1,"load_balancer_use":true,"cloud_configuration_id":2}' https://$EMS_ADDRESS/api/cloud_providers/1 >> $LOG 2>&1
  elif [[ $1 == "standard" ]]; then
    echo -e "Setting storage type: $1" | tee -a $LOG
    curl -k -b $SESSION_FILE -H "Content-Type: application/json" -X PUT -d '{"id":1,"load_balancer_use":true,"cloud_configuration_id":3}' https://$EMS_ADDRESS/api/cloud_providers/1 >> $LOG 2>&1
  fi
}

function set_storage_type_custom {
    type=$1
    disks=`echo $2 | cut -d "_" -f 1`
    disk_size=`echo $2 | cut -d "_" -f 2`
    cpu_cores=`echo $3 | cut -d "_" -f 1`
    ram=`echo $3 | cut -d "_" -f 2`
    echo -e "Setting custom storage type: $type, num of disks: $disks, disk size=$disk_size cpu cores: $cpu_cores, ram: $ram \n" | tee -a $LOG
    curl -k -b $SESSION_FILE -H "Content-Type: application/json" -X POST -d '{"name":"custom","storage_type":"'$type'","num_of_disks":'$disks',"disk_size":'$disk_size',"instance_type":"custom","cores":'$cpu_cores',"memory":'$ram',"min_num_of_instances":3}' https://$EMS_ADDRESS/api/cloud_configurations
    curl -k -b $SESSION_FILE -H "Content-Type: application/json" -X PUT -d '{"id":1,"load_balancer_use":true,"cloud_configuration_id":5}' https://$EMS_ADDRESS/api/cloud_providers/1
}

function setup_ems {
  echo -e  "\n Establish new https session using updated PASSWORD...\n" | tee -a $LOG
  establish_session $PASSWORD

  #configure EMS
  echo -e "\nConfigure EMS...\n" | tee -a $LOG
  curl -k -b $SESSION_FILE -H "Content-Type: application/json" -X PUT -d '{"name":"'$EMS_NAME'","replication_level":2,"show_wizard":false,"name_server":"'$EMS_HOSTNAME'","eula":true}' https://$EMS_ADDRESS/api/systems/1 >> $LOG 2>&1

  echo -e "\nSet storage type\n" | tee -a $LOG
  if [[ $NUM_OF_VMS == 0 ]]; then
    echo -e "0 VMs configured, skipping set storage type."
  elif [[ $CONFIGTYPE == "custom" ]]; then
    set_storage_type_custom $DISKTYPE $DISK_CONFIG $VM_CONFIG
  else
    set_storage_type $CONFIGTYPE
  fi

  #update terraform state with SETUP_COMPLETE
  #terraform apply -var 'SETUP_COMPLETE=true'
}

# Kickoff a create vhead instances job
function create_instances {
  echo -e "\nCreating $NUM_OF_VMS ECFS instances\n" | tee -a $LOG
  curl -k -b $SESSION_FILE -H "Content-Type: application/json" -X POST -d '{"instances":'$1',"async":true,"auto_start":true}' https://$EMS_ADDRESS/api/hosts/create_instances >> $LOG 2>&1
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
  if [[ $NUM_OF_VMS != 0 ]]; then
    echo -e "Create data container & 200GB NFS export /my_fs0/root\n" | tee -a $LOG
    curl -k -b $SESSION_FILE -H "Content-Type: application/json" -X POST -d '{"name":"fs_0","dedup":0,"compression":1,"soft_quota":{"bytes":214748364800},"hard_quota":{"bytes":214748364800},"policy_id":1,"dir_uid":0,"dir_gid":0,"dir_permissions":"755","data_type":"general_purpose","namespace_scope":"global","exports_attributes":[{"name":"root","path":"/","user_mapping":"remap_all","uid":0,"gid":0,"access_permission":"read_write","client_rules_attributes":[],"namespace_scope":"global","data_type":"general_purpose"}]}' https://$EMS_ADDRESS/api/data_containers >> $LOG 2>&1
    echo -e "Create export dir /my_fs0/src\n" | tee -a $LOG
    curl -k -b $SESSION_FILE -H "Content-Type: application/json" -X POST -d '{"id":1,"path":"src","uid":0,"gid":0,"permissions":"755"}' https://$EMS_ADDRESS/api/data_containers/1/create_dir >> $LOG 2>&1
    curl -k -b $SESSION_FILE -H "Content-Type: application/json" -X POST -d '{"name":"src","path":"src","user_mapping":"remap_all","uid":0,"gid":0,"access_permission":"read_write","client_rules_attributes":[],"namespace_scope":"global","data_type":"general_purpose","data_container_id":1}' https://$EMS_ADDRESS/api/exports >> $LOG 2>&1
    echo -e "Create export dir /my_fs0/target\n" | tee -a $LOG
    curl -k -b $SESSION_FILE -H "Content-Type: application/json" -X POST -d '{"id":2,"path":"target","uid":0,"gid":0,"permissions":"755"}' https://$EMS_ADDRESS/api/data_containers/1/create_dir >> $LOG 2>&1
    curl -k -b $SESSION_FILE -H "Content-Type: application/json" -X POST -d '{"name":"target","path":"target","user_mapping":"remap_all","uid":0,"gid":0,"access_permission":"read_write","client_rules_attributes":[],"namespace_scope":"global","data_type":"general_purpose","data_container_id":1}' https://$EMS_ADDRESS/api/exports >> $LOG 2>&1
    echo -e "Create data container & 200GB NFS export /DC01/root\n" | tee -a $LOG
    curl -k -b $SESSION_FILE -H "Content-Type: application/json" -X POST -d '{"name":"DC01","dedup":0,"compression":1,"soft_quota":{"bytes":214748364800},"hard_quota":{"bytes":214748364800},"policy_id":1,"dir_uid":0,"dir_gid":0,"dir_permissions":"755","data_type":"general_purpose","namespace_scope":"global","exports_attributes":[{"name":"root","path":"/","user_mapping":"remap_all","uid":0,"gid":0,"access_permission":"read_write","client_rules_attributes":[],"namespace_scope":"global","data_type":"general_purpose"}]}' https://$EMS_ADDRESS/api/data_containers >> $LOG 2>&1
    echo -e "Create data container & 200GB NFS export /DC02/root\n" | tee -a $LOG
    curl -k -b $SESSION_FILE -H "Content-Type: application/json" -X POST -d '{"name":"DC02","dedup":0,"compression":1,"soft_quota":{"bytes":214748364800},"hard_quota":{"bytes":214748364800},"policy_id":1,"dir_uid":0,"dir_gid":0,"dir_permissions":"755","data_type":"general_purpose","namespace_scope":"global","exports_attributes":[{"name":"root","path":"/","user_mapping":"remap_all","uid":0,"gid":0,"access_permission":"read_write","client_rules_attributes":[],"namespace_scope":"global","data_type":"general_purpose"}]}' https://$EMS_ADDRESS/api/data_containers >> $LOG 2>&1
  fi
}

function deploy_cluster {
  curl -k -b $SESSION_FILE -H "Content-Type: application/json" -X POST -d '{"auto_start":true}' https://$EMS_ADDRESS/api/systems/1/setup >> $LOG 2>&1
}

# Provision  and deploy
function add_capacity {
  establish_session $PASSWORD
  if [[ $NUM_OF_VMS == 0 ]]; then
    echo -e "0 VMs configured, skipping create instances"
  else
    create_instances $NUM_OF_VMS
    echo "Start cluster deployment\n" | tee -a $LOG
    job_status "activate_emanage_job"
  fi
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
