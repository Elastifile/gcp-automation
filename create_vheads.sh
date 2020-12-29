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
 awk -F"[,:}]" '{for(i=1;i<=NF;i++){if($i~/'$KEY'\042/){print $(i+1)}}}' | tr -d '"'| tr '\n' ','
}


usage() {
  cat << E_O_F
Usage:
  -c configuration type: "small" "medium" "medium-plus" "large" "standard" "small standard" "local" "small local" "custom"
  -l load balancer: "none" "dns" "elastifile" "google"
  -t disk type: "persistent" "hdd" "local"
  -n number of vhead instances (cluster size): eg 3
  -d disk config: eg 8_375
  -v vm config: eg 4_42
  -p IP address
  -r cluster name
  -s deployment type: "single" "dual" "multizone"
  -a availability zones
  -e company name
  -f contact person
  -g contact person email
  -i clear tier
  -k async dr
  -j lb vip
  -b data container
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

while getopts "h?:c:l:t:n:d:v:p:s:a:e:f:g:i:k:j:b:r:" opt; do
    case "$opt" in
    h|\?)
        usage
        exit 0
        ;;
    c)  CONFIGTYPE=${OPTARG}
        [ "${CONFIGTYPE}" = "small" -o "${CONFIGTYPE}" = "medium" -o "${CONFIGTYPE}" = "medium-plus" -o "${CONFIGTYPE}" = "large" -o "${CONFIGTYPE}" = "standard" -o "${CONFIGTYPE}" = "small standard" -o "${CONFIGTYPE}" = "local" -o "${CONFIGTYPE}" = "small local" -o "${CONFIGTYPE}" = "custom" ] || usage
        ;;
    l)  LB=${OPTARG}
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
    p)  EMS_ADDRESS=${OPTARG}
        ;;
    s)  DEPLOYMENT_TYPE=${OPTARG}
        ;;
    a)  AVAILABILITY_ZONES=${OPTARG}
        ;;
    e)  COMPANY_NAME=${OPTARG}
        ;;
    f)  CONTACT_PERSON_NAME=${OPTARG}
        ;;
    g)  EMAIL_ADDRESS=${OPTARG}
        ;;
    i)  ILM=${OPTARG}
        ;;
    k)  ASYNC_DR=${OPTARG}
        ;;
    j)  LB_VIP=${OPTARG}
	;;
    b)  DATA_CONTAINER=${OPTARG}
        ;;
    r)  EMS_NAME=${OPTARG}
        ;;
    esac
done

#capture computed variables
EMS_HOSTNAME="${EMS_NAME}.local"

# load balancer mode
if [[ $LB == "elastifile" ]]; then
  USE_LB="true"
elif [[ $LB == "dns" ]]; then
  USE_LB="false"
else
  USE_LB="false"
fi

#deployment mode
if [[ $DEPLOYMENT_TYPE == "single" ]]; then
  REPLICATION="1"
elif [[ $DEPLOYMENT_TYPE == "dual" ]]; then
  REPLICATION="2"
else
  REPLICATION="2"
fi

echo "EMS_ADDRESS: $EMS_ADDRESS" | tee ${LOG}
echo "EMS_NAME: $EMS_NAME" | tee -a ${LOG}
echo "EMS_HOSTNAME: $EMS_HOSTNAME" | tee -a ${LOG}
echo "DISKTYPE: $DISKTYPE" | tee -a ${LOG}
echo "NUM_OF_VMS: $NUM_OF_VMS" | tee -a ${LOG}
echo "NUM_OF_DISKS: $NUM_OF_DISKS" | tee -a ${LOG}
echo "LB: $LB" | tee -a ${LOG}
echo "USE_LB: $USE_LB" | tee -a ${LOG}
echo "DEPLOYMENT_TYPE: $DEPLOYMENT_TYPE" | tee -a ${LOG}
echo "REPLICATION: $REPLICATION" | tee -a ${LOG}
echo "COMPANY_NAME: $COMPANY_NAME" | tee -a ${LOG}
echo "CONTACT_PERSON_NAME: $CONTACT_PERSON_NAME" | tee -a ${LOG}
echo "EMAIL_ADDRESS: $EMAIL_ADDRESS" | tee -a ${LOG}
echo "ILM: $ILM" | tee -a ${LOG}
echo "ASYNC_DR: $ASYNC_DR" | tee -a ${LOG}
echo "LB_VIP: $LB_VIP" | tee -a ${LOG}
echo "DATA_CONTAINER: $DATA_CONTAINER" | tee -a ${LOG}

#set -x

#establish https session
function establish_session {
  echo -e "Establishing https session..\n" | tee -a ${LOG}
  curl -k -D ${SESSION_FILE} -H "Content-Type: application/json" -X POST -d '{"user": {"login":"admin","password":"'$1'"}}' https://$EMS_ADDRESS/api/sessions >> ${LOG} 2>&1
}

function first_run {
  #loop function to wait for EMS to complete loading after instance creation
  while true; do
    curl -k -s -D ${SESSION_FILE} -m 5 -H "Content-Type: application/json" -X POST -d '{"user": {"login":"admin","password":"changeme"}}' https://$EMS_ADDRESS/api/sessions
    emsresponse=`curl -k -s -b ${SESSION_FILE} -m 5 -H "Content-Type: application/json" -X GET https://$EMS_ADDRESS/api/cloud_providers/is_ready | grep true`
    echo -e "Waiting for EMS init...\n" | tee -a ${LOG}
    if [[ -n "$emsresponse" ]]; then
      echo -e "EMS now ready!\n" | tee -a ${LOG}
      break
    fi
    sleep 10
  done
}

# Configure ECFS storage type
# "small" "medium" "large" "standard" "small standard" "local" "small local" "custom"
function set_storage_type {
  echo -e "Configure systems...\n" | tee -a ${LOG}
  type_id="$(curl -k -b ${SESSION_FILE} -H "Content-Type: application/json" -X GET https://$EMS_ADDRESS/api/cloud_configurations|grep -o -E '.{0,4}"name":"'$1'"'| cut -d ":" -f2| cut -d "," -f1 2>&1)"
  echo -e "Setting storage type $1..." | tee -a ${LOG}
  curl -k -b ${SESSION_FILE} -H "Content-Type: application/json" -X PUT -d '{"id":1,"load_balancer_use":'$USE_LB',"cloud_configuration_id":"'$type_id'"}' https://$EMS_ADDRESS/api/cloud_providers/1 >> ${LOG} 2>&1
}

function set_storage_type_custom {
    type=$1
    disks=`echo $2 | cut -d "_" -f 1`
    disk_size=`echo $2 | cut -d "_" -f 2`
    cpu_cores=`echo $3 | cut -d "_" -f 1`
    ram=`echo $3 | cut -d "_" -f 2`
    echo -e "Configure systems...\n" | tee -a ${LOG}
    echo -e "Setting custom storage type: $type, num of disks: $disks, disk size=$disk_size cpu cores: $cpu_cores, ram: $ram \n" | tee -a ${LOG}
    curl -k -b ${SESSION_FILE} -H "Content-Type: application/json" -X POST -d '{"name":"legacy","storage_type":"'$type'","num_of_disks":'$disks',"disk_size":'$disk_size',"instance_type":"custom","cores":'$cpu_cores',"memory":'$ram',"min_num_of_instances":3}' https://$EMS_ADDRESS/api/cloud_configurations >> ${LOG} 2>&1
    type_id="$(curl -k -b ${SESSION_FILE} -H "Content-Type: application/json" -X GET https://$EMS_ADDRESS/api/cloud_configurations|grep -o -E '.{0,4}"name":"legacy"'| cut -d ":" -f2| cut -d "," -f1 2>&1)"
    curl -k -b ${SESSION_FILE} -H "Content-Type: application/json" -X PUT -d '{"id":1,"load_balancer_use":'$USE_LB',"cloud_configuration_id":"'$type_id'"}' https://$EMS_ADDRESS/api/cloud_providers/1 >> ${LOG} 2>&1
}

function setup_ems {
  #accept EULA
  echo -e "\nAccepting EULA.. \n" | tee -a ${LOG}
  curl -k -b ${SESSION_FILE} -H "Content-Type: application/json" -X POST -d '{"id":1}' https://$EMS_ADDRESS/api/systems/1/accept_eula >> ${LOG} 2>&1

  #configure EMS
  echo -e "Configure EMS...\n" | tee -a ${LOG}

  echo -e "\nGet cloud provider id 1\n" | tee -a ${LOG}
  curl -k -s -b ${SESSION_FILE} --request GET --url "https://$EMS_ADDRESS/api/cloud_providers/1" >> ${LOG} 2>&1

  echo -e "\nValidate project configuration\n" | tee -a ${LOG}
  curl -k -s -b ${SESSION_FILE} --request GET --url "https://$EMS_ADDRESS/api/cloud_providers/1/validate" >> ${LOG} 2>&1

  echo -e "Configure systems...\n" | tee -a ${LOG}
  curl -k -b ${SESSION_FILE} -H "Content-Type: application/json" -X PUT -d '{"name":"'$EMS_NAME'","replication_level":'$REPLICATION',"show_wizard":false,"eula":true,"registration_info":{"company_name":"'$COMPANY_NAME'","contact_person_name":"'$CONTACT_PERSON_NAME'","email_address":"'$EMAIL_ADDRESS'","receive_marketing_updates":false}}' https://$EMS_ADDRESS/api/systems/1 >> ${LOG} 2>&1

  if [[ ${NUM_OF_VMS} == 0 ]]; then
    echo -e "0 VMs configured, skipping set storage type.\n"
  elif [[ ${CONFIGTYPE} == "custom" ]]; then
    echo -e "Set storage type custom $DISKTYPE $DISK_CONFIG $VM_CONFIG \n" | tee -a ${LOG}
    set_storage_type_custom ${DISKTYPE} ${DISK_CONFIG} ${VM_CONFIG}
  else
    echo -e "Set storage type ${CONFIGTYPE} \n" | tee -a ${LOG}
    set_storage_type ${CONFIGTYPE}
  fi

  if [[ ${DEPLOYMENT_TYPE} == "multizone" ]]; then
    echo -e "Multi Zone.\n" | tee -a ${LOG}
    echo -e "Multi Zone.\n"
    all_zones=$(curl -k -s -b ${SESSION_FILE} --request GET --url "https://"${EMS_ADDRESS}"/api/availability_zones" | jsonValue name | sed s'/[,]$//')
    echo -e "$all_zones"
    curl -k -b ${SESSION_FILE} -H "Content-Type: application/json" -X PUT -d '{"availability_zone_use":true}' https://${EMS_ADDRESS}/api/cloud_providers/1 >> ${LOG} 2>&1
    let i=1
    for zone in ${all_zones//,/ }; do
      zone_exists=`echo $AVAILABILITY_ZONES | grep $zone`
      if [[ ${zone_exists} == "" ]]; then
        curl -k -b ${SESSION_FILE} -H "Content-Type: application/json" -X PUT -d '{"enable":false}' https://${EMS_ADDRESS}/api/availability_zones/$i >> ${LOG} 2>&1
      fi
      let i++
    done
  else
    echo -e "Single Zone.\n" | tee -a ${LOG}
    curl -k -b ${SESSION_FILE} -H "Content-Type: application/json" -X PUT -d '{"availability_zone_use":false}' https://${EMS_ADDRESS}/api/cloud_providers/1 >> ${LOG} 2>&1
  fi

  if [[ ${LB_VIP} != "auto" ]]; then
    echo -e "\n LB_VIP "${LB_VIP}" \n" | tee -a ${LOG}
    echo -e "\n LB_VIP "${LB_VIP}" \n"
    curl -k -b ${SESSION_FILE} -H "Content-Type: application/json" -X PUT -d '{"load_balancer_vip":"'${LB_VIP}'"}' https://$EMS_ADDRESS/api/cloud_providers/1 >> ${LOG} 2>&1
  elif [[ ${USE_LB} = true && ${LB_VIP} == "auto" ]]; then
    LB_VIP=$(curl -k -s -b ${SESSION_FILE} --request GET --url "https://"${EMS_ADDRESS}"/api/cloud_providers/1/lb_vip"  | jsonValue vip | sed s'/[,]$//')
    echo -e "\n LB_VIP "${LB_VIP}" \n" | tee -a ${LOG}
    echo -e "\n LB_VIP "${LB_VIP}" \n"
    curl -k -b ${SESSION_FILE} -H "Content-Type: application/json" -X PUT -d '{"load_balancer_vip":"'${LB_VIP}'"}' https://$EMS_ADDRESS/api/cloud_providers/1 >> ${LOG} 2>&1
  else
    echo -e "\n DNS mode \n" | tee -a ${LOG}
  fi

}

# Kickoff a create vhead instances job
function create_instances {
  echo -e "Creating $NUM_OF_VMS ECFS instances\n" | tee -a ${LOG}
  curl -k -b ${SESSION_FILE} -H "Content-Type: application/json" -X POST -d '{"instances":'$1',"async":true,"auto_start":true}' https://$EMS_ADDRESS/api/hosts/create_instances >> ${LOG} 2>&1
}

# Function to check running job status
function job_status {
  while true; do
    STATUS=`curl -k -s -b ${SESSION_FILE} --request GET --url "https://$EMS_ADDRESS/api/control_tasks/recent?task_type=$1" | grep status | cut -d , -f 7 | cut -d \" -f 4`
    echo -e  "$1 : $STATUS " | tee -a ${LOG}
    if [[ $STATUS == "success" ]]; then
      echo -e "$1 Complete! \n" | tee -a ${LOG}
      sleep 5
      break
    fi
    if [[ $STATUS == "error" ]]; then
      echo -e "$1 Failed. Exiting..\n" | tee -a ${LOG}
      exit 1
    fi
    sleep 10
  done
}

# Create data containers
function create_data_container {
  if [[ $NUM_OF_VMS != 0 ]]; then
    echo -e "Create data container & 1000GB NFS export /$DATA_CONTAINER/root\n" | tee -a ${LOG}
    curl -k -b ${SESSION_FILE} -H "Content-Type: application/json" -X POST -d '{"name":"'$DATA_CONTAINER'","dedup":0,"compression":1,"soft_quota":{"bytes":1073741824000},"hard_quota":{"bytes":1073741824000},"policy_id":1,"dir_uid":0,"dir_gid":0,"dir_permissions":"755","data_type":"general_purpose","namespace_scope":"global","exports_attributes":[{"name":"root","path":"/","user_mapping":"remap_all","uid":0,"gid":0,"access_permission":"read_write","client_rules_attributes":[],"namespace_scope":"global","data_type":"general_purpose"}]}' https://$EMS_ADDRESS/api/data_containers >> ${LOG} 2>&1
  fi
}

# Provision  and deploy
function add_capacity {
  if [[ $NUM_OF_VMS == 0 ]]; then
    echo -e "0 VMs configured, skipping create instances\n"
  else
    create_instances $NUM_OF_VMS
    job_status "create_instances_job"
    echo "Start cluster deployment\n" | tee -a ${LOG}
    job_status "activate_emanage_job"
  fi
}

function change_password {
  if [[ "x$PASSWORD" != "x" ]]; then
    echo -e "Updating password...\n" | tee -a ${LOG}
    #update ems password
    curl -k -b ${SESSION_FILE} -H "Content-Type: application/json" -X PUT -d '{"user":{"id":1,"login":"admin","first_name":"Super","email":"admin@example.com","current_password":"changeme","password":"'$PASSWORD'","password_confirmation":"'$PASSWORD'"}}' https://$EMS_ADDRESS/api/users/1 >> ${LOG} 2>&1
    echo -e  "Establish new https session using updated PASSWORD...\n" | tee -a ${LOG}
    establish_session $PASSWORD
  fi
}

# ilm
function enable_clear_tier {
  if [[ $ILM == "true" ]]; then
    echo -e "auto configuraing clear tier\n"
    curl -k -b ${SESSION_FILE} -H "Content-Type: application/json" -X POST  https://$EMS_ADDRESS/api/cc_services/auto_setup
  fi
}

# asyncdr
function enable_async_dr {
  if [[ $ASYNC_DR == "true" ]]; then
    echo -e "auto configuraing async dr\n"
    curl -k -b ${SESSION_FILE} -H "Content-Type: application/json" -X POST -d '{"instances":2,"auto_start":true}' https://$EMS_ADDRESS/api/hosts/create_replication_agent_instance
  fi
}
# Main
first_run
setup_ems
add_capacity
create_data_container
change_password
enable_async_dr
enable_clear_tier
