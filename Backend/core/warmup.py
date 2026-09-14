# ==================================================
# 🔥 core/warmup.py — إحماء الفهارس عند إقلاع الخادم
# ==================================================
# القاعدة: **لا يبني الطالبُ فهرساً أبداً.** كل ما قد يُسأل عنه يكون جاهزاً
# قبل أول طلب — في الذاكرة، ومحفوظاً على القرص للإقلاع التالي.
#
# يُبنى لكل مادة/صف/مسار له محتوى:
#   • فهرس الكتاب كاملاً        ← حين يختار الطالب «الكل»
#   • فهرس لكل وحدة على حدة     ← حين يحصر سؤاله في وحدة
# وهي **نفس الشرائح** التي تمرّرها المعالجات وقت الطلب، فالبصمات تتطابق
# ويصير الطلب قراءةً من الذاكرة لا بناءً.
#
# يعمل في خيط خلفي: الخادم يستقبل الطلبات فوراً، والإحماء يكتمل خلف الكواليس.
# حالته تُقرأ من `GET /health/indexes`.

import time
import threading
import traceback

from core import index_store
from core.curriculum import SUBJECTS_BY_GRADE_TRACK

_thread = None


def _providers():
    """(اسم الوصف، دالة استخراج النصوص) لكل مادة — مطابقة لما تفعله المعالجات."""
    from subjects.common import (
        extract_all_texts_and_metas,
        extract_all_texts_and_metas_physics,
    )
    from subjects.english import extract_english_texts_flattened

    return {
        "احياء": extract_all_texts_and_metas,               # صيغة الصفحات
        "رياضيات": extract_all_texts_and_metas,
        "فيزياء": extract_all_texts_and_metas_physics,      # صيغة الدروس/الأجزاء
        "كيمياء": extract_all_texts_and_metas_physics,
        "عربي": extract_all_texts_and_metas_physics,
        "انجليزي": lambda units: (extract_english_texts_flattened(units)),
    }


def _units_of(subject: str, grade: int, track: str):
    """قائمة وحدات المادة لصف/مسار — أو None إن لم يوجد محتوى."""
    from subjects.common import subject_book_path, load_json_safe

    book = load_json_safe(subject_book_path(subject, grade, track))
    if not book:
        return None
    return book if isinstance(book, list) else book.get("الوحدات", [])


def build_all(verbose: bool = True) -> dict:
    """يبني (أو يحمّل) كل الفهارس. يعيد ملخّصاً."""
    from subjects.common import build_index_sync, embedding_corpus

    started = time.time()
    index_store._stats["warm_started_at"] = time.strftime("%H:%M:%S")
    providers = _providers()
    built = loaded = skipped = 0
    errors = []

    for (grade, track), subjects in SUBJECTS_BY_GRADE_TRACK.items():
        for subject in subjects:
            fn = providers.get(subject)
            if fn is None:
                continue                      # مادة نظرية بلا بحث دلالي بعد
            try:
                units = _units_of(subject, grade, track)
            except Exception as e:
                errors.append(f"{subject} g{grade}/{track}: {e}")
                continue
            if not units:
                skipped += 1                  # لا محتوى لهذا الصف — طبيعي
                continue

            # الكتاب كاملاً + كل وحدة على حدة
            slices = [("الكل", units)] + [
                (u.get("اسم_الوحدة", f"وحدة{i}"), [u])
                for i, u in enumerate(units) if isinstance(u, dict)
            ]

            for unit_name, data in slices:
                try:
                    texts, _ = fn(data)
                except Exception as e:
                    errors.append(f"{subject}/{unit_name}: {e}")
                    continue
                if not texts:
                    continue

                # ✂️ **الفهرسُ على المقاطع لا على الصفحات** — وهي بعينها
                #    التي يستعملها البحث ([common.embedding_corpus]). لو
                #    أحمينا فهرسَ الصفحات وبحثنا في فهرس المقاطع لبنى كلُّ
                #    سؤالٍ أولَ فهرسِه أثناء انتظار الطالب.
                texts, _owners = embedding_corpus(texts)
                if not texts:
                    continue

                fp = index_store.fingerprint(texts)
                if index_store.get_mem(fp) is not None:
                    continue
                index = index_store.load_disk(fp)
                if index is not None:
                    index_store.put_mem(fp, index)
                    loaded += 1
                    continue

                try:
                    index = build_index_sync(texts)
                    index_store.put_mem(fp, index)
                    index_store.save_disk(fp, index, {
                        "subject": subject, "grade": grade, "track": track,
                        "unit": unit_name, "texts": len(texts), "chunked": True,
                    })
                    built += 1
                except Exception as e:
                    errors.append(f"{subject}/{unit_name}: {e}")

    took = time.time() - started
    index_store._stats.update({
        "warm_done": True, "warm_seconds": round(took, 1), "warm_errors": errors[:10],
    })
    summary = {"built": built, "loaded_from_disk": loaded,
               "no_content": skipped, "errors": len(errors), "seconds": round(took, 1)}
    if verbose:
        print(f"🔥 إحماء الفهارس: بُني {built} · حُمِّل من القرص {loaded} · "
              f"بلا محتوى {skipped} · أخطاء {len(errors)} · {took:.1f}s")
        for e in errors[:5]:
            print("   ⚠️", e)
    return summary


def start_background():
    """يبدأ الإحماء في خيط خلفي — لا يؤخّر استقبال الطلبات."""
    global _thread
    if _thread is not None and _thread.is_alive():
        return
    def _run():
        try:
            build_all()
        except Exception:
            print("⚠️ فشل الإحماء:\n" + traceback.format_exc())
            index_store._stats["warm_done"] = True
    _thread = threading.Thread(target=_run, name="index-warmup", daemon=True)
    _thread.start()


def is_running() -> bool:
    return _thread is not None and _thread.is_alive()
