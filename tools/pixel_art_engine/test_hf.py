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

if not token:
    print("No token found!")
    exit(1)

print(f"Token found: {token[:10]}...")

client = InferenceClient(api_key=token, timeout=60)
print("Testing SDXL Turbo...")
try:
    img = client.text_to_image("pixel art cat", model="stabilityai/sdxl-turbo")
    img.save("test_hf.png")
    print("Success!")
except Exception as e:
    print(f"Failed with type {type(e)}")
    print(f"Error: {e}")
    traceback.print_exc()
