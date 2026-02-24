# 📡 Sniffer 2: Downlink Sniffer

This sniffer is specifically modified to listen to **Gateway → Sensor** transmissions.

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

}

/* AFTER */
if (fw_version != FW_VERSION_CAL && fw_version != 1) {
        printf("ERROR: Version of calibration firmware not expected, actual:%d expected:%d\n", fw_version, FW_VERSION_CAL);
        return -1;
    }

```

---

## 3. Base64 Encoder
**File:** `util_pkt_logger/src/util_pkt_logger.c`

**Reason:** To be able to decide on the type of message received by the sniffer, the raw physical payload need to be converted to Base64.

**The Fix:** A custom base64_encode() function converts the raw p->payload into a Base64 string.

At the beginning of the file, around lines 40-80:

```c
/* --- START JSON HELPER FUNCTIONS --- */
// Base64 Encoding Table
static char encoding_table[] = {'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H',
                                'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P',
                                'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X',
                                'Y', 'Z', 'a', 'b', 'c', 'd', 'e', 'f',
                                'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n',
                                'o', 'p', 'q', 'r', 's', 't', 'u', 'v',
                                'w', 'x', 'y', 'z', '0', '1', '2', '3',
                                '4', '5', '6', '7', '8', '9', '+', '/'};
static int mod_table[] = {0, 2, 1};

// Function to encode raw bytes to Base64 string
void base64_encode(const unsigned char *data,
                    size_t input_length,
                    char *encoded_data) {

    size_t output_length = 4 * ((input_length + 2) / 3);
    
    for (size_t i = 0, j = 0; i < input_length;) {
        uint32_t octet_a = i < input_length ? (unsigned char)data[i++] : 0;
        uint32_t octet_b = i < input_length ? (unsigned char)data[i++] : 0;
        uint32_t octet_c = i < input_length ? (unsigned char)data[i++] : 0;

        uint32_t triple = (octet_a << 0x10) + (octet_b << 0x08) + octet_c;

        encoded_data[j++] = encoding_table[(triple >> 3 * 6) & 0x3F];
        encoded_data[j++] = encoding_table[(triple >> 2 * 6) & 0x3F];
        encoded_data[j++] = encoding_table[(triple >> 1 * 6) & 0x3F];
        encoded_data[j++] = encoding_table[(triple >> 0 * 6) & 0x3F];
    }

    for (int i = 0; i < mod_table[input_length % 3]; i++)
        encoded_data[output_length - 1 - i] = '=';
    
    encoded_data[output_length] = '\0';
}
/* --- END JSON HELPER FUNCTIONS --- */
```

---

## 4. JSONL Output
**File:** `util_pkt_logger/src/util_pkt_logger.c`

**Reason:** For our needs, the output file has to be in JSONL format rather than the original CSV.

**The Fix:** A modified logging function to save the file in JSONL without CSV headers.

At around lines 385-405:

```c
/*----------------------------------------------------- MODIFIED LOGGING FUNCTION TO SAVE AS JSONL ---------------------------------------------------- */

void open_log(void) {
    char iso_date[20];

    strftime(iso_date,ARRAY_SIZE(iso_date),"%Y%m%dT%H%M%SZ",gmtime(&now_time)); /* format yyyymmddThhmmssZ */
    log_start_time = now_time; /* keep track of when the log was started, for log rotation */

    sprintf(log_file_name, "pktlog_%s_%s.jsonl", lgwm_str, iso_date);
    log_file = fopen(log_file_name, "a"); /* create log file, append if file already exist */
    if (log_file == NULL) {
        MSG("ERROR: impossible to create log file %s\n", log_file_name);
        exit(EXIT_FAILURE);
    }

    MSG("INFO: Now writing to log file %s\n", log_file_name);
    return;
}


/*----------------------------------------------------- END OF MODIFIED LOGGING FUNCTION TO SAVE AS JSONL ---------------------------------------------------- */

```

---

## 5. Global Configuration File

**File:** `util_pkt_logger/global_conf.json`

**Reason:** Because `LGW_RX_INVERT_IQ=1` creates a complex conjugate mirror of the frequency spectrum, the standard negative frequency offsets (e.g., 868.1 MHz at -400kHz) flip to the positive side (868.9 MHz at +400kHz).

**Fix:** We must configure "mirror buckets" to capture the traffic, with the center frequency being 868.5 for radio 1.

```json
"chan_multiSF_0": {
            /* Lora MAC channel, 125kHz, all SF, 868.1 (868.9) MHz */
            "enable": true,
            "radio": 1,
            "if": 400000
        },
"chan_multiSF_1": {
            /* Lora MAC channel, 125kHz, all SF, 868.3 (868.7) MHz */
            "enable": true,
            "radio": 1,
            "if": 200000
        },
```

---

## 6. Frequency Polarity Inversion

**File:** `libloragw/src/loragw_hal.c`

**Reason:** To detect downlink preambles, the SX1308 hardware must be forced into **Inverted I/Q mode** during initialization.

**Fix:** Modify `lgw_constant_adjust(void)` around line 230.

Find the lines required for an inverted I/Q and comment them out with the changed value:
```c
void lgw_constant_adjust(void) {
    /* I/Q path setup */
    lgw_reg_w(LGW_RX_INVERT_IQ,1); /* CHANGED: default 0 -> 1 */
    //lgw_reg_w(LGW_MODEM_INVERT_IQ,0); /* default 1 */
    //lgw_reg_w(LGW_CHIRP_INVERT_RX,0); /* default 1 */
    // lgw_reg_w(LGW_RX_EDGE_SELECT,0); /* default 0 */
    lgw_reg_w(LGW_MBWSSF_MODEM_INVERT_IQ,1); /* CHANGED: default 0 -> 1 */

    /* ... rest of the function remains standard ... */
}
```

---

## 7. Logger Modifications

**File:** `util_pkt_logger/src/util_pkt_logger.c`

**Packet Processing & Logging Pipeline**

Whenever the concentrator receives a batch of packets, the software loops through each one and processes it through the following pipeline:

1. **Message Type Extraction & Filtering**

   The software inspects the very first byte of the packet (the MAC Header) to determine its Message Type (MType). It explicitly checks if the packet is a Downlink (Join Accept, Unconfirmed Data Down, or Confirmed Data Down). If the packet is anything else, it is immediately discarded and ignored.

   Because of the hardware inversion, this sniffer will only capture downlinks, but we must explicitly filter out uplinks.

   Using the m_type attribute, decide if the current packet is uplink or downlink, and either drop it or log it.

   **Filter Out Uplinks:**
```c
/* --- ALLOW DOWNLINKS ONLY (FILTER) --- */.
// If it is NOT a Join Accept (1), Unconf Down (3), or Conf Down (5), SKIP IT.

    uint8_t m_type = (p->payload[0] >> 5) & 0x07;
if (m_type != 1 && m_type != 3 && m_type != 5) {
    continue;
}
```

2. **High-Precision Timestamping**

   It captures the exact system time the packet was fetched. It calculates the milliseconds from the hardware's nanosecond counter and formats a highly accurate, human-readable timestamp string (YY-MM-DD HH:MM:SS.mmm).

3. **Base64 Payload Encoding**

   Since LoRaWAN payloads are transmitted as raw hexadecimal bytes, the software passes the raw payload through a custom encoding function to convert it into a standard Base64 string. This makes the payload compatible with standard JSON parsers and network servers.

4. **Radio Metadata Translation**

   The software maps the hardware's internal machine codes into standard numerical and string values. It translates:

   - Bandwidth identifiers (e.g., converting the internal BW_125KHZ flag to 125000).

   - Error correction rates (e.g., mapping to "CR_4_5").

   -  Spreading Factors (e.g., converting the internal SF7 flag to the integer 7).

5. **Direction and Type Labeling (MType Parser)**

   Using the MType extracted in Step 1, this function assigns human-readable labels to the packet. It determines the direction (UPLINK, DOWNLINK, RFU, or PROPRIETARY) and writes out exactly what the packet is doing (e.g., "Join Accept").

   A switch statement mapping m_type (0 through 7) to readable strings (e.g., "Join Request", "Unconfirmed Data Down"), in the main packet log loop, around lines 600-650:
```c
/* --- NEW: PARSE MESSAGE TYPE (UPLINK vs DOWNLINK) --- */
            // The first byte (p->payload[0]) contains the MHDR
            // We shift right by 5 bits to get the 3-bit MType

            char *direction_str = "UNKNOWN";
            char *type_description = "Unknown";

            switch(m_type) {
                case 0: // 000
                    direction_str = "UPLINK";
                    type_description = "Join Request";
                    break;
                case 1: // 001
                    direction_str = "DOWNLINK";
                    type_description = "Join Accept";
                    break;
                case 2: // 010
                    direction_str = "UPLINK";
                    type_description = "Unconfirmed Data Up";
                    break;
                case 3: // 011
                    direction_str = "DOWNLINK";
                    type_description = "Unconfirmed Data Down";
                    break;
                case 4: // 100
                    direction_str = "UPLINK";
                    type_description = "Confirmed Data Up";
                    break;
                case 5: // 101
                    direction_str = "DOWNLINK";
                    type_description = "Confirmed Data Down";
                    break;
                case 6: // 110
                    direction_str = "RFU";
                    type_description = "Rejoin Request";
                    break;
                case 7: // 111
                    direction_str = "PROPRIETARY";
                    type_description = "Proprietary";
                    break;
            }
            /* --- END NEW --- */

```


6. **Frequency Mirror Correction**

   The software intercepts the reported frequency and checks if it matches any known "Mirrored" frequencies (e.g., 868.9 MHz or 867.9 MHz). If it detects a mirror frequency, it mathematically rewrites the value back to the true physical frequency (e.g., 868.1 MHz or 867.1 MHz) so the logs reflect reality.

   *This must be placed before the JSON printf/fprintf functions.*
```c
/* --- CORRECTED FREQUENCY MAPPING --- */
        if (p->freq_hz == 868900000) {
             p->freq_hz = 868100000;
        }
        else if (p->freq_hz == 868700000) {
             p->freq_hz = 868300000;
        }
        else if (p->freq_hz == 867900000) {
             p->freq_hz = 867100000;
        }
        else if (p->freq_hz == 867100000) {
             p->freq_hz = 867900000;
        }
        else if (p->freq_hz == 867700000) {
             p->freq_hz = 867300000;
        }
        else if (p->freq_hz == 867300000) {
             p->freq_hz = 867700000;
        }
```

7. **JSONL Construction and Output**

   It takes all the gathered data - timestamp, Base64 payload, MHDR data, physical TX parameters (frequency, modulation), and RX conditions (RSSI, SNR, CRC status) - and formats it into a single, structured JSON object string. This string is then printed to the live console and appended to the active log file as a new line.

   *It looks something like this:*

```json
{"timestamp":"26-02-24 11:52:04.857","phyPayload":"YPJ7GU5R4P8AAToWsSU=","mhdr":{"direction":"DOWNLINK","type":"Unconfirmed Data Down","mTypeID":3},"txInfo":{"frequency":868300000,"modulation":{"lora":{"bandwidth":125000,"spreadingFactor":7,"codeRate":"CR_4_5"}}},"rxInfo":{"gatewayId":"2E76B17A0F712728","uplinkId":6166859,"rssi":-103,"snr":0.0,"channel":1,"rfChain":1,"context":"AAAAAA==","crcStatus":"CRC_OK"}}
```

8. **Log File Rotation**

   Finally, a background counter tracks how long the current log file has been open. If the configured time limit (usually 1 hour) has been reached, the software safely closes the current log file, summarizes how many packets were caught, and opens a fresh file to prevent the logs from becoming too massive to open.

---

## 8. Build Instructions

After making any changes to source files (/opt/lora_gateway/util_pkt_logger) or the HAL library (/opt/lora_gateway/libloragw):

1. Navigate to the util_pkt_logger or libloragw root directory (don't stay inside /src)  
2. Run `make clean`  
3. Run `make all`
