# Сервисный аккаунт для Terraform
resource "yandex_iam_service_account" "terraform_sa" {
  name        = "diploma-terraform-sa"
  description = "Service account for Terraform infrastructure management"
}

# Назначение ролей для сервисного аккаунта
resource "yandex_resourcemanager_folder_iam_member" "terraform_roles" {
  for_each = toset([
    "editor",
    "storage.admin",
    "container-registry.admin",
    "kms.admin"
  ])
  
  folder_id = var.folder_id
  role      = each.value
  member    = "serviceAccount:${yandex_iam_service_account.terraform_sa.id}"
}

# Создание статического ключа для сервисного аккаунта
resource "yandex_iam_service_account_static_access_key" "terraform_sa_key" {
  service_account_id = yandex_iam_service_account.terraform_sa.id
  description        = "Static access key for Terraform"
}

# Создание бакета для хранения state
resource "yandex_storage_bucket" "tfstate" {
  bucket        = var.bucket_name
  force_destroy = true
}

# Назначение прав на бакет через grant (новый способ)
resource "yandex_storage_bucket_grant" "tfstate_grant" {
  bucket = yandex_storage_bucket.tfstate.bucket
  
  grant {
    id          = yandex_iam_service_account.terraform_sa.id
    type        = "CanonicalUser"
    permissions = ["FULL_CONTROL"]
  }
}

# Выводы
output "service_account_id" {
  value = yandex_iam_service_account.terraform_sa.id
}

output "static_access_key" {
  value = yandex_iam_service_account_static_access_key.terraform_sa_key.access_key
  sensitive = true
}

output "secret_key" {
  value = yandex_iam_service_account_static_access_key.terraform_sa_key.secret_key
  sensitive = true
}

output "bucket_name" {
  value = yandex_storage_bucket.tfstate.bucket
}
