#!/usr/bin/env bash
set -u

# function code from https://gist.github.com/cjus/1047794 by itstayyab
function jsonValue() {
KEY=$1
 awk -F"[,:}]" '{for(i=1;i<=NF;i++){if($i~/'${KEY}'\042/){print $(i+1)}}}' | tr -d '"'| tr '\n' ','
}

usage() {
  cat << E_O_F
Usage:
Parameters:
  -a efaas end point
  -b projects
  -c name
  -d acl range 
  -e credentials
  -f acl access rights
  -g dc name
  -i snapshot true or false
  -j snapshot scheduler
  -k snapshot retention
  -l quota tyoe
  -m hard quota

Examples:
  ./.sh -n 2 -a 1
E_O_F
  exit 1
}

#variables
SETUP_COMPLETE="false"
LOG="update_dc.log"

while getopts "h?:a:b:c:d:e:f:g:i:j:k:l:m:" opt; do
    case "$opt" in
    h|\?)
        usage
        exit 0
        ;;
    a)  EFAAS_END_POINT=${OPTARG}
        ;;
    b)  PROJECT=${OPTARG}
        ;;
    c)  NAME=${OPTARG}
        ;;
    d)  ACL_RANGE=${OPTARG}
        ;;
    e)  CREDENTIALS=${OPTARG}
        ;;
    f)  ACL_ACCESS_RIGHTS=${OPTARG}
        ;;
    g)  DC=${OPTARG}
        ;;
    i)  SNAPSHOT=${OPTARG}
        ;;
    j)  SNAPSHOT_SCHEDULER=${OPTARG}
        ;;
    k)  SNAPSHOT_RETENTION=${OPTARG}
        ;;
    l)  QUOTA_TYPE=${OPTARG}
        ;;
    m)  HARD_QUOTA=${OPTARG}
        ;;
    esac
done

# Update the efaas dc
function update_efaas_dc {
  export ELASTIFILE_APPLICATION_CREDENTIALS="$CREDENTIALS"
  source .env/bin/activate
  token=`python3.6 main.py`
  token=`echo "$token"|xargs`

# checking the dc fingerprint
  fingerprint=$(curl -k -b -X  -H "accept: application/json" -H "$token" GET "$EFAAS_END_POINT/api/v2/projects/$PROJECT/instances/$NAME"| grep -B 3 -A 50 '"name": "'$DC'"',| grep "fingerprint"| cut -d ":" -f 2| cut -d \" -f 2)  
  echo "$fingerprint"
# checking the dc id
  dc_id=$(curl -k -b -X  -H "accept: application/json" -H "$token" GET "$EFAAS_END_POINT/api/v2/projects/$PROJECT/instances/$NAME"| grep -B 3 -A 4 '"name": "'$DC'"',| grep "id"| cut -d ":" -f 2| cut -d \" -f 2)
  echo "$dc_id"

# creating an array for the acl range
  i=0
  for index in ${ACL_RANGE//,/ }
     do acl_range_array[$i]=$index
     i=$((i+1))" "
  done

# creating an array for the acl access rights
  i=0
  for index in ${ACL_ACCESS_RIGHTS//,/ }
     do acl_rights_array[$i]=$index
     i=$((i+1))" "
  done

  echo "Number of ACLs - $i"
# updating the filesystem acl
  echo -e "Updating filesystem acl.." | tee -a ${LOG}
  if (( $i == 1 )); then
        result=$(curl -k -X POST "$EFAAS_END_POINT/api/v2/projects/$PROJECT/instances/$NAME/filesystem/$dc_id/setAccessors" -H "accept: application/json" -H "Content-Type: application/json" -d "{ \"items\": [ { \"sourceRange\": \"${acl_range_array[0]}\", \"accessRights\": \"${acl_rights_array[0]}\" } ], \"fingerprint\": \"$fingerprint\" }" -H "$token") 
  elif (( $i == 2 )); then
 	result=$(curl -k -X POST "$EFAAS_END_POINT/api/v2/projects/$PROJECT/instances/$NAME/filesystem/$dc_id/setAccessors" -H "accept: application/json" -H "Content-Type: application/json" -d "{ \"items\": [ { \"sourceRange\": \"${acl_range_array[0]}\", \"accessRights\": \"${acl_rights_array[0]}\" }, { \"sourceRange\": \"${acl_range_array[1]}\", \"accessRights\": \"${acl_rights_array[1]}\" } ], \"fingerprint\": \"$fingerprint\" }" -H "$token")
  elif (( $i == 3 )); then
	result=$(curl -k -X POST "$EFAAS_END_POINT/api/v2/projects/$PROJECT/instances/$NAME/filesystem/$dc_id/setAccessors" -H "accept: application/json" -H "Content-Type: application/json" -d "{ \"items\": [ { \"sourceRange\": \"${acl_range_array[0]}\", \"accessRights\": \"${acl_rights_array[0]}\" }, { \"sourceRange\": \"${acl_range_array[1]}\", \"accessRights\": \"${acl_rights_array[1]}\" }, { \"sourceRange\": \"${acl_range_array[2]}\", \"accessRights\": \"${acl_rights_array[2]}\" } ], \"fingerprint\": \"$fingerprint\" }" -H "$token")
  elif (( $i == 4 )); then
  result=$(curl -k -X POST "$EFAAS_END_POINT/api/v2/projects/$PROJECT/instances/$NAME/filesystem/$dc_id/setAccessors" -H "accept: application/json" -H "Content-Type: application/json" -d "{ \"items\": [ { \"sourceRange\": \"${acl_range_array[0]}\", \"accessRights\": \"${acl_rights_array[0]}\" }, { \"sourceRange\": \"${acl_range_array[1]}\", \"accessRights\": \"${acl_rights_array[1]}\" }, { \"sourceRange\": \"${acl_range_array[2]}\", \"accessRights\": \"${acl_rights_array[2]}\" }, { \"sourceRange\": \"${acl_range_array[3]}\", \"accessRights\": \"${acl_rights_array[3]}\" } ], \"fingerprint\": \"$fingerprint\" }" -H "$token")
  fi
# checking the filesystem acl status
  service_id=`echo $result| cut -d " " -f 3 | cut -d \" -f 2`
  echo $result | tee -a ${LOG}
  job_status $service_id
  sleep 5

# updating the filesystem snapshot
  echo -e "Updating filesystem snapshots.." | tee -a ${LOG}
  result=$(curl -k -X POST "$EFAAS_END_POINT/api/v2/projects/$PROJECT/instances/$NAME/filesystem/$dc_id/setScheduling" -H "accept: application/json" -H "Content-Type: application/json" -d "{ \"enable\": $SNAPSHOT, \"schedule\": \"$SNAPSHOT_SCHEDULER\", \"retention\": $SNAPSHOT_RETENTION}" -H "$token")
# checking the filesystem snapshot status
  service_id=`echo $result| cut -d " " -f 3 | cut -d \" -f 2`
  echo $result | tee -a ${LOG}
  job_status $service_id

# updating the filesystem quota
  echo -e "Updating filesystem quota.." | tee -a ${LOG}
  result=$(curl -k -X POST "$EFAAS_END_POINT/api/v2/projects/$PROJECT/instances/$NAME/filesystem/$dc_id/setQuota" -H "accept: application/json" -H "Content-Type: application/json" -d "{ \"quotaType\": \"$QUOTA_TYPE\", \"hardQuota\": $HARD_QUOTA}" -H "$token")
# checking the filesystem quota status
  service_id=`echo $result| cut -d " " -f 3 | cut -d \" -f 2`
  echo $result | tee -a ${LOG}
  job_status $service_id

}

# Function to check running job status
function job_status {
  export ELASTIFILE_APPLICATION_CREDENTIALS="$CREDENTIALS"
  source .env/bin/activate
  token=`python3.6 main.py`
  token=`echo "$token"|xargs`
  
  while true; do
    STATUS=`curl -k -b -X  -H "accept: application/json" GET "$EFAAS_END_POINT/api/v2/projects/$PROJECT/operation/$1" -H "$token"| grep status| cut -d ":" -f2| awk 'NR==1{print $1}'| cut -d \" -f 2`
    echo -e  "update filesystem $DC : ${STATUS} " | tee -a ${LOG}
    
    if [[ ${STATUS} == "DONE" ]]; then
      echo -e "update efaas filesystem $DC Complete! \n" | tee -a ${LOG}
      sleep 5
      break
    fi
    if [[ ${STATUS} == "ERROR" ]]; then
      echo -e "update efaas filesystem $DC Failed. Exiting..\n" | tee -a ${LOG}
      exit 1
    fi
    sleep 10
  done
}

#MAIN
update_efaas_dc
