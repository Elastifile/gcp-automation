# Terraform-Elastifile-GCP

Terraform to create, configure and deploy a Elastifile Cloud Filesystem (ECFS) cluster in Google Compute (GCE)

## Note:
Follow the Elastifile Cloud Deployment GCP Installation Guide to make sure ECFS can be successfully deployed in GCE before using this.

## Use:
1. Create password.txt file with a password to use for eManage  (.gitignore skips this file)
2. Specify configuration variables in terraform.tfvars:
- TEMPLATE_TYPE = small, medium, standard, custom
- NUM_OF_VMS = Number of ECFS virtual controllers, 3 minimum
- USE_LB = true to let ECFS setup a load balancer
- DISK_TYPE = local, ssd, or hdd. Only applies to custom templates
- DISK_CONFIG = [disks per vm]_[disk size in GB] example: "8_375" will create 8, 375GB disks. Only applies to custom templates
- VM_CONFIG = [cpu cores per vm]_[ram per vm] example "20_128" will create 20 CPU, 128GB RAM VMs. Default: "4_42" Only applies to custom templates
- CLUSTER_NAME = Name for ECFS service, no longer than
- ZONE = Zone
- PROJECT = Project name
- NETWORK = VPC to use
- SUBNETWORK = Subnetwork to use
- IMAGE = EMS image name
- CREDENTIALS = path to service account credentials .json file
- SERVICE_EMAIL = service account email address
3. Run 'terraform init' then 'terraform apply'


## Components:

**google_ecfs.tf**
Main terraform configuration file.

**create_vheads.sh**
Bash script to configure Elastifile eManage (EMS) Server via Elastifile JSON REST API. EMS will deploy cluster of ECFS virtual controllers (vheads). Called as null_provider from google_ecfs.tf

**destroy_vheads.sh**
Bash script to query and delete multiple GCE instances and network resources simultaneously. Called as null_provider destroy from google_ecfs.tf

**password.txt**
Plaintext file with EMS password
