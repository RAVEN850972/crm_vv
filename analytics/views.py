from django.shortcuts import render
from django.contrib.auth.decorators import login_required
from django.db.models import Count, Sum, Q
from django.utils import timezone
from datetime import timedelta
from decimal import Decimal
from django.db.models.functions import TruncMonth, TruncDay

from customer_clients.models import Client
from orders.models import Order
from services.models import Service
from finance.models import Transaction
from user_accounts.models import User

@login_required
def dashboard(request):
    """Главный дашборд с основными показателями"""
    # Текущая дата
    today = timezone.now()
    start_of_month = today.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    
    # Статистика по заказам
    total_orders = Order.objects.count()
    completed_orders = Order.objects.filter(status='completed').count()
    orders_this_month = Order.objects.filter(created_at__gte=start_of_month).count()
    
    # Статистика по клиентам
    total_clients = Client.objects.count()
    clients_this_month = Client.objects.filter(created_at__gte=start_of_month).count()
    
    # Финансовые показатели
    company_balance = Transaction.get_company_balance()
    
    # Доходы и расходы за текущий месяц
    income_this_month = Transaction.objects.filter(
        type='income',
        created_at__gte=start_of_month
    ).aggregate(total=Sum('amount'))['total'] or Decimal('0.00')
    
    expenses_this_month = Transaction.objects.filter(
        type='expense',
        created_at__gte=start_of_month
    ).aggregate(total=Sum('amount'))['total'] or Decimal('0.00')
    
    # Заказы по месяцам
    orders_by_month = get_orders_by_month(months=6)
    
    # Источники клиентов
    clients_by_source_data = get_clients_by_source()
    clients_by_source = []
    for item in clients_by_source_data:
        source_display = dict(Client.SOURCE_CHOICES).get(item['source'], item['source'])
        clients_by_source.append({
            'source': item['source'],
            'source_display': source_display,
            'count': item['count']
        })
    
    # Топ менеджеры
    top_managers = get_top_managers(limit=5)
    
    # Последние заказы
    recent_orders = Order.objects.all().order_by('-created_at')[:5]
    
    context = {
        'total_orders': total_orders,
        'completed_orders': completed_orders,
        'orders_this_month': orders_this_month,
        'total_clients': total_clients,
        'clients_this_month': clients_this_month,
        'company_balance': company_balance,
        'income_this_month': income_this_month,
        'expenses_this_month': expenses_this_month,
        'orders_by_month': orders_by_month,
        'clients_by_source': clients_by_source,
        'top_managers': top_managers,
        'recent_orders': recent_orders,
    }
    
    return render(request, 'dashboard/dashboard.html', context)

def get_clients_by_source():
    """Получение статистики клиентов по источникам"""
    return Client.objects.values('source').annotate(count=Count('id'))

def get_orders_by_month(months=6):
    """Получение статистики заказов по месяцам"""
    end_date = timezone.now()
    start_date = end_date - timedelta(days=30 * months)
    
    return Order.objects.filter(
        created_at__range=(start_date, end_date)
    ).annotate(
        month=TruncMonth('created_at')
    ).values('month').annotate(
        count=Count('id'),
        revenue=Sum('total_cost')
    ).order_by('month')

def get_top_managers(limit=5):
    """Получение топ менеджеров по продажам"""
    return Order.objects.filter(
        status='completed'
    ).values(
        'manager__id', 'manager__first_name', 'manager__last_name'
    ).annotate(
        orders_count=Count('id'),
        revenue=Sum('total_cost')
    ).order_by('-revenue')[:limit]

# Добавим в utils еще функции для анализа

def get_profit_by_day(days=30):
    """Получение данных о прибыли по дням"""
    end_date = timezone.now()
    start_date = end_date - timedelta(days=days)
    
    # Получаем все доходные транзакции по дням
    income_by_day = Transaction.objects.filter(
        type='income',
        created_at__range=(start_date, end_date)
    ).annotate(
        day=TruncDay('created_at')
    ).values('day').annotate(
        total=Sum('amount')
    ).order_by('day')
    
    # Получаем все расходные транзакции по дням
    expense_by_day = Transaction.objects.filter(
        type='expense',
        created_at__range=(start_date, end_date)
    ).annotate(
        day=TruncDay('created_at')
    ).values('day').annotate(
        total=Sum('amount')
    ).order_by('day')
    
    # Объединяем данные
    result = {}
    
    for item in income_by_day:
        day_str = item['day'].strftime('%Y-%m-%d')
        if day_str not in result:
            result[day_str] = {'income': 0, 'expense': 0, 'profit': 0}
        result[day_str]['income'] = float(item['total'])
    
    for item in expense_by_day:
        day_str = item['day'].strftime('%Y-%m-%d')
        if day_str not in result:
            result[day_str] = {'income': 0, 'expense': 0, 'profit': 0}
        result[day_str]['expense'] = float(item['total'])
    
    # Вычисляем прибыль
    for day in result:
        result[day]['profit'] = result[day]['income'] - result[day]['expense']
    
    return [{'day': day, **data} for day, data in result.items()]

def get_service_category_distribution():
    """Получение распределения услуг по категориям"""
    return Service.objects.values('category').annotate(
        count=Count('id'),
        total_revenue=Sum('selling_price')
    ).order_by('-total_revenue')

def get_client_acquisition_rate(months=6):
    """Получение скорости привлечения клиентов по месяцам"""
    end_date = timezone.now()
    start_date = end_date - timedelta(days=30 * months)
    
    return Client.objects.filter(
        created_at__range=(start_date, end_date)
    ).annotate(
        month=TruncMonth('created_at')
    ).values('month').annotate(
        count=Count('id')
    ).order_by('month')