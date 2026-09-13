# subjects/english.py
"""
قسم اللغة الإنجليزية - مخصص لدعم النصوص الإنجليزية والعربية
يعالج المصطلحات (Vocabulary) والقواعد (Grammar) بشكل سليم.
"""

from .common import (
    subject_book_path, load_json_safe,
    system_prompt_strict_explain, system_prompt_strict_summary, system_prompt_strict_qa,
    collect_exam_questions_by_years, parse_exams_input, faiss_search, format_arabic_math
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

SUBJECT = "انجليزي"
sessions_english = {}

_english_session_timestamps = {}



# نظام التخزين المؤقت للإنجليزي لسرعة البرق
# نظام التخزين المؤقت للإنجليزي لسرعة البرق
_english_book_cache = None
_english_exams_cache = None
_english_exams_mtime = 0  # 👈 تتبع وقت التعديل بدلاً من عدد الملفات

def get_english_data():
    global _english_book_cache
    if _english_book_cache is not None: return _english_book_cache
    # 📖 هذا المعالج يتوقّع **قاموس وحدات ودروس** — نطلبه صراحةً
    #    كي لا يتغيّر تحته الشكل يوم يُضاف للمادة ملف صفحات.
    book = load_json_safe(subject_book_path(SUBJECT, prefer='lessons_mode'))
    if not book: return []
    _english_book_cache = book.get("الوحدات", []) if isinstance(book, dict) else book
    return _english_book_cache

def get_english_exams():
    global _english_exams_cache, _english_exams_mtime
    
    exams_dir = os.path.join(BASE_SUBJECTS_DIR, SUBJECT, "exams")
    if not os.path.exists(exams_dir):
        return []
        
    current_files = [f for f in os.listdir(exams_dir) if f.endswith(".json")]
    
    # 🚀 معرفة آخر وقت تم فيه تعديل أي ملف في المجلد
    latest_mtime = max([os.path.getmtime(os.path.join(exams_dir, f)) for f in current_files]) if current_files else 0
    
    # إذا الكاش موجود ولم تقم بتعديل أي ملف، نرجع الكاش فوراً
    if _english_exams_cache is not None and latest_mtime == _english_exams_mtime:
        return _english_exams_cache
        
    # 🔄 إذا قمت بتعديل الملف أو إضافة ملف جديد، يتحدث الكاش تلقائياً
    all_data = []
    for filename in current_files:
        data = load_json_safe(os.path.join(exams_dir, filename))
        if isinstance(data, list): all_data.extend(data)
        elif isinstance(data, dict): all_data.append(data)
        
    _english_exams_cache = all_data
    _english_exams_mtime = latest_mtime # حفظ وقت آخر تعديل
    return all_data

# ==========================================
# 🛠️ دوال مساعدة خاصة بالإنجليزي (تدعم الإنجليزية!)
# ==========================================


import time

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
        
        
        

def system_prompt_English_explain(subject: str):
    return (
       f"أنت الآن في وضع مدرس داخل الصف لمادة {subject}. "
        "تتعامل مع الطالب وكأنك تشرح له أثناء الحصة الدراسية.\n\n"
         "📌 ذكاء المحادثة:\n"
        "- قد يكون لديك سياق محادثة سابقة مع الطالب.\n"
        "- إذا كان سؤاله الجديد مرتبطاً بالمحادثة السابقة (مثل: 'وضح أكثر'، 'ما الفرق؟'، 'أعطني مثال'):\n"
        "  → استخدم السياق وأجب بناءً على ما شرحته سابقاً.\n"
        "- إذا كان سؤالاً جديداً تماماً عن موضوع مختلف:\n"
        "  → تجاهل السياق السابق وابدأ شرحاً جديداً من الصفر.\n"
        "- احكم أنت بذكاء على طبيعة السؤال.\n\n"
        "القواعد الأساسية (مهم الالتزام بها بدقة):\n"
          "1) اشرح الكلام الانجليزي والقواعد باللغة العربية  .\n"
        "5) جميع الإجابات يجب أن تكون  شرحًا مبسطًا لمعنى موجود صراحة في الكتاب.\n\n"
        "أسلوب الشرح:\n"
        "- الأسلوب تعليمي، مرتب، وكأنك داخل الصف.\n"
        "- بإمكانك اضافة معلومات خارجية تدعم الشرح .\n"
        "- يمكن تقسيم الشرح إلى نقاط أو خطوات عند الحاجة.\n\n"

    )



def extract_english_keywords(query: str):
    """استخراج الكلمات للبحث: يدعم الحروف الإنجليزية والعربية"""
    if not query: return set()
    # نحافظ على الكلمات الإنجليزية والعربية والأرقام
    words = re.findall(r'[a-zA-Z\u0600-\u06FF0-9]{2,}', query)
    return set(w.lower() for w in words)

def filter_and_rank_exams_english(questions: list, query: str):
    """فلترة الأسئلة الوزارية وتدعم البحث بكلمات إنجليزية مثل grammar و vocabulary"""
    user_keywords = extract_english_keywords(query)
    if not user_keywords: return []

    scored_questions = []
    for q in questions:
        q_text = q.get("النص", "").lower()
        score = sum(1 for kw in user_keywords if kw in q_text)
        
        if score > 0:
            scored_questions.append((score, q))

    scored_questions.sort(key=lambda x: x[0], reverse=True)
    return [q for score, q in scored_questions]

def extract_lesson_only(units_list, lesson_name):
    """استخراج درس واحد فقط من الوحدات (تطابق ذكي يتجاهل المسافات وحالة الأحرف)"""
    if not lesson_name: return []
    target_name = str(lesson_name).strip().lower()
    
    for unit in units_list:
        if isinstance(unit, dict):
            for lesson in unit.get("الدروس", []):
                if isinstance(lesson, dict):
                    current_name = str(lesson.get("اسم_الدرس", "")).strip().lower()
                    if current_name == target_name:
                        return [{"اسم_الوحدة": unit.get("اسم_الوحدة"), "الدروس": [lesson]}]
    return []

def extract_english_texts_flattened(units_list):
    """
    تحويل هيكلة الإنجليزي إلى نصوص مسطحة
    (تدعم الصيغة القديمة والصيغة الجديدة بمرونة تامة)
    """
    texts = []
    metas = []
    
    for unit in units_list:
        if not isinstance(unit, dict): continue
        unit_name = unit.get("اسم_الوحدة", "")
        
        for lesson in unit.get("الدروس", []):
            if not isinstance(lesson, dict): continue
            lesson_name = lesson.get("اسم_الدرس", "")
            meta = {"unit": unit_name, "lesson": lesson_name}
            
            lesson_parts = []
            lesson_parts.append(f"عنوان الدرس: {lesson_name}")
            
            # 1. استخراج المحتوى العام
            content = lesson.get("المحتوى", "")
            if content:
                lesson_parts.append(f"المحتوى العام: {content}")
                
            # 2. استخراج المصطلحات (Vocabulary) - مدعوم في الصيغتين
            terms = lesson.get("المصطلحات", [])
            if terms:
                vocab_str = "المصطلحات والتعريفات:\n"
                for term in terms:
                    if isinstance(term, dict):
                        word = term.get("الكلمة", "")
                        definition = term.get("التعريف", "")
                        translation = term.get("الترجمة", "")
                        term_details = [x for x in [word, definition, translation] if x]
                        vocab_str += " - " + " | ".join(term_details) + "\n"
                lesson_parts.append(vocab_str.strip())
            
            # ==========================================
            # 3. 🌟 دعم الصيغة الجديدة (Grammar Rules Array) 🌟
            # ==========================================
            grammar_rules = lesson.get("القواعد", [])
            if grammar_rules:
                rule_str = "القواعد النحوية وطريقة الحل:\n"
                for rule in grammar_rules:
                    if isinstance(rule, dict):
                        r_name = rule.get("اسم_القاعدة", "")
                        r_form = rule.get("الصيغة", "")
                        rule_str += f"\n🔸 القاعدة: {r_name}\n📌 الصيغة/المفتاح: {r_form}\n"
                        
                        examples = rule.get("أمثلة", [])
                        if examples:
                            for ex in examples:
                                if isinstance(ex, dict):
                                    pos = ex.get("الفعل_الإيجابي", "")
                                    neg = ex.get("الفعل_السلبي", "")
                                    exp = ex.get("الشرح", "")
                                    if pos: rule_str += f"  • مثال 1: {pos}\n"
                                    if neg: rule_str += f"  • مثال 2: {neg}\n"
                                    if exp: rule_str += f"  💡 توضيح: {exp}\n"
                lesson_parts.append(rule_str.strip())
                
            # ==========================================
            # 4. 🌟 دعم الصيغة القديمة (للحفاظ على الدروس السابقة) 🌟
            # ==========================================
            explanation = lesson.get("الشرح_والاستخدام", "")
            if explanation:
                lesson_parts.append(f"الشرح والاستخدام: {explanation}")
                
            rule = lesson.get("القاعدة_والتكوين", "")
            if rule:
                lesson_parts.append(f"القاعدة والتكوين: {rule}")
                
            keywords = lesson.get("الكلمات_الدالة", "")
            if keywords:
                lesson_parts.append(f"الكلمات الدالة: {keywords}")
                
            examples_old = lesson.get("الامثلة", [])
            if examples_old:
                ex_str = "الأمثلة:\n"
                for ex in examples_old:
                    if isinstance(ex, dict):
                        en = ex.get("انجليزي", "")
                        ar = ex.get("عربي", "")
                        ex_str += f"• {en} ({ar})\n"
                lesson_parts.append(ex_str.strip())
                
            exams = lesson.get("صيغة_الاسئلة_في_الامتحان", [])
            if exams:
                exam_str = "صيغة أسئلة الامتحان وطريقة الحل:\n"
                for exm in exams:
                    if isinstance(exm, dict):
                        q = exm.get("السؤال", "")
                        a = exm.get("الاجابة_الصحيحة", "")
                        r = exm.get("السبب", "")
                        exam_str += f"س: {q}\nج: {a}\nالسبب: {r}\n"
                lesson_parts.append(exam_str.strip())

            # ==========================================
            # دمج كل أجزاء الدرس في نص واحد
            # ==========================================
            if len(lesson_parts) > 1:
                full_lesson_text = "\n\n".join(lesson_parts)
                texts.append(full_lesson_text)
                metas.append(meta)

    return texts, metas

async def enhanced_search_english(book_data, query, top_k=5, chat_history=None):
    texts, metas = extract_english_texts_flattened(book_data)
    if not texts: return [], []
    combined_query = query
    if chat_history:
        last_ai = next((m.get('content', '') for m in reversed(chat_history) if m.get('role') == 'assistant'), "")
        if len(query.split()) < 5 and last_ai:
            combined_query = last_ai[:100] + " " + query
            
    # أضفنا await هنا
    sem_results, idxs = await faiss_search(texts, combined_query, top_k=top_k)
    keywords = extract_english_keywords(query)
    direct_hits = []
    direct_idxs = []
    for i, txt in enumerate(texts):
        txt_lower = txt.lower()
        if any(k in txt_lower for k in keywords):
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

# ==========================================
# 1. وضع الشرح
# ==========================================
# ==========================================
# 1. وضع الشرح
# ==========================================
async def handle_english_explain(req: AskRequest, gemini_client):
    units_list = get_english_data() # جلب من الذاكرة فوراً
    if not units_list: return {"answer": "❌ عذراً، بيانات المادة غير جاهزة حالياً."}
    
    context_text = ""
    refs = []

    # 1. التعديل: إذا الطالب حدد درس معين، نمرر الدرس كامل باستخدام دالة التجميع
    if req.lesson_name:
        target_data = extract_lesson_only(units_list, req.lesson_name)
        if not target_data: return {"answer": f"❌ لم أجد درس '{req.lesson_name}'"}
        
        # استخراج الدرس كامل بنص واحد (مصطلحات، قواعد، أمثلة، الخ)
        extracted_texts, _ = extract_english_texts_flattened(target_data)
        context_text = "\n\n".join(extracted_texts) if extracted_texts else "محتوى الدرس فارغ."
        refs.append(req.lesson_name)
        
    # 2. إذا لم يحدد درس، نستخدم البحث الذكي
    else:
        if req.unit_name and req.unit_name != "الكل":
            target_data = [u for u in units_list if u.get("اسم_الوحدة") == req.unit_name]
            if not target_data: return {"answer": f"❌ لم أجد الوحدة '{req.unit_name}'"}
        else:
            target_data = units_list
            
        results, idxs = await enhanced_search_english(target_data, req.content, top_k=5)
        context_text = "\n".join(results) if results else "لا توجد نصوص مطابقة من الكتاب."
        
        # استخراج المراجع للبحث
        _, metas = extract_english_texts_flattened(target_data)
        if results:
            for i in idxs:
                if i < len(metas):
                    ref = f"{metas[i].get('lesson', 'درس')}"
                    if ref not in refs: refs.append(ref)
    
    system_prompt = system_prompt_English_explain(SUBJECT)
    
    try:
        messages_for_ai = [{"role": "system", "content": system_prompt}]
        
        if req.chat_history:
            valid_history = [msg for msg in req.chat_history if msg.get('role') in ['user', 'assistant']]
            messages_for_ai.extend(valid_history[-HISTORY_LAST_N:])
        
        messages_for_ai.append({
            "role": "user",
            "content": f"""المعلومات المستخرجة من الكتاب:
{context_text}

رسالة الطالب: {req.content}

تعليمات:
- إذا كانت الرسالة تحية (Hi, Hello)، رد بود واسأله كيف تساعده.
- إذا طلب شرحاً، اعتمد بنسبة 100% على (المعلومات المستخرجة) واشرحها بالعربية بأسلوب جميل.
- إذا كانت المعلومات تقول 'لا توجد نصوص'، اعتذر بلطف وأخبره أن هذا غير متوفر بالمنهج."""
        })
        
        # 🌊 يبثّ حرفاً حرفاً على مسار البثّ، وإلا نداءٌ عادي حرفياً.
        _raw = await streaming.complete(
            gemini_client,
            sink=streaming.sink_of(req),
            timeout=50,
            model="gemini-3.1-flash-lite",
            messages=messages_for_ai, max_tokens=4000,
            temperature=0.2,
        )
        answer = format_arabic_math(_raw, "انجليزي")
    except asyncio.TimeoutError:
        # إذا تأخر الموديل المجاني، نرد بهذه الرسالة فوراً
        answer = "⚠️ عذراً، خوادم الذكاء الاصطناعي مشغولة حالياً بسبب الضغط. حاول مرة ثانية."
            
    except Exception as e:
        answer = f"خطأ في التوليد: {str(e)}"
    
    return {"answer": answer, "references": refs, "session_active": False}

# ==========================================
# 2. وضع التلخيص
# ==========================================
# ==========================================
# 2. وضع التلخيص
# ==========================================
async def handle_english_summary(req: AskRequest, gemini_client):
    units_list = get_english_data() # جلب من الذاكرة فوراً
    if not units_list: return {"answer": "❌ عذراً، بيانات المادة غير جاهزة حالياً."}
    
    context_text = ""
    refs = []

    # 1. التعديل: تمرير الدرس كاملاً للتلخيص
    if req.lesson_name:
        target_data = extract_lesson_only(units_list, req.lesson_name)
        if not target_data: return {"answer": f"❌ لم أجد درس '{req.lesson_name}'"}
        
        extracted_texts, _ = extract_english_texts_flattened(target_data)
        context_text = "\n\n".join(extracted_texts) if extracted_texts else "محتوى الدرس فارغ."
        refs.append(req.lesson_name)
        
    # 2. البحث العادي
    else:
        if req.unit_name and req.unit_name != "الكل":
            target_data = [u for u in units_list if u.get("اسم_الوحدة") == req.unit_name]
            if not target_data: return {"answer": f"❌ لم أجد الوحدة '{req.unit_name}'"}
        else:
            target_data = units_list
            
        results, idxs = await enhanced_search_english(target_data, req.content, top_k=6)
        context_text = "\n".join(results) if results else "لا توجد نصوص مطابقة من الكتاب."
        
        _, metas = extract_english_texts_flattened(target_data)
        if results:
            for i in idxs:
                if i < len(metas):
                    ref = f"{metas[i].get('lesson', 'درس')}"
                    if ref not in refs: refs.append(ref)
    
    system_prompt = f"""أنت معلم إنجليزي متخصص في التلخيص والتبسيط.
لخص المحتوى بالعربية بناءً على المستوى المطلوب ({req.summary_level}/5)."""
    
    try:
        messages_for_ai = [{"role": "system", "content": system_prompt}]
        messages_for_ai.append({
            "role": "user",
            "content": f"المعلومات المستخرجة:\n{context_text}\n\nما يريده الطالب: تلخيص '{req.content}'\n(اكتب التلخيص بالعربية)"
        })
        
        # 🌊 يبثّ حرفاً حرفاً على مسار البثّ، وإلا نداءٌ عادي حرفياً.
        _raw = await streaming.complete(
            gemini_client,
            sink=streaming.sink_of(req),
            timeout=50,
            model="gemini-3.1-flash-lite",
            messages=messages_for_ai, max_tokens=4000,
            temperature=0.15,
        )
        answer = format_arabic_math(_raw, "انجليزي")
    except asyncio.TimeoutError:
        # إذا تأخر الموديل المجاني، نرد بهذه الرسالة فوراً
        answer = "⚠️ عذراً، خوادم الذكاء الاصطناعي مشغولة حالياً بسبب الضغط. حاول مرة ثانية."
            
    except Exception as e:
        answer = f"خطأ: {str(e)}"
    
    return {"answer": answer, "references": refs, "session_active": False}

# ==========================================
# 3. وضع السؤال
# ==========================================
# ==========================================
# 3. وضع السؤال
# ==========================================
async def handle_english_question(req: AskRequest, gemini_client):
    units_list = get_english_data() # جلب من الذاكرة فوراً
    if not units_list: return {"answer": "❌ عذراً، بيانات المادة غير جاهزة حالياً."}
    
    chat_history_from_app = req.chat_history or []
    recent_history = [m for m in chat_history_from_app if m.get('role') in ['user', 'assistant']][-HISTORY_LAST_N:]

    context_text = ""
    refs = []

    # 1. التعديل: تمرير الدرس كاملاً إذا كان الطالب يسأل من داخل الدرس
    if req.lesson_name:
        target_data = extract_lesson_only(units_list, req.lesson_name)
        if not target_data: return {"answer": f"❌ لم أجد درس '{req.lesson_name}'"}
        
        extracted_texts, _ = extract_english_texts_flattened(target_data)
        context_text = "\n\n".join(extracted_texts) if extracted_texts else "محتوى الدرس فارغ."
        refs.append(req.lesson_name)
        
    # 2. البحث الذكي للأسئلة العامة
    else:
        if req.unit_name and req.unit_name != "الكل":
            target_data = [u for u in units_list if u.get("اسم_الوحدة") == req.unit_name]
            if not target_data: return {"answer": f"❌ لم أجد الوحدة '{req.unit_name}'"}
        else:
            target_data = units_list
            
        results, idxs = await enhanced_search_english(target_data, req.content, top_k=4, chat_history=recent_history)
        context_text = "\n".join(results) if results else "لا توجد إجابة في الكتاب لهذا السؤال."
        
        _, metas = extract_english_texts_flattened(target_data)
        if results:
            for i in idxs:
                if i < len(metas):
                    ref = f"{metas[i].get('lesson', 'درس')}"
                    if ref not in refs: refs.append(ref)
    
    system_prompt = """أنت معلم إنجليزي تجيب على الأسئلة بوضوح واختصار. اشرح الإجابات بالعربية مع الحفاظ على الكلمات الإنجليزية كما هي عند الحاجة."""
    
    try:
        messages_for_ai = [{"role": "system", "content": system_prompt}]
        messages_for_ai.extend(recent_history)
        messages_for_ai.append({
            "role": "user",
            "content": f"المعلومات المستخرجة:\n{context_text}\n\nسؤال الطالب: {req.content}\n\n(أجب مباشرة على قدر السؤال)"
        })
        
        # 🌊 يبثّ حرفاً حرفاً على مسار البثّ، وإلا نداءٌ عادي حرفياً.
        _raw = await streaming.complete(
            gemini_client,
            sink=streaming.sink_of(req),
            timeout=50,
            model="gemini-3.1-flash-lite",
            messages=messages_for_ai, max_tokens=4000,
            temperature=0.1,
        )
        answer = format_arabic_math(_raw, "انجليزي")
    
    except asyncio.TimeoutError:
        # إذا تأخر الموديل المجاني، نرد بهذه الرسالة فوراً
        answer = "⚠️ عذراً، خوادم الذكاء الاصطناعي مشغولة حالياً بسبب الضغط. حاول مرة ثانية."
            
    except Exception as e:
        answer = f"حدث خطأ: {str(e)}"
    
    return {"answer": answer, "references": refs, "session_active": False}
# ==========================================
# 4. وضع الوزاري
# ==========================================
async def handle_english_exams(req: AskRequest, sessions: Dict, gemini_client):
    """وضع الوزاري - إنجليزي (مطابقة صارمة ومثالية)"""
    content = req.content.strip()
    _english_session_timestamps[req.user_id] = time.time()
    cleanup_subject_sessions(sessions, _english_session_timestamps)

    parts = content.split("|")
    if len(parts) < 3:
        return {"answer": "❌ خطأ في صيغة الطلب. يرجى المحاولة من التطبيق.", "session_active": False}

    year = parts[0].strip()
    question_type = parts[1].strip() 
    
    count = 5
    if len(parts) > 2 and parts[2].isdigit():
        count = int(parts[2])

    all_exams_data = get_english_exams() 
    
    if not all_exams_data:
        return {"answer": "⚠️ لا توجد اختبارات متاحة حالياً في المكتبة.", "session_active": False}
    
    target_passages = [] 
    target_general_qs = [] 
    
    # 💡 التحديث السحري: تنظيف النص من كل المسافات للمطابقة بقوة 100%
    clean_req_type = question_type.lower().strip().replace(" ", "").rstrip(".")

    # تجميع الأسئلة
    for exam in all_exams_data:
        exam_year_str = str(exam.get("سنة_الاختبار", ""))
        
        # مطابقة السنة بمرونة
        if year == "الكل" or year in exam_year_str or exam_year_str in year:
            for sec in exam.get("أقسام_الأسئلة", []):
                actual_type = sec.get("نوع_السؤال", "").lower()
                clean_actual = actual_type.lower().strip().replace(" ", "").rstrip(".")
                
                # 🔴 التطابق القوي: هل النص المطلوب يطابق النص في الـ JSON؟
                if clean_req_type == clean_actual or clean_req_type in clean_actual:
                    # إذا كان يوجد نص مرجعي نعتبرها "قطعة"، وإلا نعتبرها "أسئلة عامة"
                    if sec.get("النص_المرجعي"):
                        target_passages.append(sec)
                    else:
                        target_general_qs.extend(sec.get("الأسئلة", []))

    if not target_passages and not target_general_qs:
        return {"answer": f"❌ لم أجد أسئلة من نوع '{question_type}' لسنة '{year}'.", "session_active": False}

    text = f"✅ **Practice: {question_type} - {year if year != 'الكل' else 'All Years'}**\n\n"

    # طريقة العرض
    if target_passages:
        selected_passages = random.sample(target_passages, min(count, len(target_passages)))
        for p in selected_passages:
            text += f"📜 **Passage:**\n{p.get('النص_المرجعي', '')}\n\n"
            text += "📝 **Questions:**\n"
            for idx, q in enumerate(p.get("الأسئلة", []), 1):
                text += f"**Q{idx}:** {q.get('السؤال')}\n"
                text += f"💡 **Answer:** {q.get('الإجابة_النموذجية')}\n\n"
            text += "---\n"
    
    elif target_general_qs:
        selected_qs = random.sample(target_general_qs, min(count, len(target_general_qs)))
        text += f"📝 **Questions (Count: {len(selected_qs)}):**\n\n"
        for idx, q in enumerate(selected_qs, 1):
            text += f"**Q{idx}:** {q.get('السؤال')}\n"
            text += f"💡 **Answer:** {q.get('الإجابة_النموذجية')}\n\n"

    return {"answer": text, "session_active": False}

async def handle_english_request(req: AskRequest, gemini_client):
    """الموجه الرئيسي للغة الإنجليزية"""
    mode = req.mode.strip()
    if mode == "شرح": return await handle_english_explain(req, gemini_client)
    elif mode == "تلخيص": return await handle_english_summary(req, gemini_client)
    elif mode == "سؤال": return await handle_english_question(req, gemini_client)
    elif mode == "وزاري": return await handle_english_exams(req, sessions_english, gemini_client)
    
    return {"answer": "وضع غير معروف"}