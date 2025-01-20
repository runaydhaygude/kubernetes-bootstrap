terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.82"
    }
  }
}

provider "aws" {
    alias="mumbai"
    region = "ap-south-1"
}


data "aws_availability_zones" "available" {
  state = "available"
}


resource "random_string" "random" {
  length  = 16
  lower   = true
  upper = false
  numeric = false
  special = false
}


output "az" {
  value = data.aws_availability_zones.available.names[0]
}


output "cluster-name" {
  value = "kops-cluster-${random_string.random.result}.k8s.local"
}
