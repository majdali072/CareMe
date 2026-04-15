from django.urls import path
from . import views

urlpatterns = [
    path('auth/register/', views.register),
    path('auth/login/', views.login),
    path('auth/refresh-token/', views.refresh_token_view),
    path('auth/logout/', views.logout),
    path('auth/send-otp/', views.send_otp),
    path('auth/verify-otp/', views.verify_otp),
    path('auth/change-password/', views.change_password),
    path('users/profile/', views.profile),
    path('medications/', views.medications),
    path('medications/<str:med_id>/', views.medication_detail),
    path('lab-tests/', views.lab_tests),
    path('lab-tests/<str:lab_id>/', views.lab_test_detail),
    path('lab-tests/<str:lab_id>/file/', views.lab_test_file),
    path('users/deactivate/', views.deactivate_account),
    path('doctors/', views.doctors),
    path('doctors/<str:doctor_id>/', views.doctor_detail),
    path('pharmacies/', views.pharmacies),
    path('pharmacies/<str:pharmacy_id>/', views.pharmacy_detail),
    path('users/export-data/', views.export_data),
    path('chat/', views.chat),
]
