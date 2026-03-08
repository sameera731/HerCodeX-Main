import pandas as pd
import random
from datetime import datetime, timedelta

center_lat = 18.731664012029693
center_lon = 73.43086633604906

start_time = datetime.now() - timedelta(days=7)
end_time = datetime.now()

rows = []
current = start_time

# Normal background traffic
while current <= end_time:
    num_events = random.randint(0, 2)

    for _ in range(num_events):
        lat = center_lat + random.uniform(-0.01, 0.01)
        lon = center_lon + random.uniform(-0.01, 0.01)
        phone = str(random.randint(6000000000, 9999999999))

        rows.append({
            "phone_number": phone,
            "latitude": lat,
            "longitude": lon,
            "timestamp": current
        })

    current += timedelta(minutes=5)


# SPIKE 1
for _ in range(18):
    rows.append({
        "phone_number": str(random.randint(6000000000, 9999999999)),
        "latitude": 18.735000,
        "longitude": 73.425000,
        "timestamp": datetime.now().replace(hour=18, minute=0, second=0, microsecond=0)
    })


# SPIKE 2
for _ in range(22):
    rows.append({
        "phone_number": str(random.randint(6000000000, 9999999999)),
        "latitude": 18.742000,
        "longitude": 73.438000,
        "timestamp": datetime.now().replace(hour=20, minute=0, second=0, microsecond=0)
    })


# SPIKE 3
for _ in range(25):
    rows.append({
        "phone_number": str(random.randint(6000000000, 9999999999)),
        "latitude": 18.724000,
        "longitude": 73.418000,
        "timestamp": datetime.now().replace(hour=22, minute=0, second=0, microsecond=0)
    })


df = pd.DataFrame(rows)
df.to_csv("sos_data.csv", index=False)

print("Generated 3 separate anomaly spikes.")