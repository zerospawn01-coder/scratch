import torch
import torch.nn as nn
import torch.nn.functional as F

class SharedEncoder(nn.Module):
    """
    Contract: This encoder MUST be used by both AE and JEPA models.
    Input: (B, 1, 28, 28)
    Output: (B, latent_dim), L2-normalized
    """
    def __init__(self, latent_dim=128):
        super().__init__()
        self.conv1 = nn.Conv2d(1, 32, kernel_size=3, stride=2, padding=1) # 14x14
        self.conv2 = nn.Conv2d(32, 64, kernel_size=3, stride=2, padding=1) # 7x7
        self.flatten = nn.Flatten()
        self.fc = nn.Linear(64 * 7 * 7, latent_dim)

    def forward(self, x):
        x = F.relu(self.conv1(x))
        x = F.relu(self.conv2(x))
        x = self.flatten(x)
        z = self.fc(x)
        return F.normalize(z, p=2, dim=1)

class Decoder(nn.Module):
    """
    Contract: Used ONLY by AE benchmark.
    Input: (B, latent_dim)
    Output: (B, 1, 28, 28)
    """
    def __init__(self, latent_dim=128):
        super().__init__()
        self.fc = nn.Linear(latent_dim, 64 * 7 * 7)
        self.unflatten = nn.Unflatten(1, (64, 7, 7))
        self.deconv1 = nn.ConvTranspose2d(64, 32, kernel_size=3, stride=2, padding=1, output_padding=1) # 14x14
        self.deconv2 = nn.ConvTranspose2d(32, 1, kernel_size=3, stride=2, padding=1, output_padding=1) # 28x28

    def forward(self, z):
        x = F.relu(self.fc(z))
        x = self.unflatten(x)
        x = F.relu(self.deconv1(x))
        x_hat = torch.sigmoid(self.deconv2(x))
        return x_hat

class Predictor(nn.Module):
    """
    Contract: Used ONLY by JEPA benchmark.
    Input: (B, latent_dim) - Context latent
    Output: (B, latent_dim) - Predicted Target latent
    
    Design note:
    Predictor capacity is intentionally limited (MLP 2-layer) to avoid 
    implicit generation or memorization. It should only map semantic states.
    """
    def __init__(self, latent_dim=128):
        super().__init__()
        self.fc1 = nn.Linear(latent_dim, latent_dim)
        self.fc2 = nn.Linear(latent_dim, latent_dim)

    def forward(self, z_context):
        x = F.relu(self.fc1(z_context))
        z_pred = self.fc2(x)
        return F.normalize(z_pred, p=2, dim=1) # Prediction is also normalized for distance logic

# --- Benchmark Forwarding Contracts ---

def ae_forward(encoder, decoder, x):
    """
    Full Autoencoder process: x -> Encoder -> Decoder -> x_hat
    """
    z = encoder(x)
    return decoder(z)

def jepa_forward(encoder, predictor, x_context):
    """
    JEPA process: x_context -> Encoder -> Predictor -> z_pred.
    Note: NO DECODER.
    """
    z_context = encoder(x_context)
    return predictor(z_context)

def ae_latent_forward(encoder, x):
    """
    Baseline for latent-only inference: x -> Encoder -> z
    """
    return encoder(x)
