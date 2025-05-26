#!/bin/bash

# CRM для кондиционеров - Скрипт автоматического развертывания
# Использование: ./deploy.sh [development|production|docker]

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функции для логирования
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Проверка аргументов
if [ $# -eq 0 ]; then
    log_error "Не указан режим развертывания!"
    echo "Использование: $0 [development|production|docker]"
    echo ""
    echo "development  - Развертывание для разработки"
    echo "production   - Развертывание на продакшн сервере"
    echo "docker       - Развертывание через Docker"
    exit 1
fi

DEPLOYMENT_MODE=$1

# Глобальные переменные
PROJECT_NAME="crm_ac"
PROJECT_DIR=$(pwd)
VENV_DIR="venv"
BACKUP_DIR="backups"

# Проверка системы
check_system() {
    log_info "Проверка системных требований..."
    
    # Проверка Python
    if ! command -v python3 &> /dev/null; then
        log_error "Python 3 не найден! Установите Python 3.9 или выше."
        exit 1
    fi
    
    PYTHON_VERSION=$(python3 --version | cut -d" " -f2 | cut -d"." -f1-2)
    log_info "Найден Python $PYTHON_VERSION"
    
    # Проверка pip
    if ! command -v pip3 &> /dev/null; then
        log_error "pip3 не найден! Установите pip3."
        exit 1
    fi
    
    # Проверка git
    if ! command -v git &> /dev/null; then
        log_warning "Git не найден. Убедитесь, что код загружен вручную."
    fi
    
    log_success "Системные требования проверены"
}

# Создание виртуального окружения
setup_virtualenv() {
    log_info "Настройка виртуального окружения..."
    
    if [ ! -d "$VENV_DIR" ]; then
        log_info "Создание виртуального окружения..."
        python3 -m venv $VENV_DIR
    else
        log_info "Виртуальное окружение уже существует"
    fi
    
    # Активация виртуального окружения
    source $VENV_DIR/bin/activate
    
    # Обновление pip
    pip install --upgrade pip
    
    log_success "Виртуальное окружение готово"
}

# Установка зависимостей
install_dependencies() {
    local req_file=$1
    log_info "Установка зависимостей из $req_file..."
    
    source $VENV_DIR/bin/activate
    pip install -r $req_file
    
    log_success "Зависимости установлены"
}

# Создание файла .env
create_env_file() {
    local env_type=$1
    log_info "Создание файла окружения для $env_type..."
    
    if [ ! -f ".env" ]; then
        log_info "Создание .env файла..."
        
        if [ "$env_type" == "development" ]; then
            cat > .env << EOF
# Django настройки для разработки
DJANGO_SECRET_KEY=$(python3 -c 'from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())')
DJANGO_DEBUG=True
DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1

# База данных SQLite для разработки
DJANGO_DB_ENGINE=django.db.backends.sqlite3
DJANGO_DB_NAME=db.sqlite3

# API ключи (заполните при необходимости)
YANDEX_MAPS_API_KEY=

# Email настройки (заполните при необходимости)
EMAIL_HOST=
EMAIL_PORT=587
EMAIL_USE_TLS=True
EMAIL_HOST_USER=
EMAIL_HOST_PASSWORD=

# Создание тестовых данных
CREATE_SUPERUSER=true
LOAD_FIXTURES=false
CREATE_TEST_SCHEDULES=false
EOF
        elif [ "$env_type" == "production" ]; then
            cat > .env << EOF
# Django настройки для продакшена
DJANGO_SECRET_KEY=$(python3 -c 'from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())')
DJANGO_DEBUG=False
DJANGO_ALLOWED_HOSTS=your-domain.com,www.your-domain.com

# База данных PostgreSQL
DJANGO_DB_ENGINE=django.db.backends.postgresql
DJANGO_DB_NAME=crm_db
DJANGO_DB_USER=crm_user
DJANGO_DB_PASSWORD=CHANGE_THIS_PASSWORD
DJANGO_DB_HOST=localhost
DJANGO_DB_PORT=5432

# API ключи
YANDEX_MAPS_API_KEY=YOUR_YANDEX_MAPS_API_KEY

# Email настройки
EMAIL_HOST=smtp.your-provider.com
EMAIL_PORT=587
EMAIL_USE_TLS=True
EMAIL_HOST_USER=noreply@your-domain.com
EMAIL_HOST_PASSWORD=YOUR_EMAIL_PASSWORD

# Sentry для мониторинга ошибок
SENTRY_DSN=https://your-sentry-dsn

# Создание суперпользователя
CREATE_SUPERUSER=true
LOAD_FIXTURES=false
CREATE_TEST_SCHEDULES=false
EOF
        fi
        
        log_warning "Файл .env создан! Отредактируйте его перед продолжением."
        
        if [ "$env_type" == "production" ]; then
            log_warning "ВАЖНО: Измените пароли и API ключи в файле .env!"
            read -p "Нажмите Enter после редактирования .env файла..."
        fi
    else
        log_info "Файл .env уже существует"
    fi
    
    log_success "Файл окружения готов"
}

# Настройка базы данных
setup_database() {
    local db_type=$1
    log_info "Настройка базы данных ($db_type)..."
    
    source $VENV_DIR/bin/activate
    
    if [ "$db_type" == "postgresql" ]; then
        # Проверка PostgreSQL
        if ! command -v psql &> /dev/null; then
            log_error "PostgreSQL не найден! Установите PostgreSQL."
            exit 1
        fi
        
        # Создание базы данных (если нужно)
        log_info "Создание базы данных PostgreSQL..."
        
        # Загружаем переменные из .env
        source .env
        
        # Пытаемся создать базу данных
        sudo -u postgres psql << EOF || log_warning "База данных может уже существовать"
CREATE DATABASE $DJANGO_DB_NAME;
CREATE USER $DJANGO_DB_USER WITH PASSWORD '$DJANGO_DB_PASSWORD';
ALTER ROLE $DJANGO_DB_USER SET client_encoding TO 'utf8';
ALTER ROLE $DJANGO_DB_USER SET default_transaction_isolation TO 'read committed';
ALTER ROLE $DJANGO_DB_USER SET timezone TO 'UTC';
GRANT ALL PRIVILEGES ON DATABASE $DJANGO_DB_NAME TO $DJANGO_DB_USER;
\q
EOF
    fi
    
    # Применение миграций
    log_info "Применение миграций..."
    python manage.py makemigrations
    python manage.py migrate
    
    log_success "База данных настроена"
}

# Создание суперпользователя
create_superuser() {
    log_info "Создание суперпользователя..."
    
    source $VENV_DIR/bin/activate
    
    # Проверяем, существует ли уже суперпользователь
    python manage.py shell << EOF
from django.contrib.auth import get_user_model
User = get_user_model()

if not User.objects.filter(is_superuser=True).exists():
    # Создаем суперпользователя
    user = User.objects.create_superuser(
        username='admin',
        email='admin@example.com',
        password='admin123',
        role='owner'
    )
    print("Суперпользователь создан:")
    print("Логин: admin")
    print("Пароль: admin123")
    print("ВАЖНО: Смените пароль после первого входа!")
else:
    print("Суперпользователь уже существует")
EOF
    
    log_success "Суперпользователь настроен"
}

# Сбор статических файлов
collect_static() {
    log_info "Сбор статических файлов..."
    
    source $VENV_DIR/bin/activate
    python manage.py collectstatic --noinput
    
    log_success "Статические файлы собраны"
}

# Создание директорий
create_directories() {
    log_info "Создание необходимых директорий..."
    
    mkdir -p $BACKUP_DIR
    mkdir -p media
    mkdir -p static
    mkdir -p logs
    
    log_success "Директории созданы"
}

# Настройка прав доступа
setup_permissions() {
    log_info "Настройка прав доступа..."
    
    # Делаем скрипты исполняемыми
    chmod +x deploy.sh
    chmod +x docker-entrypoint.sh 2>/dev/null || true
    
    # Права на медиа и статику
    chmod -R 755 media static 2>/dev/null || true
    
    log_success "Права доступа настроены"
}

# Запуск в режиме разработки
run_development() {
    log_info "Запуск в режиме разработки..."
    
    source $VENV_DIR/bin/activate
    
    log_info "Сервер разработки запускается на http://127.0.0.1:8000/"
    log_info "Для остановки нажмите Ctrl+C"
    log_info "Админ-панель: http://127.0.0.1:8000/admin/"
    log_info "API документация: http://127.0.0.1:8000/api/"
    
    python manage.py runserver
}

# Настройка systemd сервиса для продакшена
setup_systemd() {
    log_info "Настройка systemd сервиса..."
    
    local user=$(whoami)
    local project_path=$(pwd)
    
    sudo tee /etc/systemd/system/crm.service > /dev/null << EOF
[Unit]
Description=CRM Gunicorn daemon
After=network.target

[Service]
User=$user
Group=$user
WorkingDirectory=$project_path
Environment="PATH=$project_path/$VENV_DIR/bin"
ExecStart=$project_path/$VENV_DIR/bin/gunicorn --bind 127.0.0.1:8000 --workers 3 crm_ac.wsgi:application
ExecReload=/bin/kill -s HUP \$MAINPID
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    sudo systemctl daemon-reload
    sudo systemctl enable crm
    sudo systemctl start crm
    
    log_success "Systemd сервис настроен и запущен"
}

# Настройка Nginx
setup_nginx() {
    log_info "Настройка Nginx..."
    
    local project_path=$(pwd)
    
    sudo tee /etc/nginx/sites-available/crm > /dev/null << EOF
server {
    listen 80;
    server_name localhost;

    location = /favicon.ico { access_log off; log_not_found off; }
    
    location /static/ {
        root $project_path;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    location /media/ {
        root $project_path;
        expires 30d;
        add_header Cache-Control "public";
    }

    location / {
        include proxy_params;
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # Безопасность
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
}
EOF
    
    # Включаем сайт
    sudo ln -sf /etc/nginx/sites-available/crm /etc/nginx/sites-enabled/
    sudo nginx -t
    sudo systemctl restart nginx
    
    log_success "Nginx настроен"
}

# Docker развертывание
deploy_docker() {
    log_info "Развертывание через Docker..."
    
    # Проверка Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker не найден! Установите Docker."
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose не найден! Установите Docker Compose."
        exit 1
    fi
    
    # Создание .env для Docker
    if [ ! -f ".env" ]; then
        create_env_file "production"
    fi
    
    # Сборка и запуск
    log_info "Сборка Docker образов..."
    docker-compose build
    
    log_info "Запуск сервисов..."
    docker-compose up -d
    
    # Ожидание запуска сервисов
    log_info "Ожидание запуска сервисов..."
    sleep 30
    
    # Проверка статуса
    docker-compose ps
    
    log_success "Docker развертывание завершено!"
    log_info "Приложение доступно на http://localhost"
    log_info "Для просмотра логов: docker-compose logs -f"
    log_info "Для остановки: docker-compose down"
}

# Развертывание для разработки
deploy_development() {
    log_info "Начало развертывания для разработки..."
    
    check_system
    create_directories
    setup_virtualenv
    install_dependencies "requirements-dev.txt"
    create_env_file "development"
    setup_database "sqlite"
    create_superuser
    collect_static
    setup_permissions
    
    log_success "Развертывание для разработки завершено!"
    log_info "Для запуска сервера выполните: ./deploy.sh run"
}

# Развертывание для продакшена
deploy_production() {
    log_info "Начало развертывания для продакшена..."
    
    # Проверка прав root для некоторых операций
    if [ "$EUID" -eq 0 ]; then
        log_error "Не запускайте скрипт от root! Используйте обычного пользователя."
        exit 1
    fi
    
    check_system
    create_directories
    setup_virtualenv
    install_dependencies "requirements-prod.txt"
    create_env_file "production"
    setup_database "postgresql"
    create_superuser
    collect_static
    setup_permissions
    
    # Настройка сервисов (требует sudo)
    setup_systemd
    
    # Настройка Nginx (если установлен)
    if command -v nginx &> /dev/null; then
        setup_nginx
    else
        log_warning "Nginx не найден. Установите и настройте веб-сервер вручную."
    fi
    
    log_success "Продакшен развертывание завершено!"
    log_info "Сервис запущен и доступен"
    log_info "Статус сервиса: sudo systemctl status crm"
    log_info "Логи сервиса: sudo journalctl -u crm -f"
}

# Создание резервной копии
backup() {
    log_info "Создание резервной копии..."
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$BACKUP_DIR/backup_$timestamp"
    
    # Резервная копия базы данных
    source .env
    if [ "$DJANGO_DB_ENGINE" == "django.db.backends.postgresql" ]; then
        pg_dump -h $DJANGO_DB_HOST -p $DJANGO_DB_PORT -U $DJANGO_DB_USER $DJANGO_DB_NAME > "$backup_file.sql"
    else
        cp db.sqlite3 "$backup_file.sqlite3" 2>/dev/null || true
    fi
    
    # Резервная копия медиа файлов
    tar -czf "$backup_file_media.tar.gz" media/ 2>/dev/null || true
    
    log_success "Резервная копия создана: $backup_file"
}

# Обновление приложения
update() {
    log_info "Обновление приложения..."
    
    # Создаем резервную копию
    backup
    
    # Останавливаем сервис (если есть)
    sudo systemctl stop crm 2>/dev/null || true
    
    # Обновляем код
    if command -v git &> /dev/null; then
        git pull origin main
    else
        log_warning "Git не найден. Обновите код вручную."
    fi
    
    # Обновляем зависимости
    source $VENV_DIR/bin/activate
    pip install -r requirements-prod.txt
    
    # Применяем миграции
    python manage.py migrate
    
    # Собираем статику
    python manage.py collectstatic --noinput
    
    # Запускаем сервис
    sudo systemctl start crm 2>/dev/null || true
    
    log_success "Обновление завершено!"
}

# Проверка статуса
status() {
    log_info "Проверка статуса сервисов..."
    
    # Проверка systemd сервиса
    if systemctl is-active --quiet crm; then
        log_success "CRM сервис запущен"
    else
        log_warning "CRM сервис остановлен"
    fi
    
    # Проверка Nginx
    if systemctl is-active --quiet nginx; then
        log_success "Nginx запущен"
    else
        log_warning "Nginx остановлен"
    fi
    
    # Проверка PostgreSQL
    if systemctl is-active --quiet postgresql; then
        log_success "PostgreSQL запущен"
    else
        log_warning "PostgreSQL остановлен"
    fi
    
    # Проверка портов
    log_info "Проверка портов:"
    netstat -tlnp 2>/dev/null | grep -E ":8000|:80|:5432" || log_warning "Некоторые порты не прослушиваются"
}

# Основная логика
main() {
    case $DEPLOYMENT_MODE in
        "development"|"dev")
            deploy_development
            ;;
        "production"|"prod")
            deploy_production
            ;;
        "docker")
            deploy_docker
            ;;
        "run")
            run_development
            ;;
        "backup")
            backup
            ;;
        "update")
            update
            ;;
        "status")
            status
            ;;
        *)
            log_error "Неизвестный режим: $DEPLOYMENT_MODE"
            echo "Доступные режимы:"
            echo "  development - Разработка"
            echo "  production  - Продакшен"
            echo "  docker      - Docker"
            echo "  run         - Запуск dev сервера"
            echo "  backup      - Резервная копия"
            echo "  update      - Обновление"
            echo "  status      - Статус сервисов"
            exit 1
            ;;
    esac
}

# Обработка сигналов
trap 'log_warning "Прервано пользователем"; exit 1' SIGINT SIGTERM

# Запуск
log_info "CRM система - скрипт развертывания"
log_info "Режим: $DEPLOYMENT_MODE"
log_info "Директория: $PROJECT_DIR"
echo ""

main

log_success "Операция завершена успешно!"