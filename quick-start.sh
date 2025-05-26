#!/bin/bash

# CRM для кондиционеров - Быстрый старт для разработки
# Одной командой настраивает всё для локальной разработки

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# ASCII Art логотип
show_logo() {
    echo -e "${BLUE}"
    cat << 'EOF'
    ______ _____  ___ ___    ____   _____ 
   / ____//  ___|/   |   \  /    | /  ___|
  / /     |  |_ / /| | |\ \/ /| | |  |_ 
 / /      |   _/ /_| | | \  / | | |   _|
/  \____ |  | \___  | |  \/  | | |  |  
\       \|  |     | | |      | | |  |  
 \______||__|     |_| |      |_| |__|  
    
 CRM для кондиционеров - Быстрый старт
EOF
    echo -e "${NC}"
}

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

# Проверка системы
check_prerequisites() {
    log_step "Проверка системных требований..."
    
    local errors=0
    
    # Python
    if command -v python3 &> /dev/null; then
        local python_version=$(python3 --version | cut -d" " -f2)
        log_success "Python $python_version найден"
    else
        log_error "Python 3 не найден! Установите Python 3.9+"
        errors=$((errors + 1))
    fi
    
    # pip
    if command -v pip3 &> /dev/null; then
        log_success "pip3 найден"
    else
        log_error "pip3 не найден! Установите pip3"
        errors=$((errors + 1))
    fi
    
    # git (опционально)
    if command -v git &> /dev/null; then
        log_success "Git найден"
    else
        log_warning "Git не найден, но это не критично"
    fi
    
    if [ $errors -gt 0 ]; then
        log_error "Обнаружены критические ошибки. Установите недостающие компоненты."
        exit 1
    fi
    
    log_success "Системные требования выполнены"
}

# Создание виртуального окружения
setup_venv() {
    log_step "Настройка виртуального окружения..."
    
    if [ -d "venv" ]; then
        log_warning "Виртуальное окружение уже существует"
        read -p "Пересоздать? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf venv
        else
            log_info "Используем существующее окружение"
            return
        fi
    fi
    
    log_info "Создание виртуального окружения..."
    python3 -m venv venv
    
    log_info "Активация окружения..."
    source venv/bin/activate
    
    log_info "Обновление pip..."
    pip install --upgrade pip
    
    log_success "Виртуальное окружение готово"
}

# Установка зависимостей
install_dependencies() {
    log_step "Установка зависимостей..."
    
    source venv/bin/activate
    
    if [ -f "requirements-dev.txt" ]; then
        log_info "Установка зависимостей для разработки..."
        pip install -r requirements-dev.txt
    elif [ -f "requirements.txt" ]; then
        log_info "Установка основных зависимостей..."
        pip install -r requirements.txt
    else
        log_error "Файлы requirements не найдены!"
        exit 1
    fi
    
    log_success "Зависимости установлены"
}

# Создание .env файла
create_env() {
    log_step "Создание файла окружения..."
    
    if [ -f ".env" ]; then
        log_warning ".env файл уже существует"
        return
    fi
    
    log_info "Генерация SECRET_KEY..."
    local secret_key=$(python3 -c 'from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())')
    
    cat > .env << EOF
# Настройки для разработки - создано автоматически $(date)

# Django основные настройки
DJANGO_SECRET_KEY=$secret_key
DJANGO_DEBUG=True
DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1,0.0.0.0

# База данных SQLite (для разработки)
DJANGO_DB_ENGINE=django.db.backends.sqlite3
DJANGO_DB_NAME=db.sqlite3

# Для PostgreSQL (раскомментировать при необходимости):
# DJANGO_DB_ENGINE=django.db.backends.postgresql
# DJANGO_DB_NAME=crm_db
# DJANGO_DB_USER=crm_user
# DJANGO_DB_PASSWORD=password
# DJANGO_DB_HOST=localhost
# DJANGO_DB_PORT=5432

# API ключи (заполнить при необходимости)
YANDEX_MAPS_API_KEY=

# Email настройки (для тестирования)
EMAIL_BACKEND=django.core.mail.backends.console.EmailBackend
EMAIL_HOST=
EMAIL_PORT=587
EMAIL_USE_TLS=True
EMAIL_HOST_USER=
EMAIL_HOST_PASSWORD=

# Настройки разработки
CREATE_SUPERUSER=true
LOAD_FIXTURES=true
CREATE_TEST_SCHEDULES=true

# Дополнительные настройки
REDIS_URL=redis://localhost:6379/0
CELERY_BROKER_URL=redis://localhost:6379/0
EOF
    
    log_success ".env файл создан"
    log_info "Отредактируйте .env при необходимости"
}

# Инициализация базы данных
init_database() {
    log_step "Инициализация базы данных..."
    
    source venv/bin/activate
    
    log_info "Создание миграций..."
    python manage.py makemigrations
    
    log_info "Применение миграций..."
    python manage.py migrate
    
    log_success "База данных инициализирована"
}

# Создание суперпользователя
create_superuser() {
    log_step "Создание суперпользователя..."
    
    source venv/bin/activate
    
    # Проверяем, есть ли уже суперпользователь
    local has_superuser=$(python manage.py shell -c "
from django.contrib.auth import get_user_model
User = get_user_model()
print(User.objects.filter(is_superuser=True).exists())
" 2>/dev/null || echo "False")
    
    if [ "$has_superuser" = "True" ]; then
        log_warning "Суперпользователь уже существует"
        return
    fi
    
    log_info "Создание администратора..."
    python manage.py shell << 'EOF'
from django.contrib.auth import get_user_model
User = get_user_model()

if not User.objects.filter(is_superuser=True).exists():
    user = User.objects.create_superuser(
        username='admin',
        email='admin@example.com',
        password='admin123',
        role='owner',
        first_name='Администратор',
        last_name='Системы'
    )
    print("Суперпользователь создан:")
    print("  Логин: admin")
    print("  Пароль: admin123")
    print("  Email: admin@example.com")
    print("ВАЖНО: Смените пароль после первого входа!")
else:
    print("Суперпользователь уже существует")
EOF
    
    log_success "Суперпользователь создан"
}

# Загрузка тестовых данных
load_test_data() {
    log_step "Загрузка тестовых данных..."
    
    source venv/bin/activate
    
    log_info "Создание тестовых данных..."
    python manage.py shell << 'EOF'
from django.contrib.auth import get_user_model
from customer_clients.models import Client
from services.models import Service
from orders.models import Order, OrderItem
from finance.models import Transaction
import random

User = get_user_model()

# Создание пользователей
if not User.objects.filter(role='manager').exists():
    User.objects.create_user(
        username='manager1',
        email='manager1@example.com',
        password='manager123',
        role='manager',
        first_name='Иван',
        last_name='Менеджеров'
    )

if not User.objects.filter(role='installer').exists():
    User.objects.create_user(
        username='installer1',
        email='installer1@example.com',
        password='installer123',
        role='installer',
        first_name='Петр',
        last_name='Монтажников'
    )

# Создание клиентов
clients_data = [
    ('Иван Петров', 'г. Москва, ул. Ленина, 10', '+79001234567', 'avito'),
    ('Мария Сидорова', 'г. Москва, ул. Пушкина, 5', '+79001234568', 'website'),
    ('Алексей Козлов', 'г. Москва, пр. Мира, 25', '+79001234569', 'vk'),
]

for name, address, phone, source in clients_data:
    Client.objects.get_or_create(
        name=name,
        defaults={'address': address, 'phone': phone, 'source': source}
    )

# Создание услуг
services_data = [
    ('Кондиционер LG 9000 BTU', 20000, 30000, 'conditioner'),
    ('Кондиционер Samsung 12000 BTU', 25000, 35000, 'conditioner'),
    ('Монтаж сплит-системы', 3000, 5000, 'installation'),
    ('Демонтаж кондиционера', 1500, 3000, 'dismantling'),
    ('Техническое обслуживание', 1000, 2000, 'maintenance'),
    ('Дозаправка фреоном', 1500, 2500, 'additional'),
]

for name, cost, price, category in services_data:
    Service.objects.get_or_create(
        name=name,
        defaults={'cost_price': cost, 'selling_price': price, 'category': category}
    )

print("Тестовые данные созданы:")
print(f"  Пользователи: {User.objects.count()}")
print(f"  Клиенты: {Client.objects.count()}")
print(f"  Услуги: {Service.objects.count()}")
EOF
    
    log_success "Тестовые данные загружены"
}

# Сбор статических файлов
collect_static() {
    log_step "Сбор статических файлов..."
    
    source venv/bin/activate
    
    mkdir -p static media
    python manage.py collectstatic --noinput
    
    log_success "Статические файлы собраны"
}

# Проверка установки
validate_installation() {
    log_step "Проверка установки..."
    
    source venv/bin/activate
    
    log_info "Проверка конфигурации Django..."
    python manage.py check --deploy || python manage.py check
    
    log_info "Проверка базы данных..."
    python manage.py showmigrations | head -10
    
    log_success "Проверка пройдена"
}

# Создание полезных скриптов
create_helper_scripts() {
    log_step "Создание вспомогательных скриптов..."
    
    # Скрипт запуска сервера
    cat > run-server.sh << 'EOF'
#!/bin/bash
# Быстрый запуск сервера разработки

source venv/bin/activate
python manage.py runserver 0.0.0.0:8000
EOF
    chmod +x run-server.sh
    
    # Скрипт для работы с shell
    cat > django-shell.sh << 'EOF'
#!/bin/bash
# Запуск Django shell

source venv/bin/activate
python manage.py shell
EOF
    chmod +x django-shell.sh
    
    # Скрипт тестирования
    cat > run-tests.sh << 'EOF'
#!/bin/bash
# Запуск тестов

source venv/bin/activate
python manage.py test
EOF
    chmod +x run-tests.sh
    
    log_success "Вспомогательные скрипты созданы"
}

# Показ информации о завершении
show_completion_info() {
    log_success "Быстрая настройка завершена!"
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║           УСТАНОВКА ЗАВЕРШЕНА            ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}🚀 Для запуска сервера:${NC}"
    echo "   ./run-server.sh"
    echo "   или"
    echo "   source venv/bin/activate && python manage.py runserver"
    echo ""
    echo -e "${BLUE}🌐 После запуска доступно:${NC}"
    echo "   • Главная страница: http://127.0.0.1:8000/"
    echo "   • Админ-панель: http://127.0.0.1:8000/admin/"
    echo "   • API: http://127.0.0.1:8000/api/"
    echo ""
    echo -e "${BLUE}👤 Данные для входа:${NC}"
    echo "   • Логин: admin"
    echo "   • Пароль: admin123"
    echo ""
    echo -e "${BLUE}📁 Полезные команды:${NC}"
    echo "   • Django shell: ./django-shell.sh"
    echo "   • Запуск тестов: ./run-tests.sh"
    echo "   • Создание миграций: source venv/bin/activate && python manage.py makemigrations"
    echo "   • Создание суперпользователя: source venv/bin/activate && python manage.py createsuperuser"
    echo ""
    echo -e "${YELLOW}⚠️  Не забудьте:${NC}"
    echo "   • Изменить пароль администратора"
    echo "   • Настроить API ключи в .env файле"
    echo "   • Ознакомиться с документацией проекта"
    echo ""
    echo -e "${PURPLE}💡 Для продакшн развертывания используйте:${NC}"
    echo "   ./deploy.sh production"
    echo ""
}

# Обработка ошибок
handle_error() {
    log_error "Произошла ошибка на шаге: $1"
    log_info "Проверьте логи выше для диагностики"
    log_info "Для получения помощи создайте issue с описанием ошибки"
    exit 1
}

# Основная функция
main() {
    show_logo
    
    log_info "Автоматическая настройка CRM системы для разработки"
    log_info "Это займет несколько минут..."
    echo ""
    
    # Подтверждение
    read -p "Продолжить установку? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        log_info "Установка отменена"
        exit 0
    fi
    
    # Выполнение шагов
    check_prerequisites || handle_error "Проверка требований"
    setup_venv || handle_error "Настройка виртуального окружения"
    install_dependencies || handle_error "Установка зависимостей"
    create_env || handle_error "Создание .env файла"
    init_database || handle_error "Инициализация базы данных"
    create_superuser || handle_error "Создание суперпользователя"
    load_test_data || handle_error "Загрузка тестовых данных"
    collect_static || handle_error "Сбор статических файлов"
    validate_installation || handle_error "Проверка установки"
    create_helper_scripts || handle_error "Создание вспомогательных скриптов"
    
    show_completion_info
}

# Проверка аргументов командной строки
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "CRM Quick Start - Быстрая настройка для разработки"
    echo ""
    echo "Использование:"
    echo "  $0              # Интерактивная установка"
    echo "  $0 --auto       # Автоматическая установка без вопросов"
    echo "  $0 --clean      # Очистка и переустановка"
    echo "  $0 --help       # Показать эту справку"
    echo ""
    echo "Что делает скрипт:"
    echo "  • Проверяет системные требования"
    echo "  • Создает виртуальное окружение Python"
    echo "  • Устанавливает зависимости"
    echo "  • Настраивает базу данных SQLite"
    echo "  • Создает суперпользователя (admin/admin123)"
    echo "  • Загружает тестовые данные"
    echo "  • Создает полезные скрипты"
    echo ""
    exit 0
fi

if [ "$1" = "--clean" ]; then
    log_warning "Очистка существующих файлов..."
    rm -rf venv/ db.sqlite3 .env static/ media/ *.log
    rm -f run-server.sh django-shell.sh run-tests.sh
    log_success "Очистка завершена"
    echo ""
fi

if [ "$1" = "--auto" ]; then
    export AUTO_MODE=true
fi

# Обработка сигналов
trap 'log_error "Установка прервана пользователем"; exit 1' SIGINT SIGTERM

# Запуск основной функции
main