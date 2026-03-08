import joblib
import math
import json

# Load trained model
model = joblib.load("safety_model.pkl")

# Load geo data
with open("policeStation.geojson", encoding="utf-8") as f:
    police_geo = json.load(f)

with open("roads.geojson", encoding="utf-8") as f:
    roads_geo = json.load(f)

with open("nightlife.geojson", encoding="utf-8") as f:
    nightlife_geo = json.load(f)

# Extract coordinates
police_points = [(feat["geometry"]["coordinates"][1], feat["geometry"]["coordinates"][0])
                 for feat in police_geo["features"]]

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

nightlife_points = [(feat["geometry"]["coordinates"][1], feat["geometry"]["coordinates"][0])
                    for feat in nightlife_geo["features"]]

# Haversine
def haversine(lat1, lon1, lat2, lon2):
    R = 6371000
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)

    a = math.sin(dphi/2)**2 + math.cos(phi1)*math.cos(phi2)*math.sin(dlambda/2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
    return R * c

# -------- CHANGE THIS LAT LON --------
lat = 18.51110900040093
lon = 73.84475011218034
hour = 1 # try night first

# Compute distances
d_police = min(haversine(lat, lon, p_lat, p_lon) for p_lat, p_lon in police_points)
d_road = min(haversine(lat, lon, r_lat, r_lon) for r_lat, r_lon in road_points)
d_nightlife = min(haversine(lat, lon, n_lat, n_lon) for n_lat, n_lon in nightlife_points)

# Convert to km
features = [[
    d_police / 1000,
    d_road / 1000,
    d_nightlife / 1000,
    1 if hour >= 20 or hour < 6 else 0
]]

# Predict
prediction = model.predict(features)[0]

print("Predicted Safety Score:", float(prediction))