# -*- coding: utf-8 -*-
"""📄 الصفحاتُ المطلوبة — اختيارُ الطالب

    جزءٌ من [subjects/common] — فُصل 2026-09-20 بأمر المالك:
    «كل مادة/قسم في ملفٍ لحاله، فالتعديلُ على نطاقٍ أقلّ».
    والنصُّ هنا **منقولٌ حرفاً بحرف** من الملف الأصل بلا تغيير سطر.
"""
import re
from typing import List
from .content import prepare_source
from .context import hybrid_rank


def pages_with_headers(pages, subject=None):
    """نصُّ الصفحات للحقن في البرومبت — مُصلَحاً **قبل أن يراه الموديل**.

    ٠١٢ والأرقام تُعرَّب هنا أيضاً لا في المخرَج وحده: البرومبت يأمر
        بالنقل حرفياً، فما وصله عربياً نقله عربياً من تلقائه، ولا يبقى
        لفلتر [_finish] إلا الشوارد ([core/arabic_digits.py]).
    """
    from core.arabic_digits import for_subject as _arabic_digits
    blocks = []
    for p in pages:
        blocks.append(_arabic_digits(
            f"📄 الصفحة {p['رقم_الصفحة']}:\n"
            f"{prepare_source(p['نص_الصفحة'], subject)}", subject))
    return "\n\n".join(blocks)



def requested_pages(req) -> List[int]:
    """أرقام الصفحات المطلوبة — **مصدرٌ واحد لكل المواد**.

    🔴 **لماذا دالّة لا سطران؟** كان الاستخراج مكرّراً في ثلاثة مواضع
       (`pages_mode` ومرّتين في الأحياء)، فأيُّ تحسينٍ يصيب بعضَها ويُخطئ
       بعضَها. وقد وقع فعلاً: الاختيار المُبنيَن وُصل بـ`pages_mode` وحده،
       فبقيت الأحياء — وهي أكثر المواد استعمالاً لوضع الصفحات — تتجاهل
       ما يختاره الطالب ([sweep-siblings-before-reporting]).

    ⚖️ والأولوية للاختيار المُبنيَن، ثم استخراجُ الأرقام من الكلام —
       والثاني يبقى للعملاء القدامى ولمن كتبها بيده.
    """
    picked = list(getattr(req, "selected_pages", None) or [])
    if picked:
        return picked
    return [int(n) for n in re.findall(r"\d+", req.page_source or "")]


def fetch_pages_by_numbers(book_data: List[dict], page_nums: List[int]):
    """جلب صفحات محددة برقمها"""
    found = []
    missing = []
    for p in page_nums:
        found_flag = False
        for unit in book_data:
            for page in unit.get("الصفحات", []):
                if page.get("رقم_الصفحة") == p:
                    found.append(page)
                    found_flag = True
                    break
            if found_flag:
                break
        if not found_flag:
            missing.append(p)
    return found, missing



def extract_all_texts_and_metas_physics(book_data: List[dict], subject=None):
    """استخراج جميع النصوص من بيانات الفيزياء بذكاء لدعم المعادلات والمسائل"""
    texts = []
    metas = []
    
    for unit in book_data:
        unit_name = unit.get("اسم_الوحدة", "")
        
        for lesson in unit.get("الدروس", []):
            lesson_name = lesson.get("اسم_الدرس", "")
            
            for part in lesson.get("الأجزاء", []):
                part_type = part.get("نوع", "")
                part_name = part.get("اسم_الجزء", "")
                
                content = part.get("المحتوى", [])
                
                if isinstance(content, list):
                    for item in content:
                        # ✅ التعديل السحري هنا: قراءة كل المفاتيح بذكاء
                        if isinstance(item, dict):
                            text_parts = []
                            # 1. إذا كان تعريف
                            if "المصطلح" in item:
                                text_parts.append(f"{item.get('المصطلح')}: {item.get('التعريف', '')}")
                            
                            # 2. إذا كانت معادلة أو مسألة حسابية (هنا كان الخلل)
                            if "الصيغة" in item:
                                text_parts.append(f"السؤال أو القانون: {item.get('الصيغة')}")
                            if "الاستخدام" in item:
                                text_parts.append(f"طريقة الحل: {item.get('الاستخدام')}")
                            if "مثال_رقمي" in item:
                                text_parts.append(f"الحل بالخطوات: {item.get('مثال_رقمي')}")
                                
                            # 3. احتياط لأي مفاتيح جديدة في المستقبل
                            if not text_parts:
                                for k, v in item.items():
                                    text_parts.append(f"{k}: {v}")
                            
                            text = " | ".join(text_parts)
                            
                        # إذا كان نص عادي (نقاط)
                        else:
                            text = str(item)
                        
                        if text.strip():
                            texts.append(text)
                            metas.append({
                                "unit": unit_name,
                                "lesson": lesson_name,
                                "part_type": part_type,
                                "part_name": part_name
                            })
                else:
                    # محتوى نصي مباشر
                    if content:
                        texts.append(str(content))
                        metas.append({
                            "unit": unit_name,
                            "lesson": lesson_name,
                            "part_type": part_type,
                            "part_name": part_name
                        })
    
    # 🧮 نفس القاعدة هنا: نصّ الدرس المهيكل يصل الموديل بكسور مرمَّزة
    return [prepare_source(t, subject) for t in texts], metas


async def enhanced_search_physics(book_data, query, top_k=5, subject=None):
    # ⚗️ و`subject` يمرّ كي تصل الصيغُ العضوية مرمَّزة في المسار القديم
    #    أيضاً — كان يُستدعى بلا مادة فتسقط الحلقات والسلاسل عن الكيمياء.
    texts, _metas = extract_all_texts_and_metas_physics(book_data, subject)
    if not texts:
        return [], []
    # 🔄 نفس الترتيب الهجين — كان هنا **نفسُ عطل الدمج بالأسبقية** حرفياً،
    #    وهذه الدالّة تخدم الفيزياء والكيمياء والعربي معاً.
    return await hybrid_rank(texts, query, top_k)




