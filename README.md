# README

>  TBD: Spout implementation

---
![alt text](<_assets/Screenshot 2025-03-29 at 00.53.40.png>)

main view

![alt text](<_assets/Screenshot 2025-03-29 at 00.53.46.png>)

debug view

---

## System Requirements

- MacOS (Intel or Arm)
- ~~[Windows] Would need SPOUT Implementation - TBD~~

## Installation

1. Install [Processing](https://processing.org/download) - __Processing 4.x recommended for Intel X86 Architecture__
  > As the [Syphon Lib](https://github.com/Syphon/Processing) for Processing has not been ported for ARM Architechture yet. But running a Processing with Intel Architecture will render the things over Rosetta, on any ARM M Series Macs. [Follow this thread](https://github.com/Syphon/Java/issues/7) for more details.
2. Install the required libraries via Processing's Library Manager
   - Sketch > Import Library > Add Library
   - Search for and install: Syphon, paho-mqtt, ControlP5
3. Clone or download this repository
4. Open `mqtt_trigg_eye.pde` in Processing

## Usage Instructions

### Starting the Application

1. Open `mqtt_trigg_eye.pde` in Processing
2. Click the Run button or press Ctrl/Cmd + R
3. The application window will appear with empty canvases

### Controls

| Key | Function |
|-----|----------|
| `M` | Toggle 'Mirror' |
| `S` | Toggle Syphon Frame sharing |
| `D` | Toggle DEBUG view |
| `1/2/3/4` | Moves pupil to extremes |
| `mouse` | pupil follows mouse |

### MQTT Configuration

MQTT is used to receive extenal triggers for the eye animations.

The MQTT messages used as triggers [are listed here](https://github.com/dattazigzag/mic_level_monitor/blob/main/docs/mqtt_api.md).  

The below configuration could be edited in the .pde file.

> I was lazy to use an external json config for this - too much effort for a PoC

```processing
// MQTT configuration
final String BROKER_IP = "127.0.0.1";
final String BROKER_PORT = "1883";
final String CLIENT_ID = "Processing_MQTT_EYE_Client";
```

> If the MQTT broker is not running during PApplet launch, it will wait for the broker to be available and retry to connect every few seconds and the paho-mqtt lib offers auto reconnect functionality afterwards, if the broker, for some reason goes offline.

---

## LICENSE

[MIT License](LICENSE)
