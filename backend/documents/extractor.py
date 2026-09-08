"""
Text extraction utilities for uploaded study files.
Supports PDF (.pdf), plain text (.txt), Markdown (.md), and common source/notes files.
"""

import io
import os
import logging
from pypdf import PdfReader

logger = logging.getLogger(__name__)

# Max number of textless pages we'll run OCR on per document, to keep
# uploads from hanging for minutes on very long scanned PDFs.
MAX_OCR_PAGES = 60
OCR_DPI = 200


class TextExtractionError(Exception):
    pass


class TextExtractor:
    @classmethod
    def extract_text(cls, file_obj, filename: str) -> tuple[str, int]:
        """
        Extracts plain text from an uploaded file object.
        
        Args:
            file_obj: File-like object (Django UploadedFile or io.BytesIO)
            filename: Name of the file with extension
            
        Returns:
            tuple of (extracted_text: str, page_count: int)
        """
        ext = os.path.splitext(filename)[1].lower()
        
        # Reset file pointer to beginning
        if hasattr(file_obj, 'seek'):
            file_obj.seek(0)
            
        try:
            if ext == '.pdf':
                return cls._extract_pdf(file_obj)
            elif ext in ('.txt', '.md', '.markdown', '.rst', '.csv', '.json', '.py', '.dart', '.js', '.html'):
                return cls._extract_text_file(file_obj)
            else:
                # Fallback: attempt plain text decode
                return cls._extract_text_file(file_obj)
        except Exception as e:
            logger.error(f"Error extracting text from {filename}: {str(e)}")
            raise TextExtractionError(f"Could not extract text from {filename}: {str(e)}")

    @classmethod
    def _extract_pdf(cls, file_obj) -> tuple[str, int]:
        reader = PdfReader(file_obj)
        page_count = len(reader.pages)
        pages_text = {}
        blank_pages = []

        for idx, page in enumerate(reader.pages):
            page_text = page.extract_text() or ""
            cleaned = page_text.strip()
            if cleaned:
                pages_text[idx] = cleaned
            else:
                blank_pages.append(idx)

        # Fallback: pages with no embedded text layer are likely scanned
        # images. Run OCR on those specific pages instead of leaving the
        # document with no extracted text at all.
        if blank_pages:
            ocr_pages = blank_pages[:MAX_OCR_PAGES]
            if len(blank_pages) > MAX_OCR_PAGES:
                logger.warning(
                    f"{len(blank_pages)} pages had no text layer; only OCR'ing "
                    f"the first {MAX_OCR_PAGES} to keep upload times reasonable."
                )
            ocr_results = cls._ocr_pdf_pages(file_obj, ocr_pages)
            for idx, text in ocr_results.items():
                if text.strip():
                    pages_text[idx] = text.strip()

        full_text = "\n\n".join(
            f"--- Page {idx + 1} ---\n{pages_text[idx]}"
            for idx in sorted(pages_text.keys())
        )
        return full_text, page_count

    @classmethod
    def _ocr_pdf_pages(cls, file_obj, page_indices: list) -> dict:
        """
        Runs OCR on specific 0-indexed pages of a PDF. Returns {index: text}.
        Requires the pytesseract/pdf2image packages plus the tesseract and
        poppler system binaries to be installed.
        """
        if not page_indices:
            return {}

        try:
            from pdf2image import convert_from_bytes
            import pytesseract
        except ImportError:
            logger.warning(
                "pytesseract/pdf2image not installed; skipping OCR fallback "
                "for pages with no embedded text."
            )
            return {}

        if hasattr(file_obj, 'seek'):
            file_obj.seek(0)
        file_bytes = file_obj.read()
        if hasattr(file_obj, 'seek'):
            file_obj.seek(0)

        results = {}
        # Group contiguous pages into ranges to minimize convert_from_bytes calls.
        for idx in page_indices:
            page_num = idx + 1  # pdf2image uses 1-indexed pages
            try:
                images = convert_from_bytes(
                    file_bytes, dpi=OCR_DPI, first_page=page_num, last_page=page_num
                )
                if images:
                    results[idx] = pytesseract.image_to_string(images[0])
            except Exception as e:
                logger.warning(f"OCR failed on page {page_num}: {str(e)}")

        return results

    @classmethod
    def _extract_text_file(cls, file_obj) -> tuple[str, int]:
        raw_bytes = file_obj.read()
        if hasattr(file_obj, 'seek'):
            file_obj.seek(0)
            
        # Try UTF-8 first, fallback to Latin-1
        try:
            text = raw_bytes.decode('utf-8')
        except UnicodeDecodeError:
            text = raw_bytes.decode('latin-1', errors='replace')
            
        return text.strip(), 1
