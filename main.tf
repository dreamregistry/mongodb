terraform {
  backend "s3" {}

  required_providers {
    random = {
      source  = "registry.terraform.io/hashicorp/random"
      version = "3.2.0"
    }
    mongodbatlas = {
      source  = "registry.terraform.io/mongodb/mongodbatlas"
      version = "1.3.1"
    }
    aws = {
      source  = "registry.terraform.io/hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "random" {}
provider "mongodbatlas" {}
provider "aws" {}

data "aws_region" "current" {}

data "mongodbatlas_project" "myproject" {
  project_id = var.mongodb_atlas_project_id
}


data "mongodbatlas_cluster" "devcluster" {
  project_id = data.mongodbatlas_project.myproject.id
  name       = var.mongodb_atlas_cluster_name
}

resource "random_pet" "username" {}

resource "random_password" "dbpassword" {
  length  = 12
  special = false
}

resource "random_pet" "dbname" {}

resource "mongodbatlas_database_user" "dbuser" {
  username           = random_pet.username.id
  password           = random_password.dbpassword.result
  project_id         = data.mongodbatlas_project.myproject.id
  auth_database_name = "admin"

  roles {
    role_name     = "readWrite"
    database_name = random_pet.dbname.id
  }

  scopes {
    name = var.mongodb_atlas_cluster_name
    type = "CLUSTER"
  }
}

locals {
  mongo_uri = "mongodb+srv://${mongodbatlas_database_user.dbuser.username}:${mongodbatlas_database_user.dbuser.password}@${substr(data.mongodbatlas_cluster.devcluster.connection_strings[0].standard_srv, 14, -1)}/${random_pet.dbname.id}"
}

resource "aws_ssm_parameter" "mongo_uri" {
  name        = "/mongodb/${random_pet.dbname.id}/uri"
  description = "The MongoDB connection string"
  type        = "SecureString"
  value       = local.mongo_uri
}

output "MONGO_URI" {
  value = {
    type   = "ssm"
    arn    = aws_ssm_parameter.mongo_uri.arn
    key    = aws_ssm_parameter.mongo_uri.name
    region = data.aws_region.current.name
  }
}

output "MONGO_DATABASE_NAME" {
  value = random_pet.dbname.id
}
