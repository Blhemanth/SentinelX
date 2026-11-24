import os
import torch

pth_path = r'b:\SentinelX\server_ml\models\sentinelx_model.pth'
print('pth exists:', os.path.exists(pth_path))
if os.path.exists(pth_path):
    print('pth size:', os.path.getsize(pth_path))
    ckpt = torch.load(pth_path, map_location='cpu')
    if isinstance(ckpt, dict):
        print('Keys in ckpt:', ckpt.keys())
        if 'epoch' in ckpt:
            print('Epoch:', ckpt['epoch'])
        if 'val_loss' in ckpt:
            print('Val loss:', ckpt['val_loss'])
        if 'val_acc' in ckpt:
            print('Val acc:', ckpt['val_acc'])
        if 'state_dict' in ckpt:
            print('Num state_dict keys:', len(ckpt['state_dict']))
        elif 'model_state_dict' in ckpt:
            print('Num model_state_dict keys:', len(ckpt['model_state_dict']))
        else:
            print('Direct state_dict keys count:', len(ckpt))
            first_few = list(ckpt.keys())[:5]
            print('First few keys:', first_few)
            for k in first_few:
                v = ckpt[k]
                print(f'  {k}: shape={v.shape}, mean={v.float().mean().item():.5f}, std={v.float().std().item():.5f}')
    else:
        print('Checkpoint type:', type(ckpt))

ckpt_dir = r'b:\SentinelX\server_ml\models\sentinelx_checkpoint'
if os.path.exists(ckpt_dir):
    print('\nFiles in sentinelx_checkpoint:')
    for f in os.listdir(ckpt_dir):
        print(' ', f)
