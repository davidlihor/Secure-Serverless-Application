module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.5"

  name = "${var.project_name}-vpc"
  cidr = "10.0.0.0/16"

  azs              = slice(data.aws_availability_zones.available.names, 0, 3)
  public_subnets   = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnets  = ["10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"]
  database_subnets = ["10.0.20.0/24", "10.0.21.0/24", "10.0.22.0/24"]

  enable_nat_gateway     = true
  single_nat_gateway     = !var.is_production
  one_nat_gateway_per_az = var.is_production

  enable_dns_hostnames    = true
  enable_dns_support      = true
  map_public_ip_on_launch = false

  enable_flow_log                      = true
  create_flow_log_cloudwatch_iam_role  = true
  create_flow_log_cloudwatch_log_group = true

  create_database_subnet_group       = true
  create_database_subnet_route_table = true
  database_subnet_group_name         = "${var.project_name}-db-subnet-group"

  public_subnet_tags = {
    Type = "public"
  }
  private_subnet_tags = {
    Type = "private"
  }
  database_subnet_tags = {
    Type = "database"
  }

  tags = {
    Name     = "${var.project_name}-vpc"
    Security = "High-Compliance"
  }
}
