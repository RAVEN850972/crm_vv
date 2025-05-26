# CRM для кондиционеров - Dockerfile

# Используем официальный Python образ
FROM python:3.11-slim

# Устанавливаем системные зависимости
RUN apt-get update && apt-get install -y \
    postgresql-client \
    build-essential \
    libpq-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Устанавливаем рабочую директорию
WORKDIR /app

# Копируем файлы требований
COPY requirements.txt requirements-prod.txt ./

# Устанавливаем Python зависимости
RUN pip install --no-cache-dir -r requirements-prod.txt

# Создаем пользователя для приложения
RUN adduser --disabled-password --gecos '' appuser && \
    chown -R appuser:appuser /app

# Копируем код приложения
COPY . .

# Устанавливаем права доступа
RUN chown -R appuser:appuser /app && \
    chmod +x /app/docker-entrypoint.sh

# Переключаемся на пользователя приложения
USER appuser

# Собираем статические файлы
RUN python manage.py collectstatic --noinput

# Открываем порт
EXPOSE 8000

# Точка входа
ENTRYPOINT ["/app/docker-entrypoint.sh"]
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "3", "crm_ac.wsgi:application"]