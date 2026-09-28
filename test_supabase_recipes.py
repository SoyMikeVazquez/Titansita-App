import requests
import json
import time

URL = 'https://ffbjqwvadxnqrbxnysjl.supabase.co/rest/v1/recipes'
KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZmYmpxd3ZhZHhucXJieG55c2psIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjEwODY5MzksImV4cCI6MjA3NjY2MjkzOX0.sH2yt0Yfi1z4sdUSlSi8LEcVbQHYw-N7bZqOQYjUIX0'

headers = {
    'apikey': KEY,
    'Authorization': f'Bearer {KEY}',
    'Content-Type': 'application/json',
    'Prefer': 'return=representation'
}

data = {
    "title": "Test Recipe",
    "calories": 500,
    "protein": "30g",
    "carbs": "40g",
    "fat": "10g",
    "time": "30 min",
    "difficulty": "Easy",
    "ingredients": ["1 apple", "1 banana"],
    "steps": ["Eat apple", "Eat banana"]
}

response = requests.post(URL, headers=headers, json=data)
print("Status Code:", response.status_code)
print("Response:", response.text)
