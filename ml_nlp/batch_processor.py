import pandas as pd
from transformers import pipeline
import json

print("1. Loading YOUR Custom HerCodeX Lonavala Model...")
classifier = pipeline("text-classification", model="./hercodex_lonavala_model", tokenizer="./hercodex_lonavala_model")

print("2. Loading Lonavala tweet dataset...")
df = pd.read_csv('scraped_tweets.csv')

print("3. Running Custom NLP Analysis on all tweets...")
grid_raw_scores = {}

# --- THE AI BRAIN ---
for index, row in df.iterrows():
    result = classifier(row["tweet"])[0]
    label = result['label']
    
    if label == "LABEL_0":
        tweet_score = 1.0  # Safe
    elif label == "LABEL_1":
        tweet_score = 0.5  # Cautious
    else: 
        tweet_score = 0.0  # Danger (LABEL_2)
        
    grid = row["grid_code"]
    if grid not in grid_raw_scores:
        grid_raw_scores[grid] = []
    grid_raw_scores[grid].append(tweet_score)

# --- AGGREGATION & EXPORT ---
print("4. Calculating final safety scores and attaching real map names & status...")

location_names = {
    "X9Y8Z": "SIT Campus",
    "M4N5P": "Bhushi Dam",
    "L2K3J": "Khandala Ghat",
    "A1B2C": "Lonavala Station Area",
    "R7T8W": "Tiger Point"
}

final_safety_data = {}

for grid, scores in grid_raw_scores.items():
    avg_score = sum(scores) / len(scores)
    real_name = location_names.get(grid, "Unknown Area")
    
    # --- NEW LOGIC: Translate the math back into a final status word ---
    if avg_score >= 0.7:
        final_status = "Safe"
    elif avg_score >= 0.3:
        final_status = "Cautious"
    else:
        final_status = "Danger"
    
    # Pack it all together for the frontend
    final_safety_data[grid] = {
        "place_name": real_name,
        "safety_score": round(avg_score, 3),
        "status": final_status
    }

# Dump the final dictionary to a JSON file
with open("weekly_safety_grid.json", "w") as json_file:
    json.dump(final_safety_data, json_file, indent=4)

print("\n✅ SUCCESS! Exported to 'weekly_safety_grid.json'.")
print("Here is your final, frontend-ready safety data:")
print(json.dumps(final_safety_data, indent=4))