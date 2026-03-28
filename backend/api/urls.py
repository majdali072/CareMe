from django.urls import path
from . import views

urlpatterns = [
    path('auth/register/', views.register),
    path('auth/login/', views.login),
    path('users/profile/', views.profile),
    path('medications/', views.medications),
    path('medications/<str:med_id>/', views.medication_detail),
    path('lab-tests/', views.lab_tests),
    path('lab-tests/<str:lab_id>/', views.lab_test_detail),
    path('lab-tests/<str:lab_id>/file/', views.lab_test_file),
    path('users/delete/', views.delete_account),
]
