import json
import os
import sys
import time
import urllib.parse
import urllib.request
import jwt
import requests

sys.stdout.reconfigure(encoding='utf-8')

KEY_PATH = r"C:\Users\gibra\Downloads\prende-3dd30-e5aab36c257d.json"
PKG = "com.sendallc.minesweeper"
AAB_PATH = r"c:\Users\gibra\OneDrive\Documents\Coding\Minesweeper\app\build\app\outputs\bundle\release\app-release.aab"

if not os.path.isfile(AAB_PATH):
    print(f"Error: {AAB_PATH} not found!")
    sys.exit(1)

print(f"Starting upload process for {PKG}...")
with open(KEY_PATH) as f:
    key = json.load(f)

now = int(time.time())
claims = {
    "iss": key["client_email"],
    "scope": "https://www.googleapis.com/auth/androidpublisher",
    "aud": key["token_uri"],
    "iat": now,
    "exp": now + 3600,
}
assertion = jwt.encode(claims, key["private_key"], algorithm="RS256")
data = urllib.parse.urlencode({
    "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
    "assertion": assertion,
}).encode()
token_resp = json.loads(urllib.request.urlopen(urllib.request.Request(key["token_uri"], data=data), timeout=30).read())
token = token_resp["access_token"]
print("✓ OAuth token acquired")

BASE = f"https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{PKG}"
UP = f"https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/{PKG}"
headers = {"Authorization": f"Bearer {token}"}

# 1. Create edit
r = requests.post(f"{BASE}/edits", headers=headers, json={})
if r.status_code not in (200, 201):
    print("Error creating edit:", r.status_code, r.text)
    sys.exit(1)
eid = r.json()["id"]
print(f"✓ Edit created: {eid}")

try:
    # 2. Upload bundle
    size_mb = os.path.getsize(AAB_PATH) / (1024 * 1024)
    print(f"Uploading {AAB_PATH} ({size_mb:.1f} MB)...")
    upload_url = f"{UP}/edits/{eid}/bundles?uploadType=media"
    upload_headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/octet-stream",
    }
    with open(AAB_PATH, "rb") as f:
        up_res = requests.post(upload_url, headers=upload_headers, data=f, timeout=600)
    
    if up_res.status_code not in (200, 201):
        raise RuntimeError(f"Error uploading bundle: {up_res.status_code} {up_res.text}")
    
    bundle_data = up_res.json()
    version_code = bundle_data.get("versionCode")
    sha1 = bundle_data.get("sha1")
    print(f"✓ Bundle uploaded successfully: versionCode={version_code}, sha1={sha1}")
    
    # 3. Assign to internal track
    track_body = {
        "track": "internal",
        "releases": [
            {
                "name": f"1.0.0 ({version_code}) — Buscaminas Material 3 Expressive",
                "versionCodes": [str(version_code)],
                "status": "completed",
                "releaseNotes": [
                    {
                        "language": "es-419",
                        "text": f"Buscaminas 1.0.0 ({version_code}):\n• Rótulo expresivo táctil en dos líneas (BUSCA / MINAS) estilo CINCO.\n• Anuncio mostrado inmediatamente al terminar la partida de práctica.\n• Enfriamiento mínimo de 15 segundos entre anuncios."
                    },
                    {
                        "language": "en-US",
                        "text": f"Minesweeper 1.0.0 ({version_code}):\n• Two-line Material 3 Expressive title graphic (MINE / SWEEPER) matching CINCO.\n• Immediate ad presentation upon finishing practice mode games.\n• Minimum 15-second cooldown between interstitial ads."
                    }
                ]
            }
        ]
    }
    t_res = requests.put(f"{BASE}/edits/{eid}/tracks/internal", headers=headers, json=track_body)
    if t_res.status_code not in (200, 201):
        raise RuntimeError(f"Error updating internal track: {t_res.status_code} {t_res.text}")
    print("✓ Configured internal track")
    
    # 4. Commit edit
    print("Committing edit to Google Play Console...")
    commit_res = requests.post(f"{BASE}/edits/{eid}:commit", headers=headers)
    if commit_res.status_code not in (200, 201):
        raise RuntimeError(f"Error committing edit: {commit_res.status_code} {commit_res.text}")
    print(f"🎉 Edit committed successfully! Minesweeper 1.0.0 ({version_code}) is live on Internal Testing!")

except Exception as e:
    print(f"\nERROR: {e}")
    print("Deleting edit...")
    requests.delete(f"{BASE}/edits/{eid}", headers=headers)
    sys.exit(1)
