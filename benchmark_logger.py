import subprocess
import json
import csv
import re
import os
import datetime
import signal
import sys
import threading
import time

# Configuration
LOG_TAG = "flutter"
SEARCH_PATTERN = "BENCHMARK_DATA: "
CSV_FILE = "benchmark_results.csv"
PACKAGE_NAME = "com.armhack.speech_translator"

current_cpu = "0%"
current_mem_mb = "0.0"
stop_monitoring = False

def monitor_stats():
    global current_cpu, current_mem_mb
    while not stop_monitoring:
        try:
            # get cpu
            cpu_cmd = ["adb", "shell", "dumpsys", "cpuinfo"]
            cpu_out = subprocess.check_output(cpu_cmd, universal_newlines=True, errors='replace', timeout=2)
            for line in cpu_out.splitlines():
                if PACKAGE_NAME in line:
                    parts = line.strip().split()
                    if parts:
                        current_cpu = parts[0].strip('%') + '%'
                    break
                    
            # get memory
            mem_cmd = ["adb", "shell", "dumpsys", "meminfo", PACKAGE_NAME]
            mem_out = subprocess.check_output(mem_cmd, universal_newlines=True, errors='replace', timeout=2)
            for line in mem_out.splitlines():
                if "TOTAL PSS:" in line or (line.strip().startswith("TOTAL:") and "TOTAL:" in line):
                    parts = line.strip().split()
                    for p in parts:
                        if p.isdigit():
                            current_mem_mb = str(round(int(p) / 1024.0, 1))
                            break
                    break
        except Exception:
            pass
        time.sleep(1)

def signal_handler(sig, frame):
    global stop_monitoring
    print("\nExiting...")
    stop_monitoring = True
    sys.exit(0)

signal.signal(signal.SIGINT, signal_handler)

def main():
    print(f"Starting benchmark logger...")
    print(f"Listening for logs with tag '{LOG_TAG}' containing '{SEARCH_PATTERN}'...")
    print(f"Saving results to '{CSV_FILE}'")
    print("Press Ctrl+C to stop.")

    threading.Thread(target=monitor_stats, daemon=True).start()

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
            'total_latency_ms',
            'estimated_tokens',
            'tokens_per_second',
            'cpu_usage',
            'memory_usage_mb'
        ]
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)

        if not file_exists:
            writer.writeheader()


        cmd = ["adb", "logcat", "-s", LOG_TAG]
        
        process = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True, encoding='utf-8', errors='replace')

        while True:
            line = process.stdout.readline()
            if not line:
                break
            
            if SEARCH_PATTERN in line:
                try:
                    json_str = line.split(SEARCH_PATTERN, 1)[1].strip()
                    
                    data = json.loads(json_str)
                    
                    data['cpu_usage'] = current_cpu
                    data['memory_usage_mb'] = current_mem_mb
                    
                    writer.writerow(data)
                    csvfile.flush() # Ensure data is written immediately
                    
                    print(f"[{datetime.datetime.now().strftime('%H:%M:%S')}] Logged translation: {data.get('input_text', '')[:20]}... -> {data.get('translated_text', '')[:20]}... ({data.get('total_latency_ms')}ms) [TPS: {data.get('tokens_per_second')}] [CPU: {current_cpu}, Mem: {current_mem_mb}MB]")
                    
                except json.JSONDecodeError as e:
                    print(f"Error parsing JSON: {e}")
                except Exception as e:
                    print(f"Error processing line: {e}")

if __name__ == "__main__":
    main()