# Create private subnets if CIDRs provided
resource "aws_subnet" "private" {
  count                   = local.using_new_subnets ? 3 : 0
  vpc_id                  = var.vpc_id
  cidr_block              = var.subnet_cidr_blocks[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = false

  tags = merge(var.tags, {
    Name = "${var.name}-private-${count.index + 1}"
    Tier = "private"
  })
}

# Optional route table associations for created subnets
resource "aws_route_table_association" "private" {
  count          = local.using_new_subnets && length(var.route_table_ids) == 3 ? 3 : 0
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = var.route_table_ids[count.index]
}

locals {
  effective_subnet_ids = local.using_existing_subnets ? var.subnet_ids : [for s in aws_subnet.private : s.id]
}

# Security group for Lambda ENIs
resource "aws_security_group" "lambda" {
  name        = "${var.name}-lambda"
  description = "Security group for Lambda (${var.name})"
  vpc_id      = var.vpc_id

  # Default: no ingress. Egress open so Lambda can reach S3 via NAT, VPC endpoint, etc.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name}-lambda" })
}