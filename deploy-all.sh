#!/bin/bash
set -e

echo "Дипломный практикум: Полное развертывание"

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$BASE_DIR"

# ШАГ 1: IAM

echo -e "\n[1/8] Создание IAM ресурсов..."
cd "$BASE_DIR/terraform/iam"
terraform init
terraform import yandex_storage_bucket.tfstate dev-oll 2>/dev/null || true
SA_ID=$(yc iam service-account get --name diploma-terraform-sa --format json 2>/dev/null | jq -r '.id' || echo "")
if [ -n "$SA_ID" ] && [ "$SA_ID" != "null" ]; then
    terraform import yandex_iam_service_account.terraform_sa "$SA_ID" 2>/dev/null || true
fi
terraform apply -auto-approve
export AWS_ACCESS_KEY_ID=$(terraform output -raw static_access_key)
export AWS_SECRET_ACCESS_KEY=$(terraform output -raw secret_key)

# ШАГ 2: Инфраструктура

echo -e "\n[2/8] Создание инфраструктуры..."
cd "$BASE_DIR/terraform/infra"
terraform init -backend-config="bucket=dev-oll" -backend-config="key=diploma/terraform.tfstate" -backend-config="region=ru-central1"
terraform apply -auto-approve

MASTER_IP=$(terraform output -json master_ips | jq -r '.[0]')
REGISTRY_ID=$(terraform output -raw registry_id)
echo "✅ Мастер-нода: $MASTER_IP"
echo "✅ ID реестра: $REGISTRY_ID"

# ШАГ 3: Ожидание SSH на всех узлах

echo -e "\n[3/8] Ожидание загрузки всех виртуальных машин..."
ALL_IPS="$MASTER_IP $(cd "$BASE_DIR/terraform/infra" && terraform output -json worker_ips | jq -r '.[]')"
for ip in $ALL_IPS; do
    for i in {1..60}; do
        if ssh -i /home/Ollrins/key -o ConnectTimeout=5 -o StrictHostKeyChecking=no Ollrins@$ip "echo 'SSH ready'" 2>/dev/null; then
            echo "✅ Узел $ip доступен!"
            break
        fi
        sleep 5
    done
done


# ШАГ 4: Ansible Inventory

echo -e "\n[4/8] Генерация Ansible inventory..."
cd "$BASE_DIR/ansible"
WORKER_IPS=$(cd "$BASE_DIR/terraform/infra" && terraform output -json worker_ips | jq -r '.[]')
cat > inventory.ini << '__INI_END__'
[masters]
master ansible_host=PLACEHOLDER_MASTER ansible_user=Ollrins
[workers]
__INI_END__
sed -i "s/PLACEHOLDER_MASTER/$MASTER_IP/" inventory.ini
count=1
for ip in $WORKER_IPS; do
    echo "worker$count ansible_host=$ip ansible_user=Ollrins" >> inventory.ini
    count=$((count + 1))
done
cat >> inventory.ini << '__INI_END__'
[k8s_cluster:children]
masters
workers
[all:vars]
ansible_ssh_private_key_file = /home/Ollrins/key
ansible_ssh_common_args = '-o StrictHostKeyChecking=no'
ansible_python_interpreter = /usr/bin/python3
__INI_END__


# ШАГ 5: Ansible Playbook

echo -e "\n[5/8] Установка Kubernetes и мониторинга..."
ansible-playbook -i inventory.ini playbook-rocky.yml -v


# ШАГ 6: Настройка локального kubectl

echo -e "\n[6/8] Настройка локального kubectl..."
ssh -i /home/Ollrins/key Ollrins@$MASTER_IP "mkdir -p /home/Ollrins/.kube && sudo cp /etc/kubernetes/admin.conf /home/Ollrins/.kube/config && sudo chown Ollrins:Ollrins /home/Ollrins/.kube/config && chmod 600 /home/Ollrins/.kube/config"
scp -q -i /home/Ollrins/key Ollrins@$MASTER_IP:/home/Ollrins/.kube/config ~/.kube/config
sed -i "s|server: https://.*:6443|server: https://$MASTER_IP:6443|" ~/.kube/config
sed -i '/certificate-authority-data/d' ~/.kube/config
sed -i "/server: https:\/\/$MASTER_IP:6443/a\    insecure-skip-tls-verify: true" ~/.kube/config
kubectl get nodes


# ШАГ 7: Сборка и пуш Docker-образа

echo -e "\n[7/8] Сборка и пуш Docker-образа..."
cd "$BASE_DIR/app"
KEY_FILE="/home/Ollrins/key.json"
if [ -f "$KEY_FILE" ]; then
    echo "Отключаем yc credential helper для использования статического ключа..."
    python3 -c "
import json, os
cfg = os.path.expanduser('~/.docker/config.json')
if os.path.exists(cfg):
    try:
        with open(cfg, 'r') as f: data = json.load(f)
        if 'credHelpers' in data and 'cr.yandex' in data['credHelpers']:
            del data['credHelpers']['cr.yandex']
            if not data['credHelpers']: del data['credHelpers']
        with open(cfg, 'w') as f: json.dump(data, f, indent=4)
        print('✅ Конфликтующий helper удален из ~/.docker/config.json')
    except Exception as e:
        pass
"
    echo "Выполняем docker login с ключом сервисного аккаунта..."
    cat "$KEY_FILE" | docker login --username json_key --password-stdin cr.yandex
else
    echo "⚠️ Файл ключа не найден!"
    exit 1
fi

IMAGE_URI="cr.yandex/$REGISTRY_ID/diploma-app:v1.0.0"
echo "Сборка образа: $IMAGE_URI"
docker build -t "$IMAGE_URI" .
docker push "$IMAGE_URI"
docker tag "$IMAGE_URI" "cr.yandex/$REGISTRY_ID/diploma-app:latest"
docker push "cr.yandex/$REGISTRY_ID/diploma-app:latest"
echo "✅ Образ отправлен в реестр."


# ШАГ 8: Деплой приложения в Kubernetes

echo -e "\n[8/8] Деплой приложения в Kubernetes..."

# Создаем секрет для доступа к приватному реестру (если его еще нет)
echo "Создаем imagePullSecret для доступа к Container Registry..."
kubectl create secret docker-registry yc-registry-secret \
  --docker-server=cr.yandex \
  --docker-username=json_key \
  --docker-password="$(cat /home/Ollrins/key.json)" \
  --docker-email=not@used.com \
  --dry-run=client -o yaml | kubectl apply -f -

cat > app-deployment.yaml << DEPLOY_EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: diploma-app
  namespace: default
spec:
  replicas: 2
  selector:
    matchLabels:
      app: diploma-app
  template:
    metadata:
      labels:
        app: diploma-app
    spec:
      imagePullSecrets:
      - name: yc-registry-secret
      containers:
      - name: app
        image: $IMAGE_URI
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: diploma-app
  namespace: default
spec:
  selector:
    app: diploma-app
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-ingress
  namespace: default
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - http:
      paths:
      - path: /app
        pathType: Prefix
        backend:
          service:
            name: diploma-app
            port:
              number: 80
DEPLOY_EOF

kubectl apply -f app-deployment.yaml
echo "Ожидание запуска подов приложения..."
kubectl rollout status deployment/diploma-app -n default --timeout=120s

echo ""

echo " Развертывание завершено успешно"

echo "📊 Grafana:       http://$MASTER_IP/"
echo "🌐 Приложение:    http://$MASTER_IP/app"
echo "📦 Реестр:        $REGISTRY_ID"

