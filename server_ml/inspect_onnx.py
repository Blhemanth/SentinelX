import os
import onnx
import onnxruntime as ort

model_path = r'b:\SentinelX\assets\models\sentinelx_model.onnx'
print('Model file exists:', os.path.exists(model_path))
print('Model file size:', os.path.getsize(model_path), 'bytes')

model = onnx.load(model_path)
print('IR Version:', model.ir_version)
print('Producer Name:', model.producer_name)
print('Producer Version:', model.producer_version)
print('Opset Imports:')
for opset in model.opset_import:
    print(f'  Domain: "{opset.domain}", Version: {opset.version}')

meta = {p.key: p.value for p in model.metadata_props}
print('Metadata props:', meta)

session = ort.InferenceSession(model_path, providers=['CPUExecutionProvider'])
print('\nAvailable Providers:', ort.get_available_providers())
print('Session Providers:', session.get_providers())

print('\nModel Inputs:')
for inp in session.get_inputs():
    print(f'  Name: {inp.name}, Shape: {inp.shape}, Type: {inp.type}')

print('\nModel Outputs:')
for out in session.get_outputs():
    print(f'  Name: {out.name}, Shape: {out.shape}, Type: {out.type}')
