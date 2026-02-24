import sys
import socket
import re
import binascii

# --- CONFIGURATION ---
# REPLACE THIS with your PC's VPN IP address (e.g., "10.x.x.x")
TARGET_IP = "192.168.160.22"
TARGET_PORT = 5555
# ---------------------

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

print(f"Forwarding LoRa packets to {TARGET_IP}:{TARGET_PORT}...")

try:
    # Read from the pipe (stdin) line by line
    for line in sys.stdin:
        # Print to local console so you can still see it
        sys.stdout.write(line)
        sys.stdout.flush()

        # Look for the "DATA:" marker we added to the C code
        if "DATA:" in line:
            try:
                # Extract the Hex string after "DATA: "
                parts = line.split("DATA: ")
                if len(parts) > 1:
                    hex_payload = parts[1].strip()
                    
                    # Convert Hex to Bytes
                    raw_bytes = binascii.unhexlify(hex_payload)
                    
                    # Send via UDP
                    sock.sendto(raw_bytes, (TARGET_IP, TARGET_PORT))
            except Exception as e:
                print(f"Error parsing line: {e}")

except KeyboardInterrupt:
    print("\nStopping bridge.")
