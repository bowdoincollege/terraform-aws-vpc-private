terraform {
  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "bowdoincollege"
    workspaces {
      prefix = "noc-privatevpctest-"
    }
  }
}

provider "aws" {
  region  = "us-east-1"
  version = "~> 2.0"
}

data "terraform_remote_state" "cc" {
  backend = "remote"
  config = {
    organization = "bowdoincollege"
    workspaces = {
      name = "noc-cloudconnect-aws"
    }
  }
}

locals {
  cidr   = "192.168.0.0/16"
  azs    = ["a", "b"]
  region = "us-east-1"
  tgw_id = data.terraform_remote_state.cc.outputs.tgw_ids["usea1"]
}

resource "aws_vpc" "this" {
  cidr_block           = local.cidr
  enable_dns_hostnames = true
}

resource "aws_subnet" "private" {
  for_each          = { for az in local.azs : az => az }
  vpc_id            = aws_vpc.this.id
  availability_zone = join("", [local.region, each.key])
  cidr_block        = cidrsubnet(aws_vpc.this.cidr_block, 4, index(local.azs, each.key))
}

resource "aws_ec2_transit_gateway_vpc_attachment" "private" {
  subnet_ids         = [for subnet in aws_subnet.private : subnet.id]
  transit_gateway_id = local.tgw_id
  vpc_id             = aws_vpc.this.id

  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false
}


resource "aws_ec2_transit_gateway_route_table_association" "common" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.private.id
  transit_gateway_route_table_id = data.terraform_remote_state.cc.outputs.route_tables["usea1"]["private"].id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block         = "139.140.0.0/16"
    transit_gateway_id = local.tgw_id
  }
  route {
    cidr_block         = "10.0.0.0/8"
    transit_gateway_id = local.tgw_id
  }
  route {
    cidr_block         = "192.168.0.0/16"
    transit_gateway_id = local.tgw_id
  }
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
}

resource "aws_route_table_association" "private" {
  for_each       = { for az in local.azs : az => az }
  subnet_id      = aws_subnet.private[each.key].id
  route_table_id = aws_route_table.private.id
}

# temp igw for testing
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
}
