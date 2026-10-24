/*
  UHI_BLE_Sensor.ino
  ------------------
  Reads surface temperature, broadcasts it over Bluetooth LE to the UHI
  Tracker iOS app, and mirrors live status on a 16x2 character LCD.

  TARGET BOARD: Arduino GIGA R1 WiFi (ABX00063)
    Board package: "Arduino Mbed OS GIGA Boards"
    Select: Tools > Board > Arduino Mbed OS GIGA Boards > Arduino GIGA R1

  ============================ IMPORTANT ============================
  1. ATTACH THE ANTENNA. The GIGA R1 WiFi has NO built-in antenna. The
     small antenna in the box screws onto the U.FL connector near the
     USB-C port. Without it, BLE range is a few centimeters at best.

  2. BLE RUNS ON THE M7 CORE ONLY. BLE.begin() silently returns 0 on
     the M4. Upload to the default main (M7) core.

  3. ANALOG INPUTS ARE 3.3V MAX, NOT 5V TOLERANT. Wire the thermistor
     divider (if used) to the 3.3V pin, never 5V.

  4. THE LCD IS POWERED FROM 5V BUT DRIVEN BY 3.3V LOGIC. This is safe
     in the wiring below ONLY because R/W is tied to GND, making the
     LCD write-only — it never drives a signal back into the GIGA. Do
     not connect R/W to a GIGA pin. See HARDWARE.md for the full
     explanation and the I2C-backpack alternative.
  ===================================================================

  DISPLAY: 1602A (16x2 HD44780) in 4-bit parallel mode.
    Line 1: live surface temperature
    Line 2: status — pushed from the iOS app over BLE, so the display
            shows the live recording count during a survey without you
            needing to look at your phone.

  SENSOR OPTIONS — pick one by editing USE_IR_SENSOR below.
    Option A (recommended): MLX90614 non-contact infrared, I2C.
    Option B (cheapest):    10k NTC thermistor divider on A0.

  LIBRARIES REQUIRED (Tools > Manage Libraries):
    - ArduinoBLE                     (always)
    - Adafruit MLX90614 Library      (only if USE_IR_SENSOR is 1)
    - LiquidCrystal                  (bundled with the IDE; used when
                                      USE_LCD is 1 and USE_I2C_LCD is 0)
    - LiquidCrystal I2C  by Frank de Brabander
                                     (only if USE_I2C_LCD is 1)

  PROTOCOL
    Service 19B10000-E8F2-537E-4F6C-D104768A1214
      - 19B10001-...  temperature, READ | NOTIFY, ASCII e.g. "24.7"
                      (unchanged; updated every 2 s)
      - 19B10002-...  status text, READ | WRITE, ASCII up to 20 chars
                      (new; the app writes what it wants on LCD line 2)
*/

#include <ArduinoBLE.h>

// ---- Sensor: 1 = MLX90614 infrared, 0 = NTC thermistor ----
#define USE_IR_SENSOR 1

// ---- Display: 1 = drive a 1602A LCD, 0 = no display ----
#define USE_LCD 1
// ---- 0 = 4-bit parallel wiring (recommended on the GIGA, no level
//      shifter needed). 1 = PCF8574 I2C backpack (REQUIRES a level
//      shifter on SDA/SCL — see HARDWARE.md). ----
#define USE_I2C_LCD 0

#if USE_IR_SENSOR
  #include <Wire.h>
  #include <Adafruit_MLX90614.h>
  Adafruit_MLX90614 mlx = Adafruit_MLX90614();
#endif

#if USE_LCD
  #if USE_I2C_LCD
    #include <Wire.h>
    #include <LiquidCrystal_I2C.h>
    // 0x27 is the most common backpack address; some are 0x3F.
    LiquidCrystal_I2C lcd(0x27, 16, 2);
  #else
    #include <LiquidCrystal.h>
    // LiquidCrystal(RS, E, D4, D5, D6, D7)
    const int LCD_RS = 12, LCD_EN = 11, LCD_D4 = 5, LCD_D5 = 4, LCD_D6 = 3, LCD_D7 = 2;
    LiquidCrystal lcd(LCD_RS, LCD_EN, LCD_D4, LCD_D5, LCD_D6, LCD_D7);
  #endif
#endif

// --- Must match UHIBLEIdentifiers in BluetoothManager.swift ---
BLEService uhiService("19B10000-E8F2-537E-4F6C-D104768A1214");

BLEStringCharacteristic temperatureCharacteristic(
    "19B10001-E8F2-537E-4F6C-D104768A1214",
    BLERead | BLENotify,
    16
);

// The app writes to this to drive LCD line 2 (e.g. "REC 12 pts").
BLEStringCharacteristic statusCharacteristic(
    "19B10002-E8F2-537E-4F6C-D104768A1214",
    BLERead | BLEWrite,
    20
);

// --- Thermistor config (used only when USE_IR_SENSOR is 0) ---
const int THERMISTOR_PIN = A0;
const float SERIES_RESISTOR = 10000.0;
const float NOMINAL_RESISTANCE = 10000.0;
const float NOMINAL_TEMPERATURE = 25.0;
const float B_COEFFICIENT = 3950.0;

// The GIGA's ADC defaults to 10-bit for AVR compatibility. 12-bit is a
// real accuracy gain; we don't ask for 16 because only the top 14 bits
// are genuine data on this chip, so it would be false precision.
const int ADC_RESOLUTION_BITS = 12;
const float ADC_MAX = (1 << ADC_RESOLUTION_BITS) - 1;

unsigned long lastUpdateMs = 0;
const unsigned long UPDATE_INTERVAL_MS = 2000;

// Cached so we only repaint the LCD when something actually changed —
// needless redraws make the display flicker visibly.
String lastTempShown = "";
String lastStatusShown = "";

void setup() {
  Serial.begin(9600);
  unsigned long serialWaitStart = millis();
  while (!Serial && (millis() - serialWaitStart < 3000)) { }

#if USE_LCD
  #if USE_I2C_LCD
    lcd.init();
    lcd.backlight();
  #else
    lcd.begin(16, 2);
  #endif
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("UHI Tracker");
  lcd.setCursor(0, 1);
  lcd.print("Starting...");
#endif

#if USE_IR_SENSOR
  Wire.begin();
  if (!mlx.begin()) {
    Serial.println("MLX90614 not found. Check SDA/SCL wiring and 3.3V power.");
    showStatus("No IR sensor");
    while (1) { delay(100); }
  }
  Serial.println("MLX90614 infrared sensor ready.");
#else
  analogReadResolution(ADC_RESOLUTION_BITS);
  Serial.println("Thermistor mode ready.");
#endif

  if (!BLE.begin()) {
    Serial.println("Failed to start BLE! (GIGA: BLE only works on the M7 core.)");
    showStatus("BLE failed");
    while (1) { delay(100); }
  }

  BLE.setLocalName("UHI-Sensor-01");
  BLE.setDeviceName("UHI-Sensor-01");
  BLE.setAdvertisedService(uhiService);

  uhiService.addCharacteristic(temperatureCharacteristic);
  uhiService.addCharacteristic(statusCharacteristic);
  BLE.addService(uhiService);

  temperatureCharacteristic.writeValue("0.0");
  statusCharacteristic.writeValue("Ready");

  BLE.advertise();
  Serial.println("UHI BLE sensor advertising as 'UHI-Sensor-01'...");
  Serial.println("If your phone can't find it, check the antenna is attached.");
  showStatus("Advertising...");
}

void loop() {
  BLEDevice central = BLE.central();

  if (central) {
    Serial.print("Connected to: ");
    Serial.println(central.address());
    showStatus("Connected");

    while (central.connected()) {
      // If the app pushed new status text, mirror it on line 2.
      if (statusCharacteristic.written()) {
        String incoming = statusCharacteristic.value();
        showStatus(incoming);
        Serial.print("Status from app: ");
        Serial.println(incoming);
      }

      if (millis() - lastUpdateMs >= UPDATE_INTERVAL_MS) {
        lastUpdateMs = millis();
        float tempC = readSurfaceTemperature();

        // snprintf rather than dtostrf: dtostrf is an AVR-ism and isn't
        // dependably available on the GIGA's mbed core.
        char buffer[16];
        snprintf(buffer, sizeof(buffer), "%.1f", tempC);
        temperatureCharacteristic.writeValue(buffer);
        showTemperature(tempC);

        Serial.print("Surface temp: ");
        Serial.println(buffer);
      }
    }

    Serial.println("Disconnected.");
    showStatus("Advertising...");
  } else {
    // Keep the display live even with no phone attached, so the rig is
    // useful as a standalone thermometer.
    if (millis() - lastUpdateMs >= UPDATE_INTERVAL_MS) {
      lastUpdateMs = millis();
      showTemperature(readSurfaceTemperature());
    }
  }
}

float readSurfaceTemperature() {
#if USE_IR_SENSOR
  // Object temperature = the surface the sensor is aimed at.
  // readAmbientTempC() would give the sensor's own body temperature;
  // the app gets ambient air from the weather API instead.
  return mlx.readObjectTempC();
#else
  int raw = analogRead(THERMISTOR_PIN);
  if (raw <= 0) return NAN;

  float resistance = SERIES_RESISTOR / ((ADC_MAX / (float)raw) - 1.0);

  float steinhart = resistance / NOMINAL_RESISTANCE;
  steinhart = log(steinhart);
  steinhart /= B_COEFFICIENT;
  steinhart += 1.0 / (NOMINAL_TEMPERATURE + 273.15);
  steinhart = 1.0 / steinhart;
  steinhart -= 273.15;

  return steinhart;
#endif
}

// MARK: - Display helpers
// Both are no-ops when USE_LCD is 0, so the sketch runs unchanged
// without a display attached.

void showTemperature(float tempC) {
#if USE_LCD
  char line[17];
  if (isnan(tempC)) {
    snprintf(line, sizeof(line), "Surface: --.-C");
  } else {
    snprintf(line, sizeof(line), "Surface:%6.1fC", tempC);
  }
  String next = String(line);
  if (next == lastTempShown) return;
  lastTempShown = next;

  lcd.setCursor(0, 0);
  lcd.print(padTo16(next));
#endif
}

void showStatus(String text) {
#if USE_LCD
  if (text == lastStatusShown) return;
  lastStatusShown = text;

  lcd.setCursor(0, 1);
  lcd.print(padTo16(text));
#endif
}

// The 1602 has no "clear this line" call, so short text would leave
// stale characters behind. Pad to the full 16 columns to wipe them.
String padTo16(String text) {
  if (text.length() > 16) return text.substring(0, 16);
  while (text.length() < 16) text += ' ';
  return text;
}
