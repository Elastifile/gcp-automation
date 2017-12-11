#/bin/bash

SESSION_FILE=session.txt
PASSWORD="changed_me"

EMS_ADDRESS=`terraform show | grep assigned_nat_ip | cut -d " " -f 5`
EMS_NAME=`terraform show | grep reference_name | cut -d " " -f 5`
EMS_HOSTNAME="${EMS_NAME}.local"
echo "EMS_ADDRESS: $EMS_ADDRESS"
echo "EMS_NAME: $EMS_NAME"
echo "EMS_HOSTNAME: $EMS_HOSTNAME"

function establish_session {
echo -e "Establishing http session.."
curl -D $SESSION_FILE -H "Content-Type: application/json" -X POST -d '{"user": {"login":"admin","password":"'$1'"}}' http://$EMS_ADDRESS/api/sessions
}

function create_data_container {
  echo -e "Create data container & 200GB NFS export /my_fs0/root"
  curl -b session.txt -H "Content-Type: application/json" -X POST -d '{"name":"fs_0","dedup":0,"compression":1,"soft_quota":{"bytes":200000000000},"hard_quota":{"bytes":200000000000},"policy_id":1,"dir_uid":0,"dir_gid":0,"dir_permissions":"755","data_type":"general_purpose","namespace_scope":"global","exports_attributes":[{"name":"root","path":"/","user_mapping":"remap_all","uid":65534,"gid":65534,"access_permission":"read_write","client_rules_attributes":[],"namespace_scope":"global","data_type":"general_purpose"}]}' http://$EMS_ADDRESS/api/data_containers
  echo -e ""
  echo -e ""
  echo -e "Create export dir /my_fs0/src"
  echo -e ""
  echo -e ""
  curl -b session.txt -H "Content-Type: application/json" -X POST -d '{"id":1,"path":"src","uid":0,"gid":0,"permissions":"755"}' http://$EMS_ADDRESS/api/data_containers/1/create_dir
  echo -e ""
  echo -e ""
  curl -b session.txt -H "Content-Type: application/json" -X POST -d '{"name":"src","path":"src","user_mapping":"remap_all","uid":0,"gid":0,"access_permission":"read_write","client_rules_attributes":[],"namespace_scope":"global","data_type":"general_purpose","data_container_id":1}' http://$EMS_ADDRESS/api/exports
  echo -e ""
  echo -e ""
  echo -e "Create export dir /my_fs0/target"
  echo -e ""
  echo -e ""
  curl -b session.txt -H "Content-Type: application/json" -X POST -d '{"id":2,"path":"target","uid":0,"gid":0,"permissions":"755"}' http://$EMS_ADDRESS/api/data_containers/1/create_dir
  echo -e ""
  echo -e ""
  curl -b session.txt -H "Content-Type: application/json" -X POST -d '{"name":"target","path":"target","user_mapping":"remap_all","uid":0,"gid":0,"access_permission":"read_write","client_rules_attributes":[],"namespace_scope":"global","data_type":"general_purpose","data_container_id":1}' http://$EMS_ADDRESS/api/exports
  echo -e ""
  echo -e ""
  echo -e "Create data container & 200GB NFS export /slurm/root"
  curl -b session.txt -H "Content-Type: application/json" -X POST -d '{"name":"slurm","dedup":0,"compression":1,"soft_quota":{"bytes":200000000000},"hard_quota":{"bytes":200000000000},"policy_id":1,"dir_uid":0,"dir_gid":0,"dir_permissions":"755","data_type":"general_purpose","namespace_scope":"global","exports_attributes":[{"name":"root","path":"/","user_mapping":"remap_all","uid":65534,"gid":65534,"access_permission":"read_write","client_rules_attributes":[],"namespace_scope":"global","data_type":"general_purpose"}]}' http://$EMS_ADDRESS/api/data_containers
}

establish_session $PASSWORD
create_data_container
