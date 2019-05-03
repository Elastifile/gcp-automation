
variable "EFAAS_END_POINT" {
  default = "https://golden-eagle.gcp.elastifile.com"
}

variable "PROJECT" {
  default = ""
}

variable "NAME" {
  default = "elastifile"
}

variable "DESCRIPTION" {
  default = "elastifile efaas"
}

variable "CAPACITY" {
  default = "3"
}

variable "SERVICE_CLASS" {
  default = "general-use"
}

variable "SETUP_COMPLETE" {
  default = "false"
}

variable "REGION" {
  default = "us-central1"
}

variable "ZONE" {
  default = "us-central1-f"
}

variable "NETWORK" {
  default = "default"
}

variable "ACL_RANGE" {
  default = "all"
}

variable "ACL_ACCESS_RIGHTS" {
  default = "readWrite"
}

variable "CREDENTIALS" {}

variable "SNAPSHOT" {
  default = "true"
}

variable "SNAPSHOT_SCHEDULER" {
  default = "Weekly"
}

variable "SNAPSHOT_RETENTION" {
  default = "10"
}

variable "DATA_CONTAINER" {
  default = "DC01"
}

variable "MULTIZONE" {
  default = "false"
}

locals {
  jwt = "${file("${var.CREDENTIALS}")}"
}

resource "null_resource" "instance" {
#  count = "${var.SETUP_COMPLETE == "false" ? 1 : 0}"
  provisioner "local-exec" {
     command	 = "${path.module}/create_efaas.sh -a ${var.EFAAS_END_POINT} -b ${var.PROJECT} -c ${var.NAME} -d ${var.DESCRIPTION} -e ${var.REGION} -f ${var.ZONE} -g ${var.SERVICE_CLASS} -i ${var.NETWORK} -j ${var.ACL_RANGE} -k ${var.ACL_ACCESS_RIGHTS} -l ${var.SNAPSHOT} -m ${var.SNAPSHOT_SCHEDULER} -n ${var.SNAPSHOT_RETENTION} -o ${var.CAPACITY} -p ${var.CREDENTIALS} -q ${var.MULTIZONE}"

    interpreter = ["/bin/bash", "-c"]
  }

#  depends_on = ["google_compute_instance.Elastifile-EMS-Public", "google_compute_instance.Elastifile-EMS-Private", "google_compute_address.google-ilb-static-vip"]

  provisioner "local-exec" {
    when        = "destroy"
    command     = "${path.module}/delete_efaas.sh -a ${var.EFAAS_END_POINT} -b ${var.PROJECT} -c ${var.NAME} -p ${var.CREDENTIALS}"
    interpreter = ["/bin/bash", "-c"]
  }
}

resource "null_resource" "update_acl" {
  count = "${var.SETUP_COMPLETE == "true" ? 1 : 0}"

  triggers {
    snapshot = "${var.ACL_RANGE}"
    schedule = "${var.ACL_ACCESS_RIGHTS}"
  }
 
  provisioner "local-exec" {
    command     = "${path.module}/update_efaas_acl.sh -a ${var.EFAAS_END_POINT} -b ${var.PROJECT} -c ${var.NAME} -d ${var.ACL_RANGE} -e ${var.CREDENTIALS} -f ${var.ACL_ACCESS_RIGHTS}"
    interpreter = ["/bin/bash", "-c"]
  }
  depends_on = ["null_resource.instance"]
}

resource "null_resource" "update_snapshot" {
  count = "${var.SETUP_COMPLETE == "true" ? 1 : 0}"

  triggers {
    snapshot = "${var.SNAPSHOT}"
    schedule = "${var.SNAPSHOT_SCHEDULER}"
    retention = "${var.SNAPSHOT_RETENTION}"
  }

  provisioner "local-exec" {
    command     = "${path.module}/update_efaas_snap.sh -a ${var.EFAAS_END_POINT} -b ${var.PROJECT} -c ${var.NAME} -d ${var.SNAPSHOT} -e ${var.CREDENTIALS} -f ${var.SNAPSHOT_SCHEDULER} -g ${var.SNAPSHOT_RETENTION}"
    interpreter = ["/bin/bash", "-c"]
  }
  depends_on = ["null_resource.instance"]

}

resource "null_resource" "update_instance" {
  count = "${var.SETUP_COMPLETE == "true" ? 1 : 0}"

  triggers {
    num_of_vms = "${var.CAPACITY}"
  }

  provisioner "local-exec" {
    command     = "${path.module}/update_efaas.sh -a ${var.EFAAS_END_POINT} -b ${var.PROJECT} -c ${var.NAME} -d ${var.CAPACITY} -e ${var.CREDENTIALS}"
    interpreter = ["/bin/bash", "-c"]
  }
  depends_on = ["null_resource.instance"]
}
