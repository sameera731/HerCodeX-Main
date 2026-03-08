import pandas as pd
from sklearn.ensemble import IsolationForest

def detect_anomalies():

    df = pd.read_csv("sos_data.csv")
    df["timestamp"] = pd.to_datetime(df["timestamp"])

    # Bucket lat/lon and time
    df["lat_bucket"] = df["latitude"].round(3)
    df["lon_bucket"] = df["longitude"].round(3)
    df["time_bucket"] = df["timestamp"].dt.floor("5min")

    grouped = df.groupby(
        ["lat_bucket", "lon_bucket", "time_bucket"]
    )["phone_number"].nunique().reset_index()

    grouped.rename(columns={"phone_number": "count"}, inplace=True)

    # Train Isolation Forest on full history
    X = grouped[["count"]]

    model = IsolationForest(
        contamination=0.07,   # allow ~7% anomalies
        random_state=42
    )

    model.fit(X)

    grouped["anomaly"] = model.predict(X)

    # Keep only anomaly rows
    anomalies = grouped[grouped["anomaly"] == -1]

    # IMPORTANT: remove weak anomalies
    anomalies = anomalies[anomalies["count"] > 10]

    # Format output
    result = []

    for _, row in anomalies.iterrows():
        result.append({
            "latitude": row["lat_bucket"],
            "longitude": row["lon_bucket"],
            "incident_count": int(row["count"]),
            "time": str(row["time_bucket"]),
            "model_prediction": "ANOMALY"
        })

    return result