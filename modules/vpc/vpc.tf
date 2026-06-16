resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name      = var.vpc_name
    ManagedBy = "Terraform"
  }
}

resource "aws_subnet" "public" {
  count = length(var.public_subnets)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnets[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name      = "${var.vpc_name}-public-${count.index + 1}"
    Type      = "Public"
    ManagedBy = "Terraform"
  }
}

resource "aws_subnet" "private" {
  count = length(var.private_subnets)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnets[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name      = "${var.vpc_name}-private-${count.index + 1}"
    Type      = "Private"
    ManagedBy = "Terraform"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name      = "${var.vpc_name}-igw"
    ManagedBy = "Terraform"
  }
}

resource "aws_eip" "nat" {
  count  = length(var.public_subnets)
  domain = "vpc"

  tags = {
    Name      = "${var.vpc_name}-nat-eip-${count.index + 1}"
    ManagedBy = "Terraform"
  }

  depends_on = [aws_internet_gateway.main]
}

resource "aws_nat_gateway" "main" {
  count = length(var.public_subnets)

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name      = "${var.vpc_name}-nat-${count.index + 1}"
    ManagedBy = "Terraform"
  }

  depends_on = [aws_internet_gateway.main]
}
