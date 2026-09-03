# Создание сети
resource "yandex_vpc_network" "main" {
  name = var.network_name
}

# Создание подсетей в разных зонах доступности
resource "yandex_vpc_subnet" "subnets" {
  count          = length(var.zones)
  name           = "${var.network_name}-subnet-${var.zones[count.index]}"
  zone           = var.zones[count.index]
  network_id     = yandex_vpc_network.main.id
  v4_cidr_blocks = [var.subnet_cidrs[count.index]]
}

# Группа безопасности
resource "yandex_vpc_security_group" "main" {
  name        = var.sg_name
  description = "Security group for Diploma Kubernetes cluster"
  network_id  = yandex_vpc_network.main.id

  ingress {
    protocol       = "ANY"
    description    = "Allow all traffic between VMs in subnets"
    v4_cidr_blocks = [var.internal_cidr]
    from_port      = 0
    to_port        = 65535
  }

  ingress {
    protocol       = "TCP"
    description    = "Allow SSH"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 22
    to_port        = 22
  }

  ingress {
    protocol       = "TCP"
    description    = "Allow Kubernetes API"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 6443
    to_port        = 6443
  }

  ingress {
    protocol       = "TCP"
    description    = "Allow NodePort range"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 30000
    to_port        = 32767
  }

  ingress {
    protocol       = "TCP"
    description    = "Allow kubeadm join / kubelet"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 10250
    to_port        = 10250
  }

  ingress {
    protocol       = "TCP"
    description    = "Allow etcd"
    v4_cidr_blocks = [var.internal_cidr]
    from_port      = 2379
    to_port        = 2380
  }
  
  ingress {
    protocol       = "TCP"
    description    = "Allow HTTP for Ingress"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 80
    to_port        = 80
  }

  ingress {
    protocol       = "TCP"
    description    = "Allow HTTPS for Ingress"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 443
    to_port        = 443
  }

  egress {
    protocol       = "ANY"
    description    = "Allow all egress traffic"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }
}

# Создание мастер-ноды
resource "yandex_compute_instance" "k8s-master" {
  count       = var.master_count
  name        = "${var.master_name_prefix}-${count.index + 1}"
  zone        = var.zones[0]
  platform_id = var.platform_id
  
  resources {
    cores         = var.master_cores
    memory        = var.master_memory
    core_fraction = var.core_fraction
  }
  
  boot_disk {
    initialize_params {
      image_id = var.vm_image_id
      size     = var.disk_size
      type     = var.disk_type
    }
  }
  
  network_interface {
    subnet_id          = yandex_vpc_subnet.subnets[0].id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.main.id]
  }
  
  scheduling_policy {
    preemptible = false
  }
  
  metadata = {
    ssh-keys = "${var.ssh_user}:${file(var.ssh_public_key)}"
    user-data = templatefile("${path.module}/cloud-init.yaml", {
      hostname       = "${var.master_name_prefix}-${count.index + 1}"
      ssh_user       = var.ssh_user
      ssh_public_key = file(var.ssh_public_key)
      timezone       = var.timezone
    })
  }
}

# Создание воркер-нод
resource "yandex_compute_instance" "k8s-worker" {
  count       = var.worker_count
  name        = "${var.worker_name_prefix}-${count.index + 1}"
  zone        = var.zones[count.index % length(var.zones)]
  platform_id = var.platform_id
  
  resources {
    cores         = var.worker_cores
    memory        = var.worker_memory
    core_fraction = var.core_fraction
  }
  
  boot_disk {
    initialize_params {
      image_id = var.vm_image_id
      size     = var.disk_size
      type     = var.disk_type
    }
  }
  
  network_interface {
    subnet_id          = yandex_vpc_subnet.subnets[count.index % length(var.zones)].id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.main.id]
  }
  
  scheduling_policy {
    preemptible = true
  }
  
  metadata = {
    ssh-keys = "${var.ssh_user}:${file(var.ssh_public_key)}"
    user-data = templatefile("${path.module}/cloud-init.yaml", {
      hostname       = "${var.worker_name_prefix}-${count.index + 1}"
      ssh_user       = var.ssh_user
      ssh_public_key = file(var.ssh_public_key)
      timezone       = var.timezone
    })
  }
}

# Container Registry
resource "yandex_container_registry" "main" {
  name      = var.registry_name
  folder_id = var.folder_id
}

# Outputs
output "master_ips" {
  value = yandex_compute_instance.k8s-master[*].network_interface[0].nat_ip_address
}

output "worker_ips" {
  value = yandex_compute_instance.k8s-worker[*].network_interface[0].nat_ip_address
}

output "all_ips" {
  value = concat(
    yandex_compute_instance.k8s-master[*].network_interface[0].nat_ip_address,
    yandex_compute_instance.k8s-worker[*].network_interface[0].nat_ip_address
  )
}

output "registry_id" {
  value = yandex_container_registry.main.id
}
