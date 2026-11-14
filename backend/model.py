import torch
import numpy as np
from .net1d import Net1D
from .config import MODEL_PATH,CLASSES,THRESHOLDS

class ECGFounderService:
    def __init__(self):
        self.device=torch.device('cuda' if torch.cuda.is_available() else 'cpu')
        self.model=None; self.error=None
        self.load()
    def load(self):
        try:
            self.model=Net1D(in_channels=12,base_filters=64,ratio=1,
                filter_list=[64,160,160,400,400,1024,1024],
                m_blocks_list=[2,2,2,3,3,4,4],kernel_size=16,stride=2,
                groups_width=16,n_classes=5,use_bn=False,use_do=False).to(self.device)
            state=torch.load(MODEL_PATH,map_location=self.device,weights_only=True)
            if 'model_state_dict' in state: state=state['model_state_dict']
            self.model.load_state_dict(state,strict=True)
            self.model.eval(); self.error=None
        except Exception as e:
            self.model=None; self.error=str(e)
    def status(self):
        return {'loaded':self.model is not None,'device':str(self.device),'checkpoint':MODEL_PATH.name,'checkpoint_exists':MODEL_PATH.exists(),'error':self.error}
    @staticmethod
    def prepare(signal):
        x=np.asarray(signal,dtype=np.float32)
        if x.shape==(5000,12): x=x.T
        if x.shape!=(12,5000): raise ValueError(f'Expected signal shape (12,5000) or (5000,12), got {x.shape}')
        if not np.isfinite(x).all(): raise ValueError('Signal contains NaN or infinite values.')
        # Match the fine-tuning code: one mean and one standard deviation
        # over the complete 12-lead x 5000-sample record (global per-record z-score).
        # No extra filtering or resampling is applied here.
        mu=x.mean()
        sd=x.std()
        x=(x-mu)/(sd+1e-8)
        return torch.from_numpy(x).unsqueeze(0)
    def predict(self,signal):
        if self.model is None: raise RuntimeError('ECGFounder checkpoint failed to load: '+str(self.error))
        x=self.prepare(signal).to(self.device)
        with torch.inference_mode(): logits=self.model(x)
        probs=torch.sigmoid(logits).cpu().numpy()[0]
        rows=[]
        for name,p,t in zip(CLASSES,probs,THRESHOLDS):
            rows.append({'label':name,'probability':float(p),'threshold':float(t),'positive':bool(p>=t)})
        return rows
service=ECGFounderService()
