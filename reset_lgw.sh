#!/bin/bash

# SX1308 Reset on GPIO 17 using pinctrl
PIN=17

echo "Resetting SX1308 on GPIO $PIN using pinctrl..."

# Set pin to Output
pinctrl set $PIN op

# Drive High (Reset State)
pinctrl set $PIN dh
sleep 0.1

# Drive Low (Operating State)
pinctrl set $PIN dl
sleep 0.1

echo "Reset complete."
