import requests
import csv
import time
import sys
import os

OUTPUT = "e:\\Market Scan\\egyptian_products.csv"
HEADERS = {"User-Agent": "MarketScan/1.0 (contact@marketscan.com)"}

print("Connecting to OpenFoodFacts...")
session = requests.Session()
session.headers.update(HEADERS)

# Get total count first
url = "https://world.openfoodfacts.org/api/v2/search"
params = {
    "countries_tags_en": "egypt",
    "page_size": 100,
    "page": 1,
    "fields": "code,product_name,image_front_url,image_url",
    "sort_by": "unique_scans_n"
}

# Try up to 5 times to connect and get total count
success = False
for attempt in range(5):
    try:
        r = session.get(url, params=params, timeout=30)
        r.raise_for_status()
        data = r.json()
        total = data.get("count", 0)
        pages = (total + 99) // 100
        print(f"Found {total} Egyptian products across {pages} pages")
        success = True
        break
    except Exception as e:
        print(f"Connection attempt {attempt+1} failed: {e}")
        time.sleep(3)

if not success:
    print("Failed to initialize search connection. Exiting.")
    sys.exit(1)

all_products = []
seen = set()

for page in range(1, pages + 1):
    page_data = None
    if page == 1:
        page_data = data
    else:
        params["page"] = page
        # Retry logic for fetching pages
        for attempt in range(5):
            try:
                # Add delay between pages
                time.sleep(1.5)
                r = session.get(url, params=params, timeout=30)
                r.raise_for_status()
                page_data = r.json()
                break
            except Exception as e:
                print(f"\n  Retry {attempt+1} on page {page}: {e}")
                time.sleep(5)
    
    if not page_data:
        print(f"\nFailed to fetch page {page} after multiple attempts. Skipping this page.")
        continue

    added = 0
    for p in page_data.get("products", []):
        barcode = p.get("code", "").strip()
        if not barcode or barcode in seen:
            continue
        seen.add(barcode)
        name = p.get("product_name") or p.get("product_name_en") or p.get("product_name_ar") or ""
        image = p.get("image_front_url") or p.get("image_url") or ""
        all_products.append({
            "barcode": barcode.strip(),
            "name": name.strip(),
            "image": image.strip()
        })
        added += 1
    
    pct = page / pages * 100
    print(f"  Page {page}/{pages} ({pct:.0f}%) — +{added} products — Total: {len(all_products)}")
    sys.stdout.flush()
    
    # Save checkpoints every 10 pages
    if page % 10 == 0:
        with open(OUTPUT, "w", newline="", encoding="utf-8") as f:
            csv.DictWriter(f, fieldnames=["barcode","name","image"]).writeheader()
            csv.DictWriter(f, fieldnames=["barcode","name","image"]).writerows(all_products)

# Final save
with open(OUTPUT, "w", newline="", encoding="utf-8") as f:
    writer = csv.DictWriter(f, fieldnames=["barcode", "name", "image"])
    writer.writeheader()
    writer.writerows(all_products)

print(f"\nDONE! Saved {len(all_products)} products to {OUTPUT}")
print(f"File location: {os.path.abspath(OUTPUT)}")
