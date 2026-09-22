# subjects/chemistry.py
"""
قسم الكيمياء - يعتمد على ذاكرة التطبيق (الجوال) فقط - Stateless
مع دعم المحادثة الطبيعية (الترحيب) والدقة الصارمة في المنهج
نفس لوجيك الفيزياء تماماً لكن باسم الكيمياء
"""

from .common import (
    turn_note,
    subject_book_path, load_json_safe, extract_all_texts_and_metas_physics,
    enhanced_search_physics, system_prompt_strict_explain,
    system_prompt_strict_summary, system_prompt_strict_qa,
    filter_and_rank_exams, collect_exam_questions_by_years,
    parse_exams_input, extract_keywords, faiss_search, format_arabic_math,
    unit_missing, unit_required_response, search_text_of, hybrid_rank,
    book_context, Ranked,
    contextual_search_text,
)
from config import BASE_SUBJECTS_DIR, QA_TOP_K, EXAMS_BATCH_SIZE, HISTORY_LAST_N
from models import AskRequest
from typing import Dict, List, Optional
import json
import asyncio

from core import streaming
from core.curriculum import subject_call
import time

SUBJECT = "كيمياء"
sessions_chemistry = {}

_chemistry_session_timestamps = {}




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
# دوال مساعدة
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
    texts, metas = extract_all_texts_and_metas_physics(book_data, SUBJECT)
    if not texts: return Ranked([], [], best=0.0)
    
    # 🧵 **استعارةُ الموضوع صارت مصدراً واحداً** ([common.contextual_search_text]).
    #    كان هنا: «لو السؤال أقلّ من ٥ كلمات ألحِق أول ١٥٠ حرفاً من الرد
    #    السابق». وهي حيلةٌ تُخطئ مرّتين: «ما الفرق بينها وبين الغدة
    #    الدرقية» ستُّ كلماتٍ فلا تستعير شيئاً وموضوعُها ضمير، وأولُ ١٥٠
    #    حرفاً من الرد غالباً تحيةٌ ومقدّمة لا موضوع.
    combined_query = contextual_search_text(query, chat_history)
    
    # 🔄 **نفسُ عطل الدمج بالأسبقية كان هنا أيضاً** — نسخةٌ ثالثة منه.
    #    كلمةُ «بين» وحدها كانت تطرد البحثَ الدلاليَّ كلَّه من المقاعد
    #    الثلاثة. راجع [common.hybrid_rank].
    return await hybrid_rank(texts, combined_query, top_k)


# =====================
# الدوال الرئيسية
# =====================

async def handle_chemistry_explain(req: AskRequest, openai_client):
    """وضع الشرح - الكيمياء"""
    
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
                        # ✅ التعديل الذكي: يقرأ كل المفاتيح (صيغة، رموز، اسم الرسم، الخ)
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
            
        # 📚 الوحدة إلزامية على مسار البحث ([common.unit_required_response]).
        if unit_missing(req):
            return unit_required_response()
        found = await enhanced_search_physics(target_data, search_text_of(req), top_k=5)
        results, idxs = found
        context_text = book_context(found, sep="\n", req=req)
        
        _, metas = extract_all_texts_and_metas_physics(target_data, SUBJECT)
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
            messages_for_ai.extend(valid_history[-HISTORY_LAST_N:])
        
        messages_for_ai.append({
            "role": "user",
            "content": (f"""
المعلومات المستخرجة من الكتاب:
{context_text}

رسالة الطالب: {req.content}

تعليمات صارمة للرد:
1. ⚠️ تنبيه هام جداً: إذا كانت رسالة الطالب هي "اشرح لي الدرس" أو "اشرح" أو أي طلب شرح عام، **يجب عليك فوراً** البدء في شرح (المعلومات المستخرجة من الكتاب) بالتفصيل، ويُمنع منعاً باتاً الرد برسالة ترحيب!
2. إذا كانت رسالته سؤالاً أو طلباً لشرح كيميائي، يجب أن تعتمد بنسبة 100% على (المعلومات المستخرجة من الكتاب) فقط.
3🧪 القواعد الكيميائية: اكتب المعادلات الكيميائية بنص عادي وواضح ومطابق حرفياً لما هو موجود في سياق الدرس (استخدم الأسهم العادية مثل -> أو =). اجعل كل معادلة في سطر مستقل لسهولة القراءة، ويُمنع منعاً باتاً تأليف معادلات خارجية أو استخدام أكواد LaTeX المعقدة — عدا **الكسور** فهي مطلوبة بصيغتها: كل بسط ومقام يُكتب \\frac{{البسط}}{{المقام}} ولا يُكتب بـ«/» ولا «÷».

════════════════════════════════════════════════════
⚗️ **الصيغ البنائية والحلقات — قاعدة مُلزِمة تسبق كل ما عداها**
════════════════════════════════════════════════════
🚫 **يُمنع منعاً باتاً رسم أي شكل بالرموز أو الشرطات أو داخل ```** —
   ولا تقل «لا أستطيع الرسم». أنت **تكتب ترميزاً** والتطبيق **يرسمه** للطالب.

📌 السلسلة المفتوحة ⇐ \\chem{{...}}
   • المجموعات موصولةً بشرطة: \\chem{{CH3-CH2-CH2-NH2}}
   • الفرع بين قوسين بعد أصله مباشرةً: \\chem{{CH3-CH(CH3)-CH3}}
   • الرابطة الثنائية = والثلاثية #: \\chem{{CH3-CH=O}} · \\chem{{CH3-C#N}}

📌 الحلقة ⇐ \\ring{{...}} — الأجزاء يفصلها | :
   • العدد أولاً: \\ring{{3}} مثلث · \\ring{{4}} مربع · \\ring{{6}} سداسي
   • ar للعطرية: \\ring{{6|ar}} بنزين
   • رمز الذرّة داخل الحلقة: \\ring{{6|ar|N}} بيريدين · \\ring{{6|NH}} بيبيريدين
   • +المجموعة المعلّقة: \\ring{{6|ar|+NH2}} أنيلين · \\ring{{3|+NH2}} أمينو سيكلوبروبان

⚠️ **هذه القاعدة أقوى من قاعدة «انقل بلغة الدرس حرفياً»**: إن كتب الكتاب
   الصيغة سطراً مسطّحاً فحوّلها أنت إلى \\chem أو \\ring. وكلّما ذكرتَ مركّباً
   عضوياً بالاسم (بروبان · سيكلوهيكسان · أنيلين …) أرفِق ترميزه بعده.

✅ مطلوب: «المركب \\chem{{CH3-NH-CH3}} يسمى ثنائي ميثيل أمين.»
❌ مرفوض: رسمٌ بالشرطات والخطوط داخل كتلة برمجية.

4. إذا طلب شرحاً كيميائياً وكانت (المعلومات المستخرجة) تقول 'لا توجد نصوص مطابقة'، اعتذر بلطف وأخبره أن هذا الموضوع غير موجود في المنهج الحالي.
4. 🧮 **الكسور**: كل كسر يُكتب \\frac{{البسط}}{{المقام}} — لا بـ«/» ولا «÷» ولا بكلمة «على»، حتى لو كتبه الكتاب هكذا. مثال: ك = \\frac{{الوزن}}{{تسارع الجاذبية}}. ⚠️ ووحدات القياس ليست كسوراً وتبقى كما هي: م/ث · كجم.م/ث · كم/ساعة.
""" + turn_note(req))
        })
        
        # 🌊 يبثّ حرفاً حرفاً على مسار البثّ، وإلا نداءٌ عادي حرفياً.
        raw_answer = await streaming.complete(
            openai_client,
            sink=streaming.sink_of(req),
            messages=messages_for_ai,
            **subject_call("كيمياء", req),
            temperature=0.2,
        )
        clean_answer = format_arabic_math(raw_answer, "كيمياء")
        
        # ✅ فلتر التنظيف الجذري لإزالة أكواد LaTeX والشرطة السفلية
        # ℹ️ حُذف من هنا فلترٌ يمسح كل أمرٍ لاتيكيّ عدا ثلاثة
        #    (`frac` · `chem` · `ring`) — وهي **قائمةٌ متخلّفة**: الترميزات
        #    عشرة اليوم، فكان يمسح `\sup` و`\nuc` و`\sqrt` بعد أن
        #    وَلَّدها [_finish] فتصل الطالبَ أقواسُها عارية. و
        #    `format_arabic_math` تنتهي أصلاً بـ`latex_guard.clean` الذي
        #    **يحوّل** ما لا يعرفه إلى رمزه ولا يحذف إلا ما لا مقابل له.
        clean_answer = clean_answer.replace('_', ' ')
        answer = clean_answer
    except asyncio.TimeoutError:
        # إذا تأخر الموديل المجاني، نرد بهذه الرسالة فوراً
        answer = "⚠️ عذراً، خوادم الذكاء الاصطناعي مشغولة حالياً بسبب الضغط. حاول مرة ثانية."
        
    except Exception as e:
        answer = f"خطأ في التوليد: {str(e)}"
    
    return {"answer": answer, "references": refs, "session_active": False}

async def handle_chemistry_summary(req: AskRequest, openai_client):
    """وضع التلخيص - الكيمياء"""
    
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
            
        # 📚 الوحدة إلزامية على مسار البحث ([common.unit_required_response]).
        if unit_missing(req):
            return unit_required_response()
        found = await enhanced_search_physics(target_data, search_text_of(req), top_k=QA_TOP_K)
        results, idxs = found
        
        context_text = book_context(found, sep="\n", req=req)
        
        _, metas = extract_all_texts_and_metas_physics(target_data, SUBJECT)
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
            messages_for_ai.extend(valid_history[-HISTORY_LAST_N:])
        
        messages_for_ai.append({
            "role": "user",
            "content": (f"""
المعلومات المستخرجة من الكتاب:
{context_text}

رسالة/موضوع الطالب: {req.content}

التعليمات:
1. إذا كانت رسالة الطالب ترحيب أو شكر، رد بلطف وتجاهل التلخيص.
2. إذا طلب التلخيص، استخدم فقط المعلومات المستخرجة أعلاه لعمل التلخيص. إذا لم تكن هناك معلومات، أخبره أن الموضوع غير متوفر في المنهج.
3🧪 القواعد الكيميائية: اكتب المعادلات الكيميائية بنص عادي وواضح ومطابق حرفياً لما هو موجود في سياق الدرس (استخدم الأسهم العادية مثل -> أو =). اجعل كل معادلة في سطر مستقل لسهولة القراءة، ويُمنع منعاً باتاً تأليف معادلات خارجية أو استخدام أكواد LaTeX المعقدة — عدا **الكسور** فهي مطلوبة بصيغتها: كل بسط ومقام يُكتب \\frac{{البسط}}{{المقام}} ولا يُكتب بـ«/» ولا «÷».

════════════════════════════════════════════════════
⚗️ **الصيغ البنائية والحلقات — قاعدة مُلزِمة تسبق كل ما عداها**
════════════════════════════════════════════════════
🚫 **يُمنع منعاً باتاً رسم أي شكل بالرموز أو الشرطات أو داخل ```** —
   ولا تقل «لا أستطيع الرسم». أنت **تكتب ترميزاً** والتطبيق **يرسمه** للطالب.

📌 السلسلة المفتوحة ⇐ \\chem{{...}}
   • المجموعات موصولةً بشرطة: \\chem{{CH3-CH2-CH2-NH2}}
   • الفرع بين قوسين بعد أصله مباشرةً: \\chem{{CH3-CH(CH3)-CH3}}
   • الرابطة الثنائية = والثلاثية #: \\chem{{CH3-CH=O}} · \\chem{{CH3-C#N}}

📌 الحلقة ⇐ \\ring{{...}} — الأجزاء يفصلها | :
   • العدد أولاً: \\ring{{3}} مثلث · \\ring{{4}} مربع · \\ring{{6}} سداسي
   • ar للعطرية: \\ring{{6|ar}} بنزين
   • رمز الذرّة داخل الحلقة: \\ring{{6|ar|N}} بيريدين · \\ring{{6|NH}} بيبيريدين
   • +المجموعة المعلّقة: \\ring{{6|ar|+NH2}} أنيلين · \\ring{{3|+NH2}} أمينو سيكلوبروبان

⚠️ **هذه القاعدة أقوى من قاعدة «انقل بلغة الدرس حرفياً»**: إن كتب الكتاب
   الصيغة سطراً مسطّحاً فحوّلها أنت إلى \\chem أو \\ring. وكلّما ذكرتَ مركّباً
   عضوياً بالاسم (بروبان · سيكلوهيكسان · أنيلين …) أرفِق ترميزه بعده.

✅ مطلوب: «المركب \\chem{{CH3-NH-CH3}} يسمى ثنائي ميثيل أمين.»
❌ مرفوض: رسمٌ بالشرطات والخطوط داخل كتلة برمجية.

""" + turn_note(req))
        })
        
        # 🌊 يبثّ حرفاً حرفاً على مسار البثّ، وإلا نداءٌ عادي حرفياً.
        raw_answer = await streaming.complete(
            openai_client,
            sink=streaming.sink_of(req),
            messages=messages_for_ai,
            **subject_call("كيمياء", req),
            temperature=0.15,
        )
        clean_answer = format_arabic_math(raw_answer, "كيمياء")
        
        # ✅ فلتر التنظيف الجذري
        # ℹ️ حُذف من هنا فلترٌ يمسح كل أمرٍ لاتيكيّ عدا ثلاثة
        #    (`frac` · `chem` · `ring`) — وهي **قائمةٌ متخلّفة**: الترميزات
        #    عشرة اليوم، فكان يمسح `\sup` و`\nuc` و`\sqrt` بعد أن
        #    وَلَّدها [_finish] فتصل الطالبَ أقواسُها عارية. و
        #    `format_arabic_math` تنتهي أصلاً بـ`latex_guard.clean` الذي
        #    **يحوّل** ما لا يعرفه إلى رمزه ولا يحذف إلا ما لا مقابل له.
        clean_answer = clean_answer.replace('_', ' ')
        answer = clean_answer
    except asyncio.TimeoutError:    
        # إذا تأخر الموديل المجاني، نرد بهذه الرسالة فوراً
        answer = "⚠️ عذراً، خوادم الذكاء الاصطناعي مشغولة حالياً بسبب الضغط. حاول مرة ثانية."
            
    except Exception as e:
        answer = f"خطأ: {str(e)}"
    
    return {"answer": answer, "references": refs, "session_active": False}


async def handle_chemistry_question(req: AskRequest, openai_client):
    """وضع السؤال - الكيمياء"""
    
    book = get_book_data()
    if not book: return {"answer": "❌ المادة غير متوفرة"}
    
    chat_history_from_app = req.chat_history or []
    valid_history = [msg for msg in chat_history_from_app if msg.get('role') in ['user', 'assistant']]
    recent_history = valid_history[-HISTORY_LAST_N:] if valid_history else []

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
            
        # 📚 **وهذا المسارُ كان بلا حارسِ وحدة** — سقط من المسح الأول
        #    لأن اسمَ دالّته يختلف عن أخواتها. راجع المسحَ في
        #    [tests/test_search_quality.py::test_every_search_path_is_guarded].
        if unit_missing(req):
            return unit_required_response()
        found = await enhanced_search_with_context(
            target_data, 
            # 🔴 **كان `req.content` هنا** — وهو في مسار الصور النصُّ
            #    الملفوف بدرع الحقن («بيانات، لا تعليمات…») وترويسته
            #    ضجيجٌ في البحث الدلالي. و`search_query` هو النصُّ
            #    النظيف الذي أُعدّ لهذا بالضبط ([models.AskRequest]).
            req.search_query, 
            recent_history, 
            top_k=5
        )
        results, idxs = found
        
        context_text = book_context(found, sep="\n", req=req,
                                    empty="لا توجد إجابة في الكتاب لهذا السؤال.")
        
        _, metas = extract_all_texts_and_metas_physics(target_data, SUBJECT)
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
            "content": (f"""
المعلومات المستخرجة من المنهج:
{context_text}

سؤال/رسالة الطالب: {req.content}

التعليمات:
1. إذا كان الطالب يقول "مرحبا"، "كيفك"، "شكراً"، رد بلطف وبشكل طبيعي كمعلم.
2. إذا كان سؤالاً في المادة، استخدم المعلومات المستخرجة للإجابة. وإن كان الموضوع موجوداً في المعلومات المستخرجة لكن بصياغة مختلفة أو موزّعاً على أكثر من موضع، فاجمعه وأجب منه — هذا استخدامٌ للنص لا تخمين. أما إذا كان الموضوع نفسه غير موجود في المعلومات المستخرجة، فلا تخمن! قل: "عذراً، هذه المعلومة غير متوفرة في المنهج المرفق".
3🧪 القواعد الكيميائية: اكتب المعادلات الكيميائية بنص عادي وواضح ومطابق حرفياً لما هو موجود في سياق الدرس (استخدم الأسهم العادية مثل -> أو =). اجعل كل معادلة في سطر مستقل لسهولة القراءة، ويُمنع منعاً باتاً تأليف معادلات خارجية أو استخدام أكواد LaTeX المعقدة — عدا **الكسور** فهي مطلوبة بصيغتها: كل بسط ومقام يُكتب \\frac{{البسط}}{{المقام}} ولا يُكتب بـ«/» ولا «÷».

════════════════════════════════════════════════════
⚗️ **الصيغ البنائية والحلقات — قاعدة مُلزِمة تسبق كل ما عداها**
════════════════════════════════════════════════════
🚫 **يُمنع منعاً باتاً رسم أي شكل بالرموز أو الشرطات أو داخل ```** —
   ولا تقل «لا أستطيع الرسم». أنت **تكتب ترميزاً** والتطبيق **يرسمه** للطالب.

📌 السلسلة المفتوحة ⇐ \\chem{{...}}
   • المجموعات موصولةً بشرطة: \\chem{{CH3-CH2-CH2-NH2}}
   • الفرع بين قوسين بعد أصله مباشرةً: \\chem{{CH3-CH(CH3)-CH3}}
   • الرابطة الثنائية = والثلاثية #: \\chem{{CH3-CH=O}} · \\chem{{CH3-C#N}}

📌 الحلقة ⇐ \\ring{{...}} — الأجزاء يفصلها | :
   • العدد أولاً: \\ring{{3}} مثلث · \\ring{{4}} مربع · \\ring{{6}} سداسي
   • ar للعطرية: \\ring{{6|ar}} بنزين
   • رمز الذرّة داخل الحلقة: \\ring{{6|ar|N}} بيريدين · \\ring{{6|NH}} بيبيريدين
   • +المجموعة المعلّقة: \\ring{{6|ar|+NH2}} أنيلين · \\ring{{3|+NH2}} أمينو سيكلوبروبان

⚠️ **هذه القاعدة أقوى من قاعدة «انقل بلغة الدرس حرفياً»**: إن كتب الكتاب
   الصيغة سطراً مسطّحاً فحوّلها أنت إلى \\chem أو \\ring. وكلّما ذكرتَ مركّباً
   عضوياً بالاسم (بروبان · سيكلوهيكسان · أنيلين …) أرفِق ترميزه بعده.

✅ مطلوب: «المركب \\chem{{CH3-NH-CH3}} يسمى ثنائي ميثيل أمين.»
❌ مرفوض: رسمٌ بالشرطات والخطوط داخل كتلة برمجية.

""" + turn_note(req))
        })
        
        # 🌊 يبثّ حرفاً حرفاً على مسار البثّ، وإلا نداءٌ عادي حرفياً.
        raw_answer = await streaming.complete(
            openai_client,
            sink=streaming.sink_of(req),
            messages=messages_for_ai,
            **subject_call("كيمياء", req),
            temperature=0.1,
        )
        clean_answer = format_arabic_math(raw_answer, "كيمياء")
        
        # ✅ فلتر التنظيف الجذري
        # ℹ️ حُذف من هنا فلترٌ يمسح كل أمرٍ لاتيكيّ عدا ثلاثة
        #    (`frac` · `chem` · `ring`) — وهي **قائمةٌ متخلّفة**: الترميزات
        #    عشرة اليوم، فكان يمسح `\sup` و`\nuc` و`\sqrt` بعد أن
        #    وَلَّدها [_finish] فتصل الطالبَ أقواسُها عارية. و
        #    `format_arabic_math` تنتهي أصلاً بـ`latex_guard.clean` الذي
        #    **يحوّل** ما لا يعرفه إلى رمزه ولا يحذف إلا ما لا مقابل له.
        clean_answer = clean_answer.replace('_', ' ')
        answer = clean_answer
    except asyncio.TimeoutError:    
        # إذا تأخر الموديل المجاني، نرد بهذه الرسالة فوراً
        answer = "⚠️ عذراً، خوادم الذكاء الاصطناعي مشغولة حالياً بسبب الضغط. حاول مرة ثانية." 
            
    except Exception as e:
        answer = f"حدث خطأ: {str(e)}"
    
    return {"answer": answer, "references": refs, "session_active": False}


async def handle_chemistry_exams(req: AskRequest, sessions: Dict, openai_client):
    """وضع الوزاري - الكيمياء"""
    
    _chemistry_session_timestamps[req.user_id] = time.time()
    cleanup_subject_sessions(sessions, _chemistry_session_timestamps)
    
    
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


async def handle_chemistry_request(req: AskRequest, openai_client):
    """معالج الطلب الرئيسي للكيمياء"""
    mode = req.mode.strip()
    if mode == "شرح": return await handle_chemistry_explain(req, openai_client)
    elif mode == "تلخيص": return await handle_chemistry_summary(req, openai_client)
    elif mode == "سؤال": return await handle_chemistry_question(req, openai_client)
    elif mode == "وزاري": return await handle_chemistry_exams(req, sessions_chemistry, openai_client)
    
    return {"answer": "وضع غير معروف"}