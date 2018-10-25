# Elastifile image version
IMAGE = "elastifile-storage-2-7-5-12-ems"
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
USE_LB = "true"
#
MIN_CLUSTER = "3"
# instance prefix
CLUSTER_NAME = "elastifile-storage"
# GCP zone
ZONE = "us-west1-c"
# GCP project
PROJECT = "elastifile-sa"
# GCP project subnetwork
SUBNETWORK = "default"
# GCP service account credential filename
CREDENTIALS = "andrew-sa-elastifile-sa.json"
SERVICE_EMAIL = "andrew-sa@elastifile-sa.iam.gserviceaccount.com"
