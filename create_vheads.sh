#!/bin/bash
#create vheads.sh, Andrew Renz, Sept 2017, June 2018
#Script to configure Elastifile EManage (EMS) Server, and deploy cluster of ECFS virtual controllers (vheads) in Google Compute Platform (GCE)
#Requires terraform to determine EMS address and name (Set EMS_ADDRESS and EMS_NAME to use standalone)

set -u

#impliment command-line options
#imported from EMS /elastifile/emanage/deployment/cloud/add_hosts_google.sh

usage() {
  cat << E_O_F
Usage:
  -c configuration type: "small" "medium" "large" "standard" "small standard" "local" "small local" "custom"
  -l use load balancer: "true" "false"
  -t disk type "persistent" "hdd" "local"
  -n number of vhead instances (cluster size)
  -d disk config eg 8_375
  -v vm config  eg 4_42
  -p use public IP: "true" "false"
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
EMS_NAME=`terraform show | grep reference_name | cut -d " " -f 5`
EMS_HOSTNAME="${EMS_NAME}.local"

while getopts "h?:c:l:t:n:d:v:p:" opt; do
    case "$opt" in
    h|\?)
        usage
        exit 0
        ;;
    c)  CONFIGTYPE=${OPTARG}
        [ "${CONFIGTYPE}" = "small" -o "${CONFIGTYPE}" = "medium" -o "${CONFIGTYPE}" = "large" -o "${CONFIGTYPE}" = "standard" -o "${CONFIGTYPE}" = "small standard" -o "${CONFIGTYPE}" = "local" -o "${CONFIGTYPE}" = "small local" -o "${CONFIGTYPE}" = "custom" ] || usage
        ;;
    l)  USE_LB=${OPTARG}
        ;;
    t)  DISKTYPE=${OPTARG}
        [ "${DISKTYPE}" = "persistent" -o "${DISKTYPE}" = "hdd" -o "${DISKTYPE}" = "local" ] || usage
        ;;
    n)  NUM_OF_VMS=${OPTARG}
        [ ${NUM_OF_VMS} -eq ${NUM_OF_VMS} ] || usage
        ;;
    d)  DISK_CONFIG=${OPTARG}
        ;;
    v)  VM_CONFIG=${OPTARG}
        ;;
    p)  USE_PUBLIC_IP=${OPTARG}
        ;;
    esac
done

if [[ $USE_PUBLIC_IP -eq 1 ]]; then
  EMS_ADDRESS=`terraform show | grep assigned_nat_ip | cut -d " " -f 5`
else
  EMS_ADDRESS=`terraform show | grep network_ip | cut -d " " -f 5`
fi

echo "EMS_ADDRESS: $EMS_ADDRESS" | tee $LOG
echo "EMS_NAME: $EMS_NAME" | tee -a $LOG
echo "EMS_HOSTNAME: $EMS_HOSTNAME" | tee -a $LOG
echo "DISKTYPE: $DISKTYPE" | tee -a $LOG
echo "NUM_OF_VMS: $NUM_OF_VMS" | tee -a $LOG
echo "NUM_OF_DISKS: $NUM_OF_DISKS" | tee -a $LOG

#set -x

#establish https session
function establish_session {
echo -e "Establishing https session..\n" | tee -a $LOG
curl -k -D $SESSION_FILE -H "Content-Type: application/json" -X POST -d '{"user": {"login":"admin","password":"'$1'"}}' https://$EMS_ADDRESS/api/sessions >> $LOG 2>&1
}

function first_run {
  #loop function to wait for EMS to complete loading after instance creation
  while true; do
    emsresponse=`curl -k -s -D $SESSION_FILE -H "Content-Type: application/json" -X POST -d '{"user": {"login":"admin","password":"changeme"}}' https://$EMS_ADDRESS/api/sessions | grep created_at | cut -d , -f 8 | cut -d \" -f 2`
    echo -e "Waiting for EMS init...\n" | tee -a $LOG
    if [[ $emsresponse == "created_at" ]]; then
      sleep 30
      echo -e "EMS now ready!\n" | tee -a $LOG
      break
    fi
    sleep 10
  done
}

# Configure ECFS storage type
# "small" "medium" "large" "standard" "small standard" "local" "small local" "custom"
function set_storage_type {
  echo -e "Configure systems...\n" | tee -a $LOG
  curl -k -b $SESSION_FILE -H "Content-Type: application/json" -X PUT -d '{"name":"'$EMS_NAME'","replication_level":2,"show_wizard":false,"name_server":"'$EMS_HOSTNAME'","eula":true}' https://$EMS_ADDRESS/api/systems/1 >> $LOG 2>&1
  if [[ $1 == "small" ]]; then
    echo -e "Setting storage type $1..." | tee -a $LOG
    curl -k -b $SESSION_FILE -H "Content-Type: application/json" -X PUT -d '{"id":1,"load_balancer_use":'$USE_LB',"cloud_configuration_id":4}' https://$EMS_ADDRESS/api/cloud_providers/1 >> $LOG 2>&1
  elif [[ $1 == "medium" ]]; then
    echo -e "Setting storage type $1..." | tee -a $LOG
    curl -k -b $SESSION_FILE -H "Content-Type: application/json" -X PUT -d '{"id":1,"load_balancer_use":'$USE_LB',"cloud_configuration_id":5}' https://$EMS_ADDRESS/api/cloud_providers/1 >> $LOG 2>&1
  elif [[ $1 == "large" ]]; then
    echo -e "Setting storage type $1..." | tee -a $LOG
    curl -k -b $SESSION_FILE -H "Content-Type: application/json" -X PUT -d '{"id":1,"load_balancer_use":'$USE_LB',"cloud_configuration_id":6}' https://$EMS_ADDRESS/api/cloud_providers/1 >> $LOG 2>&1
  elif [[ $1 == "standard" ]]; then
    echo -e "Setting storage type $1..." | tee -a $LOG
    curl -k -b $SESSION_FILE -H "Content-Type: application/json" -X PUT -d '{"id":1,"load_balancer_use":'$USE_LB',"cloud_configuration_id":7}' https://$EMS_ADDRESS/api/cloud_providers/1 >> $LOG 2>&1
  elif [[ $1 == "small standard" ]]; then
    echo -e "Setting storage type $1..." | tee -a $LOG
    curl -k -b $SESSION_FILE -H "Content-Type: application/json" -X PUT -d '{"id":1,"load_balancer_use":'$USE_LB',"cloud_configuration_id":1}' https://$EMS_ADDRESS/api/cloud_providers/1 >> $LOG 2>&1
  elif [[ $1 == "local" ]]; then
    echo -e "Setting storage type $1..." | tee -a $LOG
    curl -k -b $SESSION_FILE -H "Content-Type: application/json" -X PUT -d '{"id":1,"load_balancer_use":'$USE_LB',"cloud_configuration_id":2}' https://$EMS_ADDRESS/api/cloud_providers/1 >> $LOG 2>&1
  elif [[ $1 == "small local" ]]; then
    echo -e "Setting storage type $1..." | tee -a $LOG
    curl -k -b $SESSION_FILE -H "Content-Type: application/json" -X PUT -d '{"id":1,"load_balancer_use":'$USE_LB',"cloud_configuration_id":3}' https://$EMS_ADDRESS/api/cloud_providers/1 >> $LOG 2>&1
  fi
}

function set_storage_type_custom {
    type=$1
    disks=`echo $2 | cut -d "_" -f 1`
    disk_size=`echo $2 | cut -d "_" -f 2`
    cpu_cores=`echo $3 | cut -d "_" -f 1`
    ram=`echo $3 | cut -d "_" -f 2`
    echo -e "Configure systems...\n" | tee -a $LOG
    curl -k -b $SESSION_FILE -H "Content-Type: application/json" -X PUT -d '{"name":"'$EMS_NAME'","replication_level":2,"show_wizard":false,"name_server":"'$EMS_HOSTNAME'","eula":true}' https://$EMS_ADDRESS/api/systems/1 >> $LOG 2>&1
    echo -e "Setting custom storage type: $type, num of disks: $disks, disk size=$disk_size cpu cores: $cpu_cores, ram: $ram \n" | tee -a $LOG
    curl -k -b $SESSION_FILE -H "Content-Type: application/json" -X POST -d '{"name":"legacy","storage_type":"'$type'","num_of_disks":'$disks',"disk_size":'$disk_size',"instance_type":"custom","cores":'$cpu_cores',"memory":'$ram',"min_num_of_instances":3}' https://$EMS_ADDRESS/api/cloud_configurations >> $LOG 2>&1
    curl -k -b $SESSION_FILE -H "Content-Type: application/json" -X PUT -d '{"id":1,"load_balancer_use":'$USE_LB',"cloud_configuration_id":9}' https://$EMS_ADDRESS/api/cloud_providers/1 >> $LOG 2>&1
}

function setup_ems {
  # establish_session changeme
  #accept EULA
  echo -e "\nAccepting EULA.. \n" | tee -a $LOG
  curl -k -b $SESSION_FILE -H "Content-Type: application/json" -X POST -d '{"id":1}' https://$EMS_ADDRESS/api/systems/1/accept_eula >> $LOG 2>&1

  #configure EMS
  echo -e "Configure EMS...\n" | tee -a $LOG

  echo -e "\nGet cloud provider id 1\n" | tee -a $LOG
  curl -k -s -b $SESSION_FILE --request GET --url "https://$EMS_ADDRESS/api/cloud_providers/1" >> $LOG 2>&1

  echo -e "\nValidate project configuration\n" | tee -a $LOG
  curl -k -s -b $SESSION_FILE --request GET --url "https://$EMS_ADDRESS/api/cloud_providers/1/validate" >> $LOG 2>&1

  if [[ $NUM_OF_VMS == 0 ]]; then
    echo -e "0 VMs configured, skipping set storage type.\n"
  elif [[ $CONFIGTYPE == "custom" ]]; then
    echo -e "Set storage type custom $DISKTYPE $DISK_CONFIG $VM_CONFIG \n" | tee -a $LOG
    set_storage_type_custom $DISKTYPE $DISK_CONFIG $VM_CONFIG
  else
    echo -e "Set storage type $CONFIGTYPE \n" | tee -a $LOG
    set_storage_type $CONFIGTYPE
  fi

}

# Kickoff a create vhead instances job
function create_instances {
  echo -e "Creating $NUM_OF_VMS ECFS instances\n" | tee -a $LOG
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
    echo -e "Create data container & 1000GB NFS export /DC01/root\n" | tee -a $LOG
    curl -k -b $SESSION_FILE -H "Content-Type: application/json" -X POST -d '{"name":"DC01","dedup":0,"compression":1,"soft_quota":{"bytes":1073741824000},"hard_quota":{"bytes":1073741824000},"policy_id":1,"dir_uid":0,"dir_gid":0,"dir_permissions":"755","data_type":"general_purpose","namespace_scope":"global","exports_attributes":[{"name":"root","path":"/","user_mapping":"remap_all","uid":0,"gid":0,"access_permission":"read_write","client_rules_attributes":[],"namespace_scope":"global","data_type":"general_purpose"}]}' https://$EMS_ADDRESS/api/data_containers >> $LOG 2>&1
  fi
}

# Provision  and deploy
function add_capacity {
  if [[ $NUM_OF_VMS == 0 ]]; then
    echo -e "0 VMs configured, skipping create instances\n"
  else
    create_instances $NUM_OF_VMS
    job_status "create_instances_job"
    echo "Start cluster deployment\n" | tee -a $LOG
    job_status "activate_emanage_job"
  fi
}

function change_password {
  echo -e "Updating password...\n" | tee -a $LOG
  #update ems password
  curl -k -b $SESSION_FILE -H "Content-Type: application/json" -X PUT -d '{"user":{"id":1,"login":"admin","first_name":"Super","email":"admin@example.com","current_password":"changeme","password":"'$PASSWORD'","password_confirmation":"'$PASSWORD'"}}' https://$EMS_ADDRESS/api/users/1 >> $LOG 2>&1
  echo -e  "Establish new https session using updated PASSWORD...\n" | tee -a $LOG
  establish_session $PASSWORD
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
  change_password
else
  add_capacity
fi
