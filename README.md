# Lesson 5 — Terraform AWS Infrastructure

Terraform-проект для розгортання базової інфраструктури на AWS: S3 + DynamoDB для зберігання стейтів, VPC з публічними та приватними підмережами, ECR-репозиторій для Docker-образів.

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
