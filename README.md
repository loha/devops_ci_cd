# Lesson 7 — EKS + ECR + Helm

Terraform-проект для розгортання інфраструктури на AWS: S3 + DynamoDB для зберігання стейтів, VPC з публічними та приватними підмережами, ECR-репозиторій для Docker-образів, EKS-кластер Kubernetes. Django-застосунок розгортається у кластері за допомогою Helm-чарта `charts/django-app`.

## Структура проєкту

```
lesson-5/
│
├── main.tf                  # Підключення модулів і налаштування провайдера
├── backend.tf               # Налаштування S3-бекенду для стейт-файлів
├── outputs.tf               # Загальні вихідні дані з усіх модулів
│
├── modules/
│   ├── s3-backend/          # Модуль S3 + DynamoDB для зберігання стейтів
│   │   ├── s3.tf
│   │   ├── dynamodb.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── vpc/                 # Модуль мережевої інфраструктури
│   │   ├── vpc.tf
│   │   ├── routes.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   └── ecr/                 # Модуль ECR-репозиторію
│       ├── ecr.tf
│       ├── variables.tf
│       └── outputs.tf
│
└── README.md
```

## Перший запуск (Bootstrap)

> **Проблема "курки і яйця":** `backend.tf` посилається на S3-бакет, який ще не існує.
> Terraform намагається підключитись до бекенду ще до `apply` — і падає з помилкою
> `S3 bucket does not exist`. Тому перший запуск робиться у два кроки.

**Крок 1 — створити S3-бакет і DynamoDB з локальним стейтом**

Тимчасово відключаємо бекенд і деплоїмо тільки модуль `s3_backend`:

```bash
terraform init -backend=false
terraform apply -target=module.s3_backend
```

**Крок 2 — підключити S3-бекенд і перенести стейт**

```bash
terraform init -migrate-state
```

Terraform запитає підтвердження міграції локального стейту в S3 — відповісти `yes`.

**Крок 3 — задеплоїти решту інфраструктури**

```bash
terraform apply
```

---

## Команди

```bash
# Ініціалізація проєкту (завантаження провайдерів і модулів)
terraform init

# Перегляд плану змін без застосування
terraform plan

# Застосування змін
terraform apply

# Знищення всіх ресурсів
terraform destroy
```

## Модулі

### s3-backend

Створює S3-бакет для зберігання Terraform стейт-файлів і таблицю DynamoDB для блокування стейту під час паралельних операцій.

Що створюється:
- `aws_s3_bucket` — S3-бакет з тегами
- `aws_s3_bucket_versioning` — версіювання для збереження історії стейтів
- `aws_s3_bucket_server_side_encryption_configuration` — шифрування AES256
- `aws_s3_bucket_public_access_block` — блокування публічного доступу
- `aws_dynamodb_table` — таблиця з ключем `LockID` для блокування стейту

Вхідні змінні:
| Змінна | Опис | За замовчуванням |
|--------|------|-----------------|
| `bucket_name` | Назва S3-бакета | — |
| `table_name` | Назва таблиці DynamoDB | `terraform-locks` |
| `region` | AWS регіон | `us-west-2` |

Вихідні дані: `bucket_name`, `bucket_arn`, `bucket_url`, `dynamodb_table_name`, `dynamodb_table_arn`

---

### vpc

Будує мережеву інфраструктуру: VPC, публічні та приватні підмережі, Internet Gateway, NAT Gateway і таблиці маршрутизації.

Що створюється:
- `aws_vpc` — основний VPC з підтримкою DNS
- `aws_subnet` (public × 3) — публічні підмережі з автоматичним призначенням публічного IP
- `aws_subnet` (private × 3) — приватні підмережі
- `aws_internet_gateway` — Internet Gateway для публічних підмереж
- `aws_eip` + `aws_nat_gateway` (× 3) — NAT Gateway в кожній AZ для приватних підмереж
- `aws_route_table` (public) — маршрут `0.0.0.0/0` через IGW
- `aws_route_table` (private × 3) — маршрут `0.0.0.0/0` через відповідний NAT GW
- `aws_route_table_association` — прив'язка підмереж до таблиць маршрутів

Вхідні змінні:
| Змінна | Опис | За замовчуванням |
|--------|------|-----------------|
| `vpc_cidr_block` | CIDR блок VPC | `10.0.0.0/16` |
| `public_subnets` | Список CIDR для публічних підмереж | — |
| `private_subnets` | Список CIDR для приватних підмереж | — |
| `availability_zones` | Список AZ | — |
| `vpc_name` | Назва VPC (використовується в тегах) | `main-vpc` |

Вихідні дані: `vpc_id`, `vpc_cidr_block`, `public_subnet_ids`, `private_subnet_ids`, `internet_gateway_id`, `nat_gateway_ids`, `public_route_table_id`, `private_route_table_ids`

---

### ecr

Створює ECR-репозиторій для зберігання Docker-образів з автоматичним скануванням, lifecycle-політикою та IAM-політикою доступу.

Що створюється:
- `aws_ecr_repository` — репозиторій з налаштованим скануванням образів
- `aws_ecr_lifecycle_policy` — зберігає останні 10 образів, решта видаляються
- `aws_ecr_repository_policy` — дозволяє push/pull для поточного AWS-акаунту

Вхідні змінні:
| Змінна | Опис | За замовчуванням |
|--------|------|-----------------|
| `ecr_name` | Назва ECR-репозиторію | — |
| `scan_on_push` | Сканування образів при завантаженні | `true` |
| `image_tag_mutability` | Мутабельність тегів (`MUTABLE`/`IMMUTABLE`) | `MUTABLE` |

Вихідні дані: `repository_url`, `repository_arn`, `repository_name`, `registry_id`

---

### eks

Створює кластер Kubernetes (EKS) у вже існуючому VPC разом з керованою групою вузлів (managed node group).

Що створюється:
- `aws_iam_role` + `aws_iam_role_policy_attachment` — роль і політики для control plane кластера (`AmazonEKSClusterPolicy`)
- `aws_eks_cluster` — сам кластер, розгорнутий у приватних і публічних підмережах VPC
- `aws_iam_role` + `aws_iam_role_policy_attachment` — роль і політики для робочих вузлів (`AmazonEKSWorkerNodePolicy`, `AmazonEKS_CNI_Policy`, `AmazonEC2ContainerRegistryReadOnly`)
- `aws_eks_node_group` — керована група вузлів у приватних підмережах

Вхідні змінні:
| Змінна | Опис | За замовчуванням |
|--------|------|-----------------|
| `cluster_name` | Назва EKS-кластера | — |
| `cluster_version` | Версія Kubernetes | `1.29` |
| `vpc_id` | ID існуючого VPC | — |
| `private_subnet_ids` | Приватні підмережі для вузлів | — |
| `public_subnet_ids` | Публічні підмережі для control plane | — |
| `node_instance_types` | Типи інстансів для вузлів | `["t3.medium"]` |
| `node_desired_size` / `node_min_size` / `node_max_size` | Розмір групи вузлів | `2` / `2` / `4` |

Вихідні дані: `cluster_name`, `cluster_endpoint`, `cluster_certificate_authority_data`, `cluster_arn`, `node_group_arn`

---

## Доступ до кластера через kubectl

```bash
aws eks update-kubeconfig --region us-west-2 --name lesson-7-eks
kubectl get nodes
```

## Завантаження Docker-образу Django в ECR

```bash
aws ecr get-login-password --region us-west-2 \
  | docker login --username AWS --password-stdin <account_id>.dkr.ecr.us-west-2.amazonaws.com

docker build -t lesson-7-ecr .
docker tag lesson-7-ecr:latest <account_id>.dkr.ecr.us-west-2.amazonaws.com/lesson-7-ecr:latest
docker push <account_id>.dkr.ecr.us-west-2.amazonaws.com/lesson-7-ecr:latest
```

## Helm-чарт `charts/django-app`

Структура:
- `templates/deployment.yaml` — Deployment з образом з ECR, env-змінні підключені через `envFrom` з ConfigMap
- `templates/service.yaml` — Service типу `LoadBalancer`
- `templates/hpa.yaml` — HorizontalPodAutoscaler (2–6 подів, ціль — 70% CPU)
- `templates/configmap.yaml` — ConfigMap зі змінними середовища Django/Postgres (з `.env.example` теми 4)
- `templates/ingress.yaml` — опціональний Ingress з підтримкою TLS через cert-manager (`ingress.enabled: true` у `values.yaml`)
- `values.yaml` — параметри образу, сервісу, autoscaler, ConfigMap і Ingress

Встановлення:

```bash
helm upgrade --install django-app ./charts/django-app \
  --set image.repository=<account_id>.dkr.ecr.us-west-2.amazonaws.com/lesson-7-ecr \
  --set image.tag=latest
```

Увімкнення Ingress з TLS (потребує попередньо встановлених nginx-ingress та cert-manager у кластері):

```bash
helm upgrade --install django-app ./charts/django-app \
  --set ingress.enabled=true \
  --set ingress.host=yourdomain.com \
  --set ingress.className=nginx \
  --set ingress.tls=true \
  --set ingress.clusterIssuer=letsencrypt-prod
```
