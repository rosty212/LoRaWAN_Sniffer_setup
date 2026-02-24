#!/bin/bash

# SX1308 Reset Script for RAK7246
# Target Pin: GPIO 17
PIN=17

echo "Resetting SX1308 on GPIO $PIN..."

# Function to handle the pin toggling
# It checks if 'pinctrl' (new OS) or 'raspi-gpio' (old OS) is installed
toggle_pin() {
    # Check for the modern 'pinctrl' tool (Raspberry Pi OS Bookworm+)
    if command -v pinctrl > /dev/null; then
        # Set Output (op), Drive High (dh), Drive Low (dl)
        pinctrl set $PIN op
        
        echo "State: HIGH (Reset)"
        pinctrl set $PIN dh
        sleep 0.1
        
        echo "State: LOW (Run)"
        pinctrl set $PIN dl
        sleep 0.1

    # Check for 'raspi-gpio' (Raspberry Pi OS Bullseye/Buster)
    elif command -v raspi-gpio > /dev/null; then
        # Set Output (op), Drive High (dh), Drive Low (dl)
        raspi-gpio set $PIN op
        
        echo "State: HIGH (Reset)"
        raspi-gpio set $PIN dh
        sleep 0.1
        
        echo "State: LOW (Run)"
        raspi-gpio set $PIN dl
        sleep 0.1

    else
        echo "ERROR: Neither 'pinctrl' nor 'raspi-gpio' tools found."
        echo "Please install them: sudo apt install raspi-gpio"
        exit 1
    fi
}

# Run the function
toggle_pin

echo "Reset complete."
