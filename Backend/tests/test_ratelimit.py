import time
from core import ratelimit as rl

class FakeReq:
    def __init__(self, ip="1.2.3.4", fwd=None):
        self.headers = {"x-forwarded-for": fwd} if fwd else {}
        self.client = type("C", (), {"host": ip})()

def setup_function(_):
    rl._buckets.clear()

def test_allows_under_limit():
    r = FakeReq()
    for _ in range(rl.ASK_LIMIT):
        assert rl.check(r, "u1")

def test_blocks_over_limit():
    r = FakeReq()
    for _ in range(rl.ASK_LIMIT):
        rl.check(r, "u1")
    assert not rl.check(r, "u1")

def test_different_users_independent():
    r = FakeReq()
    for _ in range(rl.ASK_LIMIT):
        rl.check(r, "u1")
    assert rl.check(r, "u2")

def test_forwarded_for_used():
    r1 = FakeReq(fwd="9.9.9.9, 10.0.0.1")
    r2 = FakeReq(fwd="8.8.8.8, 10.0.0.1")
    for _ in range(rl.ASK_LIMIT):
        rl.check(r1, "u")
    assert not rl.check(r1, "u")
    assert rl.check(r2, "u")       # IP مختلف → عداد مستقل

def test_window_slides():
    r = FakeReq()
    for _ in range(rl.ASK_LIMIT):
        rl.check(r, "u1", window=0.2)
    assert not rl.check(r, "u1", window=0.2)
    time.sleep(0.25)
    assert rl.check(r, "u1", window=0.2)

def test_fail_open_on_broken_request():
    assert rl.check(object(), "u1")   # كائن ناقص → السماح لا الانهيار
