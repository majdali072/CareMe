from django.urls import path
from . import views

urlpatterns = [
    path('auth/register/', views.register),
    path('auth/login/', views.login),
    path('auth/send-otp/', views.send_otp),
    path('auth/verify-otp/', views.verify_otp),
    path('auth/change-password/', views.change_password),
    path('users/profile/', views.profile),
    path('medications/', views.medications),
    path('medications/<str:med_id>/', views.medication_detail),
    path('lab-tests/', views.lab_tests),
    path('lab-tests/<str:lab_id>/', views.lab_test_detail),
    path('lab-tests/<str:lab_id>/file/', views.lab_test_file),
    path('users/delete/', views.delete_account),
    path('users/export-data/', views.export_data),
    path('chat/', views.chat),
]
