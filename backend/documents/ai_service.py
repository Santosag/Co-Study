"""
Universal Multi-AI Provider Service.
Supports Google Gemini, OpenAI, Anthropic Claude, Groq, DeepSeek, Ollama (Local), and OpenRouter.
"""

import os
import logging
from django.conf import settings

logger = logging.getLogger(__name__)


class AIServiceError(Exception):
    pass


class AIService:
    @classmethod
    def get_providers_info(cls):
        """
        Returns all supported AI providers and their configuration status.
        """
        return [
            {
                "id": "gemini",
                "name": "Google Gemini",
                "is_configured": bool(settings.GEMINI_API_KEY),
                "default_model": settings.GEMINI_DEFAULT_MODEL,
                "is_default": settings.DEFAULT_AI_PROVIDER == "gemini",
                "description": "Google's state-of-the-art multimodal model (Gemini 2.5 Flash).",
            },
            {
                "id": "openai",
                "name": "OpenAI (ChatGPT)",
                "is_configured": bool(settings.OPENAI_API_KEY),
                "default_model": settings.OPENAI_DEFAULT_MODEL,
                "is_default": settings.DEFAULT_AI_PROVIDER == "openai",
                "description": "OpenAI GPT-4o-mini and GPT-4o models.",
            },
            {
                "id": "claude",
                "name": "Anthropic Claude",
                "is_configured": bool(settings.ANTHROPIC_API_KEY),
                "default_model": settings.ANTHROPIC_DEFAULT_MODEL,
                "is_default": settings.DEFAULT_AI_PROVIDER == "claude",
                "description": "Anthropic Claude 3.5 Haiku and Sonnet.",
            },
            {
                "id": "groq",
                "name": "Groq (Ultra-Fast)",
                "is_configured": bool(settings.GROQ_API_KEY),
                "default_model": settings.GROQ_DEFAULT_MODEL,
                "is_default": settings.DEFAULT_AI_PROVIDER == "groq",
                "description": "Ultra-fast inference running Llama 3.3 and DeepSeek R1.",
            },
            {
                "id": "deepseek",
                "name": "DeepSeek",
                "is_configured": bool(settings.DEEPSEEK_API_KEY),
                "default_model": settings.DEEPSEEK_DEFAULT_MODEL,
                "is_default": settings.DEFAULT_AI_PROVIDER == "deepseek",
                "description": "DeepSeek-V3 Chat and DeepSeek-R1 Reasoner.",
            },
            {
                "id": "ollama",
                "name": "Ollama (Local Offline AI)",
                "is_configured": True,  # Usually locally running on localhost:11434
                "default_model": settings.OLLAMA_DEFAULT_MODEL,
                "is_default": settings.DEFAULT_AI_PROVIDER == "ollama",
                "description": "Free open-source local AI running on your machine.",
            },
            {
                "id": "openrouter",
                "name": "OpenRouter",
                "is_configured": bool(settings.OPENROUTER_API_KEY),
                "default_model": settings.OPENROUTER_DEFAULT_MODEL,
                "is_default": settings.DEFAULT_AI_PROVIDER == "openrouter",
                "description": "Unified API gateway to hundreds of open-source and proprietary models.",
            },
        ]

    @classmethod
    def _resolve_provider(cls, provider: str = None):
        selected = (provider or settings.DEFAULT_AI_PROVIDER).lower()
        supported = ["gemini", "openai", "claude", "groq", "deepseek", "ollama", "openrouter"]
        if selected not in supported:
            selected = "gemini"
        return selected

    @classmethod
    def explain_text(cls, text: str, provider: str = None, model: str = None) -> tuple[str, str, str]:
        """
        Generates structured study explanation and summary for the provided text.
        
        Returns:
            tuple of (explanation_text: str, provider_used: str, model_used: str)
        """
        provider = cls._resolve_provider(provider)
        
        system_prompt = (
            "You are an expert AI study tutor and professor. "
            "Your task is to analyze the provided study document and generate a thorough, clear, and organized study guide. "
            "Format your response in GitHub Flavored Markdown with the following sections:\n"
            "## 📌 Executive Summary\n"
            "A concise overview of what this material covers.\n\n"
            "## 🔑 Key Concepts & Definitions\n"
            "Bullet points defining critical terms, formulas, or concepts.\n\n"
            "## 📚 In-Depth Explanation & Takeaways\n"
            "Detailed breakdown of main themes, mechanisms, arguments, or lessons.\n\n"
            "## 💡 Practice & Review Questions\n"
            "3-5 thoughtful questions to test understanding with brief answers."
        )
        
        user_prompt = f"Here is the study material to explain:\n\n{text[:60000]}"
        
        return cls._generate(system_prompt, user_prompt, provider, model)

    @classmethod
    def answer_question(
        cls,
        context: str,
        question: str,
        chat_history: list = None,
        provider: str = None,
        model: str = None,
    ) -> tuple[str, str, str]:
        """
        Answers a user question based strictly on the provided context (single doc or multi-doc folder).
        
        Returns:
            tuple of (answer_text: str, provider_used: str, model_used: str)
        """
        provider = cls._resolve_provider(provider)
        
        system_prompt = (
            "You are an intelligent AI study partner for the Co-Study platform. "
            "You are given reference documents/materials uploaded by the student. "
            "Your goal is to answer the student's question accurately and helpfully using the provided context.\n"
            "- If the context contains the answer, explain clearly and cite relevant sections or file names if mentioned.\n"
            "- If the context does not contain enough information to answer completely, acknowledge what the context says, state the limitation, and provide general assistance while clarifying it was not in the uploaded notes.\n"
            "- Be concise, structured, and student-friendly."
        )
        
        history_str = ""
        if chat_history:
            history_lines = []
            for item in chat_history[-5:]:  # keep last 5 turns
                history_lines.append(f"Student: {item.get('question', '')}")
                history_lines.append(f"AI: {item.get('answer', '')}")
            history_str = "Recent conversation:\n" + "\n".join(history_lines) + "\n\n"
            
        user_prompt = (
            f"{history_str}"
            f"Uploaded Context / Study Material:\n\"\"\"\n{context[:65000]}\n\"\"\"\n\n"
            f"Student Question: {question}"
        )
        
        return cls._generate(system_prompt, user_prompt, provider, model)

    @classmethod
    def _generate(cls, system_prompt: str, user_prompt: str, provider: str, model: str = None) -> tuple[str, str, str]:
        """
        Routes the prompt to the selected provider.
        """
        if provider == "gemini":
            return cls._call_gemini(system_prompt, user_prompt, model)
        elif provider == "openai":
            return cls._call_openai(system_prompt, user_prompt, model)
        elif provider == "claude":
            return cls._call_claude(system_prompt, user_prompt, model)
        elif provider == "groq":
            return cls._call_groq(system_prompt, user_prompt, model)
        elif provider == "deepseek":
            return cls._call_deepseek(system_prompt, user_prompt, model)
        elif provider == "ollama":
            return cls._call_ollama(system_prompt, user_prompt, model)
        elif provider == "openrouter":
            return cls._call_openrouter(system_prompt, user_prompt, model)
        else:
            return cls._call_gemini(system_prompt, user_prompt, model)

    # -------------------------------------------------------------
    # Provider Implementations
    # -------------------------------------------------------------

    @classmethod
    def _call_gemini(cls, system_prompt: str, user_prompt: str, model: str = None) -> tuple[str, str, str]:
        model_name = model or settings.GEMINI_DEFAULT_MODEL
        api_key = settings.GEMINI_API_KEY
        
        if not api_key:
            return cls._fallback_response("Google Gemini", model_name, user_prompt, "GEMINI_API_KEY")
            
        try:

            from google import genai
            client = genai.Client(api_key=api_key)
            full_prompt = f"{system_prompt}\n\n{user_prompt}"
            response = client.models.generate_content(
                model=model_name,
                contents=full_prompt,
            )
            return response.text, "gemini", model_name
        except Exception as e:
            logger.error(f"Gemini API error: {str(e)}")
            raise AIServiceError(f"Google Gemini Error: {str(e)}")

    @classmethod
    def _call_openai(cls, system_prompt: str, user_prompt: str, model: str = None) -> tuple[str, str, str]:
        model_name = model or settings.OPENAI_DEFAULT_MODEL
        api_key = settings.OPENAI_API_KEY
        
        if not api_key:
            return cls._fallback_response("OpenAI", model_name, user_prompt, "OPENAI_API_KEY")
            
        try:
            from openai import OpenAI
            client = OpenAI(api_key=api_key)
            response = client.chat.completions.create(
                model=model_name,
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt},
                ],
            )
            return response.choices[0].message.content, "openai", model_name
        except Exception as e:
            logger.error(f"OpenAI API error: {str(e)}")
            raise AIServiceError(f"OpenAI Error: {str(e)}")

    @classmethod
    def _call_claude(cls, system_prompt: str, user_prompt: str, model: str = None) -> tuple[str, str, str]:
        model_name = model or settings.ANTHROPIC_DEFAULT_MODEL
        api_key = settings.ANTHROPIC_API_KEY
        
        if not api_key:
            return cls._fallback_response("Anthropic Claude", model_name, user_prompt, "ANTHROPIC_API_KEY")
            
        try:
            import anthropic
            client = anthropic.Anthropic(api_key=api_key)
            response = client.messages.create(
                model=model_name,
                max_tokens=4096,
                system=system_prompt,
                messages=[{"role": "user", "content": user_prompt}],
            )
            return response.content[0].text, "claude", model_name
        except Exception as e:
            logger.error(f"Claude API error: {str(e)}")
            raise AIServiceError(f"Anthropic Claude Error: {str(e)}")

    @classmethod
    def _call_groq(cls, system_prompt: str, user_prompt: str, model: str = None) -> tuple[str, str, str]:
        model_name = model or settings.GROQ_DEFAULT_MODEL
        api_key = settings.GROQ_API_KEY
        
        if not api_key:
            return cls._fallback_response("Groq", model_name, user_prompt, "GROQ_API_KEY")
            
        try:
            from openai import OpenAI
            client = OpenAI(base_url="https://api.groq.com/openai/v1", api_key=api_key)
            response = client.chat.completions.create(
                model=model_name,
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt},
                ],
            )
            return response.choices[0].message.content, "groq", model_name
        except Exception as e:
            logger.error(f"Groq API error: {str(e)}")
            raise AIServiceError(f"Groq Error: {str(e)}")

    @classmethod
    def _call_deepseek(cls, system_prompt: str, user_prompt: str, model: str = None) -> tuple[str, str, str]:
        model_name = model or settings.DEEPSEEK_DEFAULT_MODEL
        api_key = settings.DEEPSEEK_API_KEY
        
        if not api_key:
            return cls._fallback_response("DeepSeek", model_name, user_prompt, "DEEPSEEK_API_KEY")
            
        try:
            from openai import OpenAI
            client = OpenAI(base_url="https://api.deepseek.com", api_key=api_key)
            response = client.chat.completions.create(
                model=model_name,
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt},
                ],
            )
            return response.choices[0].message.content, "deepseek", model_name
        except Exception as e:
            logger.error(f"DeepSeek API error: {str(e)}")
            raise AIServiceError(f"DeepSeek Error: {str(e)}")

    @classmethod
    def _call_ollama(cls, system_prompt: str, user_prompt: str, model: str = None) -> tuple[str, str, str]:
        model_name = model or settings.OLLAMA_DEFAULT_MODEL
        base_url = settings.OLLAMA_BASE_URL
        
        try:
            from openai import OpenAI
            client = OpenAI(base_url=base_url, api_key="ollama")
            response = client.chat.completions.create(
                model=model_name,
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt},
                ],
            )
            return response.choices[0].message.content, "ollama", model_name
        except Exception as e:
            logger.warning(f"Ollama connection error at {base_url}: {str(e)}")
            return cls._fallback_response(
                "Ollama (Local)", model_name, user_prompt,
                key_name="OLLAMA_BASE_URL (Ensure Ollama is running: 'ollama run llama3.2')"
            )

    @classmethod
    def _call_openrouter(cls, system_prompt: str, user_prompt: str, model: str = None) -> tuple[str, str, str]:
        model_name = model or settings.OPENROUTER_DEFAULT_MODEL
        api_key = settings.OPENROUTER_API_KEY
        
        if not api_key:
            return cls._fallback_response("OpenRouter", model_name, user_prompt, "OPENROUTER_API_KEY")
            
        try:
            from openai import OpenAI
            client = OpenAI(base_url="https://openrouter.ai/api/v1", api_key=api_key)
            response = client.chat.completions.create(
                model=model_name,
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt},
                ],
            )
            return response.choices[0].message.content, "openrouter", model_name
        except Exception as e:
            logger.error(f"OpenRouter API error: {str(e)}")
            raise AIServiceError(f"OpenRouter Error: {str(e)}")

    @classmethod
    def _fallback_response(cls, provider_name: str, model_name: str, prompt: str, key_name: str) -> tuple[str, str, str]:
        """
        Graceful response when API key is not configured, allowing complete UI & API testing.
        """
        sample_preview = prompt[-250:].replace("\n", " ") if len(prompt) > 250 else prompt.replace("\n", " ")
        msg = (
            f"> [!NOTE]\n"
            f"> **API Key Required for Live Generation**\n"
            f"> `{provider_name}` (`{model_name}`) is selected, but `{key_name}` is not configured yet in `backend/.env`.\n\n"
            f"### 📋 Preview Analysis (Simulated Response)\n"
            f"- **Context Extracted**: Ready for processing ({len(prompt)} characters received).\n"
            f"- **Prompt Preview**: \"...{sample_preview}\"\n\n"
            f"To get live AI responses, open `backend/.env` and add your API key:\n"
            f"```bash\n"
            f"{key_name}=your_actual_key_here\n"
            f"```\n"
            f"All endpoints, file uploads, text parsing, and folder aggregation are fully functional!"
        )
        return msg, f"{provider_name.lower()}_simulation", model_name
