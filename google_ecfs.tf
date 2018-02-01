variable "DISKTYPE"{
  default = "local"
}
variable "NUM_OF_VMS"{
  default = "3"
}
variable "NUM_OF_DISKS"{
  default = "1"
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
  machine_type = "n1-standard-2"
  zone         = "${var.ZONE}"

  tags = ["https-server"]

  boot_disk {
    initialize_params {
      image = "projects/elastifile-ci/global/images/${var.IMAGE}"
    }
  }

  network_interface {
    network = "default"

    access_config {
      // Ephemeral IP
    }
  }

  metadata {
    ecfs_ems = "true"
    reference_name = "${var.CLUSTER_NAME}"
    password_is_changed = "${var.PASSWORD_IS_CHANGED}"
    setup_complete = "${var.SETUP_COMPLETE}"
  }

  metadata_startup_script = "echo hi > /test.txt"

# specify the GCP project service account to use
  service_account {
    email = "${var.SERVICE_EMAIL}"
    scopes = ["cloud-platform"]
  }

}

resource "null_resource" "create_cluster" {
  provisioner "local-exec" {
    command = "./create_vheads.sh -t ${var.DISKTYPE} -n ${var.NUM_OF_VMS} -m ${var.NUM_OF_DISKS}"
    interpreter = ["/bin/bash","-c"]

  }

  depends_on = ["google_compute_instance.Elastifile-ECFS"]

  provisioner "local-exec" {
    when = "destroy"
    command = "./destroy_vheads.sh ${var.CLUSTER_NAME} ${var.ZONE}"
    interpreter = ["/bin/bash","-c"]
  }
}
