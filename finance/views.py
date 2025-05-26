from django.shortcuts import render, redirect, get_object_or_404
from django.contrib.auth.decorators import login_required
from django.contrib import messages
from django.utils import timezone
from django.db.models import Sum
from datetime import datetime, timedelta
from user_accounts.models import User  # Исправлено с accounts.models
from .models import Transaction, SalaryPayment
from .forms import TransactionForm, SalaryPaymentForm
from .utils import calculate_installer_salary, calculate_manager_salary, calculate_owner_salary

@login_required
def finance_dashboard(request):
    """Финансовый дашборд"""
    # Только владелец имеет доступ к финансовому дашборду
    if request.user.role != 'owner':
        messages.error(request, 'У вас нет прав для просмотра финансового раздела.')
        return redirect('dashboard')
    
    # Баланс компании
    company_balance = Transaction.get_company_balance()
    
    # Доходы и расходы за последние 30 дней
    end_date = timezone.now()
    start_date = end_date - timedelta(days=30)
    
    income = Transaction.objects.filter(
        type='income',
        created_at__range=(start_date, end_date)
    ).aggregate(Sum('amount'))['amount__sum'] or 0
    
    expense = Transaction.objects.filter(
        type='expense',
        created_at__range=(start_date, end_date)
    ).aggregate(Sum('amount'))['amount__sum'] or 0
    
    # Последние транзакции
    transactions = Transaction.objects.all().order_by('-created_at')[:10]
    
    context = {
        'company_balance': company_balance,
        'income': income,
        'expense': expense,
        'transactions': transactions,
    }
    
    return render(request, 'finance/finance_dashboard.html', context)

@login_required
def transaction_list(request):
    """Список транзакций"""
    # Только владелец имеет доступ к списку транзакций
    if request.user.role != 'owner':
        messages.error(request, 'У вас нет прав для просмотра транзакций.')
        return redirect('dashboard')
    
    # Фильтрация по типу
    type_filter = request.GET.get('type')
    if type_filter:
        transactions = Transaction.objects.filter(type=type_filter).order_by('-created_at')
    else:
        transactions = Transaction.objects.all().order_by('-created_at')
    
    return render(request, 'finance/transaction_list.html', {'transactions': transactions})

@login_required
def transaction_new(request):
    """Создание новой транзакции"""
    # Только владелец может создавать транзакции
    if request.user.role != 'owner':
        messages.error(request, 'У вас нет прав для создания транзакций.')
        return redirect('dashboard')
    
    if request.method == 'POST':
        form = TransactionForm(request.POST)
        if form.is_valid():
            transaction = form.save()
            messages.success(request, 'Транзакция успешно создана!')
            return redirect('transaction_list')
    else:
        form = TransactionForm()
    
    return render(request, 'finance/transaction_form.html', {'form': form})

@login_required
def salary_calculation(request):
    """Страница расчета зарплат"""
    # Только владелец может рассчитывать зарплаты
    if request.user.role != 'owner':
        messages.error(request, 'У вас нет прав для расчета зарплат.')
        return redirect('dashboard')
    
    # Получаем всех сотрудников
    users = User.objects.filter(role__in=['manager', 'installer', 'owner'])
    
    # Параметры периода для расчета
    start_date_str = request.GET.get('start_date')
    end_date_str = request.GET.get('end_date')
    
    if start_date_str and end_date_str:
        try:
            start_date = datetime.strptime(start_date_str, '%Y-%m-%d')
            end_date = datetime.strptime(end_date_str, '%Y-%m-%d')
        except ValueError:
            messages.error(request, 'Неверный формат даты. Используйте ГГГГ-ММ-ДД.')
            start_date = datetime(timezone.now().year, timezone.now().month, 1)
            end_date = timezone.now()
    else:
        # По умолчанию - текущий месяц
        today = timezone.now()
        start_date = datetime(today.year, today.month, 1)
        end_date = today
    
    # Список с расчетами зарплат
    salary_calculations = []
    
    for user in users:
        if user.role == 'installer':
            calculation = calculate_installer_salary(user, start_date, end_date)
        elif user.role == 'manager':
            calculation = calculate_manager_salary(user, start_date, end_date)
        else:  # owner
            calculation = calculate_owner_salary(start_date, end_date)
        
        salary_calculations.append({
            'user': user,
            'calculation': calculation
        })
    
    context = {
        'users': users,
        'salary_calculations': salary_calculations,
        'start_date': start_date,
        'end_date': end_date,
    }
    
    return render(request, 'finance/salary_calculation.html', context)

@login_required
def create_salary_payment(request, user_id):
    """Создание выплаты зарплаты"""
    # Только владелец может создавать выплаты зарплат
    if request.user.role != 'owner':
        messages.error(request, 'У вас нет прав для создания выплат зарплат.')
        return redirect('dashboard')
    
    user = get_object_or_404(User, pk=user_id)
    
    if request.method == 'POST':
        form = SalaryPaymentForm(request.POST)
        if form.is_valid():
            payment = form.save(commit=False)
            payment.user = user
            payment.save()
            
            # Создаем соответствующую транзакцию расхода
            Transaction.objects.create(
                type='expense',
                amount=payment.amount,
                description=f'Выплата зарплаты {user.get_full_name()} за период {payment.period_start} - {payment.period_end}',
                order=None
            )
            
            messages.success(request, f'Выплата зарплаты для {user.get_full_name()} успешно создана!')
            return redirect('salary_calculation')
    else:
        # Предзаполняем форму данными из расчета
        start_date_str = request.GET.get('start_date')
        end_date_str = request.GET.get('end_date')
        
        if start_date_str and end_date_str:
            try:
                start_date = datetime.strptime(start_date_str, '%Y-%m-%d')
                end_date = datetime.strptime(end_date_str, '%Y-%m-%d')
            except ValueError:
                start_date = datetime(timezone.now().year, timezone.now().month, 1)
                end_date = timezone.now()
        else:
            start_date = datetime(timezone.now().year, timezone.now().month, 1)
            end_date = timezone.now()
        
        if user.role == 'installer':
            calculation = calculate_installer_salary(user, start_date, end_date)
        elif user.role == 'manager':
            calculation = calculate_manager_salary(user, start_date, end_date)
        else:  # owner
            calculation = calculate_owner_salary(start_date, end_date)
        
        initial_data = {
            'amount': calculation['total_salary'],
            'period_start': start_date,
            'period_end': end_date,
        }
        
        form = SalaryPaymentForm(initial=initial_data)
    
    # Получаем расчет для отображения
    if user.role == 'installer':
        calculation = calculate_installer_salary(user, start_date, end_date)
    elif user.role == 'manager':
        calculation = calculate_manager_salary(user, start_date, end_date)
    else:  # owner
        calculation = calculate_owner_salary(start_date, end_date)
    
    return render(request, 'finance/create_salary_payment.html', {
        'form': form,
        'user': user,
        'calculation': calculation
    })