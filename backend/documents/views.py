import os
import logging
from django.conf import settings
from rest_framework import status, viewsets
from rest_framework.decorators import api_view, action
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import StudyFolder, Document, ChatMessage
from .serializers import (
    StudyFolderSerializer,
    DocumentSerializer,
    DocumentDetailSerializer,
    ChatMessageSerializer,
    FileUploadSerializer,
    ExplainRequestSerializer,
    AskQuestionSerializer,
)
from .extractor import TextExtractor, TextExtractionError
from .ai_service import AIService, AIServiceError

logger = logging.getLogger(__name__)


@api_view(['GET'])
def health_check(request):
    """
    Health check endpoint for Flutter client to test backend connectivity.
    """
    return Response({
        "status": "ok",
        "service": "co_study_backend",
        "version": "1.0.0",
        "default_provider": settings.DEFAULT_AI_PROVIDER,
    })


@api_view(['GET'])
def ai_providers(request):
    """
    Returns list of supported AI providers and their configuration status.
    """
    return Response({
        "default_provider": settings.DEFAULT_AI_PROVIDER,
        "providers": AIService.get_providers_info(),
    })


class StudyFolderViewSet(viewsets.ModelViewSet):
    queryset = StudyFolder.objects.all()
    serializer_class = StudyFolderSerializer

    @action(detail=True, methods=['post'], url_path='ask')
    def ask_folder(self, request, pk=None):
        """
        Ask a question across all documents contained in this folder.
        """
        folder = self.get_object()
        serializer = AskQuestionSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        question = serializer.validated_data['question']
        provider = serializer.validated_data.get('provider')
        model = serializer.validated_data.get('model')

        combined_context = folder.get_combined_text()
        if not combined_context.strip():
            return Response(
                {"error": "This folder contains no extracted document text to query. Please upload files to this folder first."},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Retrieve recent chat history for this folder
        history_qs = folder.chat_messages.all().order_by('-created_at')[:5]
        history_list = [{"question": m.question, "answer": m.answer} for m in reversed(history_qs)]

        try:
            answer, provider_used, model_used = AIService.answer_question(
                context=combined_context,
                question=question,
                chat_history=history_list,
                provider=provider,
                model=model,
            )
        except AIServiceError as e:
            return Response({"error": str(e)}, status=status.HTTP_502_BAD_GATEWAY)

        # Record chat message
        chat_msg = ChatMessage.objects.create(
            folder=folder,
            question=question,
            answer=answer,
            provider_used=provider_used,
            model_used=model_used,
        )

        return Response({
            "folder_id": folder.id,
            "folder_name": folder.name,
            "question": question,
            "answer": answer,
            "provider": provider_used,
            "model": model_used,
            "message_id": chat_msg.id,
            "created_at": chat_msg.created_at,
        })

    @action(detail=True, methods=['get'], url_path='history')
    def history(self, request, pk=None):
        folder = self.get_object()
        messages = folder.chat_messages.all().order_by('created_at')
        return Response(ChatMessageSerializer(messages, many=True).data)


class DocumentViewSet(viewsets.ModelViewSet):
    queryset = Document.objects.all()
    serializer_class = DocumentSerializer

    def get_serializer_class(self):
        if self.action == 'retrieve':
            return DocumentDetailSerializer
        return DocumentSerializer

    @action(detail=False, methods=['post'], url_path='upload')
    def upload(self, request):
        """
        Upload one or multiple files.
        Accepts:
            - file (or files): uploaded file(s)
            - folder_id (optional): integer ID of target StudyFolder
            - title (optional): custom title for single file upload
        """
        uploaded_files = request.FILES.getlist('files')
        if not uploaded_files and 'file' in request.FILES:
            uploaded_files = [request.FILES['file']]

        if not uploaded_files:
            return Response(
                {"error": "No file provided. Send file or files in multipart/form-data."},
                status=status.HTTP_400_BAD_REQUEST
            )

        folder = None
        folder_id = request.data.get('folder_id')
        if folder_id:
            try:
                folder = StudyFolder.objects.get(pk=folder_id)
            except (StudyFolder.DoesNotExist, ValueError):
                return Response({"error": f"Folder with ID {folder_id} does not exist."}, status=status.HTTP_404_NOT_FOUND)

        custom_title = request.data.get('title', '').strip()
        created_docs = []

        for f in uploaded_files:
            name = f.name
            ext = os.path.splitext(name)[1].lower().replace('.', '')
            title = custom_title if (custom_title and len(uploaded_files) == 1) else name
            size = f.size

            # Extract text
            try:
                extracted_text, page_count = TextExtractor.extract_text(f, name)
            except TextExtractionError as e:
                logger.warning(f"Extraction warning: {str(e)}")
                extracted_text = ""
                page_count = 1

            doc = Document.objects.create(
                folder=folder,
                title=title,
                file=f,
                file_type=ext,
                file_size=size,
                page_count=page_count,
                extracted_text=extracted_text,
            )
            created_docs.append(doc)

        serializer = DocumentSerializer(created_docs, many=True, context={'request': request})
        return Response(
            {
                "message": f"Successfully uploaded and processed {len(created_docs)} document(s).",
                "documents": serializer.data,
            },
            status=status.HTTP_201_CREATED
        )

    @action(detail=True, methods=['post'], url_path='explain')
    def explain(self, request, pk=None):
        """
        Generates an AI study breakdown and summary of this document.
        """
        document = self.get_object()
        serializer = ExplainRequestSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        if not document.extracted_text.strip():
            return Response(
                {"error": "No text could be extracted from this document to explain."},
                status=status.HTTP_400_BAD_REQUEST
            )

        provider = serializer.validated_data.get('provider')
        model = serializer.validated_data.get('model')

        try:
            explanation, provider_used, model_used = AIService.explain_text(
                text=document.extracted_text,
                provider=provider,
                model=model,
            )
        except AIServiceError as e:
            return Response({"error": str(e)}, status=status.HTTP_502_BAD_GATEWAY)

        # Cache summary on document
        document.summary = explanation
        document.save(update_fields=['summary', 'updated_at'])

        return Response({
            "document_id": document.id,
            "document_title": document.title,
            "summary": explanation,
            "provider": provider_used,
            "model": model_used,
        })

    @action(detail=True, methods=['post'], url_path='ask')
    def ask_document(self, request, pk=None):
        """
        Ask a question specifically about this document.
        """
        document = self.get_object()
        serializer = AskQuestionSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        question = serializer.validated_data['question']
        provider = serializer.validated_data.get('provider')
        model = serializer.validated_data.get('model')

        if not document.extracted_text.strip():
            return Response(
                {"error": "No text available in this document to answer questions."},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Retrieve recent chat history for this document
        history_qs = document.chat_messages.all().order_by('-created_at')[:5]
        history_list = [{"question": m.question, "answer": m.answer} for m in reversed(history_qs)]

        context = f"=== Document: {document.title} ===\n{document.extracted_text}"

        try:
            answer, provider_used, model_used = AIService.answer_question(
                context=context,
                question=question,
                chat_history=history_list,
                provider=provider,
                model=model,
            )
        except AIServiceError as e:
            return Response({"error": str(e)}, status=status.HTTP_502_BAD_GATEWAY)

        # Save to ChatMessage
        chat_msg = ChatMessage.objects.create(
            document=document,
            question=question,
            answer=answer,
            provider_used=provider_used,
            model_used=model_used,
        )

        return Response({
            "document_id": document.id,
            "document_title": document.title,
            "question": question,
            "answer": answer,
            "provider": provider_used,
            "model": model_used,
            "message_id": chat_msg.id,
            "created_at": chat_msg.created_at,
        })

    @action(detail=True, methods=['get'], url_path='history')
    def history(self, request, pk=None):
        document = self.get_object()
        messages = document.chat_messages.all().order_by('created_at')
        return Response(ChatMessageSerializer(messages, many=True).data)
