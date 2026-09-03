#!/bin/bash
set -e


echo "Удаление ресурсов диплома"


BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$BASE_DIR"

# ШАГ 1: Удаляем инфраструктуру (ВМ, сети, реестр)

echo -e "\n[1/2] Удаление инфраструктуры (ВМ, сети, registry)..."
cd "$BASE_DIR/terraform/infra"

# Инициализируем бэкенд, чтобы Terraform мог прочитать state из бакета
terraform init \
  -backend-config="bucket=dev-oll" \
  -backend-config="key=diploma/terraform.tfstate" \
  -backend-config="region=ru-central1"

# Удаляем ресурсы. Бакет НЕ будет удален, так как его нет в state этого модуля
terraform destroy -auto-approve

echo "Инфраструктура удалена"

# ШАГ 2: Удаляем IAM (Сервисный аккаунт и ключи)

echo -e "\n[2/2] Удаление IAM ресурсов..."
cd "$BASE_DIR/terraform/iam"

terraform init

# Исключаем бакет из удаления перед выполнением destroy
echo "Исключаем бакет 'dev-oll' из управления Terraform (чтобы не удалить его)..."
terraform state rm yandex_storage_bucket.tfstate 2>/dev/null || echo "Бакет уже не в state или не существовал."

# Теперь удаляем только сервисный аккаунт и его ключи
terraform destroy -auto-approve

echo "IAM ресурсы удалены."

echo ""

echo "Ресурсы удалены"
