# crm_ac/urls.py
from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static
from analytics.views import dashboard

urlpatterns = [
    path('admin/', admin.site.urls),
    path('', dashboard, name='dashboard'),
    path('user_accounts/', include('user_accounts.urls')),
    path('clients/', include('customer_clients.urls')),
    path('services/', include('services.urls')),
    path('orders/', include('orders.urls')),
    path('finance/', include('finance.urls')),
    path('calendar/', include('calendar_app.urls')),  # Новый маршрут для календаря
    path('api/', include('api.urls')),
]

# Добавляем обработку медиа-файлов в режиме разработки
if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
    urlpatterns += static(settings.STATIC_URL, document_root=settings.STATIC_ROOT)