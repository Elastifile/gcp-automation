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

variable "IMAGE" {
  default = "elastifile-storage-3-2-1-51-ems"
}

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

variable "EMS_DISK_TYPE" {
  default = "pd-standard"
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
  default = "true"
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

variable "IMAGE_PROJECT" {
  default = "elastifile-ci"
}

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
  image = "projects/${var.IMAGE_PROJECT}/global/images/${var.IMAGE}"
  type = "${var.EMS_DISK_TYPE}"
  disk_encryption_key{
        kms_key_self_link = "${var.KMS_KEY}"
   }
}

resource "google_compute_disk" "ems-boot-disk" {
  count = "${var.KMS_KEY == "" ? 1 : 0}"
  name  = "${var.CLUSTER_NAME}"
  zone  = "${var.EMS_ZONE}"
  size  = "100"
  image = "projects/${var.IMAGE_PROJECT}/global/images/${var.IMAGE}"
  type = "${var.EMS_DISK_TYPE}"
}

# -------------------------------------------------
#  Create Public/Private EMS
# -------------------------------------------------

resource "google_compute_instance" "Elastifile-EMS-Public" {
  count        = "${var.USE_PUBLIC_IP == "true" ? 1 : 0}"
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
#      image = "projects/${var.IMAGE_PROJECT}/global/images/${var.IMAGE}"
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
  bash -c sudo\ sed\ -i\ \'/image_project=Elastifile-CI/c\\image_project=${var.IMAGE_PROJECT}\'\ /elastifile/emanage/deployment/cloud/init_cloud_google.sh
  sudo echo type=subscription >> /elastifile/emanage/lic/license.gcp.lic
  sudo echo order_number=GCP-Launcher >> /elastifile/emanage/lic/license.gcp.lic
  sudo echo start_date=18.03.2018 >> /elastifile/emanage/lic/license.gcp.lic
  sudo echo expiration_date=unlimited >> /elastifile/emanage/lic/license.gcp.lic
  sudo echo raw_capacity=320T >> /elastifile/emanage/lic/license.gcp.lic
  sudo echo hosts=32 >> /elastifile/emanage/lic/license.gcp.lic
  sudo echo customer_id=unlimited >> /elastifile/emanage/lic/license.gcp.lic
  sudo echo signature=qcTHRt/gDCi5q8U3F3cte9iwRqY0EBi/7yoGNQ7d3CaSWtOuMoYSz4wYQ8tO >> /elastifile/emanage/lic/license.gcp.lic
  sudo echo YLFdyXCyPQlFPSBIDzpVzo0UitJwzCIazf2ylTNDVZwXi+GchYvNn1znsrM/ >> /elastifile/emanage/lic/license.gcp.lic
  sudo echo gvcNeIC4aTBzdQ7aFFr7ZnVHlAs26OzDKeCF7Q9fsaVaBcljCi4= >> /elastifile/emanage/lic/license.gcp.lic
SCRIPT

  # specify the GCP project service account to use
  service_account {
    email  = "${var.SERVICE_EMAIL}"
    scopes = ["cloud-platform"]
  }
}

resource "google_compute_instance" "Elastifile-EMS-Private" {
  count        = "${var.USE_PUBLIC_IP == "false" ? 1 : 0}"
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
#      image = "projects/${var.IMAGE_PROJECT}/global/images/${var.IMAGE}"
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
  bash -c sudo\ sed\ -i\ \'/image_project=Elastifile-CI/c\\image_project=${var.IMAGE_PROJECT}\'\ /elastifile/emanage/deployment/cloud/init_cloud_google.sh
  sudo echo type=subscription >> /elastifile/emanage/lic/license.gcp.lic
  sudo echo order_number=GCP-Launcher >> /elastifile/emanage/lic/license.gcp.lic
  sudo echo start_date=18.03.2018 >> /elastifile/emanage/lic/license.gcp.lic
  sudo echo expiration_date=unlimited >> /elastifile/emanage/lic/license.gcp.lic
  sudo echo raw_capacity=320T >> /elastifile/emanage/lic/license.gcp.lic
  sudo echo hosts=32 >> /elastifile/emanage/lic/license.gcp.lic
  sudo echo customer_id=unlimited >> /elastifile/emanage/lic/license.gcp.lic
  sudo echo signature=qcTHRt/gDCi5q8U3F3cte9iwRqY0EBi/7yoGNQ7d3CaSWtOuMoYSz4wYQ8tO >> /elastifile/emanage/lic/license.gcp.lic
  sudo echo YLFdyXCyPQlFPSBIDzpVzo0UitJwzCIazf2ylTNDVZwXi+GchYvNn1znsrM/ >> /elastifile/emanage/lic/license.gcp.lic
  sudo echo gvcNeIC4aTBzdQ7aFFr7ZnVHlAs26OzDKeCF7Q9fsaVaBcljCi4= >> /elastifile/emanage/lic/license.gcp.lic
SCRIPT

  # specify the GCP project service account to use
  service_account {
    email  = "${var.SERVICE_EMAIL}"
    scopes = ["cloud-platform"]
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
    command     = "${path.module}/destroy_vheads.sh -c ${var.CLUSTER_NAME} -a ${var.NODES_ZONES} -b ${var.EMS_ZONE} -p ${var.PROJECT}"
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
