variable "service_account_key_file" {
  type        = string
  description = "Path to service account key file"
  default     = "/home/Ollrins/key.json"
}

variable "cloud_id" {
  type        = string
  description = "Yandex Cloud ID"
}

variable "folder_id" {
  type        = string
  description = "Yandex Folder ID"
}

variable "bucket_name" {
  type        = string
  description = "S3 bucket name for Terraform state"
  default     = "diploma-tfstate"
}
