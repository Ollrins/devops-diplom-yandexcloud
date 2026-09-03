terraform {
  required_version = "~>1.14.0"
  
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~>0.193.0"
    }
  }
}

provider "yandex" {
  zone = "ru-central1-a"
  service_account_key_file = var.service_account_key_file
  cloud_id                 = var.cloud_id
  folder_id                = var.folder_id
}
