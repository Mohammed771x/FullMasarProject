# ==================================================
# 📦 Models Configuration - إدارة الموديلات والتحقق من التوافق
# ==================================================

AVAILABLE_MODELS = {
    "groq": {
        "default": "llama-groq",
        "models": [
            {
                "id": "llama-groq",
                "name": "لاما 3.1 - سريع وخفيف",
                "api": "groq",
                "model_name": "llama-3.1-8b-instant",
                "description": "موديل سريع من Groq",
                "speed": "سريع جداً",
                "quality": "جيد",
                "cost": "مجاني",
                "compatible_subjects": ["رياضيات", "فيزياء"],
                "incompatible_subjects": ["احياء"]
            }
        ]
    },
    "openrouter": {
        "default": "nemotron-nano",
        "models": [
            {
                "id": "nemotron-nano",
                "name": "نيمترون نانو",
                "api": "openrouter",
                "model_name": "nvidia/nemotron-3-nano-30b-a3b:free",
                "description": "موديل متوازن - سريع وجودة عالية",
                "speed": "سريع",
                "quality": "ممتاز",
                "cost": "مجاني",
                "compatible_subjects": ["احياء", "كيمياء", "فيزياء", "رياضيات"],
                "incompatible_subjects": []
            },
            {
                "id": "deepseek-rt2",
                "name": "ديب سيك R1 T2",
                "api": "openrouter",
                "model_name": "tngtech/deepseek-r1t2-chimera:free",
                "description": "موديل متقدم للحسابات المعقدة",
                "speed": "متوسط",
                "quality": "ممتاز جداً",
                "cost": "مجاني",
                "compatible_subjects": ["رياضيات", "فيزياء", "كيمياء"],
                "incompatible_subjects": []
            }
        ]
    }
}

def get_model_details(model_id: str) -> dict:
    """
    جلب تفاصيل موديل معين
    """
    for api_type in AVAILABLE_MODELS.values():
        for model in api_type.get("models", []):
            if model["id"] == model_id:
                return model
    # إرجاع الموديل الافتراضي إذا لم يُوجد
    return AVAILABLE_MODELS["openrouter"]["models"][0]

def get_all_models_list() -> list:
    """
    جلب قائمة بجميع الموديلات المتاحة
    """
    all_models = []
    for api_type in AVAILABLE_MODELS.values():
        all_models.extend(api_type.get("models", []))
    return all_models

def get_api_for_model(model_id: str) -> str:
    """
    جلب API نوع الموديل
    """
    model = get_model_details(model_id)
    return model.get("api", "openrouter")

def is_model_compatible_with_subject(model_id: str, subject: str) -> bool:
    """
    ✅ التحقق من توافق الموديل مع المادة
    
    مثال:
    - لاما يعمل مع الرياضيات فقط
    - نيمترون يعمل مع جميع المواد
    """
    model = get_model_details(model_id)
    
    # إذا كانت المادة في قائمة المتوافقة
    if subject in model.get("compatible_subjects", []):
        return True
    
    # إذا كانت المادة في قائمة غير المتوافقة
    if subject in model.get("incompatible_subjects", []):
        return False
    
    # افتراضياً: إذا لم تكن محددة، افترض أنها متوافقة
    return True

def get_compatible_models_for_subject(subject: str) -> list:
    """
    🔍 جلب جميع الموديلات المتوافقة مع مادة معينة
    """
    compatible = []
    for model in get_all_models_list():
        if is_model_compatible_with_subject(model["id"], subject):
            compatible.append(model)
    return compatible

def get_safe_model_for_subject(model_id: str, subject: str) -> str:
    """
    🛡️ جلب موديل آمن بديل إذا كان الموديل المختار غير متوافق
    
    المنطق:
    - إذا كان الموديل متوافق → استخدمه
    - إذا لم يكن متوافق → أرجع أول موديل متوافق
    """
    if is_model_compatible_with_subject(model_id, subject):
        return model_id
    
    # جلب أول موديل متوافق
    compatible = get_compatible_models_for_subject(subject)
    if compatible:
        return compatible[0]["id"]
    
    # fallback: استخدم النيمترون (الأكثر أماناً)
    return "nemotron-nano"

def get_default_model_for_subject(subject: str) -> str:
    """
    📌 جلب الموديل الافتراضي الأمثل لكل مادة
    """
    defaults = {
        "رياضيات": "deepseek-rt2",  # للرياضيات: deepseek أفضل
        "احياء": "nemotron-nano",     # للأحياء: نيمترون (لاما يسبب مشاكل)
        "فيزياء": "nemotron-nano",
        "كيمياء": "nemotron-nano",
    }
    return defaults.get(subject, "nemotron-nano")

def get_default_model_for_math_mode(mode: str) -> str:
    """
    📌 اختيار الموديل المثالي حسب وضع الرياضيات
    
    - شرح: استخدم deepseek (أفضل للشرح المفصل)
    - سؤال: استخدم nemotron (أسرع للإجابات المباشرة)
    - وزاري: استخدم deepseek (للحسابات المعقدة)
    """
    if mode in ["شرح", "وزاري"]:
        return "deepseek-rt2"
    elif mode == "سؤال":
        return "nemotron-nano"
    else:
        return "nemotron-nano"

# ====== دالة مساعدة للتحقق السريع ======
def validate_model_selection(model_id: str, subject: str) -> dict:
    """
    ✅ فحص شامل لاختيار الموديل
    يرجع:
    - is_valid: هل الموديل متوافق
    - safe_model: الموديل البديل الآمن إذا لم يكن متوافق
    - warning: رسالة تحذير إذا لزم الأمر
    """
    is_compatible = is_model_compatible_with_subject(model_id, subject)
    safe_model = get_safe_model_for_subject(model_id, subject)
    
    warning = None
    if not is_compatible:
        warning = f"⚠️ الموديل '{model_id}' قد لا يعمل بشكل جيد مع مادة '{subject}'. تم التبديل إلى: {safe_model}"
    
    return {
        "is_valid": is_compatible,
        "safe_model": safe_model,
        "warning": warning,
        "original_model": model_id
    }