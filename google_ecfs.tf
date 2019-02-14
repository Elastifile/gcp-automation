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

variable "NODES_ZONES" {
  default = "us-central1-a"
}

variable "DEPLOYMENT_TYPE" {
  default = "dual"
}

variable "OPERATION_TYPE" {
  default = "none"
}

provider "google" {
  credentials = "${file("${var.CREDENTIALS}")}"
  project     = "${var.PROJECT}"
  region      = "${var.EMS_ZONE}"
}

resource "google_compute_instance" "Elastifile-EMS-Public" {
  count        = "${var.USE_PUBLIC_IP}"
  name         = "${var.CLUSTER_NAME}"
  machine_type = "n1-standard-4"
  zone         = "${var.EMS_ZONE}"

  tags = ["https-server"]

  boot_disk {
    initialize_params {
      image = "projects/elastifle-public-196717/global/images/${var.IMAGE}"
    }
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
  bash -c sudo\ sed\ -i\ \'/image_project=Elastifile-CI/c\\image_project=elastifle-public-196717\'\ /elastifile/emanage/deployment/cloud/init_cloud_google.sh
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
}

resource "google_compute_instance" "Elastifile-EMS-Private" {
  count        = "${1 - var.USE_PUBLIC_IP}"
  name         = "${var.CLUSTER_NAME}"
  machine_type = "n1-standard-4"
  zone         = "${var.EMS_ZONE}"

  tags = ["https-server"]

  boot_disk {
    initialize_params {
      image = "projects/elastifle-public-196717/global/images/${var.IMAGE}"
    }
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
  bash -c sudo\ sed\ -i\ \'/image_project=Elastifile-CI/c\\image_project=elastifle-public-196717\'\ /elastifile/emanage/deployment/cloud/init_cloud_google.sh
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
}

locals {
  public_ip = "${element(concat(google_compute_instance.Elastifile-EMS-Public.*.network_interface.0.access_config.0.nat_ip, list("")), 0)}"
  private_ip = "${element(concat(google_compute_instance.Elastifile-EMS-Private.*.network_interface.0.network_ip , list("")), 0)}"
  ems_address = "${var.USE_PUBLIC_IP ? local.public_ip : local.private_ip}"
}
resource "null_resource" "cluster" {
  provisioner "local-exec" {
     command     = "${path.module}/create_vheads.sh -c ${var.TEMPLATE_TYPE} -l ${var.LB_TYPE} -t ${var.DISK_TYPE} -n ${var.NUM_OF_VMS} -d ${var.DISK_CONFIG} -v ${var.VM_CONFIG} -p ${local.ems_address} -s ${var.DEPLOYMENT_TYPE} -a ${var.NODES_ZONES} -e ${var.COMPANY_NAME} -f ${var.CONTACT_PERSON_NAME} -g ${var.EMAIL_ADDRESS} -i ${var.ILM} -k ${var.ASYNC_DR} -j ${var.LB_VIP} -b ${var.DATA_CONTAINER} -r ${var.CLUSTER_NAME}"
    interpreter = ["/bin/bash", "-c"]
  }

  depends_on = ["google_compute_instance.Elastifile-EMS-Public", "google_compute_instance.Elastifile-EMS-Private"]

  provisioner "local-exec" {
    when        = "destroy"
    command     = "${path.module}/destroy_vheads.sh -c ${var.CLUSTER_NAME} -a ${var.NODES_ZONES}"
    interpreter = ["/bin/bash", "-c"]
  }
}

resource "null_resource" "google_ilb" {
  count = "${var.LB_TYPE == "google" ? 1 : 0}"

  provisioner "local-exec" {
    command     = "${path.module}/create_google_ilb.sh -n ${var.NETWORK} -s ${var.SUBNETWORK} -z ${var.EMS_ZONE} -c ${var.CLUSTER_NAME} -a ${var.NODES_ZONES} -e ${var.SERVICE_EMAIL} -p ${var.PROJECT}"
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
