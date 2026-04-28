import json
import uuid
from datetime import datetime, timedelta

brand_id = str(uuid.uuid4())
active_brand_id = brand_id

records = []

# Pattern for April 2026
daily_counts = {
    1: 2, 2: 4, 3: 6, 4: 8, 5: 10,
    6: 12, 7: 15, 8: 12, 9: 8, 10: 4,
    11: 2, 12: 0, 13: 2, 14: 5, 15: 7,
    16: 10, 17: 12, 18: 15, 19: 16, 20: 10,
    21: 8, 22: 5, 23: 3, 24: 12
}

for day, count in daily_counts.items():
    if count == 0:
        continue
    # Spread the count throughout the day
    for i in range(count):
        # 8 AM to 8 PM roughly
        hour = 8 + (i * 12 // count)
        minute = (i * 37) % 60
        dt = f"2026-04-{day:02d}T{hour:02d}:{minute:02d}:00Z"
        records.append({
            "id": str(uuid.uuid4()),
            "timestamp": dt,
            "count": 1,
            "brandId": brand_id,
            "brandName": "Marlboro",
            "pricePerCigarette": "30"
        })

data = {
    "version": "1.0",
    "exportDate": datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
    "appName": "SmokeCounter",
    "records": records,
    "brands": [
        {
            "id": brand_id,
            "name": "Marlboro",
            "countPerPack": 20,
            "pricePerPack": "600",
            "isActive": True,
            "createdAt": "2026-01-01T00:00:00Z",
            "isDefault": True
        }
    ],
    "settings": {
        "healthKitEnabled": False,
        "activeBrandId": brand_id,
        "dailyGoal": 10,
        "backgroundTypeRawValue": "none",
        "backgroundOpacity": 0.5,
        "iCloudSyncEnabled": False
    }
}

with open("heatmap_demo_data.json", "w") as f:
    json.dump(data, f, indent=2)

print("Created heatmap_demo_data.json")
