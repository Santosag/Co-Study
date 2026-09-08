import io
from django.test import TestCase
from django.core.files.uploadedfile import SimpleUploadedFile
from rest_framework.test import APIClient
from rest_framework import status
from pypdf import PdfWriter

from .models import StudyFolder, Document, ChatMessage
from .extractor import TextExtractor
from .ai_service import AIService


class TextExtractorTests(TestCase):
    def test_extract_plain_text(self):
        content = "Photosynthesis is the process by which green plants use sunlight to synthesize nutrients."
        f = io.BytesIO(content.encode('utf-8'))
        text, pages = TextExtractor.extract_text(f, "biology_notes.txt")
        self.assertEqual(pages, 1)
        self.assertIn("Photosynthesis", text)

    def test_extract_pdf_text(self):
        # Create a simple PDF in memory using pypdf
        writer = PdfWriter()
        writer.add_blank_page(width=200, height=200)
        pdf_bytes = io.BytesIO()
        writer.write(pdf_bytes)
        pdf_bytes.seek(0)

        text, pages = TextExtractor.extract_text(pdf_bytes, "sample.pdf")
        self.assertEqual(pages, 1)


class AIServiceTests(TestCase):
    def test_providers_info(self):
        providers = AIService.get_providers_info()
        provider_ids = [p["id"] for p in providers]
        self.assertIn("gemini", provider_ids)
        self.assertIn("openai", provider_ids)
        self.assertIn("claude", provider_ids)
        self.assertIn("groq", provider_ids)
        self.assertIn("deepseek", provider_ids)
        self.assertIn("ollama", provider_ids)
        self.assertIn("openrouter", provider_ids)

    def test_fallback_explanation_without_api_key(self):
        # When no API key is configured, AIService returns a helpful preview/guidance
        text = "Newton's Second Law states that F = m * a."
        explanation, provider, model = AIService.explain_text(text, provider="gemini")
        self.assertIn("gemini", provider)
        self.assertIn("API Key Required", explanation)


class APIEndpointsTests(TestCase):
    def setUp(self):
        self.client = APIClient()

    def test_health_check(self):
        response = self.client.get('/api/health/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['status'], 'ok')
        self.assertEqual(response.data['service'], 'co_study_backend')

    def test_ai_providers_list(self):
        response = self.client.get('/api/ai/providers/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('providers', response.data)
        self.assertGreaterEqual(len(response.data['providers']), 7)

    def test_folder_crud(self):
        # Create
        response = self.client.post('/api/folders/', {
            "name": "Computer Science 101",
            "description": "Algorithms and Data Structures"
        })
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        folder_id = response.data['id']

        # List
        response = self.client.get('/api/folders/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 1)

        # Retrieve
        response = self.client.get(f'/api/folders/{folder_id}/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['name'], 'Computer Science 101')

    def test_document_upload_and_extraction(self):
        folder = StudyFolder.objects.create(name="Biology Notes")
        uploaded_file = SimpleUploadedFile(
            "mitochondria.txt",
            b"Mitochondria is the powerhouse of the cell. It generates most of the chemical energy needed to power the cell's biochemical reactions.",
            content_type="text/plain"
        )

        response = self.client.post('/api/documents/upload/', {
            'file': uploaded_file,
            'folder_id': folder.id,
            'title': 'Cell Biology Chapter 1'
        }, format='multipart')

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(len(response.data['documents']), 1)
        doc_data = response.data['documents'][0]
        self.assertEqual(doc_data['title'], 'Cell Biology Chapter 1')
        self.assertEqual(doc_data['file_type'], 'txt')
        self.assertIn('Mitochondria', doc_data['extracted_text_preview'])

        # Check DB
        doc = Document.objects.get(pk=doc_data['id'])
        self.assertEqual(doc.folder, folder)
        self.assertIn("powerhouse", doc.extracted_text)

    def test_document_explain(self):
        doc = Document.objects.create(
            title="Calculus Derivatives",
            file=SimpleUploadedFile("calc.txt", b"The derivative of x^2 is 2x."),
            extracted_text="The derivative of x^2 is 2x. Derivatives represent the instantaneous rate of change.",
            file_type="txt"
        )

        response = self.client.post(f'/api/documents/{doc.id}/explain/', {
            'provider': 'gemini'
        })
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('summary', response.data)
        
        # Verify cached in database
        doc.refresh_from_db()
        self.assertTrue(len(doc.summary) > 0)

    def test_document_ask_question(self):
        doc = Document.objects.create(
            title="History of Internet",
            file=SimpleUploadedFile("net.txt", b"ARPANET was established in 1969."),
            extracted_text="ARPANET was established in 1969 by DARPA.",
            file_type="txt"
        )

        response = self.client.post(f'/api/documents/{doc.id}/ask/', {
            'question': 'When was ARPANET established?',
            'provider': 'openai'
        })
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('answer', response.data)
        self.assertEqual(ChatMessage.objects.filter(document=doc).count(), 1)

    def test_folder_ask_question_across_multiple_docs(self):
        folder = StudyFolder.objects.create(name="World War II")
        Document.objects.create(
            folder=folder,
            title="Part 1 - Pacific Theater",
            file=SimpleUploadedFile("pacific.txt", b"Pacific theater content"),
            extracted_text="The Pacific War began on December 7, 1941 with Pearl Harbor.",
            file_type="txt"
        )
        Document.objects.create(
            folder=folder,
            title="Part 2 - European Theater",
            file=SimpleUploadedFile("europe.txt", b"European theater content"),
            extracted_text="D-Day occurred on June 6, 1944 in Normandy, France.",
            file_type="txt"
        )

        response = self.client.post(f'/api/folders/{folder.id}/ask/', {
            'question': 'What happened on June 6, 1944 and December 7, 1941?',
            'provider': 'claude'
        })
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('answer', response.data)
        self.assertEqual(ChatMessage.objects.filter(folder=folder).count(), 1)

    def test_chat_history_retrieval(self):
        folder = StudyFolder.objects.create(name="Physics")
        ChatMessage.objects.create(
            folder=folder,
            question="What is gravity?",
            answer="Gravity is a fundamental interaction.",
            provider_used="gemini",
            model_used="gemini-2.5-flash"
        )

        response = self.client.get(f'/api/folders/{folder.id}/history/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 1)
        self.assertEqual(response.data[0]['question'], "What is gravity?")
