# subjects/math.py
"""
قسم الرياضيات - بدون أخطاء
"""

from .common import (
    subject_book_path, load_json_safe, extract_all_texts_and_metas,
    enhanced_qa_search, faiss_search, filter_and_rank_exams,
    collect_exam_questions_by_years, normalize_text_match,
    normalize_lesson_name, get_math_exam_years, get_math_exam_lessons,
    get_math_exam_questions, load_math_lesson,format_arabic_math
)
from config import BASE_SUBJECTS_DIR, QA_TOP_K, EXAMS_BATCH_SIZE, HISTORY_LAST_N
from models import AskRequest
from typing import Dict, Any, List, Optional
import json
import os
import re
import asyncio
import time





# =====================
# ثوابت المادة
# =====================
SUBJECT = "رياضيات"
sessions_math = {}


_session_timestamps = {}

def cleanup_old_sessions():
    now = time.time()
    expired = [
        uid for uid, ts in _session_timestamps.items()
        if now - ts > 1800
    ]
    for uid in expired:
        sessions_math.pop(uid, None)
        _session_timestamps.pop(uid, None)
    if expired:
        print(f"🧹 حذفت {len(expired)} session منتهية")
        
        
        
# =====================
# برومبتات خاصة بالرياضيات
# =====================
def format_lesson_safely(data, level=0):
    """
    هذه الدالة تفكك أي درس مهما كان معقداً إلى نص عربي نقي 
    بدون ضياع أي معلومة، مما يخفف التوكنز بنسبة 40% ويسرع الموديل.
    """
    text = ""
    indent = "  " * level
    if isinstance(data, dict):
        for k, v in data.items():
            if isinstance(v, (dict, list)):
                text += f"{indent}▪️ {k}:\n" + format_lesson_safely(v, level + 1)
            else:
                text += f"{indent}▪️ {k}: {v}\n"
    elif isinstance(data, list):
        for item in data:
            if isinstance(item, (dict, list)):
                text += format_lesson_safely(item, level + 1) + "\n"
            else:
                text += f"{indent}- {item}\n"
    else:
        text += f"{indent}{data}\n"
    return text.strip()


def system_prompt_math_explain():
    """برومبت شرح الرياضيات"""
    return (
        "أنت مدرس رياضيات تشرح من ملخص الطالب فقط.\n"
        "📌 ذكاء المحادثة:\n"
        "- قد تكون شرحت درساً سابقاً للطالب.\n"
        "- إذا سألك عن نقطة في الشرح السابق → استخدم السياق وأجب بناءً عليه.\n"
        "- إذا طلب شرح موضوع جديد → ابدأ شرحاً جديداً.\n\n"
        "القواعد:\n"
        "1) الشرح يكون بنفس أسلوب الملخص.\n"
        "2) تأكد من صحة القوانين وبعدها اشرح.\n"
        "3) الشرح يكون تدريجي وبسيط.\n"
        "4) عند الأمثلة: اشرح خطوة خطوة كما هي.\n"
        "5) اشرح باللغة العربية فقط.\n\n"
        "الرموز:\n"
        "- استخدم (جا، جتا، ظا) و (س، ص)\n"
        "- او اي صيغ اخرى  LaTeX او int اكتب الرموز والمعادلات باللغة العربية بالرموز و الطرق المكتوبة بالدرس لاتستخدم\n"
        "- ✅ استثناء وحيد: **الكسور**. اكتب كل كسر بالصيغة \\frac{البسط}{المقام} ولا تكتبه بـ«/» ولا «÷» — مثال: \\frac{لو أ}{لو ب}\n"
        "- اكتب المعادلات كنص عادي: ص = 2س² + 1"
    )

# =====================
# دوال مساعدة
# =====================

async def explain_math_lesson(lesson: dict, groq_client,deepseek_client):
    """شرح درس رياضيات"""
    content = format_lesson_safely(lesson)
    
    prompt = f"""
هذا ملخص درس رياضيات:

{content}

المطلوب:
اشرح هذا الدرس شرحًا تعليميًا واضحًا للطالب.
- اكتب باللغة العربية فقط
- استخدم الرموز العربية مثل (جا، جتا، ظا) و (س، ص،أ،ب،ج وغيرها )
- لا تستخدم LaTeX أو \\text
- ✅ استثناء وحيد: **الكسور**. اكتب كل كسر بالصيغة \\frac{{البسط}}{{المقام}} ولا تكتبه بـ«/» ولا «÷» — مثال: \\frac{{لو أ}}{{لو ب}}
- اكتب المعادلات كنص عادي
مثال: ص = 2س² + 1
"""
    
    try:
        # 1. الطلب محمي بتايمر 50 ثانية
        response = await asyncio.wait_for(
            deepseek_client.chat.completions.create(
                model="deepseek-chat",
                temperature=0.2,
                max_tokens=4000,
                messages=[
                    {"role": "system", "content": system_prompt_math_explain()},
                    {"role": "user", "content": prompt}
                ]
            ), 
            timeout=50.0  # <== التايمر هنا
        )
        
        raw_answer = response.choices[0].message.content
        clean_answer = format_arabic_math(raw_answer)
        return clean_answer  # 👈 نرجع النص النظيف الخالي من المربعات

    # 2. اصطياد خطأ الوقت (التايم آوت)
    except asyncio.TimeoutError:
        return "⚠️ عذراً، خوادم الذكاء الاصطناعي مشغولة حالياً بسبب الضغط. حاول مرة ثانية."

        
    # 3. اصطياد أي خطأ برمجي آخر
    except Exception as e:
        return f"⚠️ عذراً، حدث خطأ أثناء تجهيز الشرح: {str(e)}"

# =====================
# الدوال الرئيسية
# =====================

async def handle_math_request(req: AskRequest, deepseek_client, groq_client):
    """معالج الطلب الرئيسي للرياضيات"""
    
    cleanup_old_sessions()
    _session_timestamps[req.user_id] = time.time()
    
    user_id = req.user_id
    mode = req.mode.strip()
    branch = req.unit_name  # الفرع: تفاضل، تكامل، إلخ
    user_text = req.content.strip()
    lesson_name = req.lesson_name
    
    # =====================
    # 1️⃣ علمني
    # =====================
    if user_text == "علمني":
        return {
           "answer": (
                "📘 أنت في قسم الرياضيات:\n\n"
                "🟢 شرح الدرس:\n"
                "- اختر الفرع\n"
                "- اختر الدرس\n"
                "- اضغط (شرح الدرس)\n"
                "- بعد الشرح يمكنك السؤال عن أي نقطة في الشرح\n\n"
                "🔵 سؤال:\n"
                "- اختر الدرس\n"
                "- اكتب المسألة\n"
                "- سيحلها الذكاء الاصطناعي بنفس أسلوب الملخص\n"
            ),
            "session_active": False
        }
    
    # =====================
    # تحقق من الفرع
    # =====================
    if not branch:
        return {"answer": "⚠️ اختر فرع الرياضيات أولاً."}
    
    # =====================
    # 2️⃣ وضع الوزاري
    # =====================
    if mode == "وزاري":
        return await handle_math_exams(req, sessions_math, deepseek_client, groq_client)
    
    # =====================
    # 3️⃣ وضع الشرح
    # =====================
    elif mode == "شرح":
        return await handle_math_explain(req, sessions_math, deepseek_client, groq_client)
    
    # =====================
    # 4️⃣ وضع السؤال
    # =====================
    elif mode == "سؤال":
        return await handle_math_question(req, sessions_math, deepseek_client)
    
    return {"answer": "وضع غير معروف"}


async def handle_math_explain(req: AskRequest, sessions: Dict, deepseek_client, groq_client):
    """شرح درس رياضيات - النسخة الصحيحة"""
    
    user_id = req.user_id
    branch = req.unit_name
    lesson_name = req.lesson_name
    user_text = req.content.strip()
    
    if not lesson_name:
        return {"answer": "⚠️ يجب اختيار الدرس أولاً."}
    
    sess = sessions.get(user_id)
    norm_lesson_name = normalize_text_match(lesson_name)
    sess_lesson_name = normalize_text_match(sess.get("lesson_name", "")) if sess else ""
    
    # ============================================
    # ✅ الحالة 1: الطالب ضغط "شرح الدرس" (content فارغ)
    # ============================================
    if user_text == "" or user_text.startswith("شرح درس:"):
        # إذا فيه جلسة نشطة للدرس نفسه → رجع الشرح السابق
        if sess and sess_lesson_name == norm_lesson_name:
            return {
                "answer": sess.get("last_explanation", ""),
                "session_active": False
            }
        
        # إذا درس جديد → اشرح الدرس
        sessions.pop(user_id, None)
        lesson = load_math_lesson(branch, lesson_name)
        if not lesson: 
            return {"answer": f"❌ لم أجد درس '{lesson_name}'."}
        
        explanation = await explain_math_lesson(lesson, groq_client,deepseek_client)
        
        sessions[user_id] = {
            "subject": "رياضيات",
            "mode": "math_explain",
            "lesson": lesson,
            "lesson_name": lesson_name,
            "last_explanation": explanation
        }
        _session_timestamps[user_id] = time.time()  # ← أضف هذا
        return {"answer": explanation, "session_active": False}
    
    # ============================================
    # ✅ الحالة 2: الطالب كتب سؤال عن الشرح
    # ============================================
    # تحقق إذا فيه جلسة شرح نشطة للدرس الحالي
    if sess and sess.get("mode") == "math_explain" and sess_lesson_name == norm_lesson_name:
        lesson = sess["lesson"]
        last_explanation = sess["last_explanation"]
        
        messages_for_ai = [
            {"role": "system", "content": system_prompt_math_explain()}
        ]
        
        messages_for_ai.append({
            "role": "assistant",
            "content": f"هذا شرح الدرس الذي نتحدث عنه:\n{last_explanation}"
        })
        
        if req.chat_history:
            valid_history = [msg for msg in req.chat_history if msg.get('role') in ['user', 'assistant']]
            messages_for_ai.extend(valid_history[-HISTORY_LAST_N:])
        
        messages_for_ai.append({
            "role": "user",
            "content": f"سؤال الطالب حول الشرح: {user_text}\n(  المطلوب )\n"
            """- أجب على السؤال بالاعتماد على نفس الدرس فقط.
لاتكتب اي كلمة انجليزية او كلمة غير عربية اثناء الشرح
- وضّح الفكرة بأسلوب تعليمي مرتبط بالشرح السابق.
- اكتب الشرح باللغة العربية فقط
- لا تستخدم LaTeX
- لا تستخدم \\text
- ✅ استثناء وحيد: **الكسور**. اكتب كل كسر بالصيغة \\frac{البسط}{المقام} ولا تكتبه بـ«/» ولا «÷» — مثال: \\frac{لو أ}{لو ب}
- اكتب المعادلات كنص عادي
مثال: ص = 2س² + 1"""
        })
        
        try:
            response = await asyncio.wait_for(
                deepseek_client.chat.completions.create(
                model="deepseek-chat",
                temperature=0.2,
                messages=messages_for_ai,
                max_tokens=4000
            ), timeout=60)  # إضافة مهلة زمنية للتأكد من عدم الانتظار الطويل    
            
            
            raw_answer = response.choices[0].message.content
            clean_answer = format_arabic_math(raw_answer)
            full_answer = clean_answer # نمرر الإجابة النظيفة للتطبيق
            clean_answer = re.sub(r'<think>.*?</think>', '', full_answer, flags=re.DOTALL | re.IGNORECASE).strip()
            
            return {"answer": clean_answer, "session_active": False}
        
        except asyncio.TimeoutError:
            return {"answer": "⚠️ عذراً، خوادم الذكاء الاصطناعي مشغولة حالياً بسبب الضغط. حاول مرة ثانية.", "session_active": False}
        
        
        except Exception as e:
            return {"answer": f"خطأ: {str(e)}", "session_active": False}
    
    # ============================================
    # ✅ الحالة 3: درس جديد → اشرح من الصفر
    # ============================================
    sessions.pop(user_id, None)
    lesson = load_math_lesson(branch, lesson_name)
    if not lesson: 
        return {"answer": f"❌ لم أجد درس '{lesson_name}'."}
    
    explanation = await explain_math_lesson(lesson, groq_client,deepseek_client)
    
    sessions[user_id] = {
        "subject": "رياضيات",
        "mode": "math_explain",
        "lesson": lesson,
        "lesson_name": lesson_name,
        "last_explanation": explanation
    }
    _session_timestamps[user_id] = time.time()  # ← أضف هذا
    return {"answer": explanation, "session_active": False}

async def handle_math_question(req: AskRequest, sessions: Dict, deepseek_client):
    """حل مسألة رياضيات"""
    
    user_id = req.user_id
    branch = req.unit_name
    lesson_name = req.lesson_name
    user_text = req.content.strip()
    
    if not lesson_name:
        return {"answer": "⚠️ اختر الدرس أولاً."}
    
    lesson = load_math_lesson(branch, lesson_name)
    if not lesson:
        return {"answer": f"⚠️ لم أجد ملف الدرس: {lesson_name}"}
    
    lesson_text = format_lesson_safely(lesson)
    
    system_prompt = (
        "أنت مدرس رياضيات محترف في تطبيق \"مسار\". التزم بالقواعد التالية:\n\n"
              "📌 ذكاء المحادثة:\n"
            "- قد تكون شرحت درساً سابقاً للطالب.\n"
            "- إذا سأل عن نقطة من الشرح السابق → استخدم السياق وأجب بناءً عليه.\n"
            "- إذا طلب موضوعاً جديداً → ابدأ شرحاً جديداً من البداية.\n\n"
             "📖 التعامل مع الأسئلة:\n"
             "- اشرح الدرس أو السؤال كما لو كنت تشرحه للطلاب في الفصل.\n"
            "- استخدم طريقة تعليمية مبسطة وواضحة.\n"
            "- حل المسائل خطوة بخطوة حتى يفهم الطالب كل مرحلة.\n"
            "- ابحث أولاً في أمثلة الدرس الموجودة.\n"
            "- إذا كان السؤال مطابقاً لمثال → اعرض الحل النموذجي.\n"
            "- إذا كان مشابهاً (اختلاف أرقام أو رموز) → حلّه بنفس الخطوات والمنهج تماماً.\n\n"
            "- في نهاية الحل، اذكر القوانين المستخدمة.\n\n"
            "📝 اللغة:\n"
            "- استخدم العربية الفصحى فقط.\n"
            "- يمنع استخدام الإنجليزية أو أي لغة أخرى.\n\n"
            "🔢 الرموز الرياضية:\n"
            "- استخدم فقط: (جا، جتا، ظا) و (س، ص)\n\n"
            "-  لا تستخدم \\text او اي رموز اخرى مشابه لها , اكتب بنفس الصيغه الموجودة في الدرس \n"
            "- ✅ استثناء وحيد: **الكسور**. اكتب كل كسر بالصيغة \\frac{البسط}{المقام} ولا تكتبه بـ«/» ولا «÷» — مثال: \\frac{لو أ}{لو ب}\n\n"
            "✏️ مثال للكتابة الصحيحة:\nص = 2س² + 1\n\n"
            "⚠️ مهم جداً: اكتب الحل مرة واحدة فقط، بدون تكرار."
    )
    
    try:
        messages_for_ai = [{"role": "system", "content": system_prompt}]
        
        if req.chat_history:
            valid_history = [msg for msg in req.chat_history 
                            if msg.get('role') in ['user', 'assistant']]
            messages_for_ai.extend(valid_history[-HISTORY_LAST_N:])
        
        messages_for_ai.append({
            "role": "user",
            "content": f"سياق الدرس:\n{lesson_text}\n\nسؤال الطالب: {user_text}"
        })
        
        response = await asyncio.wait_for(
            deepseek_client.chat.completions.create(
            model="deepseek-chat",
            messages=messages_for_ai, max_tokens=4000,
            temperature=0.2
        ), timeout=60)  # إضافة مهلة زمنية للتأكد من عدم الانتظار الطويل    
        
        
        raw_answer = response.choices[0].message.content
        clean_answer = format_arabic_math(raw_answer)
        full_answer = clean_answer # نمرر الإجابة النظيفة للتطبيق
        
        # تنظيف النص
        clean_answer = re.sub(r'<think>.*?</think>', '', full_answer, flags=re.DOTALL).strip()
        clean_answer = clean_answer.replace("sin", "جا").replace("cos", "جتا").replace("tan", "ظا")
        clean_answer = clean_answer.replace("x", "س").replace("y", "ص")
        
        return {"answer": clean_answer, "session_active": False}
    except asyncio.TimeoutError:
        return {"answer": "⚠️ عذراً، خوادم الذكاء الاصطناعي مشغولة حالياً بسبب الضغط. حاول مرة ثانية.", "session_active": False}
        
    except Exception as e:
        return {"answer": f"عذراً، حدث خطأ: {str(e)}", "session_active": False}


async def handle_math_exams(req: AskRequest, sessions: Dict, deepseek_client, groq_client):
    """وضع الوزاري للرياضيات"""
    
    user_id = req.user_id
    branch = req.unit_name
    user_text = req.content.strip()
    
    # =====================
    # 1️⃣ أوامر التحكم (وقف)
    # =====================
    if user_text in ["وقف", "خلاص", "شكرا", "إلغاء"]:
        sess = sessions.get(user_id)
        if sess:
            sess["pending_exams"] = []
            sess["has_more"] = False  # 🔥 التعديل: إغلاق ظهور الأزرار نهائياً في الجلسة
            sessions[user_id] = sess
        
        return {
            "answer": "✅ تم إيقاف عرض المزيد.",
            "session_active": False
        }
    
    # =====================
    # 2️⃣ كمل (متابعة)
    # =====================
    if user_text in ["كمل", "نعم", "متابعة"]:
        sess = sessions.get(user_id)
        if sess and sess.get("mode") == "وزاري":
            year = sess.get("year")
            lesson = sess.get("lesson")
            shown_count = sess.get("shown_count", 0)
            
            result = get_math_exam_questions(branch, year, lesson, shown_count + 10)
            new_questions = result["questions"][shown_count:]
            
            # ✅ إذا ما فيه أسئلة إضافية
            if not new_questions:
                sess["has_more"] = False
                sessions[user_id] = sess
                return {
                    "answer": "✅ انتهت جميع الأسئلة.",
                    "session_active": False
                }
            
            text = f"📋 الأسئلة الإضافية:\n\n"
            
            for i, q in enumerate(new_questions, shown_count + 1):
                q_text = q['نص_السؤال'].replace('\n', '\n\n')
                text += f"\n📌 السؤال {i}:\n{q_text}\n"
                
                if q.get('الحل'):
                    sol_text = q['الحل'].replace('\n', '\n\n')
                    text += f"💡 الإجابة:\n{sol_text}\n"
                
                text += "━━━━━━━━━━━━━━━\n"
            
            if len(new_questions) < result.get("remaining", 0):
                text += f"\n💡 تبقى {result['remaining']} سؤال. اكتب 'كمل' للمزيد."
            
            # حفظ الأسئلة الجديدة
            all_displayed = sess.get("displayed_questions", []) + new_questions
            
            sessions[user_id] = {
                "subject": "رياضيات",
                "mode": "وزاري",
                "branch": branch,
                "year": year,
                "lesson": lesson,
                "shown_count": shown_count + len(new_questions),
                "displayed_questions": all_displayed,
                "pending_exams": [],
                "has_more": result.get("has_more", False)  # 🔥 التعديل: حفظ حالة الأزرار
            }
            _session_timestamps[user_id] = time.time()  # ← أضف هذا
            
            return {"answer": text, "session_active": result.get("has_more", False)}
        else:
            return {
                "answer": "⚠️ لا توجد جلسة وزاري نشطة.",
                "session_active": False
            }
    
    # =====================
    # 3️⃣ جلب أسئلة جديدة (صيغة: السنة|الدرس|العدد)
    # =====================
    parts = user_text.split("|")
    
    if len(parts) == 3:
        year = parts[0].strip()
        lesson = parts[1].strip()
        try:
            count = int(parts[2].strip())
        except:
            count = 10
        
        result = get_math_exam_questions(branch, year, lesson, count)
        
        if not result["questions"]:
            return {"answer": f"❌ لم أجد أسئلة في '{lesson}' لسنة {year}"}
        
        total = result["total"]
        shown = len(result["questions"])
        
        text = f"✅ وجدت {total} سؤالاً في '{lesson}' - سنة {year}\n"
        text += f"📋 عرض {shown} سؤال:\n\n"
        text += "━━━━━━━━━━━━━━━\n"
        
        for i, q in enumerate(result["questions"], 1):
            q_text = q['نص_السؤال'].replace('\n', '\n\n')
            text += f"\n📌 السؤال {i}:\n{q_text}\n"
            
            if q.get('الحل'):
                sol_text = q['الحل'].replace('\n', '\n\n')
                text += f"💡 الإجابة:\n{sol_text}\n"
            
            text += "━━━━━━━━━━━━━━━\n"
        
        if result["has_more"]:
            text += f"\n💬 يوجد {result['remaining']} سؤالاً إضافياً.\n"
            text += "هل تريد عرضها؟ (اكتب 'كمل')\n"
        
        sessions[user_id] = {
            "subject": "رياضيات",
            "mode": "وزاري",
            "branch": branch,
            "year": year,
            "lesson": lesson,
            "shown_count": shown,
            "displayed_questions": result["questions"],  
            "pending_exams": [],
            "has_more": result["has_more"]  # 🔥 التعديل: حفظ الحالة من البداية
        }
        _session_timestamps[user_id] = time.time()  # ← أضف هذا
        
        return {"answer": text, "session_active": result["has_more"]}
    
    # =====================
    # 4️⃣ 🔥 سؤال عن الأسئلة الوزارية المعروضة 🔥
    # =====================
    sess = sessions.get(user_id)
    
    if sess and sess.get("mode") == "وزاري":
        displayed_questions = sess.get("displayed_questions", [])
        branch_current = sess.get("branch")
        year_current = sess.get("year")
        lesson_current = sess.get("lesson")
        
        if not displayed_questions:
            return {
                "answer": "⚠️ لا توجد أسئلة معروضة.",
                "session_active": False
            }
        
        # ✅ تحميل الدرس للسياق
        lesson_data = load_math_lesson(branch_current, lesson_current)
        lesson_text = format_lesson_safely(lesson_data) if lesson_data else ""
        
        # ✅ بناء نص الأسئلة المعروضة
        questions_context = f"📚 الأسئلة الوزارية المعروضة (سنة {year_current}, درس: {lesson_current}):\n\n"
        for i, q in enumerate(displayed_questions, 1):
            q_text = q.get('نص_السؤال', '').replace('\n', '\n  ')
            sol_text = q.get('الحل', '').replace('\n', '\n  ')
            
            questions_context += f"📌 السؤال {i}:\n{q_text}\n\n"
            if sol_text:
                questions_context += f"💡 الحل:\n{sol_text}\n\n"
            questions_context += "━━━━━━━━━━━━━━━\n\n"
        
        # ✅ برومبت خاص بالإجابة على الأسئلة الوزارية
        system_prompt = (
           "أنت مدرس رياضيات محترف.\n"
                "المطلوب: الإجابة على سؤال الطالب بناءً على الأسئلة الوزارية المعروضة.\n\n"
                "📌 السياق المهم:\n"
                "- الطالب يسأل عن أسئلة وزارية معروضة أمامه\n"
                "- قد يسأل: 'وضح السؤال 3'، 'كيف حلينا الثاني'، 'ما فهمت قيمة س'\n"
                "- أنت تفهم سؤاله وتجيب بناءً على الأسئلة المعروضة\n\n"
                "القواعد:\n"
            "- استخدم العربية الفصحى فقط.\n"
            "- يمنع استخدام الإنجليزية أو أي لغة أخرى.\n\n"
            "يمنع استخدام اي رموز غير عربية .\n\n"
            "- استخدم فقط: (جا، جتا، ظا) و (س، ص)\n\n"
            "- لا تستخدم \\text\n"
            "- ✅ استثناء وحيد: **الكسور**. اكتب كل كسر بالصيغة \\frac{البسط}{المقام} ولا تكتبه بـ«/» ولا «÷» — مثال: \\frac{لو أ}{لو ب}\n\n"
            "✏️ مثال للكتابة الصحيحة:\nص = 2س² + 1\n\n"
                "- اشرح الحل خطوة بخطوة\n"
                "- اذكر القوانين المستخدمة\n"
                "- إذا ذكر رقم سؤال، ارجع للسؤال المطابق من القائمة المعروضة\n"
                "- إذا كان سؤالاً عاماً، استخدم الأسئلة المعروضة للتوضيح\n"
        )
        
        try:
            # ✅ بناء الرسائل
            messages_for_ai = [{"role": "system", "content": system_prompt}]
            
            # ✅ إضافة السياق: الأسئلة المعروضة
            messages_for_ai.append({
                "role": "assistant",
                "content": f"هذه الأسئلة الوزارية المعروضة أمامك:\n\n{questions_context}"
            })
            
            # ✅ إضافة التاريخ (إن وجد)
            if req.chat_history:
                valid_history = [msg for msg in req.chat_history 
                                if msg.get('role') in ['user', 'assistant']]
                messages_for_ai.extend(valid_history[-HISTORY_LAST_N:])
            
            # ✅ سؤال الطالب الجديد
            messages_for_ai.append({
                "role": "user",
                "content": (
                    f"بيانات الدرس (للمرجعية):\n{lesson_text}\n\n"
                    f"سؤال الطالب: {user_text}"
                )
            })
            
            # ✅ استدعاء الـ AI
            response = await asyncio.wait_for(
                deepseek_client.chat.completions.create(
                model="deepseek-chat",
                messages=messages_for_ai, max_tokens=4000,
                temperature=0.2
            ), timeout=60)  # إضافة مهلة زمنية للتأكد من عدم الانتظار الطويل    
            
            raw_answer = response.choices[0].message.content
            clean_answer = format_arabic_math(raw_answer)
            full_answer = clean_answer # نمرر الإجابة النظيفة للتطبيق
            
            # ✅ تنظيف النص
            clean_answer = re.sub(r'<think>.*?</think>', '', full_answer, flags=re.DOTALL).strip()
            clean_answer = clean_answer.replace("sin", "جا").replace("cos", "جتا").replace("tan", "ظا")
            clean_answer = clean_answer.replace("x", "س").replace("y", "ص")
            
            # إزالة أي كود LaTeX متبقي
            clean_answer = re.sub(r'\$.*?\$', '', clean_answer)
            # ⚠️ `\frac` مستثناة: هي ترميز الكسر الذي يرسمه التطبيق
            #    بسطاً فوق مقام. مسحُها هنا كان يُفرغ البرومبت من معناه.
            clean_answer = re.sub(r'\\(?!frac\b|chem\b|ring\b)[a-z]+', '', clean_answer)
            
            return {
                "answer": clean_answer,
                "session_active": sess.get("has_more", False)  # 🔥 التعديل الجوهري: الاعتماد على الجلسة وليس True
            }
        except asyncio.TimeoutError:
            return {
                "answer": "⚠️ عذراً، خوادم الذكاء الاصطناعي مشغولة حالياً بسبب الضغط. حاول مرة ثانية.",
                "session_active": sess.get("has_more", False)  # 🔥 لضمان بقاء الأزرار مخفية في حال التأخير
            }
        except Exception as e:
            return {
                "answer": f"❌ خطأ: {str(e)}",
                "session_active": sess.get("has_more", False)  # 🔥 لضمان بقاء الأزرار مخفية في حال الخطأ
            }
    
    # =====================
    # ❌ لا يوجد جلسة وزاري نشطة
    # =====================
    return {
        "answer": (
          "⚠️ يرجى جلب الأسئلة الوزارية أولاً!\n\n"
            "📝 الخطوات:\n"
            "1. اختر السنة من القائمة أعلاه\n"
            "2. اختر الدرس\n"
            "3. حدد عدد الأسئلة\n"
            "4. اضغط 'جلب الأسئلة'\n\n"
            "✨ بعدها يمكنك السؤال عن أي سؤال مباشرة!"
        ),
        "session_active": False
    }