#!/bin/bash
# Guy Rinkevich, Jan 2019

set -ux

#variables
SYSTEM_NAME_P="elastifile-guyr-aa"
SYSTEM_NAME_S="elastifile-guyr-bb"
EMS_ADDRESS_P="35.188.165.43"
EMS_ADDRESS_S="35.193.102.103"
SESSION_FILE_ECFS_P=session1.txt
SESSION_FILE_ECFS_S=session2.txt
PASSWORD_ECFS_P="changeme"
PASSWORD_ECFS_S="changeme"
RPO="5"
SNAP_RETENTION="2"
DC_NAME="dc"
SNAPSHOT_P="snap"
LOG="asyncdr-auto.log"
PROMOTE_SLAVE_DC="false"

#impliment command-line options

usage() {
  cat << E_O_F
Usage:
  -a primary cluster name
  -b primary ip address
  -c primary password 
  -d slave cluster name
  -e slave ip address
  -f slave password
  -g rpo
  -i snapshot retention
  -j dc name
  -k promote slave dc: "true" "false"
E_O_F
  exit 1
}

while getopts "h?:a:b:c:d:e:f:g:i:j:k:" opt; do
    case "$opt" in
    h|\?)
        usage
        exit 0
        ;;
    a)  SYSTEM_NAME_P=${OPTARG}
        ;;
    b)  EMS_ADDRESS_P=${OPTARG}
        ;;
    c)  PASSWORD_ECFS_P=${OPTARG}
        ;;
    d)  SYSTEM_NAME_S=${OPTARG}
        ;;
    e)  EMS_ADDRESS_S=${OPTARG}
        ;;
    f)  PASSWORD_ECFS_S=${OPTARG}
        ;;
    g)  RPO=${OPTARG}
        ;;
    i)  SNAP_RETENTION=${OPTARG}
        ;;
    j)  DC_NAME=${OPTARG}
        ;;
    k)  PROMOTE_SLAVE_DC=${OPTARG}
        ;;
    esac
done

#set -x

#establish https session
function establish_session {
  echo -e "Establishing https session..\n" | tee -a ${LOG}
  curl -k -D ${SESSION_FILE_ECFS_P} -H "Content-Type: application/json" -X POST -d '{"user": {"login":"admin","password":"'$PASSWORD_ECFS_P'"}}' https://$EMS_ADDRESS_P/api/sessions >> ${LOG} 2>&1
  curl -k -D ${SESSION_FILE_ECFS_S} -H "Content-Type: application/json" -X POST -d '{"user": {"login":"admin","password":"'$PASSWORD_ECFS_S'"}}' https://$EMS_ADDRESS_S/api/sessions >> ${LOG} 2>&1
  #curl -k -D ${SESSION_FILE_CC} -H "Content-Type: application/json" -X POST -d '{"user": {"login":"admin","password":"'$PASSWORD_CC'"}}' https://$CC_ADDRESS/elcc_api/sessions >> ${LOG} 2>&1
}


# asyncdr configuration
function site_pairing {
    if [[ $PROMOTE_SLAVE_DC == "false" ]]; then
        # Pair Primary and Secondary clusters
        pair_id="$(curl -k -b ${SESSION_FILE_ECFS_P} -H "Content-Type: application/json" -X POST -d '{"remote_site":{"remote_system_name":"'$SYSTEM_NAME_S'","ip_address":"'$EMS_ADDRESS_S'","login":"admin","password":"'$PASSWORD_ECFS_S'","local_login":"admin","local_password":"'$PASSWORD_ECFS_P'","local_ip_address":"'$EMS_ADDRESS_P'"}}'  https://$EMS_ADDRESS_P/api/remote_sites|grep "id"| cut -d ":" -f2| cut -d "," -f1 2>&1)"
        curl -k -b ${SESSION_FILE_ECFS_P} -H "Content-Type: application/json" -X POST -d '{"id":1,"ip_address":"'$EMS_ADDRESS_S'","login":"admin","password":"'$PASSWORD_ECFS_S'"}'  https://$EMS_ADDRESS_P/api/remote_sites/$pair_id/connect
   fi
}
function dc_pairing {
    if [[ $PROMOTE_SLAVE_DC == "false" ]]; then
        # Check the dc ID
        dc_id="$(curl -k -s -b ${SESSION_FILE_ECFS_P} -H "Content-Type: application/json" --request GET --url https://$EMS_ADDRESS_P/api/data_containers|grep -o -E '.{0,4}"name":"'$DC_NAME'"'| cut -d ":" -f2| cut -d "," -f1 2>&1)"    
        # Sync data containers
        #pair_id="$(curl -k -b ${SESSION_FILE_ECFS_P} -H "Content-Type: application/json" -X POST -d '{"dc_pair":{"remote_site_id":"'$connection_id'","rpo":"'$RPO'","snapshots_retention":"'$SNAP_RETENTION'","dr_role":"role_dc_active"}}'  https://$EMS_ADDRESS_P/api/data_containers/$dc_id/dc_pairs|grep "id"| cut -d ":" -f2| cut -d "," -f1 2>&1)"
        curl -k -b ${SESSION_FILE_ECFS_P} -H "Content-Type: application/json" -X POST -d '{"dc_pair":{"remote_site_id":"'$pair_id'","rpo":"'$RPO'","snapshots_retention":"'$SNAP_RETENTION'","dr_role":"role_dc_active"}}'  https://$EMS_ADDRESS_P/api/data_containers/$dc_id/dc_pairs
        # Connect the data containers pairing
        curl -k -b ${SESSION_FILE_ECFS_P} -H "Content-Type: application/json" -X POST   https://$EMS_ADDRESS_P/api/dc_pairs/$pair_id/connect
    fi
}

function promote_slave_dc {
    if [[ $PROMOTE_SLAVE_DC == "true" ]]; then
        # Check the dc ID
        dc_id="$(curl -k -s -b ${SESSION_FILE_ECFS_S} -H "Content-Type: application/json" --request GET --url https://$EMS_ADDRESS_S/api/data_containers|grep -o -E '.{0,4}"name":"'$DC_NAME'"'| cut -d ":" -f2| cut -d "," -f1 2>&1)"    
        # Check the pairing ID
        pair_id="$(curl -k -s -b ${SESSION_FILE_ECFS_S} -H "Content-Type: application/json" --request GET --url https://$EMS_ADDRESS_S/api/data_containers/$dc_id/dc_pairs|grep "id"| cut -d ":" -f2| cut -d "," -f1 2>&1)"
        # Disconnect the dc pairing
        curl -k -b ${SESSION_FILE_ECFS_S} -H "Content-Type: application/json" -X POST   https://$EMS_ADDRESS_S/api/data_containers/$dc_id/dc_pairs/$pair_id/disconnect
        # Create a new snapshot before promoting the slave dc
        echo -e "\nCreating Snapshot.. \n" | tee -a ${LOG}
        curl -k -b ${SESSION_FILE_ECFS_S} -H "Content-Type: application/json" -X POST -d '{"name":new_snap,"data_container_id":'$dc_id'}' https://$EMS_ADDRESS_S/api/snapshots
        # Force promote the slave DC
        curl -k -b ${SESSION_FILE_ECFS_S} -H "Content-Type: application/json" -X POST   https://$EMS_ADDRESS_S/api/data_containers/$dc_id/dc_pairs/$pair_id/force_promote
    fi
}

# Main
establish_session
site_pairing
dc_pairing
promote_slave_dc
