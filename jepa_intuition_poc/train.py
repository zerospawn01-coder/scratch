import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader
from torchvision import datasets, transforms
import copy

from model import SharedEncoder, Decoder, Predictor, ae_forward, jepa_forward

def apply_mask(x, mask_ratio=0.5):
    """
    Applies a simple horizontal or vertical mask to the image.
    In JEPA/PoC terms: x_context = visible part, x_target = full or hidden part?
    For MVP: Let's split 50/50 vertically.
    """
    b, c, h, w = x.shape
    x_context = x.clone()
    x_target = x.clone()
    
    # Simple vertical mask: Left half is context, Right half is hidden target
    x_context[:, :, :, w//2:] = 0
    x_target[:, :, :, :w//2] = 0
    
    return x_context, x_target

def train_ae(model_pair, loader, device, epochs=5):
    encoder, decoder = model_pair
    optimizer = optim.Adam(list(encoder.parameters()) + list(decoder.parameters()), lr=1e-3)
    criterion = nn.MSELoss()
    
    encoder.train()
    decoder.train()
    
    for epoch in range(epochs):
        total_loss = 0
        for x, _ in loader:
            x = x.to(device)
            optimizer.zero_grad()
            
            x_hat = ae_forward(encoder, decoder, x)
            loss = criterion(x_hat, x)
            
            loss.backward()
            optimizer.step()
            total_loss += loss.item()
        print(f"AE Epoch {epoch+1}/{epochs}, Loss: {total_loss/len(loader):.4f}")

def train_jepa(model_pair, loader, device, epochs=5):
    encoder, predictor = model_pair
    # In real JEPA, target encoder is a moving average or EMA. 
    # For MVP, let's use a static copy or same encoder with stop-gradient.
    target_encoder = copy.deepcopy(encoder).to(device)
    target_encoder.eval()
    
    optimizer = optim.Adam(list(encoder.parameters()) + list(predictor.parameters()), lr=1e-3)
    criterion = nn.MSELoss() # Latent distance (L2 on normalized embeddings)
    
    encoder.train()
    predictor.train()
    
    for epoch in range(epochs):
        total_loss = 0
        for x, _ in loader:
            x = x.to(device)
            x_context, x_target = apply_mask(x)
            
            optimizer.zero_grad()
            
            # Context path
            z_context = encoder(x_context)
            z_pred = predictor(z_context)
            
            # Target path (stop gradient)
            with torch.no_grad():
                z_target = target_encoder(x_target)
            
            loss = criterion(z_pred, z_target)
            
            loss.backward()
            optimizer.step()
            total_loss += loss.item()
            
            # EMA Update for Target Encoder (Simple version)
            for param_q, param_k in zip(encoder.parameters(), target_encoder.parameters()):
                param_k.data = param_k.data * 0.99 + param_q.data * 0.01
                
        print(f"JEPA Epoch {epoch+1}/{epochs}, Loss: {total_loss/len(loader):.4f}")

if __name__ == "__main__":
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print(f"Using device: {device}")
    
    transform = transforms.Compose([transforms.ToTensor()])
    mnist_train = datasets.MNIST(root='./data', train=True, download=True, transform=transform)
    loader = DataLoader(mnist_train, batch_size=64, shuffle=True)
    
    # 1. Training AE
    print("\nTraining Autoencoder...")
    ae_enc = SharedEncoder().to(device)
    ae_dec = Decoder().to(device)
    train_ae((ae_enc, ae_dec), loader, device)
    torch.save(ae_enc.state_dict(), "ae_enc.pth")
    torch.save(ae_dec.state_dict(), "ae_dec.pth")
    
    # 2. Training JEPA
    print("\nTraining JEPA...")
    jepa_enc = SharedEncoder().to(device)
    jepa_pred = Predictor().to(device)
    train_jepa((jepa_enc, jepa_pred), loader, device)
    torch.save(jepa_enc.state_dict(), "jepa_enc.pth")
    torch.save(jepa_pred.state_dict(), "jepa_pred.pth")
