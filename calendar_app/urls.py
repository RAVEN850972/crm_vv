# calendar_app/urls.py
from django.urls import path
from . import views

urlpatterns = [
    # Основные маршруты календаря
    path('', views.CalendarView.as_view(), name='calendar'),
    path('schedule/<int:schedule_id>/', views.ScheduleDetailView.as_view(), name='schedule-detail'),
    
    # Управление работами
    path('schedule/<int:schedule_id>/start/', views.StartWorkView.as_view(), name='start-work'),
    path('schedule/<int:schedule_id>/complete/', views.CompleteWorkView.as_view(), name='complete-work'),
    
    # Маршрутизация
    path('routes/', views.RouteOptimizationView.as_view(), name='route-optimization'),
    path('routes/optimize/', views.RouteOptimizationView.as_view(), name='optimize-route'),
    
    # Расписание монтажника
    path('installer/<int:installer_id>/schedule/', views.InstallerScheduleView.as_view(), name='installer-schedule'),
    
    # Проверка доступности
    path('availability/check/', views.AvailabilityCheckView.as_view(), name='availability-check'),
]