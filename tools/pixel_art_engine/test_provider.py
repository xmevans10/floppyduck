import os, traceback
from huggingface_hub import InferenceClient
from pathlib import Path

token = os.environ.get("HF_TOKEN")
if not token:
    env_path = Path("../../.env")
    if env_path.exists():
        for line in env_path.read_text().splitlines():
            if line.startswith("HF_TOKEN="):
                token = line.split("=", 1)[1].strip()
                break

client = InferenceClient(api_key=token, provider="fal-ai")
print("Testing SD 3.5 Large Turbo via fal-ai provider...")
try:
    img = client.text_to_image("pixel art cat", model="stabilityai/stable-diffusion-3.5-large-turbo")
    img.save("test_provider.png")
    print("Success!")
except Exception as e:
    print(f"Failed: {e}")
    traceback.print_exc()
