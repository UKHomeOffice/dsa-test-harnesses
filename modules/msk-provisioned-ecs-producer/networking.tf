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
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = local.private_route_table_ids[tonumber(each.key)]
}
