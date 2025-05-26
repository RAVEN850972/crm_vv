# Из finance/utils.py
from datetime import datetime, timedelta
from decimal import Decimal
from django.db.models import Sum, Count
from user_accounts.models import User
from orders.models import Order, OrderItem

def calculate_installer_salary(installer, start_date=None, end_date=None):
    """Расчет зарплаты монтажника"""
    if not start_date:
        # По умолчанию - начало текущего месяца
        today = datetime.now()
        start_date = datetime(today.year, today.month, 1)
    if not end_date:
        end_date = datetime.now()
    
    # Базовая оплата за монтаж
    completed_orders = Order.objects.filter(
        installers=installer,
        status='completed',
        completed_at__gte=start_date,
        completed_at__lte=end_date
    )
    
    # 1500р за каждый монтаж
    installation_pay = Decimal('1500.00') * completed_orders.count()
    
    # Оплата за доп. услуги
    additional_services = OrderItem.objects.filter(
        order__in=completed_orders,
        service__category='additional',
        seller=installer
    )
    
    # Бонус за каждую доп. услугу (например, 30% от прибыли)
    additional_pay = sum(
        (item.price - item.service.cost_price) * Decimal('0.3')
        for item in additional_services
    )
    
    # Штрафы (если есть)
    # Здесь должна быть логика учета штрафов
    penalties = Decimal('0.00')
    
    total_salary = installation_pay + additional_pay - penalties
    
    return {
        'installation_pay': installation_pay,
        'additional_pay': additional_pay,
        'penalties': penalties,
        'total_salary': total_salary,
        'completed_orders_count': completed_orders.count(),
        'additional_services_count': additional_services.count()
    }

def calculate_manager_salary(manager, start_date=None, end_date=None):
    """Расчет зарплаты менеджера"""
    if not start_date:
        today = datetime.now()
        start_date = datetime(today.year, today.month, 1)
    if not end_date:
        end_date = datetime.now()
    
    # Фиксированная ставка
    fixed_salary = Decimal('30000.00')
    
    # Завершенные заявки
    completed_orders = Order.objects.filter(
        manager=manager,
        status='completed',
        completed_at__gte=start_date,
        completed_at__lte=end_date
    )
    
    # 250р за каждую завершенную заявку
    orders_pay = Decimal('250.00') * completed_orders.count()
    
    # Продажи кондиционеров
    conditioner_sales = OrderItem.objects.filter(
        order__in=completed_orders,
        service__category='conditioner',
        seller=manager
    )
    
    # 20% от прибыли с проданных кондиционеров
    conditioner_pay = sum(
        (item.price - item.service.cost_price) * Decimal('0.2')
        for item in conditioner_sales
    )

    # Продажи доп. услуг
    additional_sales = OrderItem.objects.filter(
        order__in=completed_orders,
        service__category='additional',
        seller=manager
    )
    
    # 30% от прибыли с доп. услуг
    additional_pay = sum(
        (item.price - item.service.cost_price) * Decimal('0.3')
        for item in additional_sales
    )
    
    total_salary = fixed_salary + orders_pay + conditioner_pay + additional_pay
    
    return {
        'fixed_salary': fixed_salary,
        'orders_pay': orders_pay,
        'conditioner_pay': conditioner_pay,
        'additional_pay': additional_pay,
        'total_salary': total_salary,
        'completed_orders_count': completed_orders.count(),
        'conditioner_sales_count': conditioner_sales.count(),
        'additional_sales_count': additional_sales.count()
    }

def calculate_owner_salary(start_date=None, end_date=None):
    """Расчет зарплаты владельца"""
    if not start_date:
        today = datetime.now()
        start_date = datetime(today.year, today.month, 1)
    if not end_date:
        end_date = datetime.now()
    
    # Все завершенные заказы
    completed_orders = Order.objects.filter(
        status='completed',
        completed_at__gte=start_date,
        completed_at__lte=end_date
    )
    
    # 1500р за каждый завершенный монтаж
    installation_pay = Decimal('1500.00') * completed_orders.count()
    
    # Вся выручка за период
    total_revenue = OrderItem.objects.filter(
        order__in=completed_orders
    ).aggregate(Sum('price'))['price__sum'] or Decimal('0.00')
    
    # Себестоимость
    total_cost_price = sum(
        item.service.cost_price
        for item in OrderItem.objects.filter(order__in=completed_orders)
    )
    
    # Выплаты монтажникам и менеджерам
    # Это упрощенный расчет, реальная логика может быть сложнее
    installers_pay = Decimal('1500.00') * completed_orders.count() * Decimal('2')  # Примерно 2 монтажника на заказ
    managers_pay = Decimal('30000.00') + (Decimal('250.00') * completed_orders.count())  # Фикс + бонусы
    
    # Оставшаяся прибыль
    remaining_profit = total_revenue - total_cost_price - installers_pay - managers_pay
    
    total_salary = installation_pay + remaining_profit
    
    return {
        'installation_pay': installation_pay,
        'total_revenue': total_revenue,
        'total_cost_price': total_cost_price,
        'installers_pay': installers_pay,
        'managers_pay': managers_pay,
        'remaining_profit': remaining_profit,
        'total_salary': total_salary,
        'completed_orders_count': completed_orders.count()
    }