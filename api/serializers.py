from rest_framework import serializers
from user_accounts.models import User
from customer_clients.models import Client
from services.models import Service
from orders.models import Order, OrderItem
from finance.models import Transaction, SalaryPayment

class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ['id', 'username', 'first_name', 'last_name', 'email', 'role', 'phone']
        extra_kwargs = {'password': {'write_only': True}}

class ClientSerializer(serializers.ModelSerializer):
    class Meta:
        model = Client
        fields = ['id', 'name', 'address', 'phone', 'source', 'created_at']

class ServiceSerializer(serializers.ModelSerializer):
    category_display = serializers.CharField(source='get_category_display', read_only=True)
    
    class Meta:
        model = Service
        fields = ['id', 'name', 'cost_price', 'selling_price', 'category', 'category_display', 'created_at']

class OrderItemSerializer(serializers.ModelSerializer):
    service_name = serializers.CharField(source='service.name', read_only=True)
    service_category = serializers.CharField(source='service.category', read_only=True)
    service_category_display = serializers.CharField(source='service.get_category_display', read_only=True)
    service_cost_price = serializers.DecimalField(source='service.cost_price', max_digits=10, decimal_places=2, read_only=True)
    seller_name = serializers.CharField(source='seller.get_full_name', read_only=True)
    
    class Meta:
        model = OrderItem
        fields = ['id', 'order', 'service', 'price', 'seller', 'created_at', 
                 'service_name', 'service_category', 'service_category_display', 
                 'service_cost_price', 'seller_name']
        
    def create(self, validated_data):
        # Убеждаемся, что order правильно установлен
        return OrderItem.objects.create(**validated_data)

class OrderSerializer(serializers.ModelSerializer):
    items = OrderItemSerializer(many=True, read_only=True)
    client_name = serializers.CharField(source='client.name', read_only=True)
    client_phone = serializers.CharField(source='client.phone', read_only=True)
    client_address = serializers.CharField(source='client.address', read_only=True)
    manager_name = serializers.CharField(source='manager.get_full_name', read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    installers_names = serializers.SerializerMethodField(read_only=True)
    
    class Meta:
        model = Order
        fields = ['id', 'client', 'manager', 'status', 'installers', 'total_cost', 'items', 
                 'created_at', 'completed_at', 'client_name', 'client_phone', 'client_address', 
                 'manager_name', 'status_display', 'installers_names']
    
    def get_installers_names(self, obj):
        return [{'id': installer.id, 'name': installer.get_full_name()} for installer in obj.installers.all()]

class TransactionSerializer(serializers.ModelSerializer):
    type_display = serializers.CharField(source='get_type_display', read_only=True)
    order_display = serializers.CharField(source='order.__str__', read_only=True)
    
    class Meta:
        model = Transaction
        fields = ['id', 'type', 'amount', 'description', 'order', 'created_at', 
                 'type_display', 'order_display']

class SalaryPaymentSerializer(serializers.ModelSerializer):
    user_name = serializers.CharField(source='user.get_full_name', read_only=True)
    
    class Meta:
        model = SalaryPayment
        fields = ['id', 'user', 'amount', 'period_start', 'period_end', 'created_at', 'user_name']