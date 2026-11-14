from pathlib import Path
BASE_DIR=Path(__file__).resolve().parents[1]
MODEL_PATH=BASE_DIR/'models'/'best_ecgfounder_ptbxl.pth'
DATA_DIR=BASE_DIR/'data'; UPLOAD_DIR=DATA_DIR/'uploads'; REPORT_DIR=DATA_DIR/'reports'
DB_PATH=DATA_DIR/'history.sqlite3'
for p in (DATA_DIR,UPLOAD_DIR,REPORT_DIR): p.mkdir(parents=True,exist_ok=True)
CLASSES=['NORM','MI','STTC','CD','HYP']
# Thresholds saved/selected on the validation set in the prior training workflow.
THRESHOLDS=[0.3048989,0.1730635,0.1963626,0.1812232,0.07899384]
