variable "DISK_TYPE"{
  default = "persistent"
}
variable "TEMPLATE_TYPE"{
  default = "medium"
}
variable "VM_CONFIG"{
  default = "4_42"
}
variable "NUM_OF_VMS"{
  default = "3"
}
variable "DISK_CONFIG"{
  default = "5_2000"
}
variable "CLUSTER_NAME"{
}
variable "IMAGE"{
}
variable "SETUP_COMPLETE"{
  default = "false"
}
variable "PASSWORD_IS_CHANGED"{
  default = "false"
}
variable "PASSWORD"{
  default = "changeme"
}
variable "ZONE"{
  default = "us-central1-a"
}
variable "NETWORK"{
  default = "default"
}
variable "SUBNETWORK"{
  default = "default"
}
variable "PROJECT"{
}
variable "CREDENTIALS"{
}
variable "SERVICE_EMAIL"{
}

provider "google" {
  credentials = "${file("${var.CREDENTIALS}")}"
  project     = "${var.PROJECT}"
  region      = "${var.ZONE}"
}

resource "google_compute_instance" "Elastifile-ECFS" {
  name         = "${var.CLUSTER_NAME}"
  machine_type = "n1-standard-4"
  zone         = "${var.ZONE}"

  tags = ["https-server"]

  boot_disk {
    initialize_params {
      image = "projects/elastifile-ci/global/images/${var.IMAGE}"
    }
  }

  network_interface {
#    network = "${var.NETWORK}"
    subnetwork = "${var.SUBNETWORK}"

    access_config {
      // Ephemeral IP
    }
  }

  metadata {
    ecfs_ems = "true"
    reference_name = "${var.CLUSTER_NAME}"
    version = "${var.IMAGE}"
    disk_type = "${var.DISK_TYPE}"
    disk_config = "${var.DISK_CONFIG}"
    password_is_changed = "${var.PASSWORD_IS_CHANGED}"
    setup_complete = "${var.SETUP_COMPLETE}"
  }

  metadata_startup_script = "echo ${var.IMAGE} > /ecfs_image.txt"

# specify the GCP project service account to use
  service_account {
    email = "${var.SERVICE_EMAIL}"
    scopes = ["cloud-platform"]
  }

}

resource "null_resource" "create_cluster" {
  provisioner "local-exec" {
    command = "./create_vheads.sh -c ${var.TEMPLATE_TYPE} -t ${var.DISK_TYPE} -n ${var.NUM_OF_VMS} -d ${var.DISK_CONFIG} -v ${var.VM_CONFIG}"
    interpreter = ["/bin/bash","-c"]

  }

  depends_on = ["google_compute_instance.Elastifile-ECFS"]

  provisioner "local-exec" {
    when = "destroy"
    command = "./destroy_vheads.sh ${var.CLUSTER_NAME} ${var.ZONE}"
    interpreter = ["/bin/bash","-c"]
  }
}
