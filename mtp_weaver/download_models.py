import os
from huggingface_hub import hf_hub_download

# <SINCERE>
def download_model(repo_id, filename, local_dir):
    print(f"Downloading {filename} from {repo_id} to {local_dir}...")
    try:
        path = hf_hub_download(
            repo_id=repo_id,
            filename=filename,
            local_dir=local_dir,
            local_dir_use_symlinks=False
        )
        print(f"Successfully downloaded to: {path}")
    except Exception as e:
        print(f"Error downloading {filename}: {e}")

# <SINCERE>
if __name__ == "__main__":
    models_dir = r"C:\Users\zeros\.gemini\antigravity\scratch\mtp_weaver\models"
    
    # 1. Llama-3.1-8B-Instruct-Q4_K_M.gguf
    download_model(
        repo_id="bartowski/Meta-Llama-3.1-8B-Instruct-GGUF",
        filename="Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf",
        local_dir=os.path.join(models_dir, "llama-3.1-8b")
    )
    
    # 2. glm-4-9b-chat-Q4_K_M.gguf
    # Note: Filename might vary, check exact name in repo if this fails.
    # Searching for GLM-4-9B-Chat GGUF filename...
    download_model(
        repo_id="bartowski/glm-4-9b-chat-GGUF",
        filename="glm-4-9b-chat-Q4_K_M.gguf",
        local_dir=os.path.join(models_dir, "glm-4-9b")
    )
