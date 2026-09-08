from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    health_check,
    ai_providers,
    StudyFolderViewSet,
    DocumentViewSet,
)

router = DefaultRouter()
router.register(r'folders', StudyFolderViewSet, basename='folder')
router.register(r'documents', DocumentViewSet, basename='document')

urlpatterns = [
    path('health/', health_check, name='health-check'),
    path('ai/providers/', ai_providers, name='ai-providers'),
    path('', include(router.urls)),
]
