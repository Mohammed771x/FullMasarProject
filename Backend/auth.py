import os
import json
import tempfile
import threading
from pathlib import Path

ORIGINAL_CODES_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "codes.json")
WRITABLE_CODES_FILE = "/tmp/active_codes.json"

_codes_lock = threading.Lock()

def load_codes():
    target_file = WRITABLE_CODES_FILE if os.path.exists(WRITABLE_CODES_FILE) else ORIGINAL_CODES_FILE
    if not os.path.exists(target_file):
        return {"active_codes": {}}
    try:
        with open(target_file, "r", encoding="utf-8") as f:
            return json.load(f)
    except json.JSONDecodeError:
        print("⚠️ ملف الأكواد قيد الكتابة مؤقتاً")
        return {"active_codes": {}}
    except Exception as e:
        print(f"Error loading codes: {e}")
        return {"active_codes": {}}

def save_codes(data):
    temp_path = ""
    try:
        fd, temp_path = tempfile.mkstemp(dir="/tmp")
        with os.fdopen(fd, 'w', encoding="utf-8") as f:
            json.dump(data, f, indent=4, ensure_ascii=False)
        os.replace(temp_path, WRITABLE_CODES_FILE)
    except Exception as e:
        print(f"Error saving codes: {e}")
        if temp_path and os.path.exists(temp_path):
            os.remove(temp_path)

def verify_code(code: str, device_id: str):
    with _codes_lock:  # ← lock واحد يغطي كل العملية
        data = load_codes()
        codes_db = data.get("active_codes", {})
        input_code = code.strip()

        if input_code not in codes_db:
            return {"status": "error", "message": "❌ كود التفعيل غير صحيح."}

        code_info = codes_db[input_code]
        code_type = code_info.get("type", "single")
        saved_device = code_info.get("device_id")

        if code_type == "master":
            return {"status": "success", "message": "✅ مرحباً بك (دخول مشرف)."}

        if code_type == "single":
            if saved_device is None:
                code_info["device_id"] = device_id
                codes_db[input_code] = code_info
                data["active_codes"] = codes_db
                save_codes(data)
                return {"status": "success", "message": "✅ تم تفعيل الكود على هذا الجهاز."}
            elif saved_device == device_id:
                return {"status": "success", "message": "✅ مرحباً بك مجدداً."}
            else:
                return {"status": "error", "message": "⛔ هذا الكود مستخدم بالفعل على جهاز آخر!"}

        return {"status": "error", "message": "حدث خطأ غير متوقع."}