data "aws_ssoadmin_instances" "this" {
  region = var.region
}

locals {
  instance_arns      = tolist(data.aws_ssoadmin_instances.this.arns)
  identity_store_ids = tolist(data.aws_ssoadmin_instances.this.identity_store_ids)
}

resource "terraform_data" "instance" {
  input = local.instance_arns

  lifecycle {
    precondition {
      condition     = length(local.instance_arns) == 1 && length(local.identity_store_ids) == 1
      error_message = "Expected exactly one AWS Identity Center instance in ${var.region}; make sure the correct Region is configured."
    }
  }
}

data "aws_identitystore_user" "admin" {
  region            = var.region
  identity_store_id = one(local.identity_store_ids)

  alternate_identifier {
    unique_attribute {
      attribute_path  = "UserName"
      attribute_value = var.admin_user_name
    }
  }

  depends_on = [terraform_data.instance]
}
