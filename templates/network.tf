# ----------Outputs-------------
output "env" {
  value = var.env
}

output "vpc_id" {
  value = aws_vpc.vpc.id
}

output "public_subnet_ids" {
  value = aws_subnet.public.*.id
}

output "private_subnet_ids" {
  value = aws_subnet.private.*.id
}

output "private_route_table_ids" {
  value = aws_route.private.*.id
}

# ----------Variables-----------
locals {
  combined_tags = merge(null_resource.tags.triggers, var.custom_tags)
}

variable "cidr_block" {
  type = string
}

variable "env" {
  type = string
}

variable "custom_tags" {
  type    = map
  default = {}
}

# ----------Resources-----------

# tags to identify resources easily.
resource "null_resource" "tags" {
  triggers = {
    Name = "ashwiniag-${var.env}"
  }
}

resource "aws_vpc" "vpc" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = merge(local.combined_tags, tomap({ Type = "vpc" }))
}

# public subnets, 1 in each AZ
resource "aws_subnet" "public" {
  count                   = lookup(null_resource.zone_count.triggers, "total")
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  cidr_block              = cidrsubnet(aws_vpc.vpc.cidr_block, 3, count.index)
  map_public_ip_on_launch = true
  vpc_id                  = aws_vpc.vpc.id
  tags                    = merge(local.combined_tags, tomap({
    Type                                     = "public-subnet",
    "kubernetes.io/role/elb"                 = 1,
    "kubernetes.io/cluster/ashwiniag-${var.env}" = "shared"
  }))
}

resource "aws_subnet" "private" {
  count                   = lookup(null_resource.zone_count.triggers, "total")
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  cidr_block              = cidrsubnet(aws_vpc.vpc.cidr_block, 3, count.index + 4)
  map_public_ip_on_launch = false
  vpc_id                  = aws_vpc.vpc.id
  tags                    = merge(local.combined_tags, tomap({
    Type                                     = "private-subnet",
    "kubernetes.io/role/internal-elb"        = 1,
    "kubernetes.io/cluster/ashwiniag-${var.env}" = "shared"
  }))
}

# Internet gateway
resource "aws_internet_gateway" "ig" {
  vpc_id = aws_vpc.vpc.id
  tags   = merge(local.combined_tags, tomap({ "Type" = "ig" }))
}

# EIP for NAT, count == AZ count
resource "aws_eip" "nat" {
  count = lookup(null_resource.zone_count.triggers, "total")
  vpc   = true
  tags  = merge(local.combined_tags, tomap({ "Type" = "nat-eip" }))
}

# NAT gateway
resource "aws_nat_gateway" "nat" {
  count         = lookup(null_resource.zone_count.triggers, "total")
  allocation_id = element(aws_eip.nat.*.id, count.index)
  subnet_id     = element(aws_subnet.public.*.id, 0)
  tags          = merge(local.combined_tags, tomap({ "Type" = "nat" }))
}

# Route table, 1 for each public subnet
resource "aws_route_table" "public" {
  count  = lookup(null_resource.zone_count.triggers, "total")
  vpc_id = aws_vpc.vpc.id
  tags   = merge(local.combined_tags, tomap({ "Type" = "public-route-table" }))
}

# Route table, 1 for each private subnet
resource "aws_route_table" "private" {
  count  = lookup(null_resource.zone_count.triggers, "total")
  vpc_id = aws_vpc.vpc.id
  tags   = merge(local.combined_tags, tomap({ "Type" = "private-route-table" }))
}

resource "aws_route" "public" {
  count                  = lookup(null_resource.zone_count.triggers, "total")
  route_table_id         = element(aws_route_table.public.*.id, count.index)
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.ig.id
}

resource "aws_route" "private" {
  count                  = lookup(null_resource.zone_count.triggers, "total")
  route_table_id         = element(aws_route_table.private.*.id, count.index)
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = element(aws_nat_gateway.nat.*.id, count.index)
}

# Associate route table to all subnets
resource "aws_route_table_association" "public" {
  count          = lookup(null_resource.zone_count.triggers, "total")
  route_table_id = element(aws_route_table.public.*.id, count.index)
  subnet_id      = element(aws_subnet.public.*.id, count.index)
}

resource "aws_route_table_association" "private" {
  count          = lookup(null_resource.zone_count.triggers, "total")
  route_table_id = element(aws_route_table.private.*.id, count.index)
  subnet_id      = element(aws_subnet.private.*.id, count.index)
}

# ---------links snf further possible blog post
# Some cool functions used in my terraform scripts.
# slice: https://www.terraform.io/language/functions/slice
# split: https://www.terraform.io/language/functions/split
# min:   https://www.terraform.io/language/functions/min
#lookup: https://www.terraform.io/language/functions/lookup
# cidrsubnet: https://www.terraform.io/language/functions/cidrsubnet
# tomap: https://www.terraform.io/language/functions/tomap
# element: https://www.terraform.io/language/functions/element

