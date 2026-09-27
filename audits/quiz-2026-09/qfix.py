"""qfix.py FILE PATCH.json — PATCH: [{"id":..., "set":{"q"/"options"/"correct_index"/"why":...}, "opt":{"2":"نص خيار واحد"}, "why_fix":"..."}]
أو {"id":..., "delete": true, "why_fix":...}. يبحث بالمعرّف في كل الدروس، يتحقق، يكتب ويسجّل في qfixes.jsonl."""
import sys, json, os, qio
HERE = os.path.dirname(os.path.abspath(__file__))
f = sys.argv[1] + ('' if sys.argv[1].endswith('.json') else '.json')
d, ind, nl = qio.load(f)
idx = {x['id']: (k, v, x) for k, v in d.items() for x in v['questions']}
log = open(os.path.join(HERE, 'qfixes.jsonl'), 'a', encoding='utf-8')
import hashlib
for p in json.load(open(sys.argv[2], encoding='utf-8')):
    if 'add' in p:  # {"add": {"key": جزء من مفتاح الدرس, q, options(✓ للصحيح), why, level, weight?, kind?, topic?}}
        a = dict(p['add']); ks = [k for k in d if a['key'] in k]; assert len(ks) == 1, (a['key'], ks); k = ks[0]; v = d[k]
        o = a['options']; ci = next(j for j, t in enumerate(o) if t.startswith('✓')); o[ci] = o[ci][1:]
        assert len(o) == 4 and len(set(o)) == 4, a['q']
        qid = hashlib.sha1((a['q'] + '|' + '|'.join(sorted(o))).encode('utf-8')).hexdigest()[:12]
        x = {'id': qid, 'q': a['q'], 'options': o, 'correct_index': ci, 'topic': a.get('topic', v['questions'][0].get('topic', '')),
             'lesson': v['lesson'], 'level': a.get('level', 'متوسط'), 'weight': a.get('weight', 4), 'kind': a.get('kind', 'فهم'), 'why': a['why']}
        v['questions'].append(x); v['count'] = len(v['questions'])
        log.write(json.dumps({'file': f, 'key': k, 'id': qid, 'old': None, 'new': x, 'why': p['why_fix']}, ensure_ascii=False) + '\n'); continue
    k, v, x = idx[p['id']]
    old = json.loads(json.dumps(x, ensure_ascii=False))
    if p.get('delete'):
        v['questions'].remove(x); v['count'] = len(v['questions'])
    else:
        st = p.get('set', {})
        o = st.get('options')
        if o:  # «✓» وحده = أبقِ نص الجواب الصحيح القديم هنا؛ «✓نص» = هذا هو الصحيح
            for j, t in enumerate(o):
                if t == '✓': o[j] = x['options'][x['correct_index']]; st['correct_index'] = j
                elif t.startswith('✓'): o[j] = t[1:]; st['correct_index'] = j
        for a, b in st.items(): x[a] = b
        for j, t in p.get('opt', {}).items(): x['options'][int(j)] = t
        assert len(x['options']) == 4 and 0 <= x['correct_index'] < 4, p['id']
        assert len(set(map(str, x['options']))) == 4, ('dup options', p['id'])
    log.write(json.dumps({'file': f, 'key': k, 'id': p['id'], 'old': old, 'new': None if p.get('delete') else x, 'why': p['why_fix']}, ensure_ascii=False) + '\n')
qio.save(f, d, ind, nl); print('OK', f, len(json.load(open(sys.argv[2]))))
