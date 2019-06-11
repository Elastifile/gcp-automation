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
  -b project
  -c name
  -d credentials
  -e dc
  -f dc description
  -g quota type
  -i hard quota
  -j snapshot
  -k snapshot scheduler
  -l snapshot retention
  -m acl range
  -n acl access rights
Examples:
  ./.sh -n 2 -a 1
E_O_F
  exit 1
}

#variables
SETUP_COMPLETE="false"
LOG="add_dc.log"
taskid=0

while getopts "h?:a:b:c:d:e:f:g:i:j:k:l:m:n:" opt; do
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
    d)  CREDENTIALS=${OPTARG}
        ;;
    e)  DC=${OPTARG}
        ;;
    f)  DC_DESCRIPTION=${OPTARG}
        ;;
    g)  QUOTA_TYPE=${OPTARG}
        ;;
    i)  HARD_QUOTA=${OPTARG}
        ;;
    j)  SNAPSHOT=${OPTARG}
        ;;
    k)  SNAPSHOT_SCHEDULER=${OPTARG}
        ;;
    l)  SNAPSHOT_RETENTION=${OPTARG}
        ;;
    m)  ACL_RANGE=${OPTARG}
        ;;
    n)  ACL_ACCESS_RIGHTS=${OPTARG}
        ;;
    esac
done

# Update the efaas capacity
function add_dc {
  export ELASTIFILE_APPLICATION_CREDENTIALS="$CREDENTIALS"
  source .env/bin/activate
  token=`python3.6 main.py`
  token=`echo "$token"|xargs`
  is_dc_exist=""
  fingerprint=$(curl -k -b -X  -H "accept: application/json" -H "$token" GET "$EFAAS_END_POINT/api/v2/projects/$PROJECT/instances/$NAME"| grep fingerprint| cut -d ":" -f2| awk 'NR==1{print $1}'| cut -d \" -f 2)
  is_dc_exist=$(curl -k -b -X  -H "accept: application/json" -H "$token" GET "$EFAAS_END_POINT/api/v2/projects/$PROJECT/instances/$NAME"| grep '"name": '| cut -d ":" -f2| cut -d \" -f 2|grep $DC)
  if [[ $is_dc_exist == $DC ]]; then
	echo -e "File System $DC is already exists .." | tee -a ${LOG}
	exit
  fi
  echo -e " Adding new FileSystem the eFaas instance - $DC"

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


  for index in ${!acl_range_array[*]}; do
      acl[index]='{"sourceRange": "'${acl_range_array[$index]}'", "accessRights": "'${acl_rights_array[$index]}'"}'
  done

  acl_vector=""
  for index in ${!acl[*]}; do
    acl_vector=$acl_vector${acl[$index]}","
  done

  inside_data=`echo ${acl_vector::-1}`
  accessor_data=' "accessors": { "items": [ '${inside_data}' ] }'

  json_data='{ "name": "'$DC'", "description": "'$DC_DESCRIPTION'", "quotaType": "'$QUOTA_TYPE'", "hardQuota": '$HARD_QUOTA', "snapshot": { "enable": '$SNAPSHOT', "schedule": "'$SNAPSHOT_SCHEDULER'", "retention": '$SNAPSHOT_RETENTION' }, '$accessor_data' }'


  result=$(curl -k -X POST "$EFAAS_END_POINT/api/v2/projects/$PROJECT/instances/$NAME/filesystem" -H "accept: application/json" -H "Content-Type: application/json" -d "$json_data" -H "$token")

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
    echo -e  "Adding new FileSystem $DC : ${STATUS} " | tee -a ${LOG}
    if [[ ${STATUS} == "DONE" ]]; then
      echo -e "Adding new FileSystem $DC - Complete! \n" | tee -a ${LOG}
      sleep 5
      break
    fi
    if [[ ${STATUS} == "ERROR" ]]; then
      echo -e "Adding new FileSystem $DC Failed. Exiting..\n" | tee -a ${LOG}
      exit 1
    fi
    sleep 10
  done
}

#MAIN
add_dc
