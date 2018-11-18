# Elastifile image version
IMAGE = "elastifile-storage-3-0-0-14-ems"
# "small" "medium" "large" "standard" "small standard" "local" "small local" "custom"
TEMPLATE_TYPE = "medium"
# number of vheads exlusive of EMS
NUM_OF_VMS = "3"
# <cpucores>_<ram> default: 4_42
VM_CONFIG = "4_42"
#local,persistent,hdd
DISK_TYPE = "local"
# <num_of_disks>_<disk_size>
DISK_CONFIG = "4_375"
# "true" "false"
USE_LB = false
# instance prefix
CLUSTER_NAME = "elastifile-storage"
# GCP zone
ZONE = "us-west1-c"
# GCP project
PROJECT = "elastifile-gce-lab-c323"
# GCP project subnetwork
SUBNETWORK = "default"
# GCP service account credential filename
CREDENTIALS = "elastifile-gce-lab-c323-4c9bbf952fce.json"
SERVICE_EMAIL = "terraform-sa-ooo@elastifile-gce-lab-c323.iam.gserviceaccount.com"
# true false
USE_PUBLIC_IP = true
# singlecopy
SINGLE_COPY = true
# singlezone
MULTI_ZONE = false

