from django.db import models


class StudyFolder(models.Model):
    """
    A collection / folder grouping multiple study documents.
    Allows querying and asking questions across all documents in the folder.
    """
    name = models.CharField(max_length=255)
    description = models.TextField(blank=True, default='')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return self.name

    @property
    def total_documents(self):
        return self.documents.count()

    def get_combined_text(self, max_length: int = 75000) -> str:
        """
        Gathers and concatenates text from all documents in this folder.
        """
        sections = []
        for doc in self.documents.all():
            if doc.extracted_text.strip():
                sections.append(f"=== Document: {doc.title} ({doc.file_type.upper()}) ===\n{doc.extracted_text.strip()}")
                
        full = "\n\n".join(sections)
        return full[:max_length]


class Document(models.Model):
    """
    An uploaded study file (PDF, TXT, MD, etc.).
    """
    folder = models.ForeignKey(
        StudyFolder,
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name='documents'
    )
    title = models.CharField(max_length=255)
    file = models.FileField(upload_to='uploads/%Y/%m/%d/')
    file_type = models.CharField(max_length=50, blank=True, default='')
    file_size = models.PositiveIntegerField(default=0)
    page_count = models.PositiveIntegerField(default=1)
    extracted_text = models.TextField(blank=True, default='')
    summary = models.TextField(blank=True, default='')
    uploaded_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-uploaded_at']

    def __str__(self):
        return self.title


class ChatMessage(models.Model):
    """
    Stores conversational Q&A history grounded in a document or study folder.
    """
    document = models.ForeignKey(
        Document,
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name='chat_messages'
    )
    folder = models.ForeignKey(
        StudyFolder,
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name='chat_messages'
    )
    question = models.TextField()
    answer = models.TextField()
    provider_used = models.CharField(max_length=50, blank=True, default='')
    model_used = models.CharField(max_length=100, blank=True, default='')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['created_at']

    def __str__(self):
        target = self.document.title if self.document else (self.folder.name if self.folder else 'General')
        return f"Q on [{target}]: {self.question[:40]}..."
