/*
  Arduino Mega Sensor Data Serial Output
  
  This sketch reads sensor data and sends it via serial port in multiple formats.
  Compatible with the Python serial listener for the Flask sensor processing system.
  
  Hardware connections:
  - DHT22 sensor on pin 2 (temperature & humidity)
  - Photoresistor on analog pin A0 (light intensity)
  - MQ-2 gas sensor on analog pin A1 (gas level)
  
  Serial output formats supported:
  1. JSON format (default)
  2. CSV format 
  3. Key-Value format
*/

#include <DHT.h>

// Pin definitions
#define DHT_PIN 2
#define DHT_TYPE DHT22
#define LIGHT_SENSOR_PIN A0
#define GAS_SENSOR_PIN A1

// Create DHT sensor object
DHT dht(DHT_PIN, DHT_TYPE);

// Configuration
const unsigned long SENSOR_INTERVAL = 5000;  // Read sensors every 5 seconds
const int OUTPUT_FORMAT = 1;  // 1=JSON, 2=CSV, 3=Key-Value
const bool DEBUG_MODE = false;  // Set to true for debug output

// Variables
unsigned long lastReadTime = 0;
int readingCount = 0;

void setup() {
  // Initialize serial communication
  Serial.begin(9600);
  
  // Initialize DHT sensor
  dht.begin();
  
  // Initialize analog pins
  pinMode(LIGHT_SENSOR_PIN, INPUT);
  pinMode(GAS_SENSOR_PIN, INPUT);
  
  // Wait for serial port to connect
  while (!Serial) {
    ; // Wait for serial port to connect (needed for native USB)
  }
  
  if (DEBUG_MODE) {
    Serial.println("Arduino Mega Sensor System Initialized");
    Serial.println("Sending sensor data every 5 seconds...");
    Serial.println("Format: JSON");
  }
  
  delay(2000);  // Allow sensors to stabilize
}

void loop() {
  // Check if it's time to read sensors
  if (millis() - lastReadTime >= SENSOR_INTERVAL) {
    
    // Read sensor values
    SensorData data = readSensors();
    
    // Validate sensor readings
    if (isValidSensorData(data)) {
      // Send data in selected format
      switch (OUTPUT_FORMAT) {
        case 1:
          sendDataJSON(data);
          break;
        case 2:
          sendDataCSV(data);
          break;
        case 3:
          sendDataKeyValue(data);
          break;
        default:
          sendDataJSON(data);  // Default to JSON
      }
      
      readingCount++;
    } else {
      if (DEBUG_MODE) {
        Serial.println("Invalid sensor readings, skipping...");
      }
    }
    
    lastReadTime = millis();
  }
  
  // Small delay to prevent overwhelming the system
  delay(100);
}

// Structure to hold sensor data
struct SensorData {
  float temperature;
  float humidity;
  int lightIntensity;
  int gasLevel;
  bool valid;
};

// Read all sensors and return structured data
SensorData readSensors() {
  SensorData data;
  
  // Read temperature and humidity from DHT22
  data.temperature = dht.readTemperature();
  data.humidity = dht.readHumidity();
  
  // Read light intensity (0-1023)
  data.lightIntensity = analogRead(LIGHT_SENSOR_PIN);
  
  // Read gas level (0-1023)
  data.gasLevel = analogRead(GAS_SENSOR_PIN);
  
  // Check if DHT readings are valid
  data.valid = (!isnan(data.temperature) && !isnan(data.humidity));
  
  if (DEBUG_MODE && data.valid) {
    Serial.print("Raw readings - Temp: ");
    Serial.print(data.temperature);
    Serial.print("°C, Humidity: ");
    Serial.print(data.humidity);
    Serial.print("%, Light: ");
    Serial.print(data.lightIntensity);
    Serial.print(", Gas: ");
    Serial.println(data.gasLevel);
  }
  
  return data;
}

// Validate sensor data ranges
bool isValidSensorData(SensorData data) {
  if (!data.valid) return false;
  
  // Check temperature range (-50 to 100°C)
  if (data.temperature < -50 || data.temperature > 100) return false;
  
  // Check humidity range (0-100%)
  if (data.humidity < 0 || data.humidity > 100) return false;
  
  // Light and gas sensors should be in ADC range (0-1023)
  if (data.lightIntensity < 0 || data.lightIntensity > 1023) return false;
  if (data.gasLevel < 0 || data.gasLevel > 1023) return false;
  
  return true;
}

// Send data in JSON format
void sendDataJSON(SensorData data) {
  Serial.print("{\"temperature\": ");
  Serial.print(data.temperature, 1);
  Serial.print(", \"humidity\": ");
  Serial.print(data.humidity, 1);
  Serial.print(", \"light_intensity\": ");
  Serial.print(data.lightIntensity);
  Serial.print(", \"gas_level\": ");
  Serial.print(data.gasLevel);
  Serial.println("}");
}

// Send data in CSV format
void sendDataCSV(SensorData data) {
  Serial.print(data.temperature, 1);
  Serial.print(",");
  Serial.print(data.humidity, 1);
  Serial.print(",");
  Serial.print(data.lightIntensity);
  Serial.print(",");
  Serial.println(data.gasLevel);
}

// Send data in Key-Value format
void sendDataKeyValue(SensorData data) {
  Serial.print("temp=");
  Serial.print(data.temperature, 1);
  Serial.print(",humidity=");
  Serial.print(data.humidity, 1);
  Serial.print(",light=");
  Serial.print(data.lightIntensity);
  Serial.print(",gas=");
  Serial.println(data.gasLevel);
}

// Example functions for different sensor scenarios (for testing)
void simulateTestScenarios() {
  /*
   * Uncomment this function call in loop() to send test data
   * instead of real sensor readings. Useful for testing the
   * Python serial listener without physical sensors.
   */
  
  static int scenario = 0;
  SensorData testData;
  
  switch (scenario % 5) {
    case 0:  // Normal conditions
      testData = {22.5, 45.0, 400, 120, true};
      break;
    case 1:  // Hot conditions
      testData = {32.1, 65.2, 800, 180, true};
      break;
    case 2:  // Cold conditions
      testData = {12.3, 80.5, 150, 95, true};
      break;
    case 3:  // Gas alert
      testData = {25.0, 55.0, 600, 450, true};
      break;
    case 4:  // Extreme conditions
      testData = {35.8, 85.0, 950, 520, true};
      break;
  }
  
  sendDataJSON(testData);
  scenario++;
}

/*
  Example Serial Output:
  
  JSON Format:
  {"temperature": 25.3, "humidity": 60.2, "light_intensity": 512, "gas_level": 150}
  {"temperature": 32.1, "humidity": 65.2, "light_intensity": 800, "gas_level": 180}
  {"temperature": 12.3, "humidity": 80.5, "light_intensity": 150, "gas_level": 95}
  
  CSV Format:
  25.3,60.2,512,150
  32.1,65.2,800,180
  12.3,80.5,150,95
  
  Key-Value Format:
  temp=25.3,humidity=60.2,light=512,gas=150
  temp=32.1,humidity=65.2,light=800,gas=180
  temp=12.3,humidity=80.5,light=150,gas=95
  
  Hardware Setup:
  
  DHT22 Sensor:
  - VCC -> 5V
  - GND -> GND
  - DATA -> Digital Pin 2
  - 10kΩ resistor between VCC and DATA
  
  Photoresistor (Light Sensor):
  - One end -> 5V
  - Other end -> A0 and 10kΩ resistor to GND
  
  MQ-2 Gas Sensor:
  - VCC -> 5V
  - GND -> GND
  - A0 -> Analog Pin A1
  - D0 -> Not connected (we use analog output)
  
  USB Connection:
  - Connect Arduino Mega to computer via USB
  - Note the COM port (e.g., COM3 on Windows, /dev/ttyUSB0 on Linux)
  - Set the same COM port in the Python serial listener configuration
  
  Troubleshooting:
  
  1. If no data appears in serial monitor:
     - Check wiring connections
     - Verify DHT22 sensor is connected properly
     - Ensure 10kΩ pull-up resistor on DHT22 data line
  
  2. If temperature/humidity show NaN:
     - Check DHT22 wiring
     - Wait 2-3 seconds after power on for sensor to stabilize
     - Try a different digital pin
  
  3. If light/gas readings are always 0 or 1023:
     - Check analog sensor wiring
     - Verify voltage divider for photoresistor
     - Ensure MQ-2 has proper power supply
  
  4. Serial communication issues:
     - Match baud rate (9600) in Python listener
     - Check COM port number
     - Close serial monitor before running Python script
*/