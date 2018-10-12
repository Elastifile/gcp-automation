TEMPLATE_TYPE = "medium"
#small,medium,standard,custom
NUM_OF_VMS = "3"
USE_LB = "true"
DISK_TYPE = "local"
#local,ssd,hdd
VM_CONFIG = "20_128"
# <cpucores>_<ram> default: 4_42
DISK_CONFIG = "8_375"
# <num_of_disks>_<disk_size>
MIN_CLUSTER = "3"
CLUSTER_NAME = "elastifile-storage"
ZONE = "us-west1-c"
PROJECT = "elastifile-sa"
SUBNETWORK = "default"
IMAGE = "elastifile-storage-2-7-5-12-ems"
CREDENTIALS = "andrew-sa-elastifile-sa.json"
SERVICE_EMAIL = "andrew-sa@elastifile-sa.iam.gserviceaccount.com"
