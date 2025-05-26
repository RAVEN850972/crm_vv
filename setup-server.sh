#!/bin/bash

# CRM для кондиционеров - Скрипт настройки сервера
# Для Ubuntu 20.04/22.04 LTS

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Проверка на root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "Этот скрипт должен быть запущен от root"
        log_info "Используйте: sudo $0"
        exit 1
    fi
}

# Обновление системы
update_system() {
    log_info "Обновление системы..."
    apt update
    apt upgrade -y
    log_success "Автоматические обновления настроены"
}

# Настройка мониторинга системы
setup_monitoring() {
    log_info "Установка инструментов мониторинга..."
    
    # Установка htop, iotop, nethogs
    apt install -y htop iotop nethogs nmon
    
    # Установка логротации
    apt install -y logrotate
    
    # Настройка логротации для приложения
    cat > /etc/logrotate.d/crm << 'EOF'
/home/crm/crm_ac/logs/*.log {
    daily
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    create 644 crm crm
    postrotate
        systemctl reload crm
    endscript
}
EOF
    
    log_success "Мониторинг настроен"
}

# Установка SSL сертификата
install_ssl() {
    local domain=$1
    
    if [ -z "$domain" ]; then
        log_warning "Домен не указан, пропуск установки SSL"
        return
    fi
    
    log_info "Установка SSL сертификата для $domain..."
    
    # Установка Certbot
    apt install -y certbot python3-certbot-nginx
    
    # Получение сертификата
    certbot --nginx -d $domain --non-interactive --agree-tos --email admin@$domain
    
    # Настройка автообновления
    crontab -l | { cat; echo "0 12 * * * /usr/bin/certbot renew --quiet"; } | crontab -
    
    log_success "SSL сертификат установлен"
}

# Оптимизация производительности
optimize_performance() {
    log_info "Оптимизация производительности..."
    
    # Настройка swap файла (если нет)
    if [ ! -f /swapfile ]; then
        log_info "Создание swap файла..."
        fallocate -l 2G /swapfile
        chmod 600 /swapfile
        mkswap /swapfile
        swapon /swapfile
        echo '/swapfile none swap sw 0 0' >> /etc/fstab
    fi
    
    # Оптимизация сети
    cat >> /etc/sysctl.conf << 'EOF'

# Оптимизация сети
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728
net.ipv4.tcp_congestion_control = bbr
EOF
    
    # Применение настроек
    sysctl -p
    
    # Оптимизация PostgreSQL
    if [ -f /etc/postgresql/*/main/postgresql.conf ]; then
        log_info "Оптимизация PostgreSQL..."
        PG_CONF=$(find /etc/postgresql -name postgresql.conf | head -1)
        
        # Базовая оптимизация для малого сервера
        sed -i "s/#shared_buffers = 128MB/shared_buffers = 256MB/" $PG_CONF
        sed -i "s/#effective_cache_size = 4GB/effective_cache_size = 1GB/" $PG_CONF
        sed -i "s/#maintenance_work_mem = 64MB/maintenance_work_mem = 64MB/" $PG_CONF
        sed -i "s/#checkpoint_completion_target = 0.5/checkpoint_completion_target = 0.7/" $PG_CONF
        sed -i "s/#wal_buffers = -1/wal_buffers = 16MB/" $PG_CONF
        sed -i "s/#default_statistics_target = 100/default_statistics_target = 100/" $PG_CONF
        
        systemctl restart postgresql
    fi
    
    log_success "Производительность оптимизирована"
}

# Создание backup скрипта
create_backup_script() {
    log_info "Создание скрипта резервного копирования..."
    
    cat > /usr/local/bin/crm-backup.sh << 'EOF'
#!/bin/bash

# Скрипт резервного копирования CRM системы

set -e

BACKUP_DIR="/home/crm/backups"
DATE=$(date +%Y%m%d_%H%M%S)
APP_DIR="/home/crm/crm_ac"

# Создание директории
mkdir -p $BACKUP_DIR

# Backup базы данных
echo "Создание backup базы данных..."
sudo -u crm pg_dump -h localhost -U crm_user crm_db > $BACKUP_DIR/db_backup_$DATE.sql

# Backup медиа файлов
echo "Создание backup медиа файлов..."
tar -czf $BACKUP_DIR/media_backup_$DATE.tar.gz -C $APP_DIR media/

# Backup конфигурации
echo "Создание backup конфигурации..."
tar -czf $BACKUP_DIR/config_backup_$DATE.tar.gz -C $APP_DIR .env

# Удаление старых backup'ов (старше 30 дней)
find $BACKUP_DIR -name "*.sql" -mtime +30 -delete
find $BACKUP_DIR -name "*.tar.gz" -mtime +30 -delete

echo "Backup завершен: $DATE"
EOF
    
    chmod +x /usr/local/bin/crm-backup.sh
    
    # Добавление в cron (ежедневно в 2:00)
    (crontab -l 2>/dev/null; echo "0 2 * * * /usr/local/bin/crm-backup.sh") | crontab -
    
    log_success "Скрипт backup создан и добавлен в cron"
}

# Настройка логирования
setup_logging() {
    log_info "Настройка системы логирования..."
    
    # Создание директории для логов приложения
    mkdir -p /var/log/crm
    chown crm:crm /var/log/crm
    
    # Настройка rsyslog для приложения
    cat > /etc/rsyslog.d/crm.conf << 'EOF'
# CRM Application logs
:programname, isequal, "crm" /var/log/crm/application.log
& stop
EOF
    
    systemctl restart rsyslog
    
    log_success "Логирование настроено"
}

# Проверка безопасности
security_check() {
    log_info "Проверка безопасности..."
    
    # Проверка на открытые порты
    log_info "Открытые порты:"
    netstat -tuln
    
    # Проверка запущенных сервисов
    log_info "Активные сервисы:"
    systemctl list-units --type=service --state=active | grep -E "(postgresql|nginx|redis|ssh)"
    
    # Проверка пользователей с sudo
    log_info "Пользователи с sudo правами:"
    getent group sudo
    
    log_success "Проверка безопасности завершена"
}

# Создание информационного файла
create_info_file() {
    log_info "Создание информационного файла..."
    
    cat > /home/crm/server-info.txt << EOF
# CRM Server Information
# Создано: $(date)

## Установленные сервисы:
- PostgreSQL: $(systemctl is-active postgresql)
- Redis: $(systemctl is-active redis-server)
- Nginx: $(systemctl is-active nginx)

## Пользователи:
- Пользователь приложения: crm
- Домашняя директория: /home/crm
- Проекты: /home/crm/projects
- Backup: /home/crm/backups

## Базы данных:
- PostgreSQL порт: 5432
- Redis порт: 6379

## Сеть:
- HTTP порт: 80
- HTTPS порт: 443

## Важные файлы:
- Конфигурация Nginx: /etc/nginx/sites-available/crm
- Systemd сервис: /etc/systemd/system/crm.service
- Логи приложения: /var/log/crm/
- Backup скрипт: /usr/local/bin/crm-backup.sh

## Команды управления:
- Статус CRM: sudo systemctl status crm
- Перезапуск CRM: sudo systemctl restart crm
- Логи CRM: sudo journalctl -u crm -f
- Backup: sudo /usr/local/bin/crm-backup.sh

## Следующие шаги:
1. Скачайте код приложения: git clone <repo> /home/crm/crm_ac
2. Запустите развертывание: cd /home/crm/crm_ac && ./deploy.sh production
3. Настройте домен в /etc/nginx/sites-available/crm
4. Установите SSL: sudo certbot --nginx -d your-domain.com

EOF
    
    chown crm:crm /home/crm/server-info.txt
    
    log_success "Информационный файл создан: /home/crm/server-info.txt"
}

# Интерактивное меню
show_menu() {
    echo ""
    echo "=== CRM Server Setup ==="
    echo "1. Полная установка (рекомендуется)"
    echo "2. Только базовые пакеты"
    echo "3. Только PostgreSQL"
    echo "4. Только Nginx"
    echo "5. Только Docker"
    echo "6. Настройка SSL"
    echo "7. Оптимизация производительности"
    echo "8. Проверка безопасности"
    echo "9. Выход"
    echo ""
    read -p "Выберите опцию [1-9]: " choice
}

# Полная установка
full_install() {
    log_info "Начало полной установки сервера..."
    
    update_system
    install_basic_packages
    install_python
    install_postgresql
    install_redis
    install_nginx
    setup_firewall
    create_app_user
    setup_auto_updates
    setup_monitoring
    optimize_performance
    create_backup_script
    setup_logging
    create_info_file
    security_check
    
    log_success "Полная установка завершена!"
    log_info "Прочитайте /home/crm/server-info.txt для следующих шагов"
}

# Основная логика
main() {
    check_root
    
    if [ $# -eq 0 ]; then
        # Интерактивный режим
        while true; do
            show_menu
            case $choice in
                1)
                    full_install
                    break
                    ;;
                2)
                    update_system
                    install_basic_packages
                    install_python
                    ;;
                3)
                    install_postgresql
                    ;;
                4)
                    install_nginx
                    setup_firewall
                    ;;
                5)
                    install_docker
                    ;;
                6)
                    read -p "Введите домен: " domain
                    install_ssl $domain
                    ;;
                7)
                    optimize_performance
                    ;;
                8)
                    security_check
                    ;;
                9)
                    log_info "Выход..."
                    exit 0
                    ;;
                *)
                    log_error "Неверный выбор"
                    ;;
            esac
        done
    else
        # Режим командной строки
        case $1 in
            "full")
                full_install
                ;;
            "basic")
                update_system
                install_basic_packages
                install_python
                ;;
            "postgresql")
                install_postgresql
                ;;
            "nginx")
                install_nginx
                setup_firewall
                ;;
            "docker")
                install_docker
                ;;
            "ssl")
                install_ssl $2
                ;;
            "optimize")
                optimize_performance
                ;;
            "check")
                security_check
                ;;
            *)
                echo "Использование: $0 [full|basic|postgresql|nginx|docker|ssl domain|optimize|check]"
                exit 1
                ;;
        esac
    fi
}

# Запуск
log_info "CRM Server Setup Script"
log_info "Ubuntu 20.04/22.04 LTS"
echo ""

main "$@"

log_success "Настройка сервера завершена!"Система обновлена"
}

# Установка базовых пакетов
install_basic_packages() {
    log_info "Установка базовых пакетов..."
    
    apt install -y \
        curl \
        wget \
        git \
        vim \
        nano \
        htop \
        tree \
        unzip \
        build-essential \
        software-properties-common \
        apt-transport-https \
        ca-certificates \
        gnupg \
        lsb-release
    
    log_success "Базовые пакеты установлены"
}

# Установка Python
install_python() {
    log_info "Установка Python и pip..."
    
    apt install -y \
        python3 \
        python3-pip \
        python3-venv \
        python3-dev \
        python3-setuptools
    
    # Обновление pip
    python3 -m pip install --upgrade pip
    
    log_success "Python установлен"
    python3 --version
}

# Установка PostgreSQL
install_postgresql() {
    log_info "Установка PostgreSQL..."
    
    apt install -y \
        postgresql \
        postgresql-contrib \
        libpq-dev
    
    # Запуск и автозапуск
    systemctl start postgresql
    systemctl enable postgresql
    
    log_success "PostgreSQL установлен"
    
    # Настройка базовой безопасности
    log_info "Настройка PostgreSQL..."
    sudo -u postgres psql << 'EOF'
ALTER USER postgres PASSWORD 'postgres_admin_password_change_me';
\q
EOF
    
    log_warning "ВАЖНО: Смените пароль postgres в продакшене!"
}

# Установка Redis
install_redis() {
    log_info "Установка Redis..."
    
    apt install -y redis-server
    
    # Настройка Redis
    sed -i 's/^supervised no/supervised systemd/' /etc/redis/redis.conf
    
    systemctl restart redis-server
    systemctl enable redis-server
    
    log_success "Redis установлен"
}

# Установка Nginx
install_nginx() {
    log_info "Установка Nginx..."
    
    apt install -y nginx
    
    # Запуск и автозапуск
    systemctl start nginx
    systemctl enable nginx
    
    # Настройка firewall
    ufw allow 'Nginx Full'
    
    log_success "Nginx установлен"
}

# Установка Docker (опционально)
install_docker() {
    log_info "Установка Docker..."
    
    # Удаление старых версий
    apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Добавление репозитория Docker
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Установка Docker
    apt update
    apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Запуск и автозапуск
    systemctl start docker
    systemctl enable docker
    
    # Установка Docker Compose
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    
    log_success "Docker установлен"
    docker --version
    docker-compose --version
}

# Настройка firewall
setup_firewall() {
    log_info "Настройка firewall..."
    
    # Базовые правила
    ufw --force enable
    ufw default deny incoming
    ufw default allow outgoing
    
    # SSH
    ufw allow ssh
    
    # HTTP/HTTPS
    ufw allow 80
    ufw allow 443
    
    # PostgreSQL (только локально)
    ufw allow from 127.0.0.1 to any port 5432
    
    # Redis (только локально)
    ufw allow from 127.0.0.1 to any port 6379
    
    log_success "Firewall настроен"
    ufw status
}

# Создание пользователя для приложения
create_app_user() {
    local username=${1:-crm}
    
    log_info "Создание пользователя приложения: $username"
    
    if id "$username" &>/dev/null; then
        log_warning "Пользователь $username уже существует"
    else
        useradd -m -s /bin/bash $username
        usermod -aG sudo $username
        
        # Создание SSH ключей
        sudo -u $username ssh-keygen -t rsa -b 4096 -f /home/$username/.ssh/id_rsa -N ""
        
        log_success "Пользователь $username создан"
    fi
    
    # Создание рабочих директорий
    sudo -u $username mkdir -p /home/$username/{projects,backups,logs}
    
    log_info "Установите пароль для пользователя $username:"
    passwd $username
}

# Настройка автоматических обновлений безопасности
setup_auto_updates() {
    log_info "Настройка автоматических обновлений безопасности..."
    
    apt install -y unattended-upgrades
    
    # Настройка автообновлений
    cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};

Unattended-Upgrade::Package-Blacklist {
};

Unattended-Upgrade::DevRelease "false";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Automatic-Reboot-Time "02:00";
EOF
    
    # Включение автообновлений
    echo 'APT::Periodic::Update-Package-Lists "1";' > /etc/apt/apt.conf.d/20auto-upgrades
    echo 'APT::Periodic::Unattended-Upgrade "1";' >> /etc/apt/apt.conf.d/20auto-upgrades
    
    systemctl enable unattended-upgrades
    systemctl start unattended-upgrades
    
    log_success "