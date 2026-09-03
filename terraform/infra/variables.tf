variable "service_account_key_file" {
  type        = string
  description = "Path to service account key file"
}

variable "cloud_id" {
  type        = string
  description = "Yandex Cloud ID"
}

variable "folder_id" {
  type        = string
  description = "Yandex Folder ID"
}

variable "ssh_public_key" {
  type        = string
  description = "Path to SSH public key file"
}

variable "ssh_user" {
  type        = string
  description = "SSH username"
  default     = "Ollrins"
}

variable "vm_image_id" {
  type        = string
  description = "VM image ID (Rocky Linux 9)"
  default     = "fd828j3n8sa03unu5arm"
}

variable "zones" {
  type        = list(string)
  description = "Availability zones for resources"
  default     = ["ru-central1-a", "ru-central1-b"]
}

variable "platform_id" {
  type        = string
  description = "Compute platform"
  default     = "standard-v3"
}

variable "master_cores" {
  type        = number
  description = "CPU cores for master node"
  default     = 2
}

variable "master_memory" {
  type        = number
  description = "Memory (GB) for master node"
  default     = 4
}

variable "worker_cores" {
  type        = number
  description = "CPU cores for worker nodes"
  default     = 2
}

variable "worker_memory" {
  type        = number
  description = "Memory (GB) for worker nodes"
  default     = 4
}

variable "core_fraction" {
  type        = number
  description = "CPU core fraction (performance level)"
  default     = 20
}

variable "disk_size" {
  type        = number
  description = "Boot disk size in GB"
  default     = 15
}

variable "disk_type" {
  type        = string
  description = "Boot disk type"
  default     = "network-ssd"
}

variable "subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for subnets (one per zone)"
  default     = ["192.168.10.0/24", "192.168.11.0/24"]
}

variable "internal_cidr" {
  type        = string
  description = "Internal network CIDR for security group rules"
  default     = "192.168.0.0/16"
}

variable "network_name" {
  type        = string
  description = "VPC network name"
  default     = "diploma-network"
}

variable "master_name_prefix" {
  type        = string
  description = "Prefix for master node names"
  default     = "diploma-master"
}

variable "worker_name_prefix" {
  type        = string
  description = "Prefix for worker node names"
  default     = "diploma-worker"
}

variable "sg_name" {
  type        = string
  description = "Security group name"
  default     = "diploma-sg"
}

variable "registry_name" {
  type        = string
  description = "Container registry name"
  default     = "diploma-registry"
}

variable "master_count" {
  type        = number
  description = "Number of master nodes"
  default     = 1
}

variable "worker_count" {
  type        = number
  description = "Number of worker nodes"
  default     = 2
}

variable "timezone" {
  type        = string
  description = "System timezone for VMs"
  default     = "Europe/Moscow"
}
