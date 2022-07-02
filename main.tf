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
  }
}

provider "random" {}
provider "mongodbatlas" {}


data "mongodbatlas_project" "myproject" {
  project_id = var.project_id
}


data "mongodbatlas_cluster" "devcluster" {
  project_id = data.mongodbatlas_project.myproject.id
  name       = var.cluster_name
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

  roles {
    role_name     = "readAnyDatabase"
    database_name = "admin"
  }


  scopes {
    name = "DEV"
    type = "CLUSTER"
  }

}


output "MONGO_URI" {
  sensitive = true
  value     = "mongodb+srv://${mongodbatlas_database_user.dbuser.username}:${mongodbatlas_database_user.dbuser.password}@${substr(data.mongodbatlas_cluster.devcluster.connection_strings[0].standard_srv, 14, -1)}/${random_pet.dbname.id}"
}
