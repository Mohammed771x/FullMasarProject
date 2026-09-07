#!/bin/bash
# ==================================================
# 🖥️  tools/server.sh — تشغيل خادم مسار المحلي وإيقافه
# ==================================================
#   ./tools/server.sh start | stop | restart | status | log
#
# ⚠️ لماذا سكربت بدل أمرٍ مباشر؟ فخّان وقعا فعلاً:
#   ١) الخادم المُشغَّل داخل مهمة يموت مع مجموعة عملياتها — فنفصله بـ setsid
#      (وهي غير موجودة على macOS كأمر، فنستدعيها من بايثون).
#   ٢) SIGTERM وحده قد يعلّق الخادم «بانتظار مهام الخلفية» وهو ماسكٌ المنفذ،
#      فيفشل التشغيل التالي بصمت — لذا نتحقق ونستعمل -9 عند اللزوم.

cd "$(dirname "$0")/.." || exit 1
PORT=8000
PY=.venv/bin/python

listening() { lsof -nP -iTCP:$PORT -sTCP:LISTEN -t 2>/dev/null; }

start() {
  if [ -n "$(listening)" ]; then
    echo "✅ الخادم يعمل أصلاً — PID $(listening)"; return 0
  fi
  nohup $PY -c "
import os, sys
os.setsid()
os.execv(sys.executable, [sys.executable, '-m', 'uvicorn', 'api:app',
                          '--host', '0.0.0.0', '--port', '$PORT'])
" > server.log 2>&1 < /dev/null &
  disown
  for _ in $(seq 1 40); do
    [ -n "$(listening)" ] && break
    sleep 0.5
  done
  if [ -n "$(listening)" ]; then
    echo "🚀 اشتغل — PID $(listening)"
    echo "   الأداة : http://localhost:$PORT/ingest"
    echo "   اللوحة : http://localhost:$PORT/admin"
  else
    echo "❌ ما اشتغل. آخر السجل:"; tail -15 server.log
    return 1
  fi
}

stop() {
  pid=$(listening)
  if [ -z "$pid" ]; then echo "⏹️  ما في خادم شغّال."; return 0; fi
  kill $pid 2>/dev/null
  for _ in $(seq 1 20); do
    [ -z "$(listening)" ] && break
    sleep 0.5
  done
  if [ -n "$(listening)" ]; then
    echo "⚠️ علق وهو ماسك المنفذ — إيقاف قسري."
    kill -9 $(listening) 2>/dev/null
    sleep 1
  fi
  [ -z "$(listening)" ] && echo "🛑 توقّف." || { echo "❌ ما قدرت أوقفه."; return 1; }
}

case "$1" in
  start)   start ;;
  stop)    stop ;;
  restart) stop && start ;;
  status)
    pid=$(listening)
    [ -n "$pid" ] && echo "✅ يعمل — PID $pid · http://localhost:$PORT/ingest" \
                  || echo "⏹️  متوقّف." ;;
  log)     tail -f server.log ;;
  *) echo "الاستعمال: $0 {start|stop|restart|status|log}"; exit 1 ;;
esac
