"""عملاء AI وهميون بواجهة OpenAI — تُستخدم في كل الاختبارات.
⚠️ وجودها يضمن ألا تنادي الاختبارات أي مزوّد حقيقي (وألا تُكلّف مالاً)."""


class FakeMsg:
    def __init__(self, content):
        self.message = type("M", (), {"content": content})()


class FakeResp:
    def __init__(self, content):
        self.choices = [FakeMsg(content)]


def make_fake_client(tag: str, vision_reply: str = "نص مستخرج من الصورة"):
    """يميّز نداء الرؤية (محتوى قائمة) عن النص العادي."""
    class _Completions:
        @staticmethod
        async def create(**kw):
            msgs = kw.get("messages", [])
            if any(isinstance(m.get("content"), list) for m in msgs):
                return FakeResp(vision_reply)
            user = next((m for m in msgs if m.get("role") == "user"), {"content": ""})
            return FakeResp(f"{tag}::" + str(user["content"])[:6000])

    class _Chat:
        completions = _Completions()

    return type("FakeClient", (), {"chat": _Chat()})()
