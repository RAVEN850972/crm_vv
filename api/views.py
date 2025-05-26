from rest_framework import viewsets, filters
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.decorators import action
from django_filters.rest_framework import DjangoFilterBackend
from django.http import HttpResponse
import openpyxl
from datetime import datetime, timedelta
from rest_framework.authentication import SessionAuthentication, BasicAuthentication
from rest_framework.permissions import IsAuthenticated
from django.db.models import Count, Sum, Q
from django.db.models.functions import TruncMonth, TruncDay
from django.utils import timezone

from user_accounts.models import User  # Исправлено с accounts.models
from customer_clients.models import Client  # Исправлено с clients.models
from services.models import Service
from orders.models import Order, OrderItem
from finance.models import Transaction, SalaryPayment
from .serializers import (
    UserSerializer, ClientSerializer, ServiceSerializer, 
    OrderSerializer, OrderItemSerializer, TransactionSerializer, 
    SalaryPaymentSerializer
)

class UserViewSet(viewsets.ModelViewSet):
    queryset = User.objects.all()
    serializer_class = UserSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter]
    filterset_fields = ['role']
    search_fields = ['username', 'first_name', 'last_name', 'email']

class ClientViewSet(viewsets.ModelViewSet):
    queryset = Client.objects.all()
    serializer_class = ClientSerializer
    authentication_classes = [SessionAuthentication, BasicAuthentication]
    permission_classes = [IsAuthenticated]
    #permission_classes = []
    filter_backends = [DjangoFilterBackend, filters.SearchFilter]
    filterset_fields = ['source']
    search_fields = ['name', 'phone', 'address']

    @action(detail=False, methods=['get'], url_path='stats/by-source')
    def stats_by_source(self, request):
        """Статистика клиентов по источникам"""
        source_stats = Client.objects.values('source').annotate(count=Count('id'))
        result = []
        
        for stat in source_stats:
            source_display = dict(Client.SOURCE_CHOICES).get(stat['source'], stat['source'])
            result.append({
                'source': stat['source'],
                'source_display': source_display,
                'count': stat['count']
            })
        
        return Response({'sources': result})
    
    @action(detail=False, methods=['get'], url_path='stats/by-month')
    def stats_by_month(self, request):
        """Статистика клиентов по месяцам"""
        month_stats = Client.objects.annotate(
            month=TruncMonth('created_at')
        ).values('month').annotate(
            count=Count('id')
        ).order_by('month')
        
        result = []
        for stat in month_stats:
            if stat['month']:
                month_str = stat['month'].strftime('%Y-%m')
                result.append({
                    'month': month_str,
                    'count': stat['count']
                })
        
        return Response({'months': result})

class ServiceViewSet(viewsets.ModelViewSet):
    queryset = Service.objects.all()
    serializer_class = ServiceSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter]
    filterset_fields = ['category']
    search_fields = ['name']

    @action(detail=False, methods=['get'], url_path='stats/by-category')
    def stats_by_category(self, request):
        """Статистика услуг по категориям"""
        category_stats = Service.objects.values('category').annotate(count=Count('id'))
        result = []
        
        for stat in category_stats:
            category_display = dict(Service.CATEGORY_CHOICES).get(stat['category'], stat['category'])
            result.append({
                'category': stat['category'],
                'category_display': category_display,
                'count': stat['count']
            })
        
        return Response({'categories': result})
    
    @action(detail=False, methods=['get'], url_path='stats/popular')
    def stats_popular(self, request):
        """Самые популярные услуги (по количеству в заказах)"""
        # Используем OrderItem для определения популярности
        from django.db.models import Count
        
        popular_services = OrderItem.objects.values(
            'service__id', 'service__name', 'service__category'
        ).annotate(
            count=Count('id')
        ).order_by('-count')[:10]  # Топ-10 услуг
        
        result = []
        for item in popular_services:
            category_display = dict(Service.CATEGORY_CHOICES).get(item['service__category'], item['service__category'])
            result.append({
                'service_id': item['service__id'],
                'service_name': item['service__name'],
                'category': item['service__category'],
                'category_display': category_display,
                'count': item['count']
            })
        
        return Response({'popular_services': result})

class OrderViewSet(viewsets.ModelViewSet):
    queryset = Order.objects.all()
    serializer_class = OrderSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter]
    filterset_fields = ['status', 'manager', 'client']
    search_fields = ['client__name']
    
    @action(detail=True, methods=['post'])
    def add_item(self, request, pk=None):
        order = self.get_object()
        serializer = OrderItemSerializer(data=request.data)
        if serializer.is_valid():
            serializer.save(order=order)
            order.refresh_from_db()
            return Response(OrderSerializer(order).data)
        return Response(serializer.errors, status=400)
    
    @action(detail=True, methods=['post'])
    def change_status(self, request, pk=None):
        order = self.get_object()
        status = request.data.get('status')
        if status in dict(Order.STATUS_CHOICES).keys():
            order.status = status
            if status == 'completed':
                order.completed_at = datetime.now()
            order.save()
            return Response(OrderSerializer(order).data)
        return Response({'error': 'Invalid status'}, status=400)
    
    @action(detail=False, methods=['get'], url_path='stats/by-status')
    def stats_by_status(self, request):
        """Статистика заказов по статусам"""
        status_stats = Order.objects.values('status').annotate(count=Count('id'))
        result = []
        
        for stat in status_stats:
            status_display = dict(Order.STATUS_CHOICES).get(stat['status'], stat['status'])
            result.append({
                'status': stat['status'],
                'status_display': status_display,
                'count': stat['count']
            })
        
        return Response({'statuses': result})
    
    @action(detail=False, methods=['get'], url_path='stats/by-month')
    def stats_by_month(self, request):
        """Статистика заказов по месяцам"""
        month_stats = Order.objects.annotate(
            month=TruncMonth('created_at')
        ).values('month').annotate(
            count=Count('id'),
            total_revenue=Sum('total_cost')
        ).order_by('month')
        
        result = []
        for stat in month_stats:
            if stat['month']:
                month_str = stat['month'].strftime('%Y-%m')
                result.append({
                    'month': month_str,
                    'count': stat['count'],
                    'revenue': float(stat['total_revenue'] or 0)
                })
        
        return Response({'months': result})
    
    @action(detail=False, methods=['get'], url_path='stats/by-manager')
    def stats_by_manager(self, request):
        """Статистика заказов по менеджерам"""
        manager_stats = Order.objects.values(
            'manager__id', 'manager__first_name', 'manager__last_name'
        ).annotate(
            count=Count('id'),
            total_revenue=Sum('total_cost')
        ).order_by('-total_revenue')
        
        result = []
        for stat in manager_stats:
            # Пропускаем записи без менеджера
            if not stat['manager__id']:
                continue
                
            result.append({
                'manager_id': stat['manager__id'],
                'manager_name': f"{stat['manager__first_name']} {stat['manager__last_name']}",
                'orders_count': stat['count'],
                'revenue': float(stat['total_revenue'] or 0)
            })
        
        return Response({'managers': result})

class TransactionViewSet(viewsets.ModelViewSet):
    queryset = Transaction.objects.all()
    serializer_class = TransactionSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter]
    filterset_fields = ['type']
    search_fields = ['description']

class SalaryPaymentViewSet(viewsets.ModelViewSet):
    queryset = SalaryPayment.objects.all()
    serializer_class = SalaryPaymentSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter]
    filterset_fields = ['user']
    search_fields = ['user__username', 'user__first_name', 'user__last_name']

class FinanceBalanceView(APIView):
    def get(self, request):
        """
        Возвращает текущий баланс компании и статистику доходов/расходов
        """
        # Расчет общего баланса
        balance = Transaction.get_company_balance()
        
        # Статистика по месяцам
        today = datetime.now()
        start_date = today.replace(day=1, month=today.month-5 if today.month > 5 else today.month+7, 
                                  year=today.year if today.month > 5 else today.year-1)
        
        # Агрегация по месяцам
        transactions = Transaction.objects.filter(created_at__gte=start_date)
        monthly_data = {}
        
        for transaction in transactions:
            month_key = transaction.created_at.strftime('%Y-%m')
            if month_key not in monthly_data:
                monthly_data[month_key] = {'income': 0, 'expense': 0}
            
            if transaction.type == 'income':
                monthly_data[month_key]['income'] += float(transaction.amount)
            else:  # expense
                monthly_data[month_key]['expense'] += float(transaction.amount)
        
        # Преобразование в список для удобства использования в клиенте
        monthly_stats = []
        for month, data in sorted(monthly_data.items()):
            monthly_stats.append({
                'month': month,
                'income': data['income'],
                'expense': data['expense'],
                'profit': data['income'] - data['expense']
            })
        
        return Response({
            'balance': balance,
            'monthly_stats': monthly_stats
        })

class CalculateSalaryView(APIView):
    def get(self, request, user_id):
        try:
            user = User.objects.get(id=user_id)
        except User.DoesNotExist:
            return Response({'error': 'User not found'}, status=404)
        
        start_date = request.query_params.get('start_date')
        end_date = request.query_params.get('end_date')
        
        # Расчет зарплаты в зависимости от роли
        if user.role == 'installer':
            # Логика расчета для монтажника
            salary = self._calculate_installer_salary(user, start_date, end_date)
        elif user.role == 'manager':
            # Логика расчета для менеджера
            salary = self._calculate_manager_salary(user, start_date, end_date)
        else:  # owner
            # Логика расчета для владельца
            salary = self._calculate_owner_salary(start_date, end_date)
            
        return Response({'salary': salary})
        
    def _calculate_installer_salary(self, user, start_date=None, end_date=None):
        # Используем функцию из utils
        from finance.utils import calculate_installer_salary
        return calculate_installer_salary(user, start_date, end_date)
        
    def _calculate_manager_salary(self, user, start_date=None, end_date=None):
        # Используем функцию из utils
        from finance.utils import calculate_manager_salary
        return calculate_manager_salary(user, start_date, end_date)
        
    def _calculate_owner_salary(self, start_date=None, end_date=None):
        # Используем функцию из utils
        from finance.utils import calculate_owner_salary
        return calculate_owner_salary(start_date, end_date)

class FinanceStatsView(APIView):
    """Расширенная финансовая статистика"""
    
    def get(self, request):
        # Текущая дата
        today = datetime.now()
        
        # Начало текущего месяца
        start_of_month = today.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
        
        # Доходы и расходы за текущий месяц
        income_this_month = Transaction.objects.filter(
            type='income',
            created_at__gte=start_of_month
        ).aggregate(total=Sum('amount'))['total'] or 0
        
        expense_this_month = Transaction.objects.filter(
            type='expense',
            created_at__gte=start_of_month
        ).aggregate(total=Sum('amount'))['total'] or 0
        
        # Статистика доходов/расходов по дням
        from django.db.models.functions import TruncDay
        
        # За последние 30 дней
        start_date = today - timedelta(days=30)
        
        daily_stats = Transaction.objects.filter(
            created_at__gte=start_date
        ).annotate(
            day=TruncDay('created_at')
        ).values('day', 'type').annotate(
            total=Sum('amount')
        ).order_by('day')
        
        # Преобразуем в формат, удобный для клиента
        days_data = {}
        for stat in daily_stats:
            day_str = stat['day'].strftime('%Y-%m-%d')
            if day_str not in days_data:
                days_data[day_str] = {'income': 0, 'expense': 0}
                
            days_data[day_str][stat['type']] = float(stat['total'])
        
        # Формируем список с расчетом прибыли
        daily_result = []
        for day, data in sorted(days_data.items()):
            daily_result.append({
                'date': day,
                'income': data['income'],
                'expense': data['expense'],
                'profit': data['income'] - data['expense']
            })
        
        return Response({
            'income_this_month': float(income_this_month),
            'expense_this_month': float(expense_this_month),
            'profit_this_month': float(income_this_month) - float(expense_this_month),
            'daily_stats': daily_result
        })

class DashboardStatsView(APIView):
    """Статистика для главного дашборда"""
    
    def get(self, request):
        # Текущая дата
        today = datetime.now()
        
        # Начало текущего месяца
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
        ).aggregate(total=Sum('amount'))['total'] or 0
        
        expense_this_month = Transaction.objects.filter(
            type='expense',
            created_at__gte=start_of_month
        ).aggregate(total=Sum('amount'))['total'] or 0
        
        # Заказы по месяцам (за последние 6 месяцев)
        six_months_ago = today.replace(day=1) - timedelta(days=180)
        orders_by_month = Order.objects.filter(
            created_at__gte=six_months_ago
        ).annotate(
            month=TruncMonth('created_at')
        ).values('month').annotate(
            count=Count('id'),
            revenue=Sum('total_cost')
        ).order_by('month')
        
        months_result = []
        for stat in orders_by_month:
            if stat['month']:
                month_str = stat['month'].strftime('%Y-%m')
                months_result.append({
                    'month': month_str,
                    'count': stat['count'],
                    'revenue': float(stat['revenue'] or 0)
                })
        
        # Топ менеджеры
        top_managers = Order.objects.filter(
            status='completed'
        ).values(
            'manager__id', 'manager__first_name', 'manager__last_name'
        ).annotate(
            orders_count=Count('id'),
            revenue=Sum('total_cost')
        ).order_by('-revenue')[:5]  # Топ-5
        
        managers_result = []
        for manager in top_managers:
            if manager['manager__id']:  # Пропускаем записи без менеджера
                managers_result.append({
                    'id': manager['manager__id'],
                    'name': f"{manager['manager__first_name']} {manager['manager__last_name']}",
                    'orders_count': manager['orders_count'],
                    'revenue': float(manager['revenue'] or 0)
                })
        
        # Последние заказы
        recent_orders = Order.objects.all().order_by('-created_at')[:5]
        recent_orders_serializer = OrderSerializer(recent_orders, many=True)
        
        return Response({
            'total_orders': total_orders,
            'completed_orders': completed_orders,
            'orders_this_month': orders_this_month,
            'total_clients': total_clients,
            'clients_this_month': clients_this_month,
            'company_balance': float(company_balance),
            'income_this_month': float(income_this_month),
            'expense_this_month': float(expense_this_month),
            'orders_by_month': months_result,
            'top_managers': managers_result,
            'recent_orders': recent_orders_serializer.data
        })

# Классы для экспорта данных в Excel
from .exports import export_clients_to_excel, export_orders_to_excel, export_finance_to_excel

class ExportClientsView(APIView):
    def get(self, request):
        return export_clients_to_excel()

class ExportOrdersView(APIView):
    def get(self, request):
        return export_orders_to_excel()

class ExportFinanceView(APIView):
    def get(self, request):
        return export_finance_to_excel()