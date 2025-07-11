import os
from dotenv import load_dotenv
load_dotenv()  # ? Loads the .env file before anything else


from log_watcher import follow_log_file
from chatgpt_helper import get_fix_suggestion

LOG_FILE = "incoming.log"

print(f"📡 Watching log file: {LOG_FILE}")

for error in follow_log_file(LOG_FILE):
    print("\n🚨 Error Detected:\n", error)
    print("🤖 Asking ChatGPT...")
    fix = get_fix_suggestion(error)
    print("\n✅ Suggested Fix:\n", fix)

