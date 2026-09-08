from rest_framework import serializers
from .models import StudyFolder, Document, ChatMessage


class ChatMessageSerializer(serializers.ModelSerializer):
    class Meta:
        model = ChatMessage
        fields = [
            'id',
            'document',
            'folder',
            'question',
            'answer',
            'provider_used',
            'model_used',
            'created_at',
        ]
        read_only_fields = ['id', 'answer', 'provider_used', 'model_used', 'created_at']


class DocumentSerializer(serializers.ModelSerializer):
    extracted_text_preview = serializers.SerializerMethodField()
    file_url = serializers.SerializerMethodField()

    class Meta:
        model = Document
        fields = [
            'id',
            'folder',
            'title',
            'file',
            'file_url',
            'file_type',
            'file_size',
            'page_count',
            'extracted_text_preview',
            'summary',
            'uploaded_at',
            'updated_at',
        ]
        read_only_fields = [
            'id',
            'file_type',
            'file_size',
            'page_count',
            'extracted_text_preview',
            'summary',
            'uploaded_at',
            'updated_at',
        ]

    def get_extracted_text_preview(self, obj):
        if not obj.extracted_text:
            return ""
        return obj.extracted_text[:300] + ("..." if len(obj.extracted_text) > 300 else "")

    def get_file_url(self, obj):
        request = self.context.get('request')
        if obj.file and hasattr(obj.file, 'url'):
            return request.build_absolute_uri(obj.file.url) if request else obj.file.url
        return None


class DocumentDetailSerializer(DocumentSerializer):
    chat_messages = ChatMessageSerializer(many=True, read_only=True)

    class Meta(DocumentSerializer.Meta):
        fields = DocumentSerializer.Meta.fields + ['extracted_text', 'chat_messages']


class StudyFolderSerializer(serializers.ModelSerializer):
    total_documents = serializers.IntegerField(read_only=True)
    documents = DocumentSerializer(many=True, read_only=True)
    recent_chat = serializers.SerializerMethodField()

    class Meta:
        model = StudyFolder
        fields = [
            'id',
            'name',
            'description',
            'total_documents',
            'documents',
            'recent_chat',
            'created_at',
            'updated_at',
        ]
        read_only_fields = ['id', 'total_documents', 'created_at', 'updated_at']

    def get_recent_chat(self, obj):
        messages = obj.chat_messages.all().order_by('-created_at')[:5]
        return ChatMessageSerializer(messages, many=True).data


class FileUploadSerializer(serializers.Serializer):
    file = serializers.FileField(required=True)
    folder_id = serializers.IntegerField(required=False, allow_null=True)
    title = serializers.CharField(max_length=255, required=False, allow_blank=True)


class ExplainRequestSerializer(serializers.Serializer):
    provider = serializers.CharField(max_length=50, required=False, allow_blank=True)
    model = serializers.CharField(max_length=100, required=False, allow_blank=True)


class AskQuestionSerializer(serializers.Serializer):
    question = serializers.CharField(required=True, min_length=1)
    provider = serializers.CharField(max_length=50, required=False, allow_blank=True)
    model = serializers.CharField(max_length=100, required=False, allow_blank=True)
