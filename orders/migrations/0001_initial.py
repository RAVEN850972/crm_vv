# Generated by Django 5.2.1 on 2025-05-15 07:25

import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    initial = True

    dependencies = [
        ('customer_clients', '0001_initial'),
        ('services', '0001_initial'),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name='Order',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('status', models.CharField(choices=[('new', 'Новый'), ('in_progress', 'В работе'), ('completed', 'Завершен')], default='new', max_length=15, verbose_name='Статус')),
                ('total_cost', models.DecimalField(decimal_places=2, default=0, max_digits=10, verbose_name='Общая стоимость')),
                ('created_at', models.DateTimeField(auto_now_add=True, verbose_name='Дата создания')),
                ('completed_at', models.DateTimeField(blank=True, null=True, verbose_name='Дата завершения')),
                ('client', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, to='customer_clients.client', verbose_name='Клиент')),
                ('installers', models.ManyToManyField(limit_choices_to={'role': 'installer'}, related_name='installation_orders', to=settings.AUTH_USER_MODEL, verbose_name='Монтажники')),
                ('manager', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='managed_orders', to=settings.AUTH_USER_MODEL, verbose_name='Менеджер')),
            ],
            options={
                'verbose_name': 'Заказ',
                'verbose_name_plural': 'Заказы',
            },
        ),
        migrations.CreateModel(
            name='OrderItem',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('price', models.DecimalField(decimal_places=2, max_digits=10, verbose_name='Цена')),
                ('created_at', models.DateTimeField(auto_now_add=True, verbose_name='Дата создания')),
                ('order', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='items', to='orders.order', verbose_name='Заказ')),
                ('seller', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, to=settings.AUTH_USER_MODEL, verbose_name='Продавец')),
                ('service', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, to='services.service', verbose_name='Услуга')),
            ],
            options={
                'verbose_name': 'Позиция заказа',
                'verbose_name_plural': 'Позиции заказа',
            },
        ),
    ]
