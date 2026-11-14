import sqlite3,json
from .config import DB_PATH

def init_db():
    with sqlite3.connect(DB_PATH) as c:
        c.execute('CREATE TABLE IF NOT EXISTS analyses(id INTEGER PRIMARY KEY AUTOINCREMENT, created_at TEXT DEFAULT CURRENT_TIMESTAMP, filename TEXT, source_type TEXT, status TEXT, results TEXT, note TEXT)')
def save(filename,source_type,status,results=None,note=''):
    with sqlite3.connect(DB_PATH) as c:
        cur=c.execute('INSERT INTO analyses(filename,source_type,status,results,note) VALUES(?,?,?,?,?)',(filename,source_type,status,json.dumps(results) if results else None,note))
        return cur.lastrowid
def history():
    with sqlite3.connect(DB_PATH) as c:
        c.row_factory=sqlite3.Row
        return [dict(r) for r in c.execute('SELECT * FROM analyses ORDER BY id DESC LIMIT 50').fetchall()]
