import json
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestRegressor
from sklearn.metrics import r2_score, mean_absolute_error
import joblib

# -----------------------------
# Load dataset
# -----------------------------

with open("training_dataset.json", "r", encoding="utf-8") as f:
    data = json.load(f)

# Convert to numpy arrays
X = []
y = []

for row in data:
    X.append([
        row["d_police_km"],
        row["d_road_km"],
        row["d_nightlife_km"],
        row["time_of_day"]
    ])
    y.append(row["safety"])

X = np.array(X)
y = np.array(y)

# -----------------------------
# Train-test split
# -----------------------------

X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.2, random_state=42
)

# -----------------------------
# Train Model
# -----------------------------

model = RandomForestRegressor(
    n_estimators=100,
    max_depth=10,
    random_state=42
)

model.fit(X_train, y_train)

# -----------------------------
# Evaluate
# -----------------------------

preds = model.predict(X_test)

print("R2 Score:", r2_score(y_test, preds))
print("MAE:", mean_absolute_error(y_test, preds))

# -----------------------------
# Feature Importance
# -----------------------------

features = ["d_police_km", "d_road_km", "d_nightlife_km", "time_of_day"]
importances = model.feature_importances_

for f, imp in zip(features, importances):
    print(f"{f}: {imp:.4f}")

# -----------------------------
# Save Model
# -----------------------------

joblib.dump(model, "safety_model.pkl")

print("Model saved as safety_model.pkl")