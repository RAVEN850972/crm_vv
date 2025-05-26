from django.shortcuts import render, redirect, get_object_or_404
from django.contrib.auth.decorators import login_required
from django.contrib import messages
from .models import User
from .forms import CustomUserCreationForm, CustomUserChangeForm, ProfileForm
from django.views.decorators.csrf import ensure_csrf_cookie
import json
from django.contrib.auth import authenticate, login
from django.http import JsonResponse

@ensure_csrf_cookie
def login_view(request):
    """
    Представление для авторизации пользователей.
    Поддерживает как обычные POST-запросы, так и AJAX.
    """
    if request.method == 'POST':
        if request.headers.get('X-Requested-With') == 'XMLHttpRequest':
            try:
                # Обработка AJAX-запроса
                data = json.loads(request.body)
                username = data.get('username', '')
                password = data.get('password', '')
            except json.JSONDecodeError:
                return JsonResponse({'success': False, 'error': 'Неверный формат данных'}, status=400)
        else:
            # Обработка обычной POST-формы
            username = request.POST.get('username', '')
            password = request.POST.get('password', '')
        
        # Проверка аутентификации
        user = authenticate(request, username=username, password=password)
        
        if user is not None:
            login(request, user)
            
            # Формирование ответа в зависимости от типа запроса
            if request.headers.get('X-Requested-With') == 'XMLHttpRequest':
                return JsonResponse({
                    'success': True,
                    'redirect': '/',
                    'user': {
                        'id': user.id,
                        'username': user.username,
                        'full_name': user.get_full_name(),
                        'role': user.role
                    }
                })
            else:
                return redirect('dashboard')
        else:
            if request.headers.get('X-Requested-With') == 'XMLHttpRequest':
                return JsonResponse({
                    'success': False,
                    'error': 'Неверное имя пользователя или пароль'
                }, status=400)
            else:
                messages.error(request, 'Неверное имя пользователя или пароль')
                return render(request, 'user_accounts/login.html')
    
    # Для GET-запросов просто отображаем форму входа
    return render(request, 'users/login.html')

@login_required
def profile(request):
    """Страница профиля пользователя"""
    if request.method == 'POST':
        form = ProfileForm(request.POST, instance=request.user)
        if form.is_valid():
            form.save()
            messages.success(request, 'Профиль успешно обновлен!')
            return redirect('profile')
    else:
        form = ProfileForm(instance=request.user)
    
    return render(request, 'user_accounts/profile.html', {'form': form})

@login_required
def user_list(request):
    """Список пользователей"""
    # Только владелец может просматривать список пользователей
    if request.user.role != 'owner':
        messages.error(request, 'У вас нет прав для просмотра списка пользователей.')
        return redirect('dashboard')
    
    users = User.objects.all().order_by('role', 'username')
    return render(request, 'users/user_list.html', {'users': users})

@login_required
def user_detail(request, pk):
    """Детальная информация о пользователе"""
    # Только владелец может просматривать информацию о пользователях
    if request.user.role != 'owner':
        messages.error(request, 'У вас нет прав для просмотра информации о пользователях.')
        return redirect('dashboard')
    
    user = get_object_or_404(User, pk=pk)
    return render(request, 'user_accounts/user_detail.html', {'user_obj': user})

@login_required
def user_new(request):
    """Создание нового пользователя"""
    # Только владелец может создавать пользователей
    if request.user.role != 'owner':
        messages.error(request, 'У вас нет прав для создания пользователей.')
        return redirect('dashboard')
    
    if request.method == 'POST':
        form = CustomUserCreationForm(request.POST)
        if form.is_valid():
            user = form.save()
            messages.success(request, 'Пользователь успешно создан!')
            return redirect('user_detail', pk=user.pk)
    else:
        form = CustomUserCreationForm()
    
    return render(request, 'user_accounts/user_form.html', {'form': form})

@login_required
def user_edit(request, pk):
    """Редактирование пользователя"""
    # Только владелец может редактировать пользователей
    if request.user.role != 'owner':
        messages.error(request, 'У вас нет прав для редактирования пользователей.')
        return redirect('dashboard')
    
    user = get_object_or_404(User, pk=pk)
    
    if request.method == 'POST':
        form = CustomUserChangeForm(request.POST, instance=user)
        if form.is_valid():
            user = form.save()
            messages.success(request, 'Пользователь успешно обновлен!')
            return redirect('user_detail', pk=user.pk)
    else:
        form = CustomUserChangeForm(instance=user)
    
    return render(request, 'user_accounts/user_form.html', {'form': form, 'edit': True})