import pandas as pd
from datasets import Dataset
from transformers import DistilBertTokenizer, DistilBertForSequenceClassification, Trainer, TrainingArguments

print("1. Loading the Lonavala Data...")
df = pd.read_csv("lonavala_training.csv")
dataset = Dataset.from_pandas(df)

# Split into 80% training, 20% testing
dataset = dataset.train_test_split(test_size=0.2)

print("2. Downloading the base DistilBERT AI...")
tokenizer = DistilBertTokenizer.from_pretrained("distilbert-base-uncased")
model = DistilBertForSequenceClassification.from_pretrained("distilbert-base-uncased", num_labels=3)

# Function to convert words into numbers the AI can understand
def tokenize_function(examples):
    return tokenizer(examples["text"], padding="max_length", truncation=True)

print("3. Prepping the data for the AI...")
tokenized_datasets = dataset.map(tokenize_function, batched=True)

# Training rules
training_args = TrainingArguments(
    output_dir="./results",
    learning_rate=2e-5,
    per_device_train_batch_size=8,
    num_train_epochs=3, # Read the "textbook" 3 times
    weight_decay=0.01,
)

trainer = Trainer(
    model=model,
    args=training_args,
    train_dataset=tokenized_datasets["train"],
    eval_dataset=tokenized_datasets["test"],
)

print("\n🚀 4. STARTING TRANSFER LEARNING! (Your laptop fans might get loud, this is normal)...")
trainer.train()

print("\n✅ 5. TRAINING COMPLETE! Saving your custom HerCodeX AI...")
model.save_pretrained("./hercodex_lonavala_model")
tokenizer.save_pretrained("./hercodex_lonavala_model")

print("Boom! Your custom model is saved in the folder 'hercodex_lonavala_model'.")