# ==================================================
# 🌊 core/streaming.py — بثّ الإجابة حرفاً بحرف
# ==================================================
# 🔴 **ما كان يحدث:** الطالب يضغط «إرسال» فيحدّق في مؤشّر تحميل **حتى ٦٠
#    ثانية** ثم يظهر النص دفعةً واحدة. وشرحُ درسٍ كامل يستغرق ٢٠–٤٠ ثانية،
#    فالانتظار الصامت هو التجربة الغالبة لا الاستثناء — ومنه يُحكَم على
#    المنتج كله بالبطء وإن كان الجواب ممتازاً.
#
# ⭐ **والبثّ لا يجعل الجواب أسرع، بل يجعل الانتظار مفهوماً**: أول كلمة تصل
#    خلال ثانيتين، فيبدأ الطالب القراءة بينما البقية تُكتب. هذا وحده يغيّر
#    الإحساس بالمنتج أكثر من أي تحسينٍ في زمن التوليد.
#
# ══════════════════════════════════════════════════
# 🧩 التصميم: «مصرف» (Sink) يمرّ مع الطلب
# ══════════════════════════════════════════════════
# ⚠️ **لماذا لا نُعيد كتابة المعالجات الأربعة عشر؟** لأن كل واحدٍ منها
#    يحمل منطق مادته ومحاولاته وتدقيقه، وتحويلها جميعاً دفعةً واحدة تغييرٌ
#    واسع الأثر بلا حاجة. فالمصرف يمرّ مع الطلب:
#
#      • معالجٌ **يعرف** المصرف ⇒ يبثّ حرفاً حرفاً.
#      • معالجٌ **لا يعرفه**   ⇒ يعمل كما كان، والمسار يبثّ جوابه دفعةً
#        واحدة في النهاية.
#
#    فالعميل يستعمل **مسار البثّ دائماً** ولا يرى فرقاً في التعامل — إنما
#    في نعومة الوصول. وتحويلُ معالجٍ جديد لاحقاً سطرٌ واحد فيه.
#
# 📡 **البروتوكول SSE** (`text/event-stream`) — لا WebSocket:
#    اتجاهٌ واحد يكفي، ويمرّ عبر كل بروكسي HTTP بلا إعداد، ويُقرأ في فلاتر
#    بـ`http.Client.send` بلا أي حزمة إضافية.
#
#    الأحداث:
#      `{"t":"delta","v":"نص"}`  ← جزءٌ جديد يُلحق بالفقاعة
#      `{"t":"done", ...}`        ← الرد الكامل + المراجع + الأعلام
#      `{"t":"error","v":"..."}`  ← رسالة عربية جاهزة للعرض

import asyncio
import json

from . import billing

# ⏱️ نبضةٌ كل ١٥ ثانية حين لا يصل شيء من الموديل.
#
# ⚠️ **ليست تحسيناً:** بروكسيات كثيرة (وHF Spaces منها) تقطع اتصالاً صامتاً
#    بعد مهلة، فيرى الطالب انقطاعاً في منتصف شرحٍ يعمل. والتعليق `:` في SSE
#    يُبقي الاتصال حيّاً ويتجاهله العميل بالتعريف.
HEARTBEAT_SECONDS = 15.0

# سقف انتظار جزءٍ واحد من الموديل قبل اعتبار البثّ ميتاً.
CHUNK_TIMEOUT = 90.0


class StreamSink:
    """قناةٌ يكتب فيها المعالج ويقرأ منها المسار.

    طابورٌ غير محدود عمداً: الموديل أبطأ من الشبكة دائماً، فالضغط العكسي
    هنا حلٌّ لمشكلةٍ لا تقع — وتحديدُ السعة كان سيعلّق التوليد بلا سبب.
    """

    def __init__(self):
        self._queue: asyncio.Queue = asyncio.Queue()
        self._closed = False
        # النص المتراكم — يحتاجه المعالج ليُرجع الجواب كاملاً كالمعتاد.
        self.text_parts: list[str] = []

    async def push(self, delta: str) -> None:
        """يدفع جزءاً للطالب **وللنص المتراكم معاً**."""
        if not delta or self._closed:
            return
        self.text_parts.append(delta)
        await self._queue.put(delta)

    @property
    def text(self) -> str:
        return "".join(self.text_parts)

    async def close(self) -> None:
        if not self._closed:
            self._closed = True
            await self._queue.put(None)

    async def drain(self):
        """يُنتج الأجزاء حتى الإغلاق — يستعمله المسار وحده."""
        while True:
            chunk = await self._queue.get()
            if chunk is None:
                return
            yield chunk


def sink_of(req):
    """مصرف هذا الطلب إن وُجد. المعالجات تنادي هذه لا تقرأ السمة مباشرةً."""
    return getattr(req, "_stream_sink", None)


def attach(req, sink: StreamSink) -> None:
    """يربط المصرف بالطلب قبل تسليمه للمعالج."""
    # ⚠️ سمةٌ ديناميكية لا حقلٌ في النموذج: `request_id` وإخوته بيانات يرسلها
    #    العميل، وهذا كائنٌ حيّ لا يُسلسَل ولا يجوز أن يقبله Pydantic أصلاً.
    object.__setattr__(req, "_stream_sink", sink)


async def complete(client, *, model, messages, sink=None, timeout=50.0, **kwargs):
    """نداءُ الموديل — يبثّ إن وُجد مصرف، وإلا يعمل كما كان حرفياً.

    يعيد **النص الكامل** في الحالتين، فالمعالج لا يتغيّر إلا في هذا السطر.

    🛟 **وسقوط البثّ لا يُسقط الجواب:** مزوّدٌ لا يدعم `stream` أو ينقطع في
       منتصفه ⇒ نعود للنداء العادي مرةً واحدة. الطالب يرى تأخيراً لا خطأً.
    """
    # 🧾 **كلُّ نداءِ موديلٍ على مسار السؤال يمرّ من هنا** — فهنا يُسجَّل.
    #    عليه تقوم قاعدةُ «ما لم يُنادَ موديلٌ لا يُخصم» ([core/billing.py]).
    billing.charge()

    if sink is None:
        response = await asyncio.wait_for(
            client.chat.completions.create(
                model=model, messages=messages, **kwargs),
            timeout=timeout)
        return response.choices[0].message.content or ""

    try:
        return await _stream_into(client, model, messages, sink, timeout, kwargs)
    except asyncio.TimeoutError:
        raise
    except Exception as e:                     # noqa: BLE001
        # ⚠️ ما وصل الطالبَ قبل السقوط يبقى معروضاً — فلا نُعيد المحاولة إن
        #    كان قد بدأ فعلاً، وإلا رأى الشرح مرتين متداخلين.
        if sink.text_parts:
            raise
        print(f"⚠️ تعذّر البثّ ({e}) — رجعنا للنداء العادي.")
        response = await asyncio.wait_for(
            client.chat.completions.create(
                model=model, messages=messages, **kwargs),
            timeout=timeout)
        text = response.choices[0].message.content or ""
        await sink.push(text)
        return text


async def _stream_into(client, model, messages, sink, timeout, kwargs):
    """يفتح بثّ المزوّد ويدفع كل جزء إلى المصرف."""
    stream = await asyncio.wait_for(
        client.chat.completions.create(
            model=model, messages=messages, stream=True, **kwargs),
        timeout=timeout)

    async def _pump():
        async for chunk in stream:
            choices = getattr(chunk, "choices", None)
            if not choices:
                continue
            delta = getattr(choices[0], "delta", None)
            piece = getattr(delta, "content", None) if delta else None
            if piece:
                await sink.push(piece)

    # ⏱️ مهلةٌ على **البثّ كله** لا على كل جزء: مهلةُ الجزء الواحد كانت
    #    ستقطع شرحاً طويلاً يعمل بلا عطل.
    await asyncio.wait_for(_pump(), timeout=CHUNK_TIMEOUT)
    return sink.text


# ══════════════════════════════════════════════════
# 📡 ترميز أحداث SSE
# ══════════════════════════════════════════════════

def event(payload: dict) -> str:
    """سطر SSE واحد. `ensure_ascii=False` كي لا تتضخّم العربية أربعة أضعاف."""
    return f"data: {json.dumps(payload, ensure_ascii=False)}\n\n"


def delta_event(text: str) -> str:
    return event({"t": "delta", "v": text})


def done_event(payload: dict) -> str:
    return event({**payload, "t": "done"})


def error_event(message: str) -> str:
    return event({"t": "error", "v": message})


HEARTBEAT = ": keep-alive\n\n"

# ترويسات تمنع البروكسيات والمتصفحات من تجميع البثّ في دفعةٍ واحدة.
#
# ⚠️ `X-Accel-Buffering` ليست زخرفة: nginx (وهو أمام أكثر منصات النشر)
#    يُخزّن الرد افتراضياً، فيصل البثّ كله **دفعةً واحدة في النهاية** —
#    أي أن الميزة تختفي تماماً في الإنتاج بينما تعمل محلياً بلا شكوى.
SSE_HEADERS = {
    "Cache-Control": "no-cache, no-transform",
    "Connection": "keep-alive",
    "X-Accel-Buffering": "no",
}
