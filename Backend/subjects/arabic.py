# subjects/arabic.py
"""
قسم اللغة العربية - يعتمد على ذاكرة التطبيق (الجوال) فقط - Stateless
مع دعم المحادثة الطبيعية (ترحيب) والدقة الصارمة في المنهج
"""

from .common import (
    subject_book_path, load_json_safe, extract_all_texts_and_metas_physics,
    enhanced_search_physics, system_prompt_strict_explain,
    system_prompt_strict_summary, system_prompt_strict_qa,
    filter_and_rank_exams, collect_exam_questions_by_years,
    parse_exams_input, extract_keywords, faiss_search, format_arabic_math
)
from config import BASE_SUBJECTS_DIR, QA_TOP_K, EXAMS_BATCH_SIZE, HISTORY_LAST_N
from models import AskRequest
from typing import Dict, List, Optional
import json
import re
import os
import random
import asyncio

from core import streaming
import time


SUBJECT = "عربي"
sessions_arabic = {}

_arabic_session_timestamps = {}


_book_cache = None

def get_book_data():
    global _book_cache
    if _book_cache is not None:
        return _book_cache
    # 📖 هذا المعالج يتوقّع **قاموس وحدات ودروس** — نطلبه صراحةً
    #    كي لا يتغيّر تحته الشكل يوم يُضاف للمادة ملف صفحات.
    book = load_json_safe(subject_book_path(SUBJECT, prefer='lessons_mode'))
    if not book:
        return {}
    _book_cache = book
    return _book_cache



# =====================
# دوال مساعدة جديدة
# =====================

_subject_session_timestamps = {}

def cleanup_subject_sessions(sessions_dict: dict, session_timestamps: dict):
    """تنظيف الجلسات المنتهية لأي مادة"""
    now = time.time()
    expired = [
        uid for uid, ts in session_timestamps.items()
        if now - ts > 1800  # 30 دقيقة
    ]
    for uid in expired:
        sessions_dict.pop(uid, None)
        session_timestamps.pop(uid, None)
        
        
        

def extract_lesson_only(book_data, lesson_name):
    """استخراج درس واحد فقط من الوحدات"""
    for unit in book_data:
        for lesson in unit.get("الدروس", []):
            if lesson.get("اسم_الدرس") == lesson_name:
                return [{
                    "اسم_الوحدة": unit.get("اسم_الوحدة"),
                    "الدروس": [lesson]
                }]
    return []


async def enhanced_search_with_context(book_data, query, chat_history, top_k=5):
    """بحث ذكي مع دعم السياق من المحادثة"""
    last_ai_response = ""
    if chat_history:
        for msg in reversed(chat_history):
            if msg.get('role') == 'assistant':
                last_ai_response = msg.get('content', '')
                break
    
    texts, metas = extract_all_texts_and_metas_physics(book_data)
    if not texts: return [], []
    
    combined_query = query
    if len(query.split()) < 5 and last_ai_response:
        combined_query = last_ai_response[:150] + " " + query
    
    sem_results, idxs = await faiss_search(texts, combined_query, top_k=top_k)
    keywords = extract_keywords(query)
    direct_hits = []
    direct_idxs = []
    
    for i, txt in enumerate(texts):
        if any(k in txt for k in keywords):
            direct_hits.append(txt)
            direct_idxs.append(i)
    
    final_texts = []
    final_idxs = []
    
    for t, i in zip(direct_hits, direct_idxs):
        if i not in final_idxs:
            final_texts.append(t)
            final_idxs.append(i)
    
    for t, i in zip(sem_results, idxs):
        if i not in final_idxs:
            final_texts.append(t)
            final_idxs.append(i)
    
    return final_texts[:top_k], final_idxs[:top_k]


# =====================
# الدوال الرئيسية
# =====================
async def handle_arabic_explain(req: AskRequest, gemini_client):
    """وضع الشرح - العربي"""
    book = get_book_data()
    if not book: return {"answer": "❌ المادة غير متوفرة"}
    
    context_text = ""
    refs = []

    # 1. إذا الطالب حدد درس معين (الدرس قصير، نمرره كامل لضمان عدم تشتت السياق)
    if req.lesson_name:
        target_data = extract_lesson_only(book.get("الوحدات", []), req.lesson_name)
        if not target_data: return {"answer": f"❌ لم أجد درس '{req.lesson_name}'"}
        
        # تجميع محتوى الدرس بنص واحد مرتب
        lesson_parts = target_data[0]['الدروس'][0].get('الأجزاء', [])
        for part in lesson_parts:
            context_text += f"[{part.get('اسم_الجزء', '')}]\n"
            content = part.get('المحتوى', [])
            if isinstance(content, list):
                # دمج عناصر المصفوفة كنص واحد
                for item in content:
                    if isinstance(item, dict):
                        context_text += f"- {item.get('المصطلح', '')}: {item.get('التعريف', '')}\n"
                    else:
                        context_text += f"- {item}\n"
            else:
                context_text += f"{content}\n"
            context_text += "\n"
            
        refs.append(req.lesson_name)

    # 2. إذا لم يحدد درس، نستخدم البحث الدلالي المعتاد على الوحدة أو الكتاب
    else:
        if req.unit_name and req.unit_name != "الكل":
            target_data = [u for u in book.get("الوحدات", []) if u.get("اسم_الوحدة") == req.unit_name]
            if not target_data: return {"answer": f"❌ لم أجد الوحدة '{req.unit_name}'"}
        else:
            target_data = book if isinstance(book, list) else book.get("الوحدات", [])
            
        results, idxs = await enhanced_search_physics(target_data, req.search_query, top_k=5)
        context_text = "\n".join(results) if results else "لا توجد نصوص مطابقة من الكتاب."
        
        # استخراج المراجع الخاصة بالبحث الدلالي
        _, metas = extract_all_texts_and_metas_physics(target_data)
        if results:
            for i in idxs:
                if i < len(metas):
                    ref = f"{metas[i].get('lesson', 'درس')}"
                    if ref not in refs: refs.append(ref)

    # 3. إعداد الـ System Prompt بشكل مباشر
    system_prompt = f"""أنت الآن في وضع مدرس محترف داخل الصف لمادة {SUBJECT}.
تتعامل مع الطالب وكأنك تشرح له أثناء الحصة الدراسية.

📌 آلية التفكير:
- اقرأ السؤال جيداً.
- افهم المقصود الحقيقي منه.
- حدد المفهوم الأساسي وراء السؤال.
- ابدأ بشرح الفكرة من الداخل (التعريف، الفكرة الجوهرية,من الدرس).
- اشرح بالاعتماد على النص من ناحية الامثلة وطريقة الشرح .
- ثم وسّع الشرح من الخارج (السياق العام، لماذا نستخدمه، أين يطبق، علاقته بالمفاهيم الأخرى).

📌 ذكاء المحادثة:
- إذا كان السؤال مرتبطاً بسؤال سابق (مثل: وضح أكثر، ما الفرق، أعطني مثال):
  → أكمل من حيث توقفت.
- إذا كان سؤالاً جديداً:
  → ابدأ شرحاً جديداً من الصفر.
- احكم بذكاء على طبيعة السؤال.

📌 أسلوب الشرح:
1) اشرح باللغة العربية الفصحى السهلة.
2) لا تكتب كلمات إنجليزية داخل الشرح.
3) اشرح وكأنك داخل الصف فعلياً.
4) قسم الشرح إلى خطوات مرتبة عند الحاجة.
5) إذا وجدت معادلات، اشرحها بنفس الرموز الموجودة دون تغيير الصيغة.
6) لا تكتفِ بالتعريف، بل وضّح لماذا وكيف.

📌 مهم جداً:
- لا تكن جامداً.
- لا تكرر السؤال فقط.
- الهدف هو الفهم العميق.
- استخدم أمثلة تعليمية مبسطة عند الحاجة.
- اربط بين المفاهيم حتى تتكوّن صورة كاملة عند الطالب.

🎯 هدفك:
أن يفهم الطالب الفكرة بعمق ويستطيع إعادة شرحها بنفسه."""

    try:
        # 4. بناء الرسائل للمودل
        messages_for_ai = [{"role": "system", "content": system_prompt}]
        
        # إرفاق سجل المحادثة إن وجد
        if req.chat_history:
            valid_history = [msg for msg in req.chat_history if msg.get('role') in ['user', 'assistant']]
            messages_for_ai.extend(valid_history[-HISTORY_LAST_N:])
        
        # رسالة الـ User مخصصة فقط للبيانات والسؤال
        messages_for_ai.append({
            "role": "user",
            "content": f"المعلومات المستخرجة من الكتاب:\n{context_text}\n\nرسالة الطالب: {req.content}"
        })
        
        # 🌊 يبثّ حرفاً حرفاً على مسار البثّ، وإلا نداءٌ عادي حرفياً.
        raw_answer = await streaming.complete(
            gemini_client,
            sink=streaming.sink_of(req),
            timeout=50,
            model="gemini-3.1-flash-lite",
            messages=messages_for_ai, max_tokens=4000,
            temperature=0.2,
        )
        clean_answer = format_arabic_math(raw_answer, "عربي")
        answer = clean_answer
    except asyncio.TimeoutError:
        # إذا تأخر الموديل المجاني، نرد بهذه الرسالة فوراً
        answer = "⚠️ عذراً، خوادم الذكاء الاصطناعي مشغولة حالياً بسبب الضغط. حاول مرة ثانية."
            
    except Exception as e:
        answer = f"خطأ في التوليد: {str(e)}"
    
    return {"answer": answer, "references": refs, "session_active": False}


async def handle_arabic_summary(req: AskRequest, gemini_client):
    """وضع التلخيص - العربي"""
    
    book = get_book_data()
    if not book: return {"answer": "❌ المادة غير متوفرة"}
    
    context_text = ""
    refs = []

    # 1. التعديل: إذا الطالب حدد درس معين، نمرر محتوى الدرس بنص واحد مرتب
    if req.lesson_name:
        target_data = extract_lesson_only(book.get("الوحدات", []), req.lesson_name)
        if not target_data: return {"answer": f"❌ لم أجد درس '{req.lesson_name}'"}
        
        lesson_parts = target_data[0]['الدروس'][0].get('الأجزاء', [])
        for part in lesson_parts:
            context_text += f"[{part.get('اسم_الجزء', '')}]\n"
            content = part.get('المحتوى', [])
            if isinstance(content, list):
                for item in content:
                    if isinstance(item, dict):
                        context_text += f"- {item.get('المصطلح', '')}: {item.get('التعريف', '')}\n"
                    else:
                        context_text += f"- {item}\n"
            else:
                context_text += f"{content}\n"
            context_text += "\n"
            
        refs.append(req.lesson_name)
        
    # 2. إذا لم يحدد درس، نستخدم البحث الدلالي
    else:
        if req.unit_name and req.unit_name != "الكل":
            target_data = [u for u in book.get("الوحدات", []) if u.get("اسم_الوحدة") == req.unit_name]
            if not target_data: return {"answer": f"❌ لم أجد الوحدة '{req.unit_name}'"}
        else:
            target_data = book if isinstance(book, list) else book.get("الوحدات", [])
        
        results, idxs = await enhanced_search_physics(target_data, req.search_query, top_k=QA_TOP_K)
        context_text = "\n".join(results) if results else "لا توجد نصوص مطابقة من الكتاب."
        
        _, metas = extract_all_texts_and_metas_physics(target_data)
        if results:
            for i in idxs:
                if i < len(metas):
                    ref = f"{metas[i].get('lesson', 'درس')}"
                    if ref not in refs: refs.append(ref)

    # باقي الكود كما هو في دالتك الأصلية
    system_prompt = system_prompt_strict_summary(SUBJECT, req.summary_level)
    
    try:
        messages_for_ai = [{"role": "system", "content": system_prompt}]
        
        if req.chat_history:
            valid_history = [msg for msg in req.chat_history if msg.get('role') in ['user', 'assistant']]
            messages_for_ai.extend(valid_history[-HISTORY_LAST_N:])
        
        messages_for_ai.append({
            "role": "user",
            "content": f"""
المعلومات المستخرجة من الكتاب:
{context_text}

رسالة/موضوع الطالب: {req.content}

التعليمات:
1. إذا كانت رسالة الطالب ترحيب أو شكر، رد بلطف وتجاهل التلخيص.
2. إذا طلب التلخيص، استخدم فقط المعلومات المستخرجة أعلاه لعمل التلخيص. إذا لم تكن هناك معلومات، أخبره أن الموضوع غير متوفر في المنهج.
"""
        })
        
        # 🌊 يبثّ حرفاً حرفاً على مسار البثّ، وإلا نداءٌ عادي حرفياً.
        raw_answer = await streaming.complete(
            gemini_client,
            sink=streaming.sink_of(req),
            timeout=50,
            model="gemini-3.1-flash-lite",
            messages=messages_for_ai, max_tokens=4000,
            temperature=0.15,
        )
        clean_answer = format_arabic_math(raw_answer, "عربي")
        answer = clean_answer
    except asyncio.TimeoutError:    
        # إذا تأخر الموديل المجاني، نرد بهذه الرسالة فوراً
        answer = "⚠️ عذراً، خوادم الذكاء الاصطناعي مشغولة حالياً بسبب الضغط. حاول مرة ثانية."
            
    except Exception as e:
        answer = f"خطأ: {str(e)}"
    
    return {"answer": answer, "references": refs, "session_active": False}


async def handle_arabic_question(req: AskRequest, gemini_client):
    """وضع السؤال - العربي"""
    
    book = get_book_data()
    if not book: return {"answer": "❌ المادة غير متوفرة"}
    
    # استخراج سجل المحادثة لاستخدامه في البحث الذكي أو التمرير للمودل
    chat_history_from_app = req.chat_history or []
    valid_history = [msg for msg in chat_history_from_app if msg.get('role') in ['user', 'assistant']]
    recent_history = valid_history[-HISTORY_LAST_N:] if valid_history else []

    context_text = ""
    refs = []

    # 1. التعديل: إذا الطالب حدد درس معين، نمرر محتوى الدرس بنص واحد مرتب
    if req.lesson_name:
        target_data = extract_lesson_only(book.get("الوحدات", []), req.lesson_name)
        if not target_data: return {"answer": f"❌ لم أجد درس '{req.lesson_name}'"}
        
        lesson_parts = target_data[0]['الدروس'][0].get('الأجزاء', [])
        for part in lesson_parts:
            context_text += f"[{part.get('اسم_الجزء', '')}]\n"
            content = part.get('المحتوى', [])
            if isinstance(content, list):
                for item in content:
                    if isinstance(item, dict):
                        context_text += f"- {item.get('المصطلح', '')}: {item.get('التعريف', '')}\n"
                    else:
                        context_text += f"- {item}\n"
            else:
                context_text += f"{content}\n"
            context_text += "\n"
            
        refs.append(req.lesson_name)
        
    # 2. إذا لم يحدد درس، نستخدم البحث الذكي مع السياق
    else:
        if req.unit_name and req.unit_name != "الكل":
            target_data = [u for u in book.get("الوحدات", []) if u.get("اسم_الوحدة") == req.unit_name]
            if not target_data: return {"answer": f"❌ لم أجد الوحدة '{req.unit_name}'"}
        else:
            target_data = book if isinstance(book, list) else book.get("الوحدات", [])
        
        results, idxs = await enhanced_search_with_context(
            target_data, 
            req.content, 
            recent_history, 
            top_k=5
        )
        
        context_text = "\n".join(results) if results else "لا توجد إجابة في الكتاب لهذا السؤال."
        
        _, metas = extract_all_texts_and_metas_physics(target_data)
        if results:
            for i in idxs:
                if i < len(metas):
                    ref_str = f"{metas[i].get('lesson', 'درس')}"
                    if ref_str not in refs: refs.append(ref_str)

    # باقي الكود كما هو في دالتك الأصلية
    system_prompt = system_prompt_strict_qa(SUBJECT)
    
    try:
        messages_for_ai = [{"role": "system", "content": system_prompt}]
        messages_for_ai.extend(recent_history)
        
        messages_for_ai.append({
            "role": "user",
            "content": f"""
المعلومات المستخرجة من المنهج:
{context_text}

سؤال/رسالة الطالب: {req.content}

التعليمات:
1. إذا كان الطالب يقول "مرحبا"، "كيفك"، "شكراً"، رد بلطف وبشكل طبيعي كمعلم.
2. إذا كان سؤالاً في المادة، استخدم المعلومات المستخرجة للإجابة. وإن كان الموضوع موجوداً في المعلومات المستخرجة لكن بصياغة مختلفة أو موزّعاً على أكثر من موضع، فاجمعه وأجب منه — هذا استخدامٌ للنص لا تخمين. أما إذا كان الموضوع نفسه غير موجود في المعلومات المستخرجة، فلا تخمن! قل: "عذراً، هذه المعلومة غير متوفرة في المنهج المرفق".
"""
        })
        
        # 🌊 يبثّ حرفاً حرفاً على مسار البثّ، وإلا نداءٌ عادي حرفياً.
        raw_answer = await streaming.complete(
            gemini_client,
            sink=streaming.sink_of(req),
            timeout=50,
            model="gemini-3.1-flash-lite",
            messages=messages_for_ai, max_tokens=4000,
            temperature=0.1,
        )
        clean_answer = format_arabic_math(raw_answer, "عربي")
        answer = clean_answer
    except asyncio.TimeoutError:    
        # إذا تأخر الموديل المجاني، نرد بهذه الرسالة فوراً
        answer = "⚠️ عذراً، خوادم الذكاء الاصطناعي مشغولة حالياً بسبب الضغط. حاول مرة ثانية."
            
    except Exception as e:
        answer = f"حدث خطأ: {str(e)}"
    
    return {"answer": answer, "references": refs, "session_active": False}







async def handle_arabic_exams(req: AskRequest, sessions: Dict, gemini_client):
    """وضع الوزاري - العربي (تجميع الأسئلة من كل الاختبارات في الملف)"""
    content = req.content.strip()
    _arabic_session_timestamps[req.user_id] = time.time()
    cleanup_subject_sessions(sessions, _arabic_session_timestamps)

    parts = content.split("|")
    if len(parts) < 3:
        return {"answer": "❌ خطأ في صيغة الطلب. الرجاء المحاولة من التطبيق.", "session_active": False}

    year = parts[0].strip()
    section_name = parts[1].strip()
    q_type = parts[2].strip()
    
    # استخراج العدد (إذا ما حط رقم، نعتبره 1 للقطع، و 5 للأسئلة العامة)
    count = 1
    if len(parts) > 3 and parts[3].isdigit():
        count = int(parts[3])
    else:
        count = 1 if q_type == "قطعة" else 5

    # 🔴 المسار اللي طلبته
    file_path = os.path.join(BASE_SUBJECTS_DIR, SUBJECT, "exams", f"{year}.json")
    backup_path = os.path.join("data", "subjects", SUBJECT, "exams", f"{year}.json")
    
    # 💡 مسار إضافي: لو حطيت كل السنين في ملف واحد وسميته (all.json) أو (arabic.json)
    all_file = os.path.join("subjects", SUBJECT, "exams", "all.json")

    exams_data = None
    if os.path.exists(file_path):
        exams_data = load_json_safe(file_path)
    elif os.path.exists(backup_path):
        exams_data = load_json_safe(backup_path)
    elif os.path.exists(all_file):
        exams_data = load_json_safe(all_file)
    else:
        return {"answer": f"❌ الملف غير موجود!\nالمسار: {file_path}", "session_active": False}

    if not exams_data:
        return {"answer": "❌ الملف فارغ أو به خطأ في صيغة الجيسون.", "session_active": False}

    if isinstance(exams_data, dict):
        exams_data = [exams_data]

    # 🔴 التعديل الجوهري: سلال فارغة لتجميع كل القطع والأسئلة من كل الاختبارات
    target_pieces = []
    target_general_qs = []

    for exam in exams_data:
        # إذا كانت السنة مطابقة، أو إذا اختار الطالب "الكل"
        if year == "الكل" or year in str(exam.get("سنة_الاختبار", "")):
            for sec in exam.get("الأقسام", []):
                # إذا تطابق اسم القسم (مثل: أولاً: القراءة)
                if sec.get("اسم_القسم", "").strip() == section_name:
                    # نضيف كل القطع والأسئلة الموجودة في هذا الاختبار للسلة الكبيرة
                    target_pieces.extend(sec.get("القطع", []))
                    target_general_qs.extend(sec.get("أسئلة_عامة", []))

    # إذا كانت السلال فارغة تماماً
    if not target_pieces and not target_general_qs:
        return {"answer": f"❌ لم أجد قسم '{section_name}' لسنة {year}.", "session_active": False}

    text = f"✅ **تدريب {section_name} - {year}**\n\n"

    # 1. إذا اختار الطالب "قطعة"
    if q_type == "قطعة":
        if not target_pieces:
            return {"answer": "❌ لا توجد قطع ونصوص في هذا القسم، جرب اختيار 'أسئلة عامة'.", "session_active": False}

        # السحب العشوائي من السلة الكبيرة اللي جمعناها (حسب العدد المطلوب)
        num_to_sample = min(count, len(target_pieces))
        selected_pieces = random.sample(target_pieces, num_to_sample)

        for p in selected_pieces:
            text += f"📑 **{p.get('اسم_القطعة', 'قطعة/نص')}**\n"
            if p.get('النص_المرجعي'):
                text += f"📜 {p.get('النص_المرجعي', '')}\n\n"
            text += "📝 **الأسئلة وإجاباتها:**\n"
            for idx, q in enumerate(p.get("الأسئلة", []), 1):
                text += f"**س{idx}:** {q.get('السؤال')}\n"
                text += f"💡 **الحل:** {q.get('الإجابة_النموذجية')}\n\n"
            text += "---\n"

    # 2. إذا اختار الطالب "أسئلة عامة"
    elif q_type == "أسئلة عامة":
        if not target_general_qs:
            return {"answer": "❌ لا توجد أسئلة عامة في هذا القسم، جرب اختيار 'قطعة'.", "session_active": False}
        
        # السحب العشوائي من السلة الكبيرة للأسئلة
        selected_qs = random.sample(target_general_qs, min(count, len(target_general_qs)))

        text += f"📝 **أسئلة عامة (عدد {len(selected_qs)}):**\n\n"
        for idx, q in enumerate(selected_qs, 1):
            text += f"**س{idx}:** {q.get('السؤال')}\n"
            text += f"💡 **الحل:** {q.get('الإجابة_النموذجية')}\n\n"

    return {"answer": text, "session_active": False}
async def handle_arabic_request(req: AskRequest, gemini_client):
    """معالج الطلب الرئيسي للعربي"""
    mode = req.mode.strip()
    if mode == "شرح": return await handle_arabic_explain(req, gemini_client)
    elif mode == "تلخيص": return await handle_arabic_summary(req, gemini_client)
    elif mode == "سؤال": return await handle_arabic_question(req, gemini_client)
    elif mode == "وزاري": return await handle_arabic_exams(req, sessions_arabic, gemini_client)
    
    return {"answer": "وضع غير معروف"}