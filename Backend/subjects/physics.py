# subjects/physics.py
"""
قسم الفيزياء - يعتمد على ذاكرة التطبيق (الجوال) فقط - Stateless
مع دعم المحادثة الطبيعية (ترحيب) والدقة الصارمة في المنهج
"""

from .common import (
    subject_book_path, load_json_safe, extract_all_texts_and_metas_physics,
    enhanced_search_physics, system_prompt_strict_explain,
    system_prompt_strict_summary, system_prompt_strict_qa,
    filter_and_rank_exams, collect_exam_questions_by_years,
    parse_exams_input, extract_keywords, faiss_search,format_arabic_math   # 👈 أضفنا هذي
)
from config import BASE_SUBJECTS_DIR, QA_TOP_K, EXAMS_BATCH_SIZE
from models import AskRequest
from typing import Dict, List, Optional
import json
import re
import asyncio
import time

SUBJECT = "فيزياء"
sessions_physics = {}


_physics_session_timestamps = {}

_book_cache = None

def get_book_data():
    global _book_cache
    if _book_cache is not None:
        return _book_cache
    book = load_json_safe(subject_book_path(SUBJECT))
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
    """بحث ذكي مع دعم السياق من المحادثة (المرسلة من الجوال)"""
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

async def handle_physics_explain(req: AskRequest, openai_client):
    """وضع الشرح - الفيزياء"""
    
    book = get_book_data()
    if not book: return {"answer": "❌ المادة غير متوفرة"}
    
    context_text = ""
    refs = []

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
                        # ✅ التعديل الذكي: يقرأ كل المفاتيح (صيغة، استخدام، ملاحظة، مصطلح...)
                        dict_values = [f"{k}: {v}" for k, v in item.items()]
                        context_text += f"- {' | '.join(dict_values)}\n"
                    else:
                        context_text += f"- {item}\n"
            else:
                context_text += f"{content}\n"
            context_text += "\n"
            
        refs.append(req.lesson_name)
        
    else:
        if req.unit_name and req.unit_name != "الكل":
            target_data = [u for u in book.get("الوحدات", []) if u.get("اسم_الوحدة") == req.unit_name]
            if not target_data: return {"answer": f"❌ لم أجد الوحدة '{req.unit_name}'"}
        else:
            target_data = book.get("الوحدات", [])
            
        results, idxs = await enhanced_search_physics(target_data, req.content, top_k=5)
        context_text = "\n".join(results) if results else "لا توجد نصوص مطابقة من الكتاب."
        
        _, metas = extract_all_texts_and_metas_physics(target_data)
        if results:
            for i in idxs:
                if i < len(metas):
                    ref = f"{metas[i].get('lesson', 'درس')}"
                    if ref not in refs: refs.append(ref)

    system_prompt = system_prompt_strict_explain(SUBJECT)
    
    try:
        messages_for_ai = [{"role": "system", "content": system_prompt}]
        if req.chat_history:
            valid_history = [msg for msg in req.chat_history if msg.get('role') in ['user', 'assistant']]
            messages_for_ai.extend(valid_history[-6:])
        
        messages_for_ai.append({
            "role": "user",
            "content": f"""المعلومات المستخرجة من الكتاب:
{context_text}

رسالة الطالب: {req.content}

تعليمات صارمة للرد:
1. ⚠️ تنبيه هام جداً: إذا كانت رسالة الطالب هي "اشرح لي الدرس" أو "اشرح" أو أي طلب شرح عام، **يجب عليك فوراً** البدء في شرح (المعلومات المستخرجة من الكتاب) بالتفصيل، ويُمنع منعاً باتاً الرد برسالة ترحيب!
2. إذا كانت رسالته سؤالاً أو طلباً لشرح فيزيائي، يجب أن تعتمد بنسبة 100% على (المعلومات المستخرجة من الكتاب) فقط.
3. إذا طلب شرحاً فيزيائياً وكانت (المعلومات المستخرجة) تقول 'لا توجد نصوص مطابقة'، اعتذر بلطف وأخبره أن هذا الموضوع غير موجود في المنهج الحالي.
"""
        })
        
        response = await asyncio.wait_for(
            openai_client.chat.completions.create(
            model="gpt-4o-mini",
            messages=messages_for_ai, max_tokens=4000,
            temperature=0.2
        ), timeout=50)  # إضافة مهلة زمنية للتأكد من عدم الانتظار الطويل
        
        raw_answer = response.choices[0].message.content
        clean_answer = format_arabic_math(raw_answer)
        
        # 1. مسح أي كود LaTeX يبدأ بـ \ (مثل \bigl, \bigr, \quad, \frac)
        clean_answer = re.sub(r'\\[a-zA-Z]+', '', clean_answer)
        
        # 2. استبدال الشرطة السفلية بمسافة عشان تطلع (م حث) بدل (م_حث)
        clean_answer = clean_answer.replace('_', ' ')
        
        answer = clean_answer
    
    except asyncio.TimeoutError:
        # إذا تأخر الموديل المجاني، نرد بهذه الرسالة فوراً
        answer = "⚠️ عذراً، خوادم الذكاء الاصطناعي مشغولة حالياً بسبب الضغط. حاول مرة ثانية."
    
    except Exception as e:
        answer = f"خطأ في التوليد: {str(e)}"
    
    return {"answer": answer, "references": refs, "session_active": False}

async def handle_physics_summary(req: AskRequest, openai_client):
    """وضع التلخيص - الفيزياء"""
    book = get_book_data()
    if not book: return {"answer": "❌ المادة غير متوفرة"}
    
    context_text = ""
    refs = []

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
                        # ✅ التعديل الذكي
                        dict_values = [f"{k}: {v}" for k, v in item.items()]
                        context_text += f"- {' | '.join(dict_values)}\n"
                    else:
                        context_text += f"- {item}\n"
            else:
                context_text += f"{content}\n"
            context_text += "\n"
            
        refs.append(req.lesson_name)
        
    else:
        if req.unit_name and req.unit_name != "الكل":
            target_data = [u for u in book.get("الوحدات", []) if u.get("اسم_الوحدة") == req.unit_name]
            if not target_data: return {"answer": f"❌ لم أجد الوحدة '{req.unit_name}'"}
        else:
            target_data = book.get("الوحدات", [])
            
        results, idxs = await enhanced_search_physics(target_data, req.content, top_k=QA_TOP_K)
        context_text = "\n".join(results) if results else "لا توجد نصوص مطابقة من الكتاب."
        
        _, metas = extract_all_texts_and_metas_physics(target_data)
        if results:
            for i in idxs:
                if i < len(metas):
                    ref = f"{metas[i].get('lesson', 'درس')}"
                    if ref not in refs: refs.append(ref)
    
    system_prompt = system_prompt_strict_summary(SUBJECT, req.summary_level)
    
    try:
        messages_for_ai = [{"role": "system", "content": system_prompt}]
        if req.chat_history:
            valid_history = [msg for msg in req.chat_history if msg.get('role') in ['user', 'assistant']]
            messages_for_ai.extend(valid_history[-6:])
        
        messages_for_ai.append({
            "role": "user",
            "content": f"""المعلومات المستخرجة من الكتاب:
{context_text}

رسالة/موضوع الطالب: {req.content}

التعليمات:
1. إذا كانت رسالة الطالب ترحيب أو شكر، رد بلطف وتجاهل التلخيص.
2. إذا طلب التلخيص، استخدم فقط المعلومات المستخرجة أعلاه لعمل التلخيص. إذا لم تكن هناك معلومات، أخبره أن الموضوع غير متوفر في المنهج.
"""
        })
        
        response = await asyncio.wait_for(
            openai_client.chat.completions.create(
            model="gpt-4o-mini",
            messages=messages_for_ai, max_tokens=4000,
            temperature=0.15
        ), timeout=50)  # إضافة مهلة زمنية للتأكد من عدم الانتظار الطويل
        
        raw_answer = response.choices[0].message.content
        clean_answer = format_arabic_math(raw_answer)
        
        # 1. مسح أي كود LaTeX يبدأ بـ \ (مثل \bigl, \bigr, \quad, \frac)
        clean_answer = re.sub(r'\\[a-zA-Z]+', '', clean_answer)
        
        # 2. استبدال الشرطة السفلية بمسافة عشان تطلع (م حث) بدل (م_حث)
        clean_answer = clean_answer.replace('_', ' ')
        
        answer = clean_answer
    except asyncio.TimeoutError:    
        # إذا تأخر الموديل المجاني، نرد بهذه الرسالة فوراً
        answer = "⚠️ عذراً، خوادم الذكاء الاصطناعي مشغولة حالياً بسبب الضغط. حاول مرة ثانية."    
    except Exception as e:
        answer = f"خطأ: {str(e)}"
    
    return {"answer": answer, "references": refs, "session_active": False}


async def handle_physics_question(req: AskRequest, openai_client):
    """وضع السؤال - الفيزياء"""
    book = get_book_data()
    if not book: return {"answer": "❌ المادة غير متوفرة"}
    
    chat_history_from_app = req.chat_history or []
    valid_history = [msg for msg in chat_history_from_app if msg.get('role') in ['user', 'assistant']]
    recent_history = valid_history[-6:] if valid_history else []

    context_text = ""
    refs = []

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
                        # ✅ التعديل الذكي
                        dict_values = [f"{k}: {v}" for k, v in item.items()]
                        context_text += f"- {' | '.join(dict_values)}\n"
                    else:
                        context_text += f"- {item}\n"
            else:
                context_text += f"{content}\n"
            context_text += "\n"
            
        refs.append(req.lesson_name)
        
    else:
        if req.unit_name and req.unit_name != "الكل":
            target_data = [u for u in book.get("الوحدات", []) if u.get("اسم_الوحدة") == req.unit_name]
            if not target_data: return {"answer": f"❌ لم أجد الوحدة '{req.unit_name}'"}
        else:
            target_data = book.get("الوحدات", [])
            
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
    
    system_prompt = system_prompt_strict_qa(SUBJECT)
    
    try:
        messages_for_ai = [{"role": "system", "content": system_prompt}]
        messages_for_ai.extend(recent_history)
        
        messages_for_ai.append({
            "role": "user",
            "content": f"""المعلومات المستخرجة من المنهج:
{context_text}

سؤال/رسالة الطالب: {req.content}

التعليمات:
1. إذا كان الطالب يقول "مرحبا"، "كيفك"، "شكراً"، رد بلطف وبشكل طبيعي كمعلم.
2. إذا كان سؤالاً في المادة، استخدم المعلومات المستخرجة للإجابة. إذا لم تكن الإجابة موجودة في المعلومات المستخرجة، لا تخمن! قل: "عذراً، هذه المعلومة غير متوفرة في المنهج المرفق".
"""
        })
        
        response = await asyncio.wait_for(
            openai_client.chat.completions.create(
            model="gpt-4o-mini",
            messages=messages_for_ai, max_tokens=4000,
            temperature=0.1
        ), timeout=50)  # إضافة مهلة زمنية للتأكد من عدم الانتظار الطويل
        
        raw_answer = response.choices[0].message.content
        clean_answer = format_arabic_math(raw_answer)
        
        # 1. مسح أي كود LaTeX يبدأ بـ \ (مثل \bigl, \bigr, \quad, \frac)
        clean_answer = re.sub(r'\\[a-zA-Z]+', '', clean_answer)
        
        # 2. استبدال الشرطة السفلية بمسافة عشان تطلع (م حث) بدل (م_حث)
        clean_answer = clean_answer.replace('_', ' ')
        
        answer = clean_answer
    except asyncio.TimeoutError:    
        # إذا تأخر الموديل المجاني، نرد بهذه الرسالة فوراً
        answer = "⚠️ عذراً، خوادم الذكاء الاصطناعي مشغولة حالياً بسبب الضغط. حاول مرة ثانية."
        
    except Exception as e:
        answer = f"حدث خطأ: {str(e)}"
    
    return {"answer": answer, "references": refs, "session_active": False}

async def handle_physics_exams(req: AskRequest, sessions: Dict, openai_client):
    """وضع الوزاري - الفيزياء"""
    
    _physics_session_timestamps[req.user_id] = time.time()
    cleanup_subject_sessions(sessions, _physics_session_timestamps)
    user_id = req.user_id
    content = req.content.strip()
    
    if content in ["وقف", "خلاص", "شكرا", "إلغاء"]:
        sessions.pop(user_id, None)
        return {"answer": "✅ تم إنهاء جلسة الأسئلة", "session_active": False}
    
    if content in ["كمل", "متابعة", "استمر"]:
        sess = sessions.get(user_id)
        if sess and sess.get("mode") == "وزاري" and sess.get("pending_exams"):
            pending = sess["pending_exams"]
            batch = pending[:EXAMS_BATCH_SIZE]
            sess["pending_exams"] = pending[EXAMS_BATCH_SIZE:]
            
            text = ""
            for i, q in enumerate(batch, 1):
                text += f"{i}. {q.get('النص', '')} (سنة {q.get('سنة', '')})\n"
            
            if sess["pending_exams"]:
                text += f"\n💡 المتبقي: {len(sess['pending_exams'])} سؤال."
            else:
                text += "\n✅ انتهت جميع الأسئلة."
                sessions.pop(user_id, None)
            
            return {"answer": text, "session_active": bool(sess.get("pending_exams"))}
    
    year_token, rest = parse_exams_input(content)
    if not year_token or not rest: return {"answer": "اكتب الصيغة هكذا:\nمثال: 2019,الموضوع"}
    
    years = [year_token] if year_token != "الكل" else ["الكل"]
    all_questions = collect_exam_questions_by_years(SUBJECT, years)
    if not all_questions: return {"answer": "لا توجد أسئلة لهذه السنة."}
    
    keyword = ",".join(rest).strip()
    matched = filter_and_rank_exams(all_questions, keyword)
    if not matched: return {"answer": f"لم أجد أسئلة تحتوي على '{keyword}'."}
    
    total = len(matched)
    first_batch = matched[:EXAMS_BATCH_SIZE]
    remaining = matched[EXAMS_BATCH_SIZE:]
    
    if remaining:
        sessions[user_id] = {"pending_exams": remaining, "mode": "وزاري", "subject": SUBJECT}
    
    text = f"✅ وجدت {total} سؤالاً يحتوي على '{keyword}':\n\n"
    for i, q in enumerate(first_batch, 1):
        text += f"{i}. {q.get('النص', '')} (سنة {q.get('سنة', '')})\n"
    
    if remaining: text += f"\n💡 تبقى {len(remaining)} سؤالاً. اكتب 'كمل' للمتابعة."
    
    return {"answer": text, "session_active": bool(remaining)}


async def handle_physics_request(req: AskRequest, openai_client):
    """معالج الطلب الرئيسي للفيزياء"""
    mode = req.mode.strip()
    if mode == "شرح": return await handle_physics_explain(req, openai_client)
    elif mode == "تلخيص": return await handle_physics_summary(req, openai_client)
    elif mode == "سؤال": return await handle_physics_question(req, openai_client)
    elif mode == "وزاري": return await handle_physics_exams(req, sessions_physics, openai_client)
    
    return {"answer": "وضع غير معروف"}