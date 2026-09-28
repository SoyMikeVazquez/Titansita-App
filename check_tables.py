import urllib.request
import json

URL = 'https://ffbjqwvadxnqrbxnysjl.supabase.co/rest/v1/'
KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZmYmpxd3ZhZHhucXJieG55c2psIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjEwODY5MzksImV4cCI6MjA3NjY2MjkzOX0.sH2yt0Yfi1z4sdUSlSi8LEcVbQHYw-N7bZqOQYjUIX0'

req = urllib.request.Request(URL, headers={
    'apikey': KEY,
    'Authorization': f'Bearer {KEY}'
})

try:
    with urllib.request.urlopen(req) as response:
        data = json.loads(response.read().decode())
        paths = data.get('paths', {})
        tables = []
        for path in paths.keys():
            if path.startswith('/'):
                tables.append(path[1:])
        print("Tables in schema:")
        for t in sorted(set(tables)):
            if '?' not in t and t != '':
                print("-", t)
except Exception as e:
    print("Error:", e)
