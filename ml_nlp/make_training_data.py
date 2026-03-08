import pandas as pd

print("Generating Lonavala Transfer Learning Dataset...")

# 0 = Safe, 1 = Cautious, 2 = Danger
data = [
    # Cautious (The subtle feelings your friend mentioned)
    {"text": "The road to Tiger Point is completely deserted right now.", "label": 1},
    {"text": "No autos outside Lonavala station and it's getting super foggy.", "label": 1},
    {"text": "Streetlights near Khandala Ghat are flickering, hard to see.", "label": 1},
    {"text": "Quiet around Ryewood park, but a few guys are just lingering.", "label": 1},
    {"text": "Lots of blind spots on the walk to the college campus at night.", "label": 1},
    
    # Danger (Actionable threats)
    {"text": "Someone is following me near the highway exit.", "label": 2},
    {"text": "Pitch black blackout on this street, do not walk here.", "label": 2},
    {"text": "Group of men catcalling outside the dhaba.", "label": 2},
    {"text": "Got harassed waiting for the bus near Bhushi Dam.", "label": 2},
    
    # Safe (Good baseline)
    {"text": "Lots of families and police around the market area, feels secure.", "label": 0},
    {"text": "SIT campus is well lit and crowded, no issues.", "label": 0},
    {"text": "Sunny and busy near the chikki shops, completely safe.", "label": 0},
    {"text": "Police jeep is patrolling the main road.", "label": 0},
]

# Duplicate the data a few times to make the dataset large enough for the AI to "learn"
expanded_data = data * 15 

df = pd.DataFrame(expanded_data)
df.to_csv("lonavala_training.csv", index=False)
print("✅ Created 'lonavala_training.csv' with", len(df), "rows.")