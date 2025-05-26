#!/bin/bash

# CRM для кондиционеров - Docker Entrypoint Script

set -e

# Функция для логирования
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Ожидание готовности базы данных
wait_for_db() {
    log "Ожидание готовности базы данных..."
    
    while ! pg_isready -h "$DJANGO_DB_HOST" -p "$DJANGO_DB_PORT" -U "$DJANGO_DB_USER" -d "$DJANGO_DB_NAME"; do
        log "База данных не готова, ожидание..."
        sleep 2
    done
    
    log "База данных готова!"
}

# Применение миграций
apply_migrations() {
    log "Применение миграций базы данных..."
    python manage.py migrate --noinput
    log "Миграции применены успешно!"
}

# Сбор статических файлов
collect_static() {
    log "Сбор статических файлов..."
    python manage.py collectstatic --noinput --clear
    log "Статические файлы собраны!"
}

# Создание суперпользователя (если не существует)
create_superuser() {
    log "Проверка существования суперпользователя..."
    python manage.py shell << EOF
from django.contrib.auth import get_user_model
User = get_user_model()

# Создаем суперпользователя только если его нет
if not User.objects.filter(is_superuser=True).exists():
    User.objects.create_superuser(
        username='admin',
        email='admin@example.com',
        password='admin123',
        role='owner'
    )
    print("Суперпользователь создан: admin/admin123")
else:
    print("Суперпользователь уже существует")
EOF
}

# Загрузка начальных данных (если нужно)
load_initial_data() {
    if [ "$LOAD_FIXTURES" = "true" ]; then
        log "Загрузка начальных данных..."
        if [ -f "/app/fixtures/initial_data.json" ]; then
            python manage.py loaddata /app/fixtures/initial_data.json
            log "Начальные данные загружены!"
        else
            log "Файл начальных данных не найден"
        fi
    fi
}

# Создание тестовых расписаний (если нужно)
create_test_schedules() {
    if [ "$CREATE_TEST_SCHEDULES" = "true" ]; then
        log "Создание тестовых расписаний..."
        python manage.py create_schedules --auto-assign --dry-run || true
        log "Тестовые расписания созданы!"
    fi
}

# Проверка здоровья приложения
health_check() {
    log "Проверка здоровья приложения..."
    python manage.py check --deploy
    log "Проверка пройдена успешно!"
}

# Основная логика
main() {
    log "Запуск CRM системы..."
    
    # Ждем готовности базы данных
    if [ "$DJANGO_DB_HOST" != "sqlite" ]; then
        wait_for_db
    fi
    
    # Применяем миграции
    apply_migrations
    
    # Собираем статические файлы
    collect_static
    
    # Создаем суперпользователя
    if [ "$CREATE_SUPERUSER" != "false" ]; then
        create_superuser
    fi
    
    # Загружаем начальные данные
    load_initial_data
    
    # Создаем тестовые расписания
    create_test_schedules
    
    # Проверка здоровья
    health_check
    
    log "Инициализация завершена. Запуск приложения..."
    
    # Выполняем переданную команду
    exec "$@"
}

# Обработка сигналов
trap 'log "Получен сигнал завершения, остановка..."; exit 0' SIGTERM SIGINT

# Запуск основной логики
main "$@"