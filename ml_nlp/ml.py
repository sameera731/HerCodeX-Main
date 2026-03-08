from transformers import pipeline

# 1. Load the NLP "Assistant" (Zero-Shot model)
print("Loading model... (this takes a minute the first time)")
classifier = pipeline("zero-shot-classification", model="facebook/bart-large-mnli")

# 2. A simulated input (e.g., a tweet about a specific grid location)
tweet = "Walking down Main St right now, the streetlights are completely out and it feels super sketchy."

# 3. The HerCodeX Safety Categories (The labels you care about)
safety_categories = ["safe", "poor lighting", "harassment", "police presence", "suspicious activity"]

# 4. Run the magic!
result = classifier(tweet, safety_categories)

# 5. Print out the results
print(f"\nTweet: '{result['sequence']}'")
print("\n--- HerCodeX Safety Breakdown ---")
for label, score in zip(result['labels'], result['scores']):
    print(f"{label}: {score:.2%} match")