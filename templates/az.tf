variable "max_az" {
  default = 2
}

#https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones
data "aws_availability_zones" "available" {
  state = "available"
}

# This will find the zones, ex: ap-south-1a, ap-south-1b
resource "null_resource" "zones" {
  triggers = {
    names = join(",", slice(data.aws_availability_zones.available.names, 0, min(var.max_az, length(data.aws_availability_zones.available.names))))
  }
}

# This will count the zones based on max_az value.
resource "null_resource" "zone_count" {
  triggers = {
    total = length(split(",", lookup(null_resource.zones.triggers, "names")))
  }
}