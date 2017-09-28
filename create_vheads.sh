#/bin/bash
#create vheads.sh

#set -u

#impliment command-line options
#imported from EMS /elastifile/emanage/deployment/cloud/add_hosts_google.sh

usage() {
  cat << E_O_F
Usage:
  -t  disk type, local or persistent
  -n  number of elfs instances, max is 10
  -m  number of disks
  -s  [DISABLED] size of each disk. defaults: persistent 2TB, local: 375GB (fixed)
E_O_F
  exit 1
}

#variables
LOGIN=admin
PASSWORD=passw0rd_too_easy
DISKTYPE=local
NUM_OF_VMS=3
NUM_OF_DISKS=1
#DISK_SIZE=

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
#add s: back to getopts if impliment DISK_SIZE
#    s)  DISK_SIZE=${OPTARG}
#        ;;
    esac
done

echo "DISKTYPE: $DISKTYPE"
echo "NUM_OF_VMS: $NUM_OF_VMS"
echo "NUM_OF_DISKS: $NUM_OF_DISKS"

#set -x

#capture variables
EMS_ADDRESS=`terraform show | grep assigned_nat_ip | cut -d " " -f 5`
EMS_NAME=`terraform show | grep reference_name | cut -d " " -f 5`
EMS_HOSTNAME="${EMS_NAME}.local"
echo "EMS_ADDRESS: $EMS_ADDRESS"
echo "EMS_NAME: $EMS_NAME"
echo "EMS_HOSTNAME: $EMS_HOSTNAME"

#wait for EMS to complete loading
echo "wait 60 seconds for EMS to start"
sleep 80

#establish session
echo "establish session"
curl -D session.txt -H "Content-Type: application/json" -X POST -d '{"user": {"login":"'$LOGIN'","password":"'$PASSWORD'"}}' http://$EMS_ADDRESS/api/sessions &>/dev/null

#accept EULA. not sure this is necessary
curl -b session.txt -H "Content-Type: application/json" -X POST -d '{"id":1}' http://$EMS_ADDRESS/api/systems/1/accept_eula &>/dev/null

#configure EMS
curl -b session.txt -H "Content-Type: application/json" -X PUT -d '{"name":"'$EMS_NAME'","show_wizard":false,"name_server":"'$EMS_HOSTNAME'","eula":true}' http://$EMS_ADDRESS/api/systems/1 &>/dev/null

#configure ECFS storage type local SSD
echo "configure ECFS storage type local SSD"
if [ "${DISKTYPE}" = "local" ]; then
  curl -b session.txt -H "Content-Type: application/json" -X PUT -d '{"storage_type":"'$DISKTYPE'","local_num_of_disks":'$NUM_OF_DISKS',"local_disk_size":{"gigabytes":375}}' http://$EMS_ADDRESS/api/cloud_providers/1 &>/dev/null
fi

#configure ECFS storage type persistent SSD
if [ "${DISKTYPE}" = "persistent" ]; then
  curl -b session.txt -H "Content-Type: application/json" -X PUT -d '{"storage_type":"'$DISKTYPE'","persistent_num_of_disks":'$NUM_OF_DISKS',"persistent_disk_size":{"gigabytes":2000}}' http://$EMS_ADDRESS/api/cloud_providers/1 &>/dev/null
fi

#create ECFS instances
echo "create $NUM_OF_VMS ECFS instances"
curl -b session.txt -H "Content-Type: application/json" -X POST -d '{"instances":'$NUM_OF_VMS',"async":true}' http://$EMS_ADDRESS/api/hosts/create_instances &>/dev/null

#wait for instances to complete
echo "Wait 120 seconds for vheads to initiialize before cluster deployment"
sleep 120

#deploy
echo "Deploy"
curl -b session.txt -H "Content-Type: application/json" -X POST -d '{"auto_start":true}' http://$EMS_ADDRESS/api/systems/1/setup &>/dev/null

#create data container & 200GB NFS export /my_fs0/
echo "create data container & 200GB NFS export /my_fs0/"
curl -b session.txt -H "Content-Type: application/json" -X POST -d '{"name":"fs_0","dedup":0,"compression":1,"soft_quota":{"bytes":200000000000},"hard_quota":{"bytes":200000000000},"policy_id":1,"dir_uid":0,"dir_gid":0,"dir_permissions":"755","data_type":"general_purpose","namespace_scope":"global","exports_attributes":[{"name":"root","path":"/","user_mapping":"remap_all","uid":65534,"gid":65534,"access_permission":"read_write","client_rules_attributes":[],"namespace_scope":"global","data_type":"general_purpose"}]}'' http://$EMS_ADDRESS/api/data_containers &>/dev/null

echo "cluster setup complete"
