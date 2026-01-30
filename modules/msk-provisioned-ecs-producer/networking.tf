resource "aws_subnet" "private" {
  count = local.len_private_subnets

  region = local.region

  availability_zone    = length(regexall("^[a-z]{2}-", element(local.azs, count.index))) > 0 ? element(local.azs, count.index) : null
  availability_zone_id = length(regexall("^[a-z]{2}-", element(local.azs, count.index))) == 0 ? element(local.azs, count.index) : null
  cidr_block           = element(concat(var.private_subnets, [""]), count.index)
  vpc_id               = var.vpc_id

  tags = merge(
    {
      Name = local.private_subnet_names[count.index]
    },
    local.merged_tags
  )
}

resource "aws_route_table_association" "private" {
  count = local.len_private_subnets

  subnet_id      = element(aws_subnet.private[*].id, count.index)
  route_table_id = local.private_route_table_ids[tonumber(count.index)]
}
