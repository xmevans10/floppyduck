import os, requests
from pathlib import Path

token = os.environ.get("HF_TOKEN")
if not token:
    env_path = Path("../../.env")
    if env_path.exists():
        for line in env_path.read_text().splitlines():
            if line.startswith("HF_TOKEN="):
                token = line.split("=", 1)[1].strip()
                break

API_URL = "https://api-inference.huggingface.co/models/stabilityai/sdxl-turbo"
headers = {"Authorization": f"Bearer {token}"}

def query(payload):
    response = requests.post(API_URL, headers=headers, json=payload)
    return response.content

print("Querying SDXL Turbo via requests...")
image_bytes = query({
    "inputs": "pixel art cat",
})

with open("test_requests.png", "wb") as f:
    f.write(image_bytes)

print("Done. Check test_requests.png size:", os.path.getsize("test_requests.png"))
