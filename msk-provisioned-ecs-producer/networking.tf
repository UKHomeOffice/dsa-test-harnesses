locals {
  merged_tags = merge(var.tags, { "Module" = "msk-provisioned-ecs-producer", "Name" = var.name })
}

resource "aws_subnet" "private" {
  for_each = {
    for idx, cidr in var.private_subnet_cidrs :
    idx => { cidr = cidr, az = var.azs[idx] }
  }

  vpc_id                  = var.vpc_id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = false

  tags = merge(local.merged_tags, {
    "Name" = "${var.name}-private-${each.value.az}"
    "Tier" = "private"
  })
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = var.private_route_table_ids[tonumber(each.key)]
}
