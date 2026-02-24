# LoRaWAN Dual Sniffer Setup (Uplink & Downlink)

This repository documents the custom modifications required to build a complete **LoRaWAN Dual-Sniffer system** using the SX1308 concentrator.

Because standard LoRaWAN gateways transmit Downlinks using **Inverted I/Q Polarity** (down-chirps instead of up-chirps), a standard sniffer cannot hear them. To capture full bidirectional traffic reliably, this setup uses **two separate sniffers**:

1. **Sniffer 1 (Uplink):** Standard configuration, modified to filter out "ghost" downlinks caused by RF cross-talk  
2. **Sniffer 2 (Downlink):** Custom hardware-level I/Q inversion, mirrored frequency buckets, and software frequency correction  

Both sniffers are modified to output data in a clean **JSONL (JSON Lines)** format, including:

- Base64-encoded payloads  
- Millisecond timestamps  
- Parsed MType metadata  

---

Notice: This repository is built upon and modifies the open-source [lora_gateway](https://github.com/Lora-net/lora_gateway/tree/master) project originally created by [Lora-net](https://github.com/Lora-net). Full credit goes to the original developers for the core architecture.
