# CRM для кондиционеров - Руководство по развертыванию

## 🚀 Быстрый старт

### Локальная разработка (самый простой способ)
```bash
# Клонируйте репозиторий
git clone <repository-url>
cd crm_ac

# Запустите автоматическую настройку (2-3 минуты)
chmod +x quick-start.sh
./quick-start.sh

# Запустите сервер
./run-server.sh
```

**Готово!** Откройте http://127.0.0.1:8000 (admin/admin123)

---

## 📋 Доступные скрипты развертывания

### 1. `quick-start.sh` - Быстрая настройка для разработки
**Рекомендуется для разработчиков**

```bash
# Автоматическая настройка
./quick-start.sh

# Очистка и переустановка
./quick-start.sh --clean

# Автоматический режим (без вопросов)
./quick-start.sh --auto

# Справка
./quick-start.sh --help
```

**Что делает:**
- ✅ Создает виртуальное окружение Python
- ✅ Устанавливает зависимости для разработки
- ✅ Настраивает SQLite базу данных
- ✅ Создает суперпользователя (admin/admin123)
- ✅ Загружает тестовые данные
- ✅ Создает полезные скрипты

### 2. `deploy.sh` - Универсальный скрипт развертывания
**Для продакшена и расширенной настройки**

```bash
# Разработка
./deploy.sh development

# Продакшн на сервере
./deploy.sh production

# Docker развертывание
./deploy.sh docker

# Запуск dev сервера
./deploy.sh run

# Создание backup
./deploy.sh backup

# Обновление приложения
./deploy.sh update

# Проверка статуса
./deploy.sh status
```

### 3. `setup-server.sh` - Настройка сервера
**Для Ubuntu 20.04/22.04 LTS серверов**

```bash
# Запуск от root
sudo ./setup-server.sh

# Полная автоматическая установка
sudo ./setup-server.sh full

# Отдельные компоненты
sudo ./setup-server.sh postgresql
sudo ./setup-server.sh nginx
sudo ./setup-server.sh docker
```

**Что устанавливает:**
- Python 3.9+, pip, виртуальные окружения
- PostgreSQL 15 с настройкой
- Redis для кэширования
- Nginx веб-сервер
- Docker и Docker Compose (опционально)
- Firewall и базовая безопасность
- Автоматические обновления
- Мониторинг и логирование

### 4. `docker-manager.sh` - Управление Docker
**Для контейнерного развертывания**

```bash
# Первоначальная настройка
./docker-manager.sh init

# Управление сервисами
./docker-manager.sh up
./docker-manager.sh down
./docker-manager.sh restart

# Мониторинг
./docker-manager.sh status
./docker-manager.sh logs
./docker-manager.sh monitor

# Django команды
./docker-manager.sh django migrate
./docker-manager.sh django createsuperuser

# Backup и восстановление
./docker-manager.sh backup
./docker-manager.sh restore backup.sql
```

---

## 🔧 Сценарии развертывания

### Сценарий 1: Разработчик начинает работу
```bash
git clone <repo>
cd crm_ac
./quick-start.sh
./run-server.sh
```
**Время: 2-3 минуты**

### Сценарий 2: Настройка продакшн сервера
```bash
# На сервере (Ubuntu)
sudo ./setup-server.sh full
su - crm
git clone <repo> /home/crm/crm_ac
cd /home/crm/crm_ac
./deploy.sh production
```
**Время: 10-15 минут**

### Сценарий 3: Docker развертывание
```bash
git clone <repo>
cd crm_ac
./docker-manager.sh init
```
**Время: 5-7 минут**

### Сценарий 4: Обновление существующей системы
```bash
# Обычное развертывание
./deploy.sh update

# Docker развертывание
./docker-manager.sh update
```

---

## 🌍 Переменные окружения

### Основные настройки
```bash
# Django
DJANGO_SECRET_KEY=your-secret-key
DJANGO_DEBUG=False
DJANGO_ALLOWED_HOSTS=your-domain.com

# База данных
DJANGO_DB_ENGINE=django.db.backends.postgresql
DJANGO_DB_NAME=crm_db
DJANGO_DB_USER=crm_user
DJANGO_DB_PASSWORD=secure_password
DJANGO_DB_HOST=localhost
DJANGO_DB_PORT=5432

# API ключи
YANDEX_MAPS_API_KEY=your-api-key

# Email
EMAIL_HOST=smtp.your-provider.com
EMAIL_PORT=587
EMAIL_HOST_USER=noreply@your-domain.com
EMAIL_HOST_PASSWORD=your-password
```

### Настройки календаря
```bash
# Календарь монтажей
DEFAULT_WORK_START_TIME=08:00
DEFAULT_WORK_END_TIME=18:00
DEFAULT_INSTALLATION_DURATION=2
MAX_INSTALLATIONS_PER_DAY=5
WAREHOUSE_ADDRESS=Москва, ул. Складская, 1
```

---

## 🔒 Безопасность

### Обязательные действия для продакшена

1. **Смените пароли по умолчанию:**
   ```bash
   # Django admin
   ./manage.py changepassword admin
   
   # PostgreSQL
   sudo -u postgres psql -c "ALTER USER postgres PASSWORD 'new_password';"
   ```

2. **Настройте HTTPS:**
   ```bash
   # Автоматический SSL с Let's Encrypt
   sudo certbot --nginx -d your-domain.com
   ```

3. **Настройте firewall:**
   ```bash
   sudo ufw enable
   sudo ufw allow ssh
   sudo ufw allow 'Nginx Full'
   ```

4. **Регулярные backup'ы:**
   ```bash
   # Добавить в cron
   0 2 * * * /usr/local/bin/crm-backup.sh
   ```

---

## 📊 Мониторинг и обслуживание

### Проверка статуса
```bash
# Systemd сервисы
sudo systemctl status crm nginx postgresql redis

# Docker сервисы
./docker-manager.sh status

# Логи приложения
sudo journalctl -u crm -f
./docker-manager.sh logs web

# Проверка портов
netstat -tlnp | grep -E ":8000|:80|:443|:5432"
```

### Производительность
```bash
# Мониторинг ресурсов
htop
iotop
nethogs

# Docker мониторинг
./docker-manager.sh monitor

# Анализ логов
tail -f /var/log/nginx/access.log
```

### Backup и восстановление
```bash
# Создание backup
./deploy.sh backup
./docker-manager.sh backup

# Автоматический backup (cron)
0 2 * * * /usr/local/bin/crm-backup.sh

# Восстановление
./docker-manager.sh restore backup_20250524_020000.sql
```

---

## 🐛 Устранение неполадок

### Общие проблемы

#### 1. Ошибка "Port already in use"
```bash
# Найти и завершить процесс
sudo lsof -t -i tcp:8000 | xargs kill -9

# Или изменить порт
python manage.py runserver 0.0.0.0:8001
```

#### 2. Проблемы с правами доступа
```bash
# Исправить права на файлы
sudo chown -R crm:crm /home/crm/crm_ac
chmod -R 755 /home/crm/crm_ac

# Права на медиа и статику
chmod -R 755 media static
```

#### 3. Ошибки базы данных
```bash
# Перезапуск PostgreSQL
sudo systemctl restart postgresql

# Проверка подключения
sudo -u postgres psql -c "SELECT version();"

# Пересоздание миграций
rm -rf */migrations/0*.py
python manage.py makemigrations
python manage.py migrate
```

#### 4. Проблемы с Docker
```bash
# Проверка Docker daemon
sudo systemctl status docker

# Очистка Docker системы
docker system prune -af

# Пересборка образов
./docker-manager.sh cleanup
./docker-manager.sh init
```

#### 5. Ошибки Nginx
```bash
# Проверка конфигурации
sudo nginx -t

# Перезапуск Nginx
sudo systemctl restart nginx

# Логи ошибок
sudo tail -f /var/log/nginx/error.log
```

### Диагностические команды
```bash
# Проверка Django конфигурации
python manage.py check --deploy

# Информация о системе
./deploy.sh status
./docker-manager.sh status

# Тест соединения с базой данных
python manage.py dbshell

# Проверка статических файлов
python manage.py findstatic admin/css/base.css
```

---

## 📈 Оптимизация производительности

### База данных
```bash
# Индексы для PostgreSQL
python manage.py dbshell
```
```sql
-- Часто используемые индексы
CREATE INDEX CONCURRENTLY idx_orders_status ON orders_order(status);
CREATE INDEX CONCURRENTLY idx_orders_created ON orders_order(created_at);
CREATE INDEX CONCURRENTLY idx_clients_source ON customer_clients_client(source);
```

### Кэширование
```python
# settings.py
CACHES = {
    'default': {
        'BACKEND': 'django_redis.cache.RedisCache',
        'LOCATION': 'redis://127.0.0.1:6379/1',
        'OPTIONS': {
            'CLIENT_CLASS': 'django_redis.client.DefaultClient',
        }
    }
}
```

### Nginx оптимизация
```nginx
# nginx.conf
gzip on;
gzip_types text/plain text/css application/json application/javascript;
client_max_body_size 100M;
worker_processes auto;
```

---

## 🔄 CI/CD Pipeline

### GitHub Actions пример
```yaml
# .github/workflows/deploy.yml
name: Deploy CRM
on:
  push:
    branches: [ main ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    
    - name: Deploy to server
      uses: appleboy/ssh-action@v0.1.5
      with:
        host: ${{ secrets.HOST }}
        username: crm
        key: ${{ secrets.SSH_KEY }}
        script: |
          cd /home/crm/crm_ac
          git pull origin main
          ./deploy.sh update
```

### Автоматическое тестирование
```bash
# Запуск тестов
python manage.py test

# Покрытие кода
coverage run --source='.' manage.py test
coverage report
coverage html
```

---

## 📚 Справочная информация

### Структура проекта
```
crm_ac/
├── deploy.sh              # Главный скрипт развертывания
├── quick-start.sh          # Быстрая настройка для разработки
├── setup-server.sh         # Настройка Ubuntu сервера
├── docker-manager.sh       # Управление Docker
├── docker-compose.yml      # Docker Compose конфигурация
├── Dockerfile             # Docker образ приложения
├── requirements.txt       # Python зависимости
├── requirements-dev.txt   # Зависимости для разработки
├── requirements-prod.txt  # Продакшн зависимости
├── .env.example          # Пример переменных окружения
├── nginx.conf            # Конфигурация Nginx
└── manage.py             # Django управление
```

### Порты по умолчанию
- **8000** - Django development server
- **80** - Nginx HTTP
- **443** - Nginx HTTPS
- **5432** - PostgreSQL
- **6379** - Redis

### Важные директории
- `/home/crm/crm_ac/` - Код приложения
- `/home/crm/backups/` - Резервные копии
- `/var/log/crm/` - Логи приложения
- `/etc/nginx/sites-available/` - Конфигурация Nginx
- `/etc/systemd/system/` - Systemd сервисы

### Команды Django
```bash
# Активация виртуального окружения
source venv/bin/activate

# Основные команды
python manage.py runserver
python manage.py migrate
python manage.py createsuperuser
python manage.py collectstatic
python manage.py shell

# Специальные команды проекта
python manage.py create_schedules
python manage.py optimize_routes
```

---

## 🆘 Получение помощи

### Логи для диагностики
```bash
# Системные логи
sudo journalctl -u crm -f
sudo journalctl -u nginx -f
sudo journalctl -u postgresql -f

# Docker логи
docker-compose logs -f
./docker-manager.sh logs

# Django логи
tail -f logs/django.log
```

### Контакты и поддержка
- 📧 Email: support@your-domain.com
- 📱 Telegram: @your_support
- 🐛 Issues: GitHub Issues
- 📖 Документация: Wiki

### Полезные ссылки
- [Django Documentation](https://docs.djangoproject.com/)
- [PostgreSQL Manual](https://www.postgresql.org/docs/)
- [Docker Documentation](https://docs.docker.com/)
- [Nginx Documentation](https://nginx.org/en/docs/)

---

## ✅ Чек-лист для продакшена

### Перед развертыванием
- [ ] Сервер настроен (`setup-server.sh`)
- [ ] Домен настроен и указывает на сервер
- [ ] SSL сертификат настроен
- [ ] .env файл заполнен корректными данными
- [ ] Backup стратегия настроена

### После развертывания
- [ ] Приложение доступно по HTTP/HTTPS
- [ ] Админ-панель работает
- [ ] API endpoints отвечают
- [ ] Email отправка настроена
- [ ] Мониторинг настроен
- [ ] Логи пишутся корректно

### Безопасность
- [ ] Пароли по умолчанию изменены
- [ ] Firewall настроен
- [ ] SSH ключи настроены
- [ ] Автоматические обновления включены
- [ ] Backup'ы создаются регулярно

### Производительность
- [ ] База данных оптимизирована
- [ ] Кэширование настроено
- [ ] Static файлы сжимаются
- [ ] CDN настроена (опционально)

---

**🎉 Поздравляем! Ваша CRM система готова к работе!**

Для дополнительной помощи обратитесь к документации API или создайте issue в репозитории.