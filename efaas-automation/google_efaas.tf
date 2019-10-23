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

variable "ACTION" {
  default = "Create_instance"
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

variable "DC" {
  default = "filesystem_1"
}

variable "DC_DESCRIPTION" {
  default = "filesystem_1"
}

variable "QUOTA_TYPE" {
  default = "auto"
}

variable "HARD_QUOTA" {
  default = "0"
}

resource "null_resource" "instance" {
  provisioner "local-exec" {
    command = "${path.module}/create_efaas.sh -a ${var.EFAAS_END_POINT} -b ${var.PROJECT} -c ${var.NAME} -d ${var.DESCRIPTION} -e ${var.REGION} -f ${var.ZONE} -g ${var.SERVICE_CLASS} -i ${var.NETWORK} -j ${var.ACL_RANGE} -k ${var.ACL_ACCESS_RIGHTS} -l ${var.SNAPSHOT} -m ${var.SNAPSHOT_SCHEDULER} -n ${var.SNAPSHOT_RETENTION} -o ${var.CAPACITY} -p ${var.CREDENTIALS} -q ${var.DC} -r ${var.DC_DESCRIPTION} -s ${var.QUOTA_TYPE} -t ${var.HARD_QUOTA}"

    interpreter = ["/bin/bash", "-c"]
  }

  provisioner "local-exec" {
    when        = "destroy"
    command     = "${path.module}/delete_efaas.sh -a ${var.EFAAS_END_POINT} -b ${var.PROJECT} -c ${var.NAME} -p ${var.CREDENTIALS}"
    interpreter = ["/bin/bash", "-c"]
  }
}

resource "null_resource" "update_dc" {
  count = "${var.ACTION == "Update_filesystem" ? 1 : 0}"

  triggers {
    range        = "${var.ACL_RANGE}"
    accessrights = "${var.ACL_ACCESS_RIGHTS}"
    snapshot     = "${var.SNAPSHOT}"
    schedule     = "${var.SNAPSHOT_SCHEDULER}"
    retention    = "${var.SNAPSHOT_RETENTION}"
    quotatype    = "${var.QUOTA_TYPE}"
    hardquota    = "${var.HARD_QUOTA}"
  }

  provisioner "local-exec" {
    command     = "${path.module}/update_dc.sh -a ${var.EFAAS_END_POINT} -b ${var.PROJECT} -c ${var.NAME} -d ${var.ACL_RANGE} -e ${var.CREDENTIALS} -f ${var.ACL_ACCESS_RIGHTS} -g ${var.DC} -i ${var.SNAPSHOT} -j ${var.SNAPSHOT_SCHEDULER} -k ${var.SNAPSHOT_RETENTION} -l ${var.QUOTA_TYPE} -m ${var.HARD_QUOTA}"
    interpreter = ["/bin/bash", "-c"]
  }

  depends_on = ["null_resource.instance"]
}

resource "null_resource" "update_instance" {
  count = "${var.ACTION == "Update_instance" ? 1 : 0}"

  triggers {
    capacity = "${var.CAPACITY}"
  }

  provisioner "local-exec" {
    command     = "${path.module}/update_efaas.sh -a ${var.EFAAS_END_POINT} -b ${var.PROJECT} -c ${var.NAME} -d ${var.CAPACITY} -e ${var.CREDENTIALS} -f ${var.SERVICE_CLASS}"
    interpreter = ["/bin/bash", "-c"]
  }

  depends_on = ["null_resource.instance"]
}

resource "null_resource" "add_dc" {
  count = "${var.ACTION == "Add_filesystem" ? 1 : 0}"

  triggers {
    datacontainer = "${var.DC}"
  }

  provisioner "local-exec" {
    command     = "${path.module}/add_dc.sh -a ${var.EFAAS_END_POINT} -b ${var.PROJECT} -c ${var.NAME} -d ${var.CREDENTIALS} -e ${var.DC} -f ${var.DC_DESCRIPTION} -g ${var.QUOTA_TYPE} -i ${var.HARD_QUOTA} -j ${var.SNAPSHOT} -k ${var.SNAPSHOT_SCHEDULER} -l ${var.SNAPSHOT_RETENTION} -m ${var.ACL_RANGE} -n ${var.ACL_ACCESS_RIGHTS}"
    interpreter = ["/bin/bash", "-c"]
  }

  depends_on = ["null_resource.instance"]
}

resource "null_resource" "delete_dc" {
  count = "${var.ACTION == "Delete_filesystem" ? 1 : 0}"

  triggers {
    datacontainer = "${var.DC}"
  }

  provisioner "local-exec" {
    command     = "${path.module}/delete_dc.sh -a ${var.EFAAS_END_POINT} -b ${var.PROJECT} -c ${var.NAME} -d ${var.CREDENTIALS} -e ${var.DC}"
    interpreter = ["/bin/bash", "-c"]
  }

  depends_on = ["null_resource.instance"]
}
