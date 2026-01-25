# 📥 GPT-OSS Download & Setup Guide

OpenAI's GPT-OSS weights are available on Hugging Face. Based on your disk space (~350GB free), you have sufficient capacity for both models.

## 1. Model Repositories

| Model | Parameters | VRAM Target | Repo Link |
| :--- | :--- | :--- | :--- |
| **GPT-OSS-120B** | 117B | 80GB (A100/H100) | [openai/gpt-oss-120b](https://huggingface.co/openai/gpt-oss-120b) |
| **GPT-OSS-20B** | 21B | 16GB (Consumer GPU) | [openai/gpt-oss-20b](https://huggingface.co/openai/gpt-oss-20b) |

---

## 2. Recommended Setup (CLI)

Since commands like `huggingface-cli` were not found, I recommend installing them via `pip`:

### A. Install Hugging Face Hub

```powershell
pip install huggingface_hub
```

### B. Download Commands

Run these in your terminal to start the download:

**For GPT-OSS-20B (Recommended for local testing):**

```powershell
huggingface-cli download openai/gpt-oss-20b --local-dir ./models/gpt-oss-20b
```

**For GPT-OSS-120B (Production/High-Reasoning):**

```powershell
huggingface-cli download openai/gpt-oss-120b --local-dir ./models/gpt-oss-120b
```

---

## 3. Alternative: Direct Download

If you prefer not to use the terminal, you can download files directly from the "Files and versions" tab on the Hugging Face links above.

> [!TIP]
> **Priority Recommendation**: Start with **GPT-OSS-20B**. It is optimized for 16GB memory and will allow us to test the "Harmony Prompt Format" and "Prospective Control" logic immediately on your local machine.

---
**STATUS**: READY_TO_DOWNLOAD
