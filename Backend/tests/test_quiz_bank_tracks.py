# -*- coding: utf-8 -*-
"""🤝 بنكُ اختبر نفسك يتشاركه العلميُّ والأدبيّ — والبصمةُ هي الحَكَم.

نظيرُ tests/test_lesson_cache_tracks.py: قِيس قبله أن الثالث علمي فيه ٢٨ بنكاً
للعربي والإنجليزي والأدبي صفر، فكان اختبارُ الأدبيّ يُولَّد حيّاً في كل مرة.
"""
import json

import pytest

from core import quiz_bank as QB

_Q = [{"q": "سؤال", "options": ["أ", "ب", "ج", "د"], "correct_index": 0}]


@pytest.fixture
def store(tmp_path, monkeypatch):
    monkeypatch.setattr(QB, "QUIZZES_DIR", tmp_path)
    QB._cache.clear()
    def put(grade, track, subject, unit, lesson, text, questions=_Q):
        p = tmp_path / str(grade) / track / f"{subject}.json"
        p.parent.mkdir(parents=True, exist_ok=True)
        data = json.loads(p.read_text(encoding="utf-8")) if p.exists() else {}
        data[QB.key_of(unit, lesson)] = {"hash": QB.fingerprint(text),
                                         "questions": questions, "spec": "s1"}
        p.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
    yield put
    QB._cache.clear()


def test_literary_reads_the_scientific_bank(store):
    store(3, "علمي", "عربي", "النحو", "المفعول المطلق", "نصّ")
    assert QB.stored_for(3, "أدبي", "عربي", "النحو", "المفعول المطلق", "نصّ") == _Q


def test_and_the_other_way_round(store):
    store(2, "أدبي", "انجليزي", "U1", "Passive", "text")
    assert QB.stored_for(2, "علمي", "انجليزي", "U1", "Passive", "text") == _Q


def test_diverged_books_do_not_share(store):
    store(3, "علمي", "عربي", "النحو", "الحال", "نصّ العلمي")
    assert QB.stored_for(3, "أدبي", "عربي", "النحو", "الحال", "نصّ الأدبي المعدَّل") is None


def test_own_track_wins(store):
    own = [{"q": "خاص", "options": ["1", "2", "3", "4"], "correct_index": 1}]
    store(3, "علمي", "عربي", "النحو", "الحال", "نصّ")
    store(3, "أدبي", "عربي", "النحو", "الحال", "نصّ", own)
    assert QB.stored_for(3, "أدبي", "عربي", "النحو", "الحال", "نصّ") == own


def test_general_track_has_no_sibling(store):
    store(1, "علمي", "عربي", "النحو", "الحال", "نصّ")
    assert QB.stored_for(1, "عام", "عربي", "النحو", "الحال", "نصّ") is None


def test_entry_spec_sees_the_sibling(store):
    store(2, "علمي", "عربي", "النحو", "الحال", "نصّ")
    assert QB.entry_spec(2, "أدبي", "عربي", "النحو", "الحال", "نصّ") == "s1"
