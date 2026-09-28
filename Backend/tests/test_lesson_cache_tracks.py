# -*- coding: utf-8 -*-
"""🤝 العلميُّ والأدبيُّ يتشاركان الشرحَ المخزون — والبصمةُ هي الحَكَم.

⚖️ أمرُ المالك (2026-09-29): «الإنجليزي العلمي الأدبي نفس كل شيء، حتى العربي…
   فخلّ نفس المخزون حقّهم». وكتابا المسارين متطابقان بايتاً ببايت.
"""
import json

import pytest

from core import lesson_cache as LC


@pytest.fixture
def store(tmp_path, monkeypatch):
    monkeypatch.setattr(LC, "EXPLANATIONS_DIR", tmp_path)
    LC._cache.clear()
    def put(grade, track, subject, unit, lesson, text, answer):
        p = tmp_path / str(grade) / track / f"{subject}.json"
        p.parent.mkdir(parents=True, exist_ok=True)
        data = json.loads(p.read_text(encoding="utf-8")) if p.exists() else {}
        data[LC.key_of(unit, lesson)] = {"hash": LC.fingerprint(text),
                                         "answer": answer, "spec": "v4"}
        p.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
    yield put
    LC._cache.clear()


def test_literary_reads_the_scientific_explanation(store):
    store(3, "علمي", "عربي", "النحو", "المفعول المطلق", "نصُّ الدرس", "شرحٌ مخزون")
    assert LC.get(3, "أدبي", "عربي", "النحو", "المفعول المطلق", "نصُّ الدرس") == "شرحٌ مخزون"


def test_and_the_other_way_round(store):
    store(2, "أدبي", "انجليزي", "U1", "Passive", "text", "stored")
    assert LC.get(2, "علمي", "انجليزي", "U1", "Passive", "text") == "stored"


def test_diverged_books_do_not_share(store):
    """☢️ درسٌ عُدّل في الأدبي وحده ⇒ لا يُعرض عليه شرحُ العلمي."""
    store(3, "علمي", "عربي", "النحو", "الحال", "نصٌّ قديم", "شرحُ النصّ القديم")
    assert LC.get(3, "أدبي", "عربي", "النحو", "الحال", "نصٌّ مُعدَّل") is None


def test_own_track_wins_when_both_exist(store):
    store(2, "علمي", "عربي", "U", "L", "t", "علمي")
    store(2, "أدبي", "عربي", "U", "L", "t", "أدبي")
    assert LC.get(2, "أدبي", "عربي", "U", "L", "t") == "أدبي"


def test_general_track_has_no_sibling(store):
    """الأولُ «عام» بلا شقيق — لا يقرأ من غيره."""
    store(2, "علمي", "عربي", "U", "L", "t", "x")
    assert LC.get(1, "عام", "عربي", "U", "L", "t") is None


def test_builder_skips_what_the_sibling_already_built(store):
    """🏗️ و`entry_spec` يرى الشقيقَ أيضاً — فلا يُبنى الدرسُ مرّتين ولا يُدفع مرّتين."""
    store(3, "علمي", "انجليزي", "U", "L", "t", "x")
    assert LC.entry_spec(3, "أدبي", "انجليزي", "U", "L", "t") == "v4"
