from backend.model import service
import numpy as np
print('Model status:',service.status())
assert service.model is not None, service.error
x=np.random.default_rng(7).normal(size=(12,5000)).astype('float32')
y=service.predict(x)
assert len(y)==5 and all(0<=r['probability']<=1 for r in y)
print('Forward pass OK. Output classes:',[r['label'] for r in y])
