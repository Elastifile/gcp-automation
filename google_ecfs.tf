variable "DISKTYPE"{
  default = "local"
}
variable "NUM_OF_VMS"{
  default = "3"
}
variable "NUM_OF_DISKS"{
  default = "1"
}
variable "cluster_name"{
}

provider "google" {
//  credentials = "${file("andrew-sa-elastifile-sa.json")}"
  project     = "elastifile-sa"
  region      = "us-central1-a"
}

resource "google_compute_instance" "default" {
  name         = "${var.cluster_name}"
  machine_type = "n1-standard-2"
  zone         = "us-central1-a"

  tags = ["http-server"]

  boot_disk {
    initialize_params {
      image = "projects/elastifile-ci/global/images/emanage-2-1-0-9-0ca67e546044"
    }
  }

  // Local SSD disk
  scratch_disk {
  }

  network_interface {
    network = "default"

    access_config {
      // Ephemeral IP
    }
  }

  metadata {
    reference_name = "${var.cluster_name}"
  }

  metadata_startup_script = "echo hi > /test.txt"

  service_account {
    scopes = ["cloud-platform"]
  }
}
