# CI/CD — EKS + ECR + Helm + Jenkins + Argo CD

Terraform-проект для розгортання інфраструктури на AWS: S3 + DynamoDB для зберігання стейтів, VPC з публічними та приватними підмережами, ECR-репозиторій для Docker-образів, EKS-кластер Kubernetes. Django-застосунок розгортається у кластері за допомогою Helm-чарта `charts/django-app`.

Поверх інфраструктури розгортається повний CI/CD-процес:

- **Jenkins** (встановлюється через Helm/Terraform) запускає pipeline на Kubernetes-агенті (**Kaniko + Git**): збирає Docker-образ, пушить його в **Amazon ECR**, оновлює тег у `charts/django-app/values.yaml` та пушить зміни в `main`.
- **Argo CD** (встановлюється через Helm/Terraform) стежить за Git-репозиторієм і **автоматично синхронізує** оновлений Helm-чарт у кластері.

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

---

## CI/CD

### Модуль `jenkins`

Встановлює Jenkins через офіційний Helm-чарт (`https://charts.jenkins.io`). Через **Jenkins Configuration as Code (JCasC)** оголошено Kubernetes-cloud з pod-шаблоном `kaniko-git` (контейнери **Kaniko** для збірки/пушу образів і **Git** для роботи з репозиторієм). Ставляться плагіни `kubernetes`, `workflow-aggregator`, `git`, `configuration-as-code`, `aws-credentials` тощо.

Вхідні змінні (основні): `namespace`, `service_type`, `admin_user`, `admin_password`, `storage_class`, `storage_size`, `ecr_registry`, `aws_region`.

Виводи: `namespace`, `get_url_command`, `get_admin_password_command`.

```bash
# URL Jenkins
kubectl get svc -n jenkins jenkins -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
# Пароль адміністратора (якщо не задано явно)
kubectl exec -n jenkins -it svc/jenkins -c jenkins -- cat /run/secrets/additional/chart-admin-password && echo
```

### Модуль `argo_cd`

Встановлює Argo CD через Helm-чарт (`https://argoproj.github.io/argo-helm`), а потім локальний **app-of-apps** чарт (`modules/argo_cd/charts`), який створює:

- `Application` (`templates/application.yaml`) — стежить за Git-репозиторієм і Helm-чартом `charts/django-app`, з `syncPolicy.automated` (prune + selfHeal), тобто **автосинхронізацією**;
- `Repository` (`templates/repository.yaml`) — реєструє Git-репозиторій в Argo CD.

Вхідні змінні (основні): `namespace`, `service_type`, `git_repo_url`, `git_target_revision`, `chart_path`, `app_name`, `destination_namespace`, `image_repository`.

Виводи: `namespace`, `application_name`, `get_url_command`, `get_admin_password_command`.

```bash
# URL Argo CD
kubectl -n argocd get svc argocd-server -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
# Початковий пароль admin
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d && echo
```

### Pipeline (`Jenkinsfile`)

Декларативний pipeline на агенті `kaniko-git`:

1. **Checkout** — клонує репозиторій (контейнер `git`);
2. **Build & Push image (Kaniko)** — збирає образ із `Dockerfile` і пушить у ECR з тегами `${BUILD_NUMBER}-${GIT_COMMIT}` та `latest`;
3. **Update Helm chart tag & push** — оновлює `tag:` у `charts/django-app/values.yaml` (`sed`), комітить і пушить у `main` (креденшели `github-token`).

Після пушу в `main` Argo CD помічає зміну і автоматично синхронізує застосунок у кластері.

### Dockerfile

Багатоетапний образ Django на `python:3.12-slim` з Gunicorn, non-root користувачем і кешуванням шарів залежностей (`requirements.txt`). Замініть модуль `app.wsgi` на реальний WSGI-модуль вашого проєкту.

---

## Як застосувати Terraform

Порядок деплою: спочатку піднімається S3-бекенд, потім базова інфраструктура (VPC, ECR, EKS), і тільки після готового кластера — Jenkins та Argo CD (бо вони створюють ресурси *всередині* кластера через `helm`/`kubernetes` провайдери).

**0. Передумови**

```bash
aws sts get-caller-identity          # переконатись, що AWS-креденшели налаштовані
terraform version                    # >= 1.0
```

**1. Bootstrap S3-бекенду (перший запуск, з локальним стейтом)**

```bash
terraform init -backend=false
terraform apply -target=module.s3_backend
```

**2. Підключити S3-бекенд і перенести стейт**

```bash
terraform init -migrate-state        # на запит про міграцію → yes
```

**3. Підняти базову інфраструктуру (VPC, ECR, EKS)**

```bash
terraform apply -target=module.vpc -target=module.ecr -target=module.eks
```

**4. Налаштувати доступ до кластера**

```bash
aws eks update-kubeconfig --region us-west-2 --name lesson-7-eks
kubectl get nodes                    # усі вузли мають бути Ready
```

**5. Розгорнути Jenkins та Argo CD**

```bash
terraform apply
```

> `git_repo_url` за замовчуванням заданий у `variables.tf`. Щоб перевизначити репозиторій або пароль Jenkins:
> ```bash
> terraform apply \
>   -var 'git_repo_url=https://github.com/<org>/<repo>.git' \
>   -var 'jenkins_admin_password=<secret>'
> ```

**6. Отримати корисні дані з виводів**

```bash
terraform output                     # список усіх виводів
terraform output -raw jenkins_url_command | sh       # URL Jenkins
terraform output -raw argocd_url_command | sh        # URL Argo CD
```

**Знесення інфраструктури** (у зворотному порядку):

```bash
terraform destroy
```

---

## Як перевірити Jenkins job

**1. Відкрити Jenkins**

```bash
# URL (LoadBalancer)
kubectl get svc -n jenkins jenkins -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'; echo
# Пароль admin (якщо не задано через -var)
kubectl exec -n jenkins -it svc/jenkins -c jenkins -- cat /run/secrets/additional/chart-admin-password; echo
```

Логін — `admin`, пароль — з команди вище. Якщо LoadBalancer ще без адреси — тимчасово прокинути порт:

```bash
kubectl port-forward -n jenkins svc/jenkins 8080:8080
# → http://localhost:8080
```

**2. Створити Pipeline job**

- **New Item** → назва `django-app` → тип **Pipeline** → OK.
- У секції **Pipeline** обрати **Pipeline script from SCM** → SCM **Git** → вказати `Repository URL` (той самий репозиторій) і гілку `*/main`.
- **Script Path**: `Jenkinsfile`.
- Додати креденшел **github-token** (Manage Jenkins → Credentials → тип *Username with password*, ID саме `github-token`) — його використовує pipeline для пушу тегу в `main`.
- Зберегти.

**3. Запустити і перевірити**

- Натиснути **Build Now**.
- Відкрити білд → **Console Output** і переконатись, що всі стадії зелені:
  1. **Checkout** — репозиторій склонований;
  2. **Build & Push image (Kaniko)** — образ зібраний і запушений у ECR (у логах видно `pushed ... :<BUILD_NUMBER>-<commit>` та `:latest`);
  3. **Update Helm chart tag & push** — у логах `Updated charts/django-app/values.yaml` і `ci: bump django-app image tag to ...`.

**4. Підтвердити результати роботи job**

```bash
# Агент Kaniko+Git стартував як під у namespace jenkins
kubectl get pods -n jenkins

# Новий образ з'явився в ECR
aws ecr describe-images --repository-name lesson-7-ecr \
  --region us-west-2 --query 'sort_by(imageDetails,&imagePushedAt)[-1].imageTags'

# Тег у чарті оновлено і закомічено в main
git pull && grep 'tag:' charts/django-app/values.yaml
```

---

## Як побачити результат в Argo CD

**1. Відкрити Argo CD**

```bash
# URL (LoadBalancer)
kubectl -n argocd get svc argocd-server -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'; echo
# Початковий пароль admin
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo
```

Логін — `admin`. Або через port-forward:

```bash
kubectl port-forward -n argocd svc/argocd-server 8081:80
# → http://localhost:8081
```

**2. Перевірити застосунок у UI**

- На дашборді знайти Application **django-app**.
- Статуси мають бути **Healthy** і **Synced**.
- Після Jenkins-білду Argo CD сам помітить новий коміт у `main` (auto-sync: `prune` + `selfHeal`) і синхронізує чарт — на дереві ресурсів з'являться оновлені `Deployment`/`Service`/`ConfigMap`/`HPA`.

**3. Перевірити через CLI / kubectl**

```bash
# Статус застосунку (потрібен argocd CLI + argocd login)
argocd app get django-app

# Ресурси, розгорнуті Argo CD (namespace default)
kubectl get deploy,svc,hpa,cm -n default -l app=django-app

# Образ у Deployment має збігатися з тегом, який запушив Jenkins
kubectl get deploy django-app -n default -o jsonpath='{.spec.template.spec.containers[0].image}'; echo
```

**4. (Опційно) форсувати синхронізацію вручну**

```bash
argocd app sync django-app
```

**Наскрізна перевірка ланцюжка:** запустити Jenkins job → у ECR з'являється новий образ → тег оновлюється в `charts/django-app/values.yaml` і пушиться в `main` → Argo CD авто-синхронізує застосунок → `kubectl get deploy` показує новий тег образу.

---

## Валідація (локально, без деплою)

```bash
# Terraform
terraform init -backend=false
terraform validate
terraform fmt -recursive -check

# Helm
helm lint charts/django-app
helm lint modules/argo_cd/charts
helm template django-app charts/django-app --set image.repository=REPO --set image.tag=TAG
helm template django-app-bootstrap modules/argo_cd/charts --set repository.url=URL
```

> **Важливо:** усі модулі Jenkins/Argo CD створюють ресурси в кластері (`helm_release`, `kubernetes_namespace`), тому `terraform apply` потребує готового EKS-кластера і доступу до нього.
