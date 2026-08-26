# subjects/biology.py
"""
قسم الأحياء - النسخة الأصلية المصححة
تعمل بنفس المنطق القديم (بحث الصفحات) مع التوافق مع الهيكلة الجديدة
"""

from .common import (
    subject_book_path, load_json_safe, extract_all_texts_and_metas,
    enhanced_qa_search, faiss_search, filter_and_rank_exams,
    collect_exam_questions_by_years, pages_with_headers,
    system_prompt_strict_explain, system_prompt_strict_summary,
    system_prompt_strict_qa, normalize_arabic, extract_keywords,
    parse_exams_input, fetch_pages_by_numbers
)
from config import BASE_SUBJECTS_DIR, QA_TOP_K, EXAMS_BATCH_SIZE, MAX_PAGES_EXPLAIN_SUMMARY
from models import AskRequest
from typing import Dict, Any, List, Optional
import json
import os
import re
import asyncio

SUBJECT = "احياء"
sessions_biology = {}


import time
_biology_session_timestamps = {}


# تخزين الكتاب في الذاكرة لمنع القراءة المتكررة من القرص
_biology_book_cache = None

def get_biology_data():
    """تحميل بيانات الأحياء مرة واحدة في الذاكرة لسرعة استجابة فائقة"""
    global _biology_book_cache
    if _biology_book_cache is not None:
        return _biology_book_cache
    
    book = load_json_safe(subject_book_path(SUBJECT))
    if not book: return []
    
    # تحويل البيانات إلى قائمة موحدة وتخزينها
    _biology_book_cache = book if isinstance(book, list) else book.get("الوحدات", [])
    return _biology_book_cache


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

# =====================
# 1. وضع الشرح (نفس منطقك القديم)
# =====================
async def handle_biology_explain(req: AskRequest, gemini_client):
    
    # 1. تحميل البيانات
    book_data = get_biology_data()
    if not book_data:
        return {"answer": "المادة غير متوفرة"}

    # 2. فلترة الوحدة (إن وجدت) لتقليل نطاق البحث، وإلا نستخدم الكتاب كامل
    if req.unit_name and req.unit_name not in ["الكل", ""]:
        # نبحث عن الوحدة داخل القائمة
        target_data = [u for u in book_data if u.get("اسم_الوحدة") == req.unit_name]
        if not target_data:
            return {"answer": f"لم أجد الوحدة '{req.unit_name}'"}
    else:
        target_data = book_data

    # ==========================
    # أ. الشرح عن طريق أرقام الصفحات (المنطق القديم)
    # ==========================
    if req.input_type == "صفحة":
        # استخراج الأرقام من النص
        numbers = re.findall(r'\d+', req.content)
        if not numbers:
            return {"answer": "صيغة غير صحيحة. الرجاء كتابة أرقام الصفحات."}
        
        page_nums = [int(n) for n in numbers]
        
        # التحقق من الحد الأقصى
        if len(page_nums) > MAX_PAGES_EXPLAIN_SUMMARY:
            return {"answer": f"الحد الأقصى {MAX_PAGES_EXPLAIN_SUMMARY} صفحات."}
        
        # جلب النصوص من الصفحات (استخدام الدالة المشتركة)
        found_pages, missing = fetch_pages_by_numbers(target_data, page_nums)
        
        if not found_pages:
            return {"answer": "الصفحات غير موجودة في النطاق المحدد."}
        
        # تنسيق النص للإرسال للذكاء الاصطناعي
        context_text = pages_with_headers(found_pages)
        system_prompt = system_prompt_strict_explain(SUBJECT)
        
        try:
            messages_for_ai = [{"role": "system", "content": system_prompt}]
            
            # إضافة التاريخ
            if req.chat_history:
                valid_history = [msg for msg in req.chat_history 
                                if msg.get('role') in ['user', 'assistant']]
                messages_for_ai.extend(valid_history[-6:])
            
            # الرسالة الحالية
            messages_for_ai.append({
                "role": "user",
                "content": f"نص الكتاب:\n{context_text}\n\nطلب الطالب: اشرح المحتوى أعلاه."
            })
            
            response = await asyncio.wait_for(
                gemini_client.chat.completions.create(
                model="gemini-3.1-flash-lite",
                messages=messages_for_ai, max_tokens=4000,
                temperature=0.1
            ), timeout=50)  # إضافة مهلة زمنية للتأكد من عدم الانتظار الطويل
                
            answer = response.choices[0].message.content
            
            # إضافة تنبيه عن الصفحات المفقودة إن وجدت
            if missing:
                answer += f"\n\n(ملاحظة: الصفحات {missing} لم يتم العثور عليها)"
        
        
        except asyncio.TimeoutError:
        # إذا تأخر الموديل المجاني، نرد بهذه الرسالة فوراً
             answer = "⚠️ عذراً، خوادم الذكاء الاصطناعي مشغولة حالياً بسبب الضغط. حاول مرة ثانية."
        except Exception as e:
            answer = f"خطأ في التوليد: {str(e)}"
        
        # تجهيز المراجع
        refs = [f"ص {p.get('رقم_الصفحة')}" for p in found_pages]
        return {"answer": answer, "references": refs, "session_active": False}

    # ==========================
    # ب. الشرح عن طريق البرومت (بحث نصي) - نفس منطق الفيزياء
    # ==========================
    elif req.input_type == "برومت":
        # البحث في النصوص باستخدام الدالة المحسنة
        results, idxs = await enhanced_qa_search(target_data, req.content, top_k=5)
        
        # ✅ حتى لو ما فيه نتائج، ما نرد مباشرة - نرسل السياق للـ AI
        context_text = "\n".join(results) if results else "لا توجد نصوص مطابقة من الكتاب."
        system_prompt = system_prompt_strict_explain(SUBJECT)
        
        try:
            messages_for_ai = [{"role": "system", "content": system_prompt}]
            
            # ✅ إضافة السياق (chat_history) أولاً
            if req.chat_history:
                valid_history = [msg for msg in req.chat_history 
                                if msg.get('role') in ['user', 'assistant']]
                messages_for_ai.extend(valid_history[-6:])
            
            # ✅ نفس البرومبت الذكي حق الفيزياء
            messages_for_ai.append({
                "role": "user",
                "content": f"""المعلومات المستخرجة من الكتاب:
{context_text}

رسالة الطالب: {req.content}

تعليمات صارمة للرد:
1. إذا كانت رسالة الطالب مجرد تحية (مثل: السلام عليكم، مرحبا، كيفك) أو شكر، رُد عليه كمعلم أحياء لطيف ومرحب، واسأله كيف يمكنك مساعدته في المادة، وتجاهل المعلومات المستخرجة.
2.إذا كانت رسالته سؤالاً أو طلباً لشرح بيولوجي، يجب أن تعتمد بنسبة 100% على (المعلومات المستخرجة من الكتاب) فقط  
3. إذا طلب شرحاً بيولوجياً وكانت (المعلومات المستخرجة) تقول 'لا توجد نصوص مطابقة', جاوب من خارج الكتاب مع اخبار الطالب بان المعلومه من خارج الكتاب
"""
            })
            
            response = await asyncio.wait_for(
                gemini_client.chat.completions.create(
                model="gemini-3.1-flash-lite",
                messages=messages_for_ai, max_tokens=4000,
                temperature=0.1
            ), timeout=50)  # إضافة مهلة زمنية للتأكد من عدم الانتظار الطويل
            answer = response.choices[0].message.content
        
        
        except asyncio.TimeoutError:
        # إذا تأخر الموديل المجاني، نرد بهذه الرسالة فوراً
             answer = "⚠️ عذراً، خوادم الذكاء الاصطناعي مشغولة حالياً بسبب الضغط. حاول مرة ثانية."
                 
        except Exception as e:
            answer = f"خطأ: {str(e)}"
        
        # استخراج المراجع
        _, metas = extract_all_texts_and_metas(target_data)
        refs = [f"{metas[i]['unit']} - ص{metas[i]['page']}" for i in idxs if i < len(metas)]
        
        return {"answer": answer, "references": refs, "session_active": False}

    return {"answer": "نوع الإدخال غير معروف"}

# =====================
# 2. وضع التلخيص
# =====================
async def handle_biology_summary(req: AskRequest, gemini_client):
    book_data = get_biology_data()
    if not book_data: return {"answer": "المادة غير متوفرة"}

    if req.unit_name and req.unit_name != "الكل":
        target_data = [u for u in book_data if u.get("اسم_الوحدة") == req.unit_name]
    else:
        target_data = book_data

    # تلخيص الصفحات
    if req.input_type == "صفحة":
        numbers = re.findall(r'\d+', req.content)
        page_nums = [int(n) for n in numbers] if numbers else []
        found_pages, _ = fetch_pages_by_numbers(target_data, page_nums)
        
        if not found_pages: return {"answer": "الصفحات غير موجودة."}

        context_text = pages_with_headers(found_pages)
        system_prompt = system_prompt_strict_summary(SUBJECT, req.summary_level)
        
        try:
            response = await asyncio.wait_for(
                gemini_client.chat.completions.create(
                model="gemini-3.1-flash-lite",
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": f"نص الكتاب:\n{context_text}\n\nالمطلوب: لخص المحتوى."}
                ],
                temperature=0.15
            ), timeout=50)  # إضافة مهلة زمنية للتأكد من عدم الانتظار الطويل
            
            
            answer = response.choices[0].message.content
            
        except asyncio.TimeoutError:
        # إذا تأخر الموديل المجاني، نرد بهذه الرسالة فوراً
             answer = "⚠️ عذراً، خوادم الذكاء الاصطناعي مشغولة حالياً بسبب الضغط. حاول مرة ثانية."    

        except Exception as e:
            answer = f"خطأ: {str(e)}"
        
        return {"answer": answer, "references": [f"ص {p['رقم_الصفحة']}" for p in found_pages], "session_active": False}

    # تلخيص البرومت
    elif req.input_type == "برومت":
        texts, metas = extract_all_texts_and_metas(target_data)
        results, idxs = await faiss_search(texts, req.content, top_k=QA_TOP_K)
        
        if not results: return {"answer": "لا توجد مقاطع صلة."}
        
        context_text = "\n".join(results)
        system_prompt = system_prompt_strict_summary(SUBJECT, req.summary_level)
        
        try:
           response = await asyncio.wait_for( 
                gemini_client.chat.completions.create(
                model="gemini-3.1-flash-lite",
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": f"نص الكتاب:\n{context_text}\n\nالمطلوب: لخص الموضوع '{req.content}'."}
                ],
                temperature=0.15
            ), timeout=50)  # إضافة مهلة زمنية للتأكد من عدم الانتظار الطويل
           answer = response.choices[0].message.content
           
           
        except asyncio.TimeoutError:
        # إذا تأخر الموديل المجاني، نرد بهذه الرسالة فوراً
             answer = "⚠️ عذراً، خوادم الذكاء الاصطناعي مشغولة حالياً بسبب الضغط. حاول مرة ثانية."    
        except Exception as e:
            answer = f"خطأ: {str(e)}"
            
        refs = [f"ص {metas[i]['page']}" for i in idxs if i < len(metas)]
        return {"answer": answer, "references": refs, "session_active": False}


# =====================
# 3. وضع السؤال
# =====================
async def handle_biology_question(req: AskRequest, gemini_client):
    book_data = get_biology_data()
    if not book_data: return {"answer": "المادة غير متوفرة"}

    if req.unit_name and req.unit_name != "الكل":
        target_data = [u for u in book_data if u.get("اسم_الوحدة") == req.unit_name]
    else:
        target_data = book_data

    results, idxs = await enhanced_qa_search(target_data, req.content, top_k=5)
    
    if not results: return {"answer": "عذراً، لم أجد إجابة دقيقة في الكتاب."}
    
    context_text = "\n".join(results)
    system_prompt = system_prompt_strict_qa(SUBJECT)
    
    try:
        messages_for_ai = [{"role": "system", "content": system_prompt}]
        if req.chat_history:
            valid_history = [msg for msg in req.chat_history if msg.get('role') in ['user', 'assistant']]
            messages_for_ai.extend(valid_history[-6:])
        
        messages_for_ai.append({
            "role": "user",
            "content": f"نص الكتاب:\n{context_text}\n\nالسؤال: {req.content}"
        })
        
        response = await asyncio.wait_for( 
            gemini_client.chat.completions.create(
            model="gemini-3.1-flash-lite",
            messages=messages_for_ai, max_tokens=4000,
            temperature=0.1
        ), timeout=50)  # إضافة مهلة زمنية للتأكد من عدم الانتظار الطويل
        answer = response.choices[0].message.content
        
        
        
    except asyncio.TimeoutError:
        # إذا تأخر الموديل المجاني، نرد بهذه الرسالة فوراً
         answer = "⚠️ عذراً، خوادم الذكاء الاصطناعي مشغولة حالياً بسبب الضغط. حاول مرة ثانية."
         
    except Exception as e:
        answer = f"خطأ: {str(e)}"
    
    _, metas = extract_all_texts_and_metas(target_data)
    refs = list(set([f"ص {metas[i]['page']}" for i in idxs if i < len(metas)]))
    
    return {"answer": answer, "references": refs, "session_active": False}


# =====================
# 4. وضع الوزاري
# =====================
# =====================
# 4. وضع الوزاري (نفس اللوجيك القديم بالضبط)
# =====================
async def handle_biology_exams(req: AskRequest, sessions: Dict, gemini_client):
    """
    وضع الوزاري - أحياء (متوافق مع الفرونت إند)
    يستلم النص بصيغة: "السنة,الموضوع" مباشرة من التطبيق
    """
    _biology_session_timestamps[req.user_id] = time.time()
    cleanup_subject_sessions(sessions, _biology_session_timestamps)
    
    user_id = req.user_id
    content = req.content.strip()
    
    # ==========================================
    # 1. أوامر التحكم (إيقاف الجلسة)
    # ==========================================
    # ملاحظة: الفرونت إند قد يرسل "2019,وقف" لأن السنة مدمجة دائماً
    # لذلك نبحث عن كلمة "وقف" في أي مكان في النص
    if any(x in content for x in ["وقف", "خلاص", "شكرا", "إلغاء", "stop"]):
        sessions.pop(user_id, None)
        return {"answer": "✅ تم إنهاء جلسة الأسئلة الوزارية.", "session_active": False}
    
    # ==========================================
    # 2. المتابعة (كمل)
    # ==========================================
    # نفس الشيء، قد يصل النص "2019,كمل"
    if any(x in content for x in ["كمل", "متابعة", "استمر", "next"]):
        sess = sessions.get(user_id)
        
        if sess and sess.get("mode") == "وزاري" and sess.get("pending_exams"):
            pending = sess["pending_exams"]
            
            # أخذ دفعة جديدة
            batch = pending[:EXAMS_BATCH_SIZE]
            sess["pending_exams"] = pending[EXAMS_BATCH_SIZE:]
            
            text = "📄 **تابع الأسئلة الوزارية:**\n\n"
            for i, q in enumerate(batch, 1):
                text += f"**{i}.** {q.get('النص')} *(سنة {q.get('سنة')})*\n\n"
            
            if sess["pending_exams"]:
                text += f"\n💡 **المتبقي:** {len(sess['pending_exams'])} سؤال. اضغط **'كمل'** للمزيد."
            else:
                text += "\n✅ **انتهت جميع الأسئلة.**"
                sessions.pop(user_id, None)
            
            sessions[user_id] = sess
            return {"answer": text, "session_active": bool(sess.get("pending_exams"))}
        else:
             # إذا كتب كمل ومافي جلسة، نعتبرها بحث جديد
             pass 

    # ==========================================
    # 3. معالجة البحث (السنة + الموضوع)
    # ==========================================
    # الفرونت إند يرسل دائماً: "السنة,النص"
    # مثال: "2019,الغدد" أو "الكل,الخلية"
    
    parts = content.split(",")
    
    if len(parts) >= 2:
        year_token = parts[0].strip()
        # ندمج الباقي في حال كان الموضوع يحتوي على فواصل
        search_topic = ",".join(parts[1:]).strip()
    else:
        # حالة احتياطية لو وصل النص بدون سنة (نعتبره الكل)
        year_token = "الكل"
        search_topic = content.strip()

    # إذا كان الموضوع فارغاً (الطالب اختار سنة بس ما كتب شي)
    if not search_topic:
        return {"answer": "⚠️ الرجاء كتابة موضوع للبحث عنه (مثال: الخلية، الوراثة...)."}

    # 1. تجميع الأسئلة حسب السنة
    years = [year_token] if year_token != "الكل" else ["الكل"]
    all_questions = collect_exam_questions_by_years(SUBJECT, years)
    
    if not all_questions:
        return {"answer": f"❌ لا توجد أسئلة وزارية مخزنة لسنة {year_token}."}
    
    # 2. الفلترة بالموضوع (الكلمة المفتاحية)
    # نستخدم الدالة الجاهزة التي ترتب النتائج حسب قوة التطابق
    matched_exams = filter_and_rank_exams(all_questions, search_topic)
    
    if not matched_exams:
        return {"answer": f"❌ لم أجد أسئلة في سنة **{year_token}** تحتوي على كلمة **'{search_topic}'**."}
    
    # 3. تقسيم النتائج (Pagination)
    total = len(matched_exams)
    first_batch = matched_exams[:EXAMS_BATCH_SIZE]
    remaining = matched_exams[EXAMS_BATCH_SIZE:]
    
    # 4. حفظ الجلسة
    if remaining:
        sessions[user_id] = {
            "pending_exams": remaining,
            "mode": "وزاري",
            "subject": SUBJECT
        }
    
    # 5. بناء الرد
    text = f"✅ وجدت **{total}** سؤال عن **'{search_topic}'** ({year_token}):\n\n"
    for i, q in enumerate(first_batch, 1):
        q_text = q.get('النص', '').replace('\n', ' ')
        text += f"**{i}.** {q_text} *(سنة {q.get('سنة')})*\n\n"
    
    if remaining:
        text += f"\n💡 **متبقي {len(remaining)} سؤال.** اضغط **'كمل'** لعرضها."
    
    return {"answer": text, "session_active": bool(remaining)}

# =====================
# الدالة الموجهة (Router)
# =====================
async def handle_biology_request(req: AskRequest, gemini_client):
    """توجيه الطلب للدالة المناسبة"""
    
    if req.mode == "شرح":
        return await handle_biology_explain(req, gemini_client)
    
    elif req.mode == "تلخيص":
        return await handle_biology_summary(req, gemini_client)
    
    elif req.mode == "سؤال":
        return await handle_biology_question(req, gemini_client)
    
    elif req.mode == "وزاري":
        return await handle_biology_exams(req, sessions_biology, gemini_client)
    
    return {"answer": "وضع غير معروف"}