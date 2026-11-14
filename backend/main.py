import json,uuid
from pathlib import Path
import numpy as np
from fastapi import FastAPI,UploadFile,File,HTTPException
from fastapi.responses import HTMLResponse
from fastapi.staticfiles import StaticFiles
from .config import BASE_DIR,UPLOAD_DIR
from .database import init_db,save,history
from .model import service
app=FastAPI(title='ECGFounder Offline Research App')
app.mount('/static',StaticFiles(directory=BASE_DIR/'frontend'),name='static')
@app.on_event('startup')
def startup(): init_db()
@app.get('/',response_class=HTMLResponse)
def home(): return (BASE_DIR/'frontend'/'index.html').read_text(encoding='utf-8')
@app.get('/api/status')
def status(): return {'app':'ready','mode':'local/offline after installation','model':service.status()}
@app.get('/api/history')
def get_history(): return history()
@app.post('/api/analyze-signal')
async def analyze_signal(file:UploadFile=File(...)):
    suffix=Path(file.filename or '').suffix.lower()
    if suffix not in {'.npy','.csv'}: raise HTTPException(400,'ارفع ملف إشارة بصيغة NPY أو CSV. صورة ECG ليست إشارة رقمية.')
    raw=await file.read()
    if len(raw)>20*1024*1024: raise HTTPException(413,'الملف أكبر من 20MB.')
    dest=UPLOAD_DIR/(uuid.uuid4().hex+suffix); dest.write_bytes(raw)
    try:
        arr=np.load(dest,allow_pickle=False) if suffix=='.npy' else np.loadtxt(dest,delimiter=',',dtype=np.float32)
        result=service.predict(arr)
        aid=save(file.filename,'signal','completed',result)
        return {'id':aid,'filename':file.filename,'results':result,'note':'بحثي فقط، وليس تشخيصًا طبيًا.'}
    except Exception as e:
        save(file.filename,'signal','failed',None,str(e))
        raise HTTPException(422,str(e))
@app.post('/api/inspect-image')
async def inspect_image(file:UploadFile=File(...)):
    suffix=Path(file.filename or '').suffix.lower()
    if suffix not in {'.png','.jpg','.jpeg'}: raise HTTPException(400,'الصيغ المقبولة JPG وPNG.')
    raw=await file.read()
    if len(raw)>20*1024*1024: raise HTTPException(413,'الصورة أكبر من 20MB.')
    dest=UPLOAD_DIR/(uuid.uuid4().hex+suffix); dest.write_bytes(raw)
    aid=save(file.filename,'image','not_digitized',None,'الصورة حُفظت للمعاينة؛ تحويل الصورة إلى إشارة 12 اشتقاقًا غير موصول بعد.')
    return {'id':aid,'status':'image_received_not_digitized','message':'تم استلام الصورة، لكن لا يمكن تمريرها مباشرة إلى ECGFounder. يلزم digitizer معاير ومتحقق منه قبل إصدار نتيجة.'}
