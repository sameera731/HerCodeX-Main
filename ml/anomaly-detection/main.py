from fastapi import FastAPI
from anomaly_detector import detect_anomalies

app = FastAPI()


@app.get("/anomalies")
def get_anomalies():
    anomalies = detect_anomalies()
    return anomalies