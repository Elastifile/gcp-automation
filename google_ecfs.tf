variable "DISK_TYPE" {
  default = "persistent"
}

variable "TEMPLATE_TYPE" {
  default = "medium"
}

variable "LB_TYPE" {
  default = "elastifile"
}

variable "VM_CONFIG" {
  default = "4_42"
}

variable "NUM_OF_VMS" {
  default = "3"
}

variable "DISK_CONFIG" {
  default = "5_2000"
}

variable "CLUSTER_NAME" {}

variable "COMPANY_NAME" {}

variable "CONTACT_PERSON_NAME" {}

variable "EMAIL_ADDRESS" {}

variable "IMAGE" {}

variable "SETUP_COMPLETE" {
  default = "false"
}

variable "PASSWORD_IS_CHANGED" {
  default = "false"
}

variable "PASSWORD" {
  default = "changeme"
}

variable "REGION" {
  default = "us-central1"
}

variable "EMS_ZONE" {
  default = "us-central1-a"
}

variable "NETWORK" {
  default = "default"
}

variable "SUBNETWORK" {
  default = "default"
}

variable "PROJECT" {}

variable "CREDENTIALS" {}

variable "SERVICE_EMAIL" {}

variable "USE_PUBLIC_IP" {
  default = true
}

variable "ILM" {
  default = "false"
}

variable "ASYNC_DR" {
  default = "false"
}

variable "LB_VIP" {
  default = "auto"
}

variable "DATA_CONTAINER" {
  default = "DC01"
}

variable "EMS_ONLY" {
  default = "false"
}

variable "NODES_ZONES" {
  default = "us-central1-a"
}

variable "DEPLOYMENT_TYPE" {
  default = "dual"
}

variable "OPERATION_TYPE" {
  default = "none"
}

variable "KMS_KEY" {
  default = ""
}

variable "SSH_CREDENTIALS" {}

variable "NO_PROXY" {
  default = "127.0.0.1,169.254.169.254,metadata,metadata.google.insternal,localhost,*.google.internal"
}

variable "PROXY_IP" {}

variable "PROXY_PORT" {}

variable "DNS_SERVER_1" {}

variable "DNS_SERVER_2" {}

variable "DOMAIN_NAME" {}

variable "DOMAIN_SEARCH" {}

provider "google" {
  credentials = "${file("${var.CREDENTIALS}")}"
  project     = "${var.PROJECT}"
  region      = "${var.REGION}"
}


#----------------------------------------------------------------------------------------------------
#   Acquire a static internal address for the google ILB that will serve the Elastifile NFS exports.
#----------------------------------------------------------------------------------------------------

resource "google_compute_address" "google-ilb-static-vip" {
  count = "${var.LB_TYPE == "google" ? 1 : 0}"
  name         = "google-ilb-static-vip-${var.CLUSTER_NAME}"
  address_type = "INTERNAL"
  #subnetwork   = "https://www.googleapis.com/compute/v1/projects/${var.PROJECT}/regions/${var.REGION}/subnetworks/${var.SUBNETWORK}"
  subnetwork   = "${var.SUBNETWORK}"
}

# -------------------------------------------------
#  Create Boot Disk with Google or Customer Managed Keys
# -------------------------------------------------

resource "google_compute_disk" "ems-encrypted-boot-disk" {
  count = "${var.KMS_KEY != "" ? 1 : 0}"
  name  = "${var.CLUSTER_NAME}"
  zone  = "${var.EMS_ZONE}"
  size  = "100"
  image = "projects/elastifile-ci/global/images/${var.IMAGE}"
  disk_encryption_key{
        kms_key_self_link = "${var.KMS_KEY}"
   }
}

resource "google_compute_disk" "ems-boot-disk" {
  count = "${var.KMS_KEY == "" ? 1 : 0}"
  name  = "${var.CLUSTER_NAME}"
  zone  = "${var.EMS_ZONE}"
  size  = "100"
  image = "projects/elastifile-ci/global/images/${var.IMAGE}"
}

# -------------------------------------------------
#  Create Public/Private EMS
# -------------------------------------------------

resource "google_compute_instance" "Elastifile-EMS-Public" {
  count        = "${var.USE_PUBLIC_IP}"
  name         = "${var.CLUSTER_NAME}"
  machine_type = "n1-standard-8"
  zone         = "${var.EMS_ZONE}"

  tags = ["https-server"]

  labels = [
	{
        "cluster-hash"="${var.CLUSTER_NAME}"
	}
  ]

  boot_disk {
#    initialize_params {
#      image = "projects/elastifile-ci/global/images/${var.IMAGE}"
#    }
     source = "${local.boot_disk}"

  }

  network_interface {
    #specify only one:
    #network = "${var.NETWORK}"
    subnetwork = "${var.SUBNETWORK}"

    access_config {
      // Ephemeral IP
    }
  }

  metadata {
    ecfs_ems            = "true"
    reference_name      = "${var.CLUSTER_NAME}"
    version             = "${var.IMAGE}"
    template_type       = "${var.TEMPLATE_TYPE}"
    cluster_size        = "${var.NUM_OF_VMS}"
    use_load_balancer   = "${var.LB_TYPE}"
    disk_type           = "${var.DISK_TYPE}"
    disk_config         = "${var.DISK_CONFIG}"
    password_is_changed = "${var.PASSWORD_IS_CHANGED}"
    setup_complete      = "${var.SETUP_COMPLETE}"
    enable-oslogin      = "false"
  }

  metadata_startup_script = <<SCRIPT
  sudo echo prepend domain-name-servers 172.16.1.2; >> /etc/dhclient.conf
  sudo echo prepend domain-name-servers 172.16.1.4; >> /etc/dhclient.conf
  sudo echo prepend domain-name "mpclone.local"; >> /etc/dhclient.conf
  sudo echo prepend domain-search "mpclone.local"; >> /etc/dhclient.conf

  sudo echo CLOUD_ZONE=${var.EMS_ZONE} | tee -a /elastifile/conf/cloud_env.sh /etc/profile.d/proxy.sh
  sudo echo GOOGLE_APPLICATION_CREDENTIALS="/home/centos/credentials.json" | tee -a /elastifile/conf/cloud_env.sh /etc/profile.d/proxy.sh
  sudo echo CLOUD_PROJECT=${var.PROJECT} | tee -a /elastifile/conf/cloud_env.sh /etc/profile.d/proxy.sh
  sudo echo HOSTNAME=${var.CLUSTER_NAME} | tee -a /elastifile/conf/cloud_env.sh /etc/profile.d/proxy.sh
  sudo echo NO_PROXY=${var.NO_PROXY} | tee -a /elastifile/conf/cloud_env.sh /etc/profile.d/proxy.sh
  sudo echo http_proxy=${var.PROXY_IP}:${var.PROXY_PORT}/ | tee -a /elastifile/conf/cloud_env.sh /etc/profile.d/proxy.sh
  sudo echo FTP_PROXY=${var.PROXY_IP}:${var.PROXY_PORT}/ | tee -a /elastifile/conf/cloud_env.sh /etc/profile.d/proxy.sh
  sudo echo ftp_proxy=${var.PROXY_IP}:${var.PROXY_PORT}/ | tee -a /elastifile/conf/cloud_env.sh /etc/profile.d/proxy.sh
  sudo echo HTTPS_PROXY=${var.PROXY_IP}:${var.PROXY_PORT}/ | tee -a /elastifile/conf/cloud_env.sh /etc/profile.d/proxy.sh
  sudo echo https_proxy=${var.PROXY_IP}:${var.PROXY_PORT}/ | tee -a /elastifile/conf/cloud_env.sh /etc/profile.d/proxy.sh
  sudo echo no_proxy=${var.NO_PROXY} | tee -a /elastifile/conf/cloud_env.sh /etc/profile.d/proxy.sh
  sudo echo HTTP_PROXY=${var.PROXY_IP}:${var.PROXY_PORT}/ | tee -a /elastifile/conf/cloud_env.sh /etc/profile.d/proxy.sh
  sudo echo export GOOGLE_APPLICATION_CREDENTIALS NO_PROXY no_proxy http_proxy HTTP_PROXY https_proxy HTTPS_PROXY FTP_PROXY ftp_proxy CLOUD_ZONE CLOUD_PROJECT HOSTNAME | tee -a /elastifile/conf/cloud_env.sh /etc/profile.d/proxy.sh
  systemctl restart ecp
  bash -c sudo\ sed\ -i\ \'/image_project=Elastifile-CI/c\\image_project=Elastifile-CI\'\ /elastifile/emanage/deployment/cloud/init_cloud_google.sh 
  sudo echo type=subscription >> /elastifile/emanage/lic/license.gcp.lic
  sudo echo order_number=unlimited >> /elastifile/emanage/lic/license.gcp.lic
  sudo echo start_date=unlimited >> /elastifile/emanage/lic/license.gcp.lic
  sudo echo expiration_date=unlimited >> /elastifile/emanage/lic/license.gcp.lic
  sudo echo raw_capacity=unlimited >> /elastifile/emanage/lic/license.gcp.lic
  sudo echo hosts=unlimited >> /elastifile/emanage/lic/license.gcp.lic
  sudo echo customer_id=unlimited >> /elastifile/emanage/lic/license.gcp.lic
  sudo echo signature=sO9+j5Q/OPBaB+bMViAITGvN6by8vOYUrxNsOBYWZ4yBNqHj02iqpmqk2oxO XI3voLGhg6f0WW2MStEwxv46ia2iOjMZVCi/ekDL4nioYG3L5Sfzs/NMLI+D vlC36rkOfAkMrjkN9z1bRFNYwHCnXf58TC/W7RM6gimzRqpIz14= >> /elastifile/emanage/lic/license.gcp.lic
SCRIPT

  # specify the GCP project service account to use
  service_account {
    email  = "${var.SERVICE_EMAIL}"
    scopes = ["cloud-platform"]
  }
  
  # move the credentials json to the ems
  provisioner "file" {
    source      = "${var.CREDENTIALS}"
    destination = "/home/centos/credentials.json"
   
    connection {
      user        = "centos"
      private_key = "${file("${var.SSH_CREDENTIALS}")}"
    }
  }
}

resource "google_compute_instance" "Elastifile-EMS-Private" {
  count        = "${1 - var.USE_PUBLIC_IP}"
  name         = "${var.CLUSTER_NAME}"
  machine_type = "n1-standard-8"
  zone         = "${var.EMS_ZONE}"

  tags = ["https-server"]

labels = [
        {
        "cluster-hash"="${var.CLUSTER_NAME}"
        }
  ]

  boot_disk {
#    initialize_params {
#      image = "projects/elastifile-ci/global/images/${var.IMAGE}"
#    }
     source = "${local.boot_disk}"
  }

  network_interface {
    #specify only one:
    #network = "${var.NETWORK}"
    subnetwork = "${var.SUBNETWORK}"
  }

  metadata {
    ecfs_ems            = "true"
    reference_name      = "${var.CLUSTER_NAME}"
    version             = "${var.IMAGE}"
    template_type       = "${var.TEMPLATE_TYPE}"
    cluster_size        = "${var.NUM_OF_VMS}"
    use_load_balancer   = "${var.LB_TYPE}"
    disk_type           = "${var.DISK_TYPE}"
    disk_config         = "${var.DISK_CONFIG}"
    password_is_changed = "${var.PASSWORD_IS_CHANGED}"
    setup_complete      = "${var.SETUP_COMPLETE}"
    enable-oslogin      = "false"
  }

  metadata_startup_script = <<SCRIPT
  sudo echo prepend domain-name-servers 172.16.1.2; >> /etc/dhclient.conf
  sudo echo prepend domain-name-servers 172.16.1.4; >> /etc/dhclient.conf
  sudo echo prepend domain-name "mpclone.local"; >> /etc/dhclient.conf
  sudo echo prepend domain-search "mpclone.local"; >> /etc/dhclient.conf

  sudo echo CLOUD_ZONE=${var.EMS_ZONE} | tee -a /elastifile/conf/cloud_env.sh /etc/profile.d/proxy.sh
  sudo echo GOOGLE_APPLICATION_CREDENTIALS="/home/centos/credentials.json" | tee -a /elastifile/conf/cloud_env.sh /etc/profile.d/proxy.sh
  sudo echo CLOUD_PROJECT=${var.PROJECT} | tee -a /elastifile/conf/cloud_env.sh /etc/profile.d/proxy.sh
  sudo echo HOSTNAME=${var.CLUSTER_NAME} | tee -a /elastifile/conf/cloud_env.sh /etc/profile.d/proxy.sh
  sudo echo NO_PROXY=${var.NO_PROXY} | tee -a /elastifile/conf/cloud_env.sh /etc/profile.d/proxy.sh
  sudo echo http_proxy=${var.PROXY_IP}:${var.PROXY_PORT}/ | tee -a /elastifile/conf/cloud_env.sh /etc/profile.d/proxy.sh
  sudo echo FTP_PROXY=${var.PROXY_IP}:${var.PROXY_PORT}/ | tee -a /elastifile/conf/cloud_env.sh /etc/profile.d/proxy.sh
  sudo echo ftp_proxy=${var.PROXY_IP}:${var.PROXY_PORT}/ | tee -a /elastifile/conf/cloud_env.sh /etc/profile.d/proxy.sh
  sudo echo HTTPS_PROXY=${var.PROXY_IP}:${var.PROXY_PORT}/ | tee -a /elastifile/conf/cloud_env.sh /etc/profile.d/proxy.sh
  sudo echo https_proxy=${var.PROXY_IP}:${var.PROXY_PORT}/ | tee -a /elastifile/conf/cloud_env.sh /etc/profile.d/proxy.sh
  sudo echo no_proxy=${var.NO_PROXY} | tee -a /elastifile/conf/cloud_env.sh /etc/profile.d/proxy.sh
  sudo echo HTTP_PROXY=${var.PROXY_IP}:${var.PROXY_PORT}/ | tee -a /elastifile/conf/cloud_env.sh /etc/profile.d/proxy.sh
  sudo echo export GOOGLE_APPLICATION_CREDENTIALS NO_PROXY no_proxy http_proxy HTTP_PROXY https_proxy HTTPS_PROXY FTP_PROXY ftp_proxy CLOUD_ZONE CLOUD_PROJECT HOSTNAME | tee -a /elastifile/conf/cloud_env.sh /etc/profile.d/proxy.sh
  systemctl restart ecp
  bash -c sudo\ sed\ -i\ \'/image_project=Elastifile-CI/c\\image_project=Elastifile-CI\'\ /elastifile/emanage/deployment/cloud/init_cloud_google.sh
  sudo echo type=subscription >> /elastifile/emanage/lic/license.gcp.lic
  sudo echo order_number=unlimited >> /elastifile/emanage/lic/license.gcp.lic
  sudo echo start_date=unlimited >> /elastifile/emanage/lic/license.gcp.lic
  sudo echo expiration_date=unlimited >> /elastifile/emanage/lic/license.gcp.lic
  sudo echo raw_capacity=unlimited >> /elastifile/emanage/lic/license.gcp.lic
  sudo echo hosts=unlimited >> /elastifile/emanage/lic/license.gcp.lic
  sudo echo customer_id=unlimited >> /elastifile/emanage/lic/license.gcp.lic
  sudo echo signature=sO9+j5Q/OPBaB+bMViAITGvN6by8vOYUrxNsOBYWZ4yBNqHj02iqpmqk2oxO XI3voLGhg6f0WW2MStEwxv46ia2iOjMZVCi/ekDL4nioYG3L5Sfzs/NMLI+D vlC36rkOfAkMrjkN9z1bRFNYwHCnXf58TC/W7RM6gimzRqpIz14= >> /elastifile/emanage/lic/license.gcp.lic

SCRIPT

  # specify the GCP project service account to use
  service_account {
    email  = "${var.SERVICE_EMAIL}"
    scopes = ["cloud-platform"]
  }

  # move the credentials json to the ems
  provisioner "file" {
   source      = "${var.CREDENTIALS}" 
   destination = "/home/centos/credentials.json"
  
   connection {
      user        = "centos"
      private_key = "${file("${var.SSH_CREDENTIALS}")}"
    }
  }
}

locals {
  public_ip = "${element(concat(google_compute_instance.Elastifile-EMS-Public.*.network_interface.0.access_config.0.nat_ip, list("")), 0)}"
  private_ip = "${element(concat(google_compute_instance.Elastifile-EMS-Private.*.network_interface.0.network_ip , list("")), 0)}"
  ems_address = "${var.USE_PUBLIC_IP ? local.public_ip : local.private_ip}"
  google_lb_vip = "${element(concat(google_compute_address.google-ilb-static-vip.*.address, list("")), 0)}"
  lb_vip = "${var.LB_TYPE == "google" ? local.google_lb_vip : var.LB_VIP}"
  encrypted_boot_disk = "${element(concat(google_compute_disk.ems-encrypted-boot-disk.*.self_link, list("")), 0)}"
  non_encrypted_boot_disk = "${element(concat(google_compute_disk.ems-boot-disk.*.self_link, list("")), 0)}"
  boot_disk = "${var.KMS_KEY == "" ? local.non_encrypted_boot_disk : local.encrypted_boot_disk}"
}

resource "null_resource" "cluster" {
  count = "${var.EMS_ONLY == "false" ? 1 : 0}"
  provisioner "local-exec" {
     command     = "${path.module}/create_vheads.sh -c '${var.TEMPLATE_TYPE}' -l ${var.LB_TYPE} -t ${var.DISK_TYPE} -n ${var.NUM_OF_VMS} -d ${var.DISK_CONFIG} -v ${var.VM_CONFIG} -p ${local.ems_address} -s ${var.DEPLOYMENT_TYPE} -a ${var.NODES_ZONES} -e ${var.COMPANY_NAME} -f ${var.CONTACT_PERSON_NAME} -g ${var.EMAIL_ADDRESS} -i ${var.ILM} -k ${var.ASYNC_DR} -j ${local.lb_vip} -b ${var.DATA_CONTAINER} -r ${var.CLUSTER_NAME}"
    interpreter = ["/bin/bash", "-c"]
  }

  depends_on = ["google_compute_instance.Elastifile-EMS-Public", "google_compute_instance.Elastifile-EMS-Private", "google_compute_address.google-ilb-static-vip"]

  provisioner "local-exec" {
    when        = "destroy"
    command     = "${path.module}/destroy_vheads.sh -c ${var.CLUSTER_NAME} -a ${var.NODES_ZONES}"
    interpreter = ["/bin/bash", "-c"]
  }
}

resource "null_resource" "google_ilb" {
  count = "${var.LB_TYPE == "google" && var.EMS_ONLY == "false" ? 1 : 0}"
  
  provisioner "local-exec" {
    command     = "${path.module}/create_google_ilb.sh -n ${var.NETWORK} -s ${var.SUBNETWORK} -z ${var.EMS_ZONE} -c ${var.CLUSTER_NAME} -a ${var.NODES_ZONES} -e ${var.SERVICE_EMAIL} -p ${var.PROJECT} -v ${local.lb_vip}"
    interpreter = ["/bin/bash", "-c"]
  }

  depends_on = ["null_resource.cluster"]

  provisioner "local-exec" {
    when        = "destroy"
    command     = "${path.module}/destroy_google_ilb.sh -n ${var.NETWORK} -s ${var.SUBNETWORK} -z ${var.EMS_ZONE} -c ${var.CLUSTER_NAME} -a ${var.NODES_ZONES} -e ${var.SERVICE_EMAIL} -p ${var.PROJECT}"
    interpreter = ["/bin/bash", "-c"]
  }
}

resource "null_resource" "update_cluster" {
  count = "${var.SETUP_COMPLETE == "true" ? 1 : 0}"

  triggers {
    num_of_vms = "${var.NUM_OF_VMS}"
  }

  provisioner "local-exec" {
    command     = "${path.module}/update_vheads.sh -n ${var.NUM_OF_VMS} -a ${local.ems_address} -r ${var.CLUSTER_NAME} -l ${var.LB_TYPE} -e ${var.SERVICE_EMAIL} -p ${var.PROJECT}"
    interpreter = ["/bin/bash", "-c"]
  }

  depends_on = ["null_resource.cluster"]
}
