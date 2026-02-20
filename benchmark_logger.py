import subprocess
import json
import csv
import re
import os
import datetime
import signal
import sys

# Configuration
LOG_TAG = "flutter"
SEARCH_PATTERN = "BENCHMARK_DATA: "
CSV_FILE = "benchmark_results.csv"

def signal_handler(sig, frame):
    print("\nExiting...")
    sys.exit(0)

signal.signal(signal.SIGINT, signal_handler)

def main():
    print(f"Starting benchmark logger...")
    print(f"Listening for logs with tag '{LOG_TAG}' containing '{SEARCH_PATTERN}'...")
    print(f"Saving results to '{CSV_FILE}'")
    print("Press Ctrl+C to stop.")

    # Initialize CSV if it doesn't exist
    file_exists = os.path.isfile(CSV_FILE)
    
    with open(CSV_FILE, 'a', newline='', encoding='utf-8') as csvfile:
        fieldnames = [
            'timestamp', 
            'input_text', 
            'input_language', 
            'translated_text', 
            'output_language', 
            'stt_latency_ms', 
            'translation_latency_ms', 
            'tts_latency_ms', 
            'total_latency_ms'
        ]
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)

        if not file_exists:
            writer.writeheader()

        # Run ADB Logcat
        # -v raw removes metadata headers to make parsing easier, but limiting by tag is harder with raw.
        # We'll use standard format and regex to extract the message.
        cmd = ["adb", "logcat", "-s", LOG_TAG]
        
        process = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True, encoding='utf-8', errors='replace')

        while True:
            line = process.stdout.readline()
            if not line:
                break
            
            if SEARCH_PATTERN in line:
                try:
                    # Extract JSON part
                    # Logcat format: date time pid tid priority tag: message
                    # We just look for the pattern and take everything after it
                    json_str = line.split(SEARCH_PATTERN, 1)[1].strip()
                    
                    data = json.loads(json_str)
                    
                    writer.writerow(data)
                    csvfile.flush() # Ensure data is written immediately
                    
                    print(f"[{datetime.datetime.now().strftime('%H:%M:%S')}] Logged translation: {data.get('input_text', '')[:20]}... -> {data.get('translated_text', '')[:20]}... ({data.get('total_latency_ms')}ms)")
                    
                except json.JSONDecodeError as e:
                    print(f"Error parsing JSON: {e}")
                except Exception as e:
                    print(f"Error processing line: {e}")

if __name__ == "__main__":
    main()
