# 📡 Sniffer 1: Uplink Sniffer

This sniffer is dedicated to listening to standard End-Device transmissions (**Sensors → Gateway**).

---


## 1. SPI Clock Speed Reduction (RAK HAT SX1308 Hardware Patch)
**File:** `libloragw/src/loragw_spi.native.c`

**Reason:** The SX1308 chip on these specific HATs is highly sensitive to the SPI clock speed. The default 8 MHz (8000000) is often too fast and causes the Pi to read garbage data from the chip's registers, resulting in a "Failed to start concentrator" error.

**The Fix:** Lower the SPI speed to 2 MHz. 

Find the `READ_ACCESS` and `WRITE_ACCESS` configurations (usually around line 55) and change the speed variable:

```c
/* BEFORE */
#define SPI_SPEED       8000000

/* AFTER */
#define SPI_SPEED       2000000
```

---

## 2. Firmware Version Bypass
**File:** `libloragw/src/loragw_hal.c`

**Reason:** The official Semtech `lora_gateway` code expects the concentrator to report Firmware Version 2. However, many RAK HATs ship with Firmware Version 1. If the code only checks for Version 2, the initialization will abort.

**The Fix:** Modify the hardware check to accept Version 1 as a valid firmware version.

Find the `lgw_start` function (around line 815) where it checks the firmware version:
```c
/* BEFORE */
if (fw_version != FW_VERSION_CAL) {
        printf("ERROR: Version of calibration firmware not expected, actual:%d expected:%d\n", fw_version, FW_VERSION_CAL);
        return -1;
    }

/* AFTER */
if (fw_version != FW_VERSION_CAL && fw_version != 1) {
        printf("ERROR: Version of calibration firmware not expected, actual:%d expected:%d\n", fw_version, FW_VERSION_CAL);
        return -1;
    }
```


---

## 3. Global Configuration File

**File:** `global_conf.json`

The configuration uses the standard **EU868 band plan**.

- No special frequency mirroring is required  
- Standard IF offsets (`-400000`, `-200000`, `0`, etc.) are used  
- Applies to both **Radio 0** and **Radio 1**

---

## 4. Logger Modifications

**File:** `util_pkt_logger/src/util_pkt_logger.c`

**Reason:** To prevent this sniffer from logging accidental **Ghost Downlinks** (caused by signal saturation from a nearby gateway), a software filter needs to drop any packets identified as downlinks.

**The Fix:** Using the m_type attribute, decide if the current packet is uplink or downlink, and either drop it or log it.

Insert inside the main `while` loop (before JSON formatting):

```c
/* --- SKIP DOWNLINKS (FILTER) --- */
// Downlink Types: 1 (Join Accept), 3 (Unconf Down), 5 (Conf Down)
uint8_t m_type = (p->payload[0] >> 5) & 0x07;

if (m_type == 1 || m_type == 3 || m_type == 5) {
    continue; // Skip the rest of the loop, do not log this packet
}
```
---

## 5. Build Instructions

After making any changes to source files (/opt/lora_gateway/util_pkt_logger) or the HAL library (/opt/lora_gateway/libloragw):

1. Navigate to the util_pkt_logger or libloragw root directory (don't stay inside /src)  
2. Run `make clean`  
3. Run `make all`
