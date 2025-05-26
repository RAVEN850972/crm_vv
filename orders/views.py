from django.shortcuts import render, get_object_or_404, redirect
from django.contrib.auth.decorators import login_required
from django.contrib import messages
from django.utils import timezone
from .models import Order, OrderItem
from .forms import OrderForm, OrderItemForm
from customer_clients.models import Client  # Исправлено с clients.models
from services.models import Service
from user_accounts.models import User  # Исправлено с accounts.models

@login_required
def order_list(request):
    """Список заказов"""
    # Для владельца - все заказы
    if request.user.role == 'owner':
        orders = Order.objects.all().order_by('-created_at')
    # Для менеджера - только его заказы
    elif request.user.role == 'manager':
        orders = Order.objects.filter(manager=request.user).order_by('-created_at')
    # Для монтажника - заказы, где он назначен
    else:  # installer
        orders = Order.objects.filter(installers=request.user).order_by('-created_at')
    
    return render(request, 'orders/order_list.html', {'orders': orders})

@login_required
def order_detail(request, pk):
    """Детальная информация о заказе"""
    # Для владельца - любой заказ
    if request.user.role == 'owner':
        order = get_object_or_404(Order, pk=pk)
    # Для менеджера - только его заказы
    elif request.user.role == 'manager':
        order = get_object_or_404(Order, pk=pk, manager=request.user)
    # Для монтажника - заказы, где он назначен
    else:  # installer
        order = get_object_or_404(Order, pk=pk, installers=request.user)
    
    items = order.items.all()
    installers = order.installers.all()
    
    return render(request, 'orders/order_detail.html', {
        'order': order,
        'items': items,
        'installers': installers
    })

@login_required
def order_new(request):
    """Создание нового заказа"""
    # Только владелец и менеджер могут создавать заказы
    if request.user.role not in ['owner', 'manager']:
        messages.error(request, 'У вас нет прав для создания заказов.')
        return redirect('order_list')
    
    if request.method == 'POST':
        form = OrderForm(request.POST)
        if form.is_valid():
            order = form.save(commit=False)
            # Если заказ создает менеджер, он автоматически назначается менеджером заказа
            if request.user.role == 'manager':
                order.manager = request.user
            order.save()
            # Сохранение выбранных монтажников
            order.installers.set(form.cleaned_data['installers'])
            messages.success(request, 'Заказ успешно создан!')
            return redirect('order_detail', pk=order.pk)
    else:
        form = OrderForm()
        # Если заказ создает менеджер, предзаполняем поле менеджера
        if request.user.role == 'manager':
            form.fields['manager'].initial = request.user
            form.fields['manager'].disabled = True
    
    return render(request, 'orders/order_form.html', {'form': form})

@login_required
def order_edit(request, pk):
    """Редактирование заказа"""
    # Для владельца - любой заказ
    if request.user.role == 'owner':
        order = get_object_or_404(Order, pk=pk)
    # Для менеджера - только его заказы
    elif request.user.role == 'manager':
        order = get_object_or_404(Order, pk=pk, manager=request.user)
    # Монтажники не могут редактировать заказы
    else:
        messages.error(request, 'У вас нет прав для редактирования заказов.')
        return redirect('order_list')
    
    if request.method == 'POST':
        form = OrderForm(request.POST, instance=order)
        if form.is_valid():
            order = form.save()
            # Обновление выбранных монтажников
            order.installers.set(form.cleaned_data['installers'])
            messages.success(request, 'Заказ успешно обновлен!')
            return redirect('order_detail', pk=order.pk)
    else:
        form = OrderForm(instance=order)
        # Для менеджера поле менеджера недоступно для редактирования
        if request.user.role == 'manager':
            form.fields['manager'].disabled = True
    
    return render(request, 'orders/order_form.html', {'form': form, 'edit': True})

@login_required
def order_add_item(request, pk):
    """Добавление позиции в заказ"""
    # Для владельца - любой заказ
    if request.user.role == 'owner':
        order = get_object_or_404(Order, pk=pk)
    # Для менеджера - только его заказы
    elif request.user.role == 'manager':
        order = get_object_or_404(Order, pk=pk, manager=request.user)
    # Монтажники не могут добавлять позиции
    else:
        messages.error(request, 'У вас нет прав для добавления позиций в заказ.')
        return redirect('order_detail', pk=pk)
    
    if request.method == 'POST':
        form = OrderItemForm(request.POST)
        if form.is_valid():
            item = form.save(commit=False)
            item.order = order
            # Если не указан продавец, то продавцом считается текущий пользователь
            if not item.seller:
                item.seller = request.user
            item.save()
            messages.success(request, 'Позиция успешно добавлена в заказ!')
            return redirect('order_detail', pk=order.pk)
    else:
        form = OrderItemForm()
        # Предварительно заполняем поле продавца текущим пользователем
        form.fields['seller'].initial = request.user
    
    return render(request, 'orders/order_item_form.html', {'form': form, 'order': order})

@login_required
def order_change_status(request, pk):
    """Изменение статуса заказа"""
    # Для владельца - любой заказ
    if request.user.role == 'owner':
        order = get_object_or_404(Order, pk=pk)
    # Для менеджера - только его заказы
    elif request.user.role == 'manager':
        order = get_object_or_404(Order, pk=pk, manager=request.user)
    # Для монтажника - заказы, где он назначен, и только для изменения статуса на "Завершен"
    elif request.user.role == 'installer':
        order = get_object_or_404(Order, pk=pk, installers=request.user)
        if order.status == 'completed' or request.POST.get('status') != 'completed':
            messages.error(request, 'У вас нет прав для изменения статуса заказа.')
            return redirect('order_detail', pk=pk)
    else:
        messages.error(request, 'У вас нет прав для изменения статуса заказа.')
        return redirect('order_list')
    
    if request.method == 'POST':
        status = request.POST.get('status')
        if status in dict(Order.STATUS_CHOICES).keys():
            order.status = status
            if status == 'completed':
                order.completed_at = timezone.now()
            order.save()
            messages.success(request, f'Статус заказа изменен на "{dict(Order.STATUS_CHOICES)[status]}"!')
        else:
            messages.error(request, 'Некорректный статус заказа.')
    
    return redirect('order_detail', pk=pk)