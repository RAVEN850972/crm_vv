# Руководство по установке CRM системы

## Системные требования

- Python 3.9 или выше
- pip (менеджер пакетов Python)
- Виртуальное окружение (рекомендуется)
- PostgreSQL 12+ (для продакшена) или SQLite (для разработки)

## Быстрая установка для разработки

### 1. Клонирование и настройка окружения

```bash
# Клонируем репозиторий
git clone <repository-url>
cd crm_ac

# Создаем виртуальное окружение
python -m venv venv

# Активируем виртуальное окружение
# Windows:
venv\Scripts\activate
# Linux/Mac:
source venv/bin/activate

# Устанавливаем зависимости для разработки
pip install -r requirements-dev.txt
```

### 2. Настройка переменных окружения

Создайте файл `.env` в корне проекта:

```env
# Django настройки
DJANGO_SECRET_KEY=your-secret-key-here
DJANGO_DEBUG=True
DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1

# База данных (для разработки можно использовать SQLite)
DJANGO_DB_ENGINE=django.db.backends.sqlite3
DJANGO_DB_NAME=db.sqlite3

# Для продакшена с PostgreSQL:
# DJANGO_DB_ENGINE=django.db.backends.postgresql
# DJANGO_DB_NAME=crm_db
# DJANGO_DB_USER=crm_user
# DJANGO_DB_PASSWORD=secure_password
# DJANGO_DB_HOST=localhost
# DJANGO_DB_PORT=5432

# API ключи (опционально)
YANDEX_MAPS_API_KEY=your-yandex-maps-api-key

# Email настройки (опционально)
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_USE_TLS=True
EMAIL_HOST_USER=your-email@gmail.com
EMAIL_HOST_PASSWORD=your-app-password
```

### 3. Инициализация базы данных

```bash
# Создаем миграции
python manage.py makemigrations

# Применяем миграции
python manage.py migrate

# Создаем суперпользователя
python manage.py createsuperuser

# Загружаем тестовые данные (опционально)
python manage.py loaddata fixtures/initial_data.json
```

### 4. Запуск сервера разработки

```bash
# Запускаем сервер
python manage.py runserver

# Сервер будет доступен по адресу: http://127.0.0.1:8000/
```

## Установка для продакшена

### 1. Подготовка сервера

```bash
# Обновляем систему
sudo apt update && sudo apt upgrade -y

# Устанавливаем необходимые пакеты
sudo apt install python3-pip python3-venv nginx postgresql postgresql-contrib

# Создаем пользователя для приложения
sudo adduser crm
sudo usermod -aG sudo crm
```

### 2. Настройка базы данных PostgreSQL

```bash
# Входим в PostgreSQL
sudo -u postgres psql

# Создаем базу данных и пользователя
CREATE DATABASE crm_db;
CREATE USER crm_user WITH PASSWORD 'secure_password';
ALTER ROLE crm_user SET client_encoding TO 'utf8';
ALTER ROLE crm_user SET default_transaction_isolation TO 'read committed';
ALTER ROLE crm_user SET timezone TO 'UTC';
GRANT ALL PRIVILEGES ON DATABASE crm_db TO crm_user;
\q
```

### 3. Настройка приложения

```bash
# Переходим к пользователю приложения
sudo su - crm

# Клонируем код
git clone <repository-url> /home/crm/crm_ac
cd /home/crm/crm_ac

# Создаем виртуальное окружение
python3 -m venv venv
source venv/bin/activate

# Устанавливаем зависимости
pip install -r requirements-prod.txt
```

### 4. Переменные окружения для продакшена

Создайте файл `/home/crm/crm_ac/.env`:

```env
DJANGO_SECRET_KEY=very-secure-secret-key-generate-new-one
DJANGO_DEBUG=False
DJANGO_ALLOWED_HOSTS=your-domain.com,www.your-domain.com

DJANGO_DB_ENGINE=django.db.backends.postgresql
DJANGO_DB_NAME=crm_db
DJANGO_DB_USER=crm_user
DJANGO_DB_PASSWORD=secure_password
DJANGO_DB_HOST=localhost
DJANGO_DB_PORT=5432

# Yandex Maps API
YANDEX_MAPS_API_KEY=your-api-key

# Email настройки
EMAIL_HOST=smtp.your-provider.com
EMAIL_PORT=587
EMAIL_USE_TLS=True
EMAIL_HOST_USER=noreply@your-domain.com
EMAIL_HOST_PASSWORD=email-password

# Sentry для мониторинга ошибок (опционально)
SENTRY_DSN=https://your-sentry-dsn
```

### 5. Инициализация продакшен базы

```bash
# Применяем миграции
python manage.py migrate

# Собираем статические файлы
python manage.py collectstatic --noinput

# Создаем суперпользователя
python manage.py createsuperuser
```

### 6. Настройка Gunicorn

Создайте файл `/home/crm/crm_ac/gunicorn.conf.py`:

```python
bind = "127.0.0.1:8000"
workers = 3
worker_class = "sync"
worker_connections = 1000
max_requests = 1000
max_requests_jitter = 100
timeout = 30
keepalive = 2
user = "crm"
group = "crm"
```

Создайте systemd сервис `/etc/systemd/system/crm.service`:

```ini
[Unit]
Description=CRM Gunicorn daemon
After=network.target

[Service]
User=crm
Group=crm
WorkingDirectory=/home/crm/crm_ac
ExecStart=/home/crm/crm_ac/venv/bin/gunicorn --config gunicorn.conf.py crm_ac.wsgi:application
ExecReload=/bin/kill -s HUP $MAINPID
Restart=always

[Install]
WantedBy=multi-user.target
```

### 7. Настройка Nginx

Создайте файл `/etc/nginx/sites-available/crm`:

```nginx
server {
    listen 80;
    server_name your-domain.com www.your-domain.com;

    location = /favicon.ico { access_log off; log_not_found off; }
    
    location /static/ {
        root /home/crm/crm_ac;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    location /media/ {
        root /home/crm/crm_ac;
        expires 30d;
        add_header Cache-Control "public";
    }

    location / {
        include proxy_params;
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Безопасность
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
}
```

### 8. Запуск сервисов

```bash
# Включаем и запускаем сервисы
sudo systemctl enable crm
sudo systemctl start crm
sudo systemctl enable nginx
sudo systemctl restart nginx

# Проверяем статус
sudo systemctl status crm
sudo systemctl status nginx
```

## Дополнительные команды

### Управление данными

```bash
# Создание тестовых данных
python manage.py shell
>>> from django.contrib.auth import get_user_model
>>> User = get_user_model()
>>> User.objects.create_user('admin', 'admin@example.com', 'password', role='owner')

# Создание автоматических расписаний
python manage.py create_schedules --start-date 2025-06-01 --auto-assign

# Оптимизация маршрутов
python manage.py optimize_routes --days-ahead 7
```

### Резервное копирование

```bash
# Создание бэкапа базы данных
pg_dump -U crm_user -h localhost crm_db > backup_$(date +%Y%m%d_%H%M%S).sql

# Восстановление из бэкапа
psql -U crm_user -h localhost crm_db < backup_file.sql
```

### Мониторинг

```bash
# Просмотр логов приложения
sudo journalctl -u crm -f

# Просмотр логов Nginx
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log

# Проверка статуса сервисов
sudo systemctl status crm nginx postgresql
```

## Обновление приложения

```bash
# Останавливаем сервис
sudo systemctl stop crm

# Обновляем код
cd /home/crm/crm_ac
git pull origin main

# Активируем виртуальное окружение
source venv/bin/activate

# Обновляем зависимости
pip install -r requirements-prod.txt

# Применяем миграции
python manage.py migrate

# Собираем статические файлы
python manage.py collectstatic --noinput

# Запускаем сервис
sudo systemctl start crm
```

## Troubleshooting

### Общие проблемы

1. **Ошибка "Port already in use"**
   ```bash
   sudo lsof -t -i tcp:8000 | xargs kill -9
   ```

2. **Проблемы с правами доступа**
   ```bash
   sudo chown -R crm:crm /home/crm/crm_ac
   sudo chmod -R 755 /home/crm/crm_ac
   ```

3. **Ошибки базы данных PostgreSQL**
   ```bash
   sudo service postgresql restart
   sudo -u postgres psql -c "SELECT version();"
   ```

4. **Проблемы с статическими файлами**
   ```bash
   python manage.py collectstatic --clear --noinput
   ```

### Логи и отладка

```bash
# Django логи
python manage.py check
python manage.py check --deploy

# Проверка конфигурации Nginx
sudo nginx -t

# Проверка конфигурации Gunicorn
/home/crm/crm_ac/venv/bin/gunicorn --check-config crm_ac.wsgi:application
```

## SSL/HTTPS (рекомендуется для продакшена)

```bash
# Установка Certbot
sudo apt install certbot python3-certbot-nginx

# Получение SSL сертификата
sudo certbot --nginx -d your-domain.com -d www.your-domain.com

# Автоматическое обновление
sudo crontab -e
# Добавить строку:
# 0 12 * * * /usr/bin/certbot renew --quiet
```

После установки SSL, Nginx автоматически настроит HTTPS и перенаправления.

## Заключение

После выполнения всех шагов у вас будет полностью работающая CRM-система, готовая для использования в продакшн среде.

Для дальнейшей поддержки и развития рекомендуется:
- Настроить мониторинг (Prometheus + Grafana)
- Настроить CI/CD пайплайн
- Регулярно создавать резервные копии
- Мониторить производительность и оптимизировать по необходимости