import random
import json

# Bounding box covering Pune + Lonavala
min_lat = 18.35
max_lat = 18.90
min_lon = 73.30
max_lon = 74.10

locations = []

for _ in range(20000):   # 20k points for better coverage
    lat = random.uniform(min_lat, max_lat)
    lon = random.uniform(min_lon, max_lon)

    locations.append({"lat": lat, "lon": lon})

with open("random_locations.json", "w") as f:
    json.dump(locations, f, indent=2)

print("Generated:", len(locations), "random locations")