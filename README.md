# Terraform-Elastifile-GCP

Terraform to create, configure and deploy a Elastifile Cloud Filesystem (ECFS) cluster in Google Compute (GCE)

Use:

1. Create password.txt file with a password (.gitignore skips this file)
2. Specify configuration variables in terraform.tvars
3. Run terraform init, terraform apply


Components

google_ecfs.tf
Main terraform configuration file.

create_vheads.sh
Bash script to configure Elastifile EManage (EMS) Server, and deploy cluster of ECFS virtual controllers (vheads). Uses Elastifile REST API. Called as null_provider from google_ecfs.tf 

destroy_vheads.sh
Bash script to query and delete multiple GCE instances simultaneously. Called as null_provider destroy from google_ecfs.tf 
