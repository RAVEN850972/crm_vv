#!/bin/bash

# CRM для кондиционеров - Docker Manager
# Управление Docker окружением одной командой

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Функции логирования
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

log_step() {
    echo -e "${PURPLE}[STEP]${NC} $1"
}

# Проверка Docker
check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker не найден! Установите Docker."
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose не найден! Установите Docker Compose."
        exit 1
    fi
    
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker daemon не запущен или нет прав доступа."
        log_info "Попробуйте: sudo systemctl start docker"
        log_info "Или добавьте пользователя в группу docker: sudo usermod -aG docker \$USER"
        exit 1
    fi
    
    log_success "Docker готов к работе"
}

# Создание .env файла для Docker
create_docker_env() {
    if [ -f ".env" ]; then
        log_warning ".env файл уже существует"
        return
    fi
    
    log_step "Создание .env файла для Docker..."
    
    local secret_key=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-50)
    local db_password=$(openssl rand -base64 16 | tr -d "=+/")
    
    cat > .env << EOF
# Docker Environment Configuration
# Создано автоматически $(date)

# Django настройки
DJANGO_SECRET_KEY=$secret_key
DJANGO_DEBUG=False
DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1,0.0.0.0

# База данных PostgreSQL
DJANGO_DB_ENGINE=django.db.backends.postgresql
DJANGO_DB_NAME=crm_db
DJANGO_DB_USER=crm_user
DJANGO_DB_PASSWORD=$db_password
DJANGO_DB_HOST=db
DJANGO_DB_PORT=5432

# Redis
REDIS_URL=redis://redis:6379/0
CELERY_BROKER_URL=redis://redis:6379/0

# API ключи (заполните при необходимости)
YANDEX_MAPS_API_KEY=

# Email настройки
EMAIL_BACKEND=django.core.mail.backends.console.EmailBackend
EMAIL_HOST=
EMAIL_PORT=587
EMAIL_USE_TLS=True
EMAIL_HOST_USER=
EMAIL_HOST_PASSWORD=

# Настройки инициализации
CREATE_SUPERUSER=true
LOAD_FIXTURES=true
CREATE_TEST_SCHEDULES=false

# PostgreSQL настройки (для docker-compose)
POSTGRES_DB=crm_db
POSTGRES_USER=crm_user
POSTGRES_PASSWORD=$db_password
EOF
    
    log_success ".env файл создан"
    log_warning "Отредактируйте .env файл при необходимости"
}

# Создание Nginx конфигурации
create_nginx_config() {
    if [ -f "nginx.conf" ]; then
        log_info "nginx.conf уже существует"
        return
    fi
    
    log_step "Создание конфигурации Nginx..."
    
    cat > nginx.conf << 'EOF'
upstream web {
    server web:8000;
}

server {
    listen 80;
    server_name localhost;
    
    client_max_body_size 100M;
    
    location = /favicon.ico { 
        access_log off; 
        log_not_found off; 
    }
    
    location /static/ {
        alias /app/staticfiles/;
        expires 30d;
        add_header Cache-Control "public, immutable";
        add_header Vary Accept-Encoding;
        gzip_static on;
    }

    location /media/ {
        alias /app/media/;
        expires 7d;
        add_header Cache-Control "public";
    }

    location / {
        proxy_pass http://web;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_redirect off;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # Безопасность
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header X-XSS-Protection "1; mode=block" always;
    
    # Логирование
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;
}
EOF
    
    log_success "Конфигурация Nginx создана"
}

# Сборка образов
build_images() {
    log_step "Сборка Docker образов..."
    
    docker-compose build --no-cache
    
    log_success "Образы собраны"
}

# Запуск сервисов
start_services() {
    log_step "Запуск сервисов..."
    
    # Запуск в фоновом режиме
    docker-compose up -d
    
    log_info "Ожидание готовности сервисов..."
    sleep 30
    
    # Проверка статуса
    docker-compose ps
    
    log_success "Сервисы запущены"
}

# Остановка сервисов
stop_services() {
    log_step "Остановка сервисов..."
    
    docker-compose down
    
    log_success "Сервисы остановлены"
}

# Перезапуск сервисов
restart_services() {
    log_step "Перезапуск сервисов..."
    
    docker-compose restart
    
    log_success "Сервисы перезапущены"
}

# Просмотр логов
show_logs() {
    local service=${1:-""}
    
    if [ -z "$service" ]; then
        log_info "Показ логов всех сервисов..."
        docker-compose logs -f --tail=100
    else
        log_info "Показ логов сервиса: $service"
        docker-compose logs -f --tail=100 "$service"
    fi
}

# Статус сервисов
show_status() {
    log_step "Статус сервисов..."
    
    echo -e "${CYAN}Docker Compose статус:${NC}"
    docker-compose ps
    
    echo -e "\n${CYAN}Использование ресурсов:${NC}"
    docker stats --no-stream
    
    echo -e "\n${CYAN}Проверка доступности:${NC}"
    
    # Проверка веб-сервиса
    if curl -f http://localhost:80 >/dev/null 2>&1; then
        log_success "Веб-сервер доступен на http://localhost"
    else
        log_warning "Веб-сервер недоступен"
    fi
    
    # Проверка базы данных
    if docker-compose exec -T db pg_isready -U crm_user >/dev/null 2>&1; then
        log_success "База данных PostgreSQL доступна"
    else
        log_warning "База данных недоступна"
    fi
    
    # Проверка Redis
    if docker-compose exec -T redis redis-cli ping >/dev/null 2>&1; then
        log_success "Redis доступен"
    else
        log_warning "Redis недоступен"
    fi
}

# Выполнение команд в контейнере
exec_command() {
    local service=$1
    shift
    local command="$@"
    
    if [ -z "$service" ] || [ -z "$command" ]; then
        log_error "Использование: docker-manager.sh exec <service> <command>"
        exit 1
    fi
    
    log_info "Выполнение команды в $service: $command"
    docker-compose exec "$service" $command
}

# Django команды
django_command() {
    local cmd="$@"
    
    if [ -z "$cmd" ]; then
        log_error "Использование: docker-manager.sh django <command>"
        exit 1
    fi
    
    log_info "Выполнение Django команды: $cmd"
    docker-compose exec web python manage.py $cmd
}

# Резервное копирование
backup() {
    log_step "Создание резервной копии..."
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_dir="backups"
    
    mkdir -p "$backup_dir"
    
    # Backup базы данных
    log_info "Backup базы данных..."
    docker-compose exec -T db pg_dump -U crm_user crm_db > "$backup_dir/db_backup_$timestamp.sql"
    
    # Backup volume'ов
    log_info "Backup данных..."
    docker run --rm -v "$(pwd)_postgres_data:/source:ro" -v "$(pwd)/$backup_dir:/backup" alpine tar czf "/backup/postgres_data_$timestamp.tar.gz" -C /source .
    docker run --rm -v "$(pwd)_media_volume:/source:ro" -v "$(pwd)/$backup_dir:/backup" alpine tar czf "/backup/media_data_$timestamp.tar.gz" -C /source .
    
    log_success "Backup создан в папке $backup_dir"
}

# Восстановление из backup
restore() {
    local backup_file=$1
    
    if [ -z "$backup_file" ] || [ ! -f "$backup_file" ]; then
        log_error "Файл backup не найден: $backup_file"
        log_info "Использование: docker-manager.sh restore <backup_file.sql>"
        exit 1
    fi
    
    log_step "Восстановление из backup: $backup_file"
    log_warning "Это удалит все текущие данные!"
    
    read -p "Продолжить? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Восстановление отменено"
        exit 0
    fi
    
    # Остановка сервисов
    docker-compose down
    
    # Удаление старых данных
    docker volume rm "$(basename $(pwd))_postgres_data" 2>/dev/null || true
    
    # Запуск только базы данных
    docker-compose up -d db
    sleep 10
    
    # Восстановление
    docker-compose exec -T db psql -U crm_user -d crm_db < "$backup_file"
    
    # Запуск всех сервисов
    docker-compose up -d
    
    log_success "Восстановление завершено"
}

# Обновление образов
update() {
    log_step "Обновление системы..."
    
    # Создание backup
    backup
    
    # Остановка сервисов
    stop_services
    
    # Обновление кода (если есть git)
    if command -v git &> /dev/null && [ -d ".git" ]; then
        log_info "Обновление кода..."
        git pull origin main
    fi
    
    # Пересборка образов
    build_images
    
    # Запуск сервисов
    start_services
    
    # Применение миграций
    django_command migrate
    
    # Сбор статики
    django_command collectstatic --noinput
    
    log_success "Обновление завершено"
}

# Очистка системы
cleanup() {
    log_step "Очистка Docker системы..."
    
    log_warning "Это удалит все неиспользуемые образы, контейнеры и volumes!"
    read -p "Продолжить? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Очистка отменена"
        exit 0
    fi
    
    # Остановка проекта
    docker-compose down -v
    
    # Удаление образов проекта
    docker-compose down --rmi all
    
    # Очистка системы
    docker system prune -af
    docker volume prune -f
    
    log_success "Очистка завершена"
}

# Мониторинг ресурсов
monitor() {
    log_info "Мониторинг ресурсов (Ctrl+C для выхода)..."
    
    while true; do
        clear
        echo -e "${CYAN}=== CRM Docker Monitor ===${NC}"
        echo "Обновление каждые 5 секунд"
        echo ""
        
        echo -e "${YELLOW}Статус сервисов:${NC}"
        docker-compose ps
        echo ""
        
        echo -e "${YELLOW}Использование ресурсов:${NC}"
        docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"
        echo ""
        
        echo -e "${YELLOW}Логи (последние 5 строк):${NC}"
        docker-compose logs --tail=5 | tail -10
        
        sleep 5
    done
}

# Помощь
show_help() {
    echo "CRM Docker Manager - Управление Docker окружением"
    echo ""
    echo "Использование: $0 <command> [args]"
    echo ""
    echo "Команды:"
    echo "  init                 - Первоначальная настройка"
    echo "  build               - Сборка образов"
    echo "  up                  - Запуск сервисов"
    echo "  down                - Остановка сервисов"
    echo "  restart             - Перезапуск сервисов"
    echo "  status              - Статус сервисов"
    echo "  logs [service]      - Просмотр логов"
    echo "  exec <service> <cmd> - Выполнение команды в контейнере"
    echo "  django <cmd>        - Выполнение Django команды"
    echo "  backup              - Создание резервной копии"
    echo "  restore <file>      - Восстановление из backup"
    echo "  update              - Обновление системы"
    echo "  cleanup             - Очистка Docker системы"
    echo "  monitor             - Мониторинг ресурсов"
    echo "  help                - Показать эту справку"
    echo ""
    echo "Примеры:"
    echo "  $0 init                              # Первоначальная настройка"
    echo "  $0 up                                # Запуск всех сервисов"
    echo "  $0 logs web                          # Логи веб-сервера"
    echo "  $0 django createsuperuser            # Создание суперпользователя"
    echo "  $0 exec web bash                     # Вход в контейнер"
    echo "  $0 backup                            # Создание backup"
    echo ""
}

# Инициализация проекта
init_project() {
    log_step "Инициализация Docker проекта..."
    
    check_docker
    create_docker_env
    create_nginx_config
    
    # Создание директорий
    mkdir -p backups ssl
    
    build_images
    start_services
    
    # Ожидание готовности базы данных
    log_info "Ожидание готовности базы данных..."
    sleep 30
    
    # Инициализация Django
    django_command migrate
    django_command collectstatic --noinput
    
    # Создание суперпользователя
    log_info "Создание суперпользователя..."
    docker-compose exec web python manage.py shell << 'EOF'
from django.contrib.auth import get_user_model
User = get_user_model()

if not User.objects.filter(is_superuser=True).exists():
    user = User.objects.create_superuser(
        username='admin',
        email='admin@example.com',
        password='admin123',
        role='owner'
    )
    print("Суперпользователь создан: admin/admin123")
else:
    print("Суперпользователь уже существует")
EOF
    
    show_status
    
    log_success "Инициализация завершена!"
    echo ""
    echo -e "${GREEN}🚀 CRM система готова к работе!${NC}"
    echo -e "${BLUE}📱 Приложение: http://localhost${NC}"
    echo -e "${BLUE}🔧 Админ-панель: http://localhost/admin${NC}"
    echo -e "${BLUE}🔗 API: http://localhost/api${NC}"
    echo ""
    echo -e "${YELLOW}👤 Логин: admin${NC}"
    echo -e "${YELLOW}🔑 Пароль: admin123${NC}"
    echo ""
}

# Основная логика
main() {
    case "${1:-help}" in
        "init")
            init_project
            ;;
        "build")
            check_docker
            build_images
            ;;
        "up")
            check_docker
            start_services
            ;;
        "down")
            stop_services
            ;;
        "restart")
            restart_services
            ;;
        "status")
            show_status
            ;;
        "logs")
            show_logs "$2"
            ;;
        "exec")
            shift
            exec_command "$@"
            ;;
        "django")
            shift
            django_command "$@"
            ;;
        "backup")
            backup
            ;;
        "restore")
            restore "$2"
            ;;
        "update")
            update
            ;;
        "cleanup")
            cleanup
            ;;
        "monitor")
            monitor
            ;;
        "help"|"--help"|"-h")
            show_help
            ;;
        *)
            log_error "Неизвестная команда: $1"
            show_help
            exit 1
            ;;
    esac
}

# Обработка сигналов
trap 'log_warning "Операция прервана"; exit 1' SIGINT SIGTERM

# Запуск
main "$@"