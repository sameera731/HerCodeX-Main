import json
import math
import random
from tqdm import tqdm

# -----------------------------
# Load Files
# -----------------------------

with open("random_locations.json", encoding="utf-8") as f:
    random_points = json.load(f)

with open("policeStation.geojson", encoding="utf-8") as f:
    police_geo = json.load(f)

with open("roads.geojson", encoding="utf-8") as f:
    roads_geo = json.load(f)

with open("nightlife.geojson", encoding="utf-8") as f:
    nightlife_geo = json.load(f)

# -----------------------------
# Extract Coordinates
# -----------------------------

police_points = []
for feature in police_geo["features"]:
    lon, lat = feature["geometry"]["coordinates"]
    police_points.append((lat, lon))

road_points = []
for feature in roads_geo["features"]:
    geom_type = feature["geometry"]["type"]
    coords = feature["geometry"]["coordinates"]

    if geom_type == "LineString":
        for lon, lat in coords:
            road_points.append((lat, lon))
    elif geom_type == "MultiLineString":
        for segment in coords:
            for lon, lat in segment:
                road_points.append((lat, lon))

nightlife_points = []
for feature in nightlife_geo["features"]:
    lon, lat = feature["geometry"]["coordinates"]
    nightlife_points.append((lat, lon))

print("Police:", len(police_points))
print("Road points:", len(road_points))
print("Nightlife:", len(nightlife_points))

# -----------------------------
# Haversine
# -----------------------------

def haversine(lat1, lon1, lat2, lon2):
    R = 6371000
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2 - lat1)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)

    a = math.sin(dphi/2)**2 + math.cos(phi1)*math.cos(phi2)*math.sin(dlambda/2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
    return R * c

# -----------------------------
# Build Dataset
# -----------------------------

dataset = []

for point in tqdm(random_points):

    lat = point["lat"]
    lon = point["lon"]

    hour = random.randint(0, 23)

    # Nearest distances
    d_police = min(haversine(lat, lon, p_lat, p_lon) for p_lat, p_lon in police_points)
    d_road = min(haversine(lat, lon, r_lat, r_lon) for r_lat, r_lon in road_points)
    d_nightlife = min(haversine(lat, lon, n_lat, n_lon) for n_lat, n_lon in nightlife_points)

    # Convert to km
    d_police_km = d_police / 1000
    d_road_km = d_road / 1000
    d_nightlife_km = d_nightlife / 1000

    # -----------------------------
    # FINAL CALIBRATED DECAY
    # -----------------------------

    police_score = math.exp(-0.25 * d_police_km)
    road_score = math.exp(-0.2 * d_road_km)
    nightlife_risk = math.exp(-0.5 * d_nightlife_km)

    # -----------------------------
    # FINAL BALANCED WEIGHTS
    # -----------------------------

    if hour >= 20 or hour < 6:  # Nighttime
        safety = (
            0.55 * police_score
            + 0.20 * road_score
            - 0.30 * nightlife_risk
        )
        time_flag = 1
    else:  # Daytime
        safety = (
            0.65 * police_score
            + 0.25 * road_score
            - 0.10 * nightlife_risk
        )
        time_flag = 0

    safety = float(max(0, min(1, safety)))

    dataset.append({
        "d_police_km": d_police_km,
        "d_road_km": d_road_km,
        "d_nightlife_km": d_nightlife_km,
        "time_of_day": time_flag,
        "safety": safety
    })

# -----------------------------
# Save Dataset
# -----------------------------

with open("training_dataset.json", "w", encoding="utf-8") as f:
    json.dump(dataset, f, indent=2)

print("Dataset created:", len(dataset))