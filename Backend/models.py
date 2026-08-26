# models.py
"""
Pydantic Models للتحقق من البيانات
"""

from pydantic import BaseModel
from typing import List, Optional, Dict

class AskRequest(BaseModel):
    """نموذج طلب المستخدم الرئيسي"""
    user_id: str
    code: str
    subject: str
    device_id: Optional[str] = None
    logic_type: int = 1
    mode: str                           # شرح، تلخيص، سؤال، وزاري
    input_type: str                     # صفحة، وحدة، برومت (للأحياء فقط)
    content: str
    summary_level: int = 3              # 1-5 (للتلخيص)
    unit_name: Optional[str] = None     # الوحدة
    lesson_name: Optional[str] = None   # الدرس (الرياضيات)
    chat_history: Optional[List[Dict[str, str]]] = None

class VerificationRequest(BaseModel):
    """نموذج التحقق من الكود"""
    code: str
    device_id: str

class ChatMessage(BaseModel):
    """رسالة في الشات"""
    role: str
    text: str
    refs: List[str] = []

class ChatConversation(BaseModel):
    """محادثة كاملة"""
    id: str
    title: str
    subject: str
    mode: str
    messages: List[ChatMessage]