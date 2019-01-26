#!/bin/bash
#############################
# Must be run from inside EMS
#############################
set -x

# GCP vars to define
# IP for client NFS access to elastifile cluster in GCP
VIP="10.255.255.1/32"
# Host project name for SPVC
GCP_HOST_PROJECT="support-team-a"
# GCP Shared VPC name in host project
SHARED_VPC_NAME="support-team-a-vpc"
# EMS zone in service project
ZONE="us-central1-f"
# GCP enode instance name prefix in service project
ENODES_GCP_PRE="elastifile-ch-test-1-elfs"

# extract info from GCP for elastfile objects
# enode IP's
ENODES=`gcloud compute instances list  --sort-by 'NAME' --filter="$ENODES_GCP_PRE" | awk '{print $8}' | sed '1d'`
readarray -t ENODES_LIST <<<"$ENODES"
# enode count
NUM_ENODES=${#ENODES[@]}
# enode names
ENODES_GCP=`gcloud compute instances list  --sort-by 'NAME' --filter="$ENODES_GCP_PRE" | awk '{print $1}' | sed '1d'`
readarray -t ENODES_GCP_LIST <<<"$ENODES_GCP"
# enode zones
ENODES_ZONE=`gcloud compute instances list  --sort-by 'NAME' --filter="$ENODES_GCP_PRE" | awk '{print $2}' | sed '1d'`
readarray -t ENODES_ZONE_LIST <<<"$ENODES_ZONE"

# create payload for enode metadata-startup-script
rm -f configure_vip.sh
cat >> configure_vip.sh <<EOF
#!/bin/bash
ip address add ${VIP} dev eth0
EOF

# add metadata start-up script and create GCP ECMP routes for each enode
unset ENODES_LIST[0]
ENODES_LIST=( "${ENODES_LIST[@]}" )
declare -p ENODES_LIST
declare -p ENODES_GCP_LIST
declare -p ENODES_ZONE_LIST
  i=0
  for ENODE in ${ENODES_GCP}; do
  gcloud compute instances add-metadata ${ENODES_GCP_LIST[$i]} --zone ${ENODES_ZONE_LIST[$i]} --metadata-from-file startup-script=configure_vip.sh
  gcloud compute routes create el-route-${ENODES_GCP_LIST[$i]} --destination-range=$VIP --next-hop-address=${ENODES_LIST[$i]} --network=$SHARED_VPC_NAME --project=$GCP_HOST_PROJECT
  i=$((i+1))
done

# update enode to hot add VIP over SSH
for VHEAD in $ENODES; do
  ssh root@$VHEAD google_metadata_script_runner --script-type startup
  ssh root@$VHEAD journalctl -u google-startup-scripts.service
done

exit 0
