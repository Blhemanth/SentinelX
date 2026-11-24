import torch

pth_path = r'b:\SentinelX\server_ml\models\sentinelx_model.pth'
ckpt = torch.load(pth_path, map_location='cpu')

print('Inspecting classifier and bbox regressor weights and biases:')
for k in ['classifier.0.weight', 'classifier.0.bias', 'classifier.3.weight', 'classifier.3.bias', 
          'bbox_regressor.0.weight', 'bbox_regressor.0.bias', 'bbox_regressor.2.weight', 'bbox_regressor.2.bias']:
    v = ckpt[k]
    print(f'{k}: shape={v.shape}, mean={v.float().mean().item():.6f}, std={v.float().std().item():.6f}, min={v.float().min().item():.6f}, max={v.float().max().item():.6f}')
    if 'bias' in k:
        print(f'  Values: {v.numpy()}')

print('\nBatchNorm num_batches_tracked:')
for k, v in ckpt.items():
    if 'num_batches_tracked' in k:
        print(f'  {k}: {v.item()}')
