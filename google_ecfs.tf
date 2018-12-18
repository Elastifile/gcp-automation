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

variable "NODES_ZONES" {
  default = "us-central1-a"
}

variable "DEPLOYMENT_TYPE"{
  default = "dual"
}

variable "OPERATION_TYPE"{
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
  }

  metadata_startup_script = <<SCRIPT
  bash -c sudo\ sed\ -i\ \'/image_project=Elastifile-CI/c\\image_project=elastifle-public-196717\'\ /elastifile/emanage/deployment/cloud/init_cloud_google.sh
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
  }

  metadata_startup_script = <<SCRIPT
  bash -c sudo\ sed\ -i\ \'/image_project=Elastifile-CI/c\\image_project=elastifle-public-196717\'\ /elastifile/emanage/deployment/cloud/init_cloud_google.sh
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

resource "null_resource" "cluster" {
  provisioner "local-exec" {
    command     = "./create_vheads.sh -c ${var.TEMPLATE_TYPE} -l ${var.LB_TYPE} -t ${var.DISK_TYPE} -n ${var.NUM_OF_VMS} -d ${var.DISK_CONFIG} -v ${var.VM_CONFIG} -p ${var.USE_PUBLIC_IP} -s ${var.DEPLOYMENT_TYPE} -a ${var.NODES_ZONES} -e ${var.COMPANY_NAME} -f ${var.CONTACT_PERSON_NAME} -g ${var.EMAIL_ADDRESS}"
    interpreter = ["/bin/bash", "-c"]
  }

  depends_on = ["google_compute_instance.Elastifile-EMS-Public", "google_compute_instance.Elastifile-EMS-Private"]

  provisioner "local-exec" {
    when        = "destroy"
    command     = "./destroy_vheads.sh -c ${var.CLUSTER_NAME} -a ${var.NODES_ZONES}"
    interpreter = ["/bin/bash", "-c"]
  }
}
resource "null_resource" "google_ilb" {
  count = "${var.LB_TYPE == "google" ? 1 : 0}"
  provisioner "local-exec" {
    command     = "./create_google_ilb.sh -n ${var.NETWORK} -s ${var.SUBNETWORK} -z ${var.EMS_ZONE} -c ${var.CLUSTER_NAME} -a ${var.NODES_ZONES} -e ${var.SERVICE_EMAIL} -p ${var.PROJECT}"
    interpreter = ["/bin/bash", "-c"]
  }

  depends_on = ["null_resource.cluster"]
  
  provisioner "local-exec" {
    when        = "destroy"
    command     = "./destroy_google_ilb.sh -n ${var.NETWORK} -s ${var.SUBNETWORK} -z ${var.EMS_ZONE} -c ${var.CLUSTER_NAME} -a ${var.NODES_ZONES} -e ${var.SERVICE_EMAIL} -p ${var.PROJECT}"
    interpreter = ["/bin/bash", "-c"]
  }
}

resource "null_resource" "update_cluster" {
  count = "${var.SETUP_COMPLETE == "true" ? 1 : 0}"
  
  triggers {
    num_of_vms = "${var.NUM_OF_VMS}"
  }

  provisioner "local-exec" {
    command     = "./update_vheads.sh -n ${var.NUM_OF_VMS} -a ${var.USE_PUBLIC_IP} -l ${var.LB_TYPE} -e ${var.SERVICE_EMAIL} -p ${var.PROJECT}"
    interpreter = ["/bin/bash", "-c"]
  }
  depends_on = ["null_resource.cluster"]
}
