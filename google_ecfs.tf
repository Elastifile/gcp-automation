variable "DISK_TYPE" {
  default = "persistent"
}

variable "TEMPLATE_TYPE" {
  default = "medium"
}

variable "USE_LB" {
  default = true
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

variable "ZONE" {
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

variable "SINGLE_COPY" {
  default = true
}

variable "MULTI_ZONE" {
  default = false
}

provider "google" {
  credentials = "${file("${var.CREDENTIALS}")}"
  project     = "${var.PROJECT}"
  region      = "${var.ZONE}"
}

resource "google_compute_instance" "Elastifile-EMS-Public" {
  count        = "${var.USE_PUBLIC_IP}"
  name         = "${var.CLUSTER_NAME}"
  machine_type = "n1-standard-4"
  zone         = "${var.ZONE}"

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
    use_load_balancer   = "${var.USE_LB}"
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
  zone         = "${var.ZONE}"

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
    use_load_balancer   = "${var.USE_LB}"
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
    command     = "./create_enodes.sh -c ${var.TEMPLATE_TYPE} -l ${var.USE_LB} -t ${var.DISK_TYPE} -n ${var.NUM_OF_VMS} -d ${var.DISK_CONFIG} -v ${var.VM_CONFIG} -p ${var.USE_PUBLIC_IP} -s ${var.SINGLE_COPY} -m ${var.MULTI_ZONE}"
    interpreter = ["/bin/bash", "-c"]
  }

  depends_on = ["google_compute_instance.Elastifile-EMS-Public", "google_compute_instance.Elastifile-EMS-Private"]

  provisioner "local-exec" {
    when        = "destroy"
    command     = "./destroy_enodes.sh  ${var.CLUSTER_NAME} ${var.ZONE} ${var.USE_LB}  ${var.USE_PUBLIC_IP}  ${var.SINGLE_COPY}  ${var.MULTI_ZONE}  ${var.PROJECT}"
    interpreter = ["/bin/bash", "-c"]
  }
}
