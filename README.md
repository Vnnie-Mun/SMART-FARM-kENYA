# Arduino Sensor Data Processor with Gemini AI + SMS Alerts

A Flask-based server application that receives sensor data from Arduino Mega via USB serial communication, uses Google Gemini AI to make intelligent control decisions, and sends real-time SMS alerts to farmers via Africa's Talking API.

## 🚀 Features

- **Serial Communication** reads Arduino sensor data via USB connection
- **Multiple Data Formats** supports JSON, CSV, and key-value formats from Arduino
- **Google Gemini AI Integration** for intelligent decision making
- **SMS Alerts via Africa's Talking** for real-time farmer notifications
- **Environmental Control Logic** for temperature, humidity, light, and gas monitoring
- **Intelligent Alert Management** prevents SMS spam with state tracking
- **Farmer-Friendly Messages** with emojis and clear action guidance
- **Automatic Reconnection** handles serial disconnections gracefully
- **Comprehensive Logging** of sensor data, AI decisions, and SMS alerts
- **Configurable Thresholds** for all sensor parameters and alert cooldowns
- **Robust Error Handling** with fallback rule-based decisions
- **Health Check Endpoints** for monitoring system status
- **Test Simulator** for development without physical Arduino

## 📊 Sensor Data Processing

The system processes four types of sensor data:
- **Temperature** (°C) - Controls fan and LED color
- **Humidity** (%) - Additional environmental context
- **Light Intensity** (0-1023) - Ambient light monitoring
- **Gas Level** (0-1023) - Safety gas detection

## 🧠 AI Decision Logic

### Temperature Control Rules:
- `≥ 30°C`: Start fan, turn on red LED (hot)
- `15°C - 30°C`: Stop fan, turn on yellow LED (normal)
- `< 15°C`: Stop fan, turn on blue LED (cold)

### Safety Rules:
- `Gas Level > 300`: Trigger gas alert (critical priority)

All decisions are processed through Google Gemini AI for intelligent reasoning and can fall back to rule-based logic if AI processing fails. Critical alerts automatically trigger SMS notifications to farmers with actionable information.

## 🛠️ Installation & Setup

### 1. Clone and Install Dependencies

```bash
git clone <repository-url>
cd arduino-sensor-processor
pip install -r requirements.txt
```

### 2. Configure Environment Variables

Copy the example environment file and configure your settings:

```bash
cp .env.example .env
```

Edit `.env` with your configuration:

```bash
# Required: Get your API key from Google AI Studio
GEMINI_API_KEY=your_gemini_api_key_here

# Optional: Customize thresholds
TEMP_HOT_THRESHOLD=30.0
TEMP_COLD_THRESHOLD=15.0
GAS_ALERT_THRESHOLD=300

# Flask settings
FLASK_HOST=0.0.0.0
FLASK_PORT=5000
DEBUG=False
```

### 3. Get API Keys

**Google Gemini API Key:**
1. Visit [Google AI Studio](https://makersuite.google.com/app/apikey)
2. Create a new API key
3. Add it to your `.env` file as `GEMINI_API_KEY`

**Africa's Talking API Key (for SMS):**
1. Sign up at [Africa's Talking](https://africastalking.com/)
2. Go to your dashboard and get your API key
3. For sandbox testing, use username: `sandbox`
4. Add credentials to your `.env` file:
   ```bash
   AT_USERNAME=sandbox
   AT_API_KEY=your_api_key_here
   AT_RECIPIENT_PHONE=+254712345678
   ```

### 4. Run the System

#### 🐳 Docker (Recommended)

**Quick Start with Docker Compose:**
```bash
# Production
docker-compose up -d

# Development with hot reload
docker-compose -f docker-compose.dev.yml up -d
```

**Using Build Scripts:**
```bash
# Build Docker images
./scripts/build.sh --type production

# Run container with auto-detection
./scripts/run.sh start

# Windows users
scripts\run.bat start
```

#### 🐍 Python (Local Development)

**Option A: Complete System (Flask + Serial Listener)**

Terminal 1 - Start Flask Server:
```bash
python app.py
```

Terminal 2 - Start Serial Listener:
```bash
python serial_listener.py --port COM3
```

**Option B: Flask Server Only (for HTTP requests)**
```bash
python app.py
```

The Flask server will start on `http://localhost:5000` by default.

## 📡 API Documentation

### POST /submit-data

Submit sensor data for AI processing.

**Request Format:**
```json
{
  "temperature": 25.5,
  "humidity": 60.2,
  "light_intensity": 512,
  "gas_level": 150
}
```

**Response Format:**
```json
{
  "status": "success",
  "timestamp": "2024-01-15T10:30:00.123456",
  "sensor_data": {
    "temperature": 25.5,
    "humidity": 60.2,
    "light_intensity": 512,
    "gas_level": 150
  },
  "decision": {
    "action": "stop fan",
    "led": "yellow",
    "fan": "off",
    "gas_alert": false,
    "reasoning": "Temperature is in normal range (15-30°C), no gas alert needed",
    "priority": "low"
  },
  "sms_alert": {
    "success": true,
    "alerts_sent": ["temperature"],
    "count": 1
  }
}
```

### GET /health

Health check endpoint.

**Response:**
```json
{
  "status": "healthy",
  "timestamp": "2024-01-15T10:30:00.123456",
  "service": "Arduino Sensor Data Processor"
}
```

### POST /sms/test

Send a test SMS message to verify SMS functionality.

**Response:**
```json
{
  "status": "success",
  "message": "Test SMS sent successfully",
  "details": {
    "success": true,
    "message": "🧪 Test message from Arduino Sensor System...",
    "recipient": "+254712345678",
    "cost": "KES 0.8000",
    "message_id": "ATXid_sample123"
  }
}
```

### GET /sms/status

Get SMS service status and configuration.

**Response:**
```json
{
  "sms_service": {
    "sms_enabled": true,
    "sandbox_mode": true,
    "recipient_configured": true,
    "sender_id": "FARMIOT",
    "gas_alert_cooldown": "300 seconds"
  }
}
```

### GET /

API information and documentation.

## 🧪 Testing

### Serial Communication Testing

**Test with Simulator (No Arduino Required):**
```bash
# Run test simulator
python serial_test_simulator.py --test

# Run with specific format
python serial_test_simulator.py --format json --interval 2

# Continuous mode
python serial_test_simulator.py --mode continuous --base-scenario hot
```

**Test with Real Arduino:**
1. Upload `arduino_example.ino` to your Arduino Mega
2. Connect via USB and note the COM port
3. Run serial listener:
   ```bash
   python serial_listener.py --port COM3
   ```

### Flask API Testing

Run the comprehensive test suite:

```bash
python test_requests.py
```

This will test:
- ✅ Health check endpoint
- ✅ All sensor data scenarios (normal, hot, cold, gas alert, extreme)
- ✅ SMS service status and configuration
- ✅ Error handling for invalid data
- ✅ Response format validation

**Note:** To test actual SMS sending, uncomment the test SMS section in `test_requests.py` and ensure you have valid Africa's Talking credentials.

### Manual Testing with curl

**Normal conditions:**
```bash
curl -X POST http://localhost:5000/submit-data \
  -H 'Content-Type: application/json' \
  -d '{"temperature": 22.5, "humidity": 45.0, "light_intensity": 400, "gas_level": 120}'
```

**Hot conditions (should trigger fan):**
```bash
curl -X POST http://localhost:5000/submit-data \
  -H 'Content-Type: application/json' \
  -d '{"temperature": 32.1, "humidity": 65.2, "light_intensity": 800, "gas_level": 180}'
```

**Gas alert conditions:**
```bash
curl -X POST http://localhost:5000/submit-data \
  -H 'Content-Type: application/json' \
  -d '{"temperature": 25.0, "humidity": 55.0, "light_intensity": 600, "gas_level": 450}'
```

**Test SMS functionality:**
```bash
# Check SMS status
curl -X GET http://localhost:5000/sms/status

# Send test SMS (requires valid credentials)
curl -X POST http://localhost:5000/sms/test
```

### Testing with Postman

1. Import the sample payloads from `sample_arduino_payload.json`
2. Set up POST requests to `http://localhost:5000/submit-data`
3. Use the provided test scenarios for comprehensive testing
4. Test SMS endpoints at `/sms/status` and `/sms/test`

## 📱 SMS Alert System

### Farmer-Friendly Messages

The system sends intelligent SMS alerts using Africa's Talking API with:

- **🌡️ Temperature Alerts**: "HIGH TEMP ALERT: 32.1°C detected! Fan turned ON automatically. Red warning light activated. Please check your crops immediately."
- **🚨 Gas Alerts**: "GAS ALERT! Dangerous gas levels detected (450/1023). IMMEDIATE ACTION REQUIRED! Check for gas leaks, ensure ventilation, and evacuate if necessary."
- **✅ Status Updates**: "TEMP NORMALIZED: 25.0°C. Fan turned OFF automatically. Yellow indicator shows normal conditions."
- **❄️ Cold Warnings**: "LOW TEMP ALERT: 12.3°C detected! Fan turned OFF. Blue indicator active. Consider protective measures for your crops."

### Smart Alert Management

- **State Tracking**: Prevents SMS spam by only sending alerts when conditions actually change
- **Gas Alert Cooldown**: Critical gas alerts limited to once every 5 minutes
- **Priority Escalation**: Alerts sent when conditions escalate to high/critical priority
- **Persistent State**: System remembers previous states across restarts

### Sample SMS Messages

See `sample_sms_messages.json` for complete examples of all alert types and scenarios.

## 🐳 Docker Deployment

### Quick Start with Docker

**1. Build and Run (Production):**
```bash
# Build the image
./scripts/build.sh --type production

# Run with auto-detected serial port
./scripts/run.sh start

# Access at http://localhost:5000
```

**2. Development with Hot Reload:**
```bash
# Build development image
./scripts/build.sh --type dev

# Run development container
./scripts/run.sh start --dev

# Or use docker-compose for development
docker-compose -f docker-compose.dev.yml up -d
```

### Docker Compose (Recommended)

**Production Deployment:**
```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

**Development Environment:**
```bash
# Start with hot reload and development tools
docker-compose -f docker-compose.dev.yml up -d

# Includes PostgreSQL and Redis for testing
# Access development database at localhost:5433
```

### Cross-Platform Serial Port Support

**Linux:**
```bash
# Auto-detect Arduino port
./scripts/run.sh start

# Specify exact port
SERIAL_PORT=/dev/ttyUSB0 docker-compose up -d
```

**Windows (Docker Desktop):**
```bash
# Use batch script
scripts\run.bat start

# Or specify COM port
set SERIAL_PORT=COM3
docker-compose up -d
```

**macOS:**
```bash
# Auto-detect Arduino port
./scripts/run.sh start

# Specify exact port
SERIAL_PORT=/dev/cu.usbmodem14101 docker-compose up -d
```

### Container Management

**Using Run Scripts:**
```bash
# Linux/Mac
./scripts/run.sh start          # Start container
./scripts/run.sh stop           # Stop container
./scripts/run.sh restart        # Restart container
./scripts/run.sh logs --follow  # View logs
./scripts/run.sh shell          # Open container shell
./scripts/run.sh status         # Show status
./scripts/run.sh cleanup        # Clean up resources

# Windows
scripts\run.bat start           # Start container
scripts\run.bat stop            # Stop container
scripts\run.bat logs            # View logs
scripts\run.bat shell           # Open container shell
```

**Direct Docker Commands:**
```bash
# Build images
docker build -t arduino-sensor-processor .
docker build -f Dockerfile.dev -t arduino-sensor-processor:dev .

# Run with serial port
docker run -d \
  --name arduino-sensor-processor \
  --device /dev/ttyUSB0:/dev/ttyUSB0 \
  --privileged \
  -p 5000:5000 \
  --env-file .env \
  -v $(pwd)/logs:/app/logs \
  arduino-sensor-processor

# View logs
docker logs -f arduino-sensor-processor

# Open shell
docker exec -it arduino-sensor-processor /bin/bash
```

### Multi-Platform Builds

```bash
# Build for multiple architectures
./scripts/build.sh --platform both --type production

# Build for ARM64 (Raspberry Pi)
./scripts/build.sh --platform linux/arm64

# Push to registry
./scripts/build.sh --push --registry your-registry.com
```

### Environment Configuration

**Docker Environment Variables:**
```bash
# In .env file or docker-compose.yml
GEMINI_API_KEY=your_api_key
AT_API_KEY=your_africas_talking_key
AT_RECIPIENT_PHONE=+254712345678
SERIAL_PORT=/dev/ttyUSB0
FLASK_PORT=5000
DEBUG=False
```

### Troubleshooting Docker

**Serial Port Issues:**
```bash
# Check available ports
ls -la /dev/tty*

# Test serial access
./scripts/run.sh start --serial /dev/ttyUSB0

# Windows: Enable COM port sharing in Docker Desktop
```

**Container Health:**
```bash
# Check container health
docker inspect arduino-sensor-processor | grep Health -A 10

# View detailed logs
docker logs arduino-sensor-processor

# Check resource usage
docker stats arduino-sensor-processor
```

**Build Issues:**
```bash
# Clean build (no cache)
./scripts/build.sh --no-cache

# Clean up Docker resources
./scripts/run.sh cleanup

# Remove all containers and images
docker system prune -a
```

## 🔌 Arduino Serial Communication

### Hardware Setup

**Required Components:**
- Arduino Mega 2560
- DHT22 temperature/humidity sensor
- Photoresistor (light sensor)
- MQ-2 gas sensor
- USB cable for serial connection

**Wiring Connections:**
```
DHT22 Sensor:
- VCC → 5V
- GND → GND  
- DATA → Digital Pin 2
- 10kΩ resistor between VCC and DATA

Photoresistor (Light Sensor):
- One end → 5V
- Other end → A0 and 10kΩ resistor to GND

MQ-2 Gas Sensor:
- VCC → 5V
- GND → GND
- A0 → Analog Pin A1
```

### Arduino Code

The Arduino sends sensor data via serial port in multiple supported formats. See `arduino_example.ino` for complete code.

**Example Serial Output:**
```cpp
// JSON Format (default)
{"temperature": 25.3, "humidity": 60.2, "light_intensity": 512, "gas_level": 150}

// CSV Format  
25.3,60.2,512,150

// Key-Value Format
temp=25.3,humidity=60.2,light=512,gas=150
```

### Serial Communication Setup

1. **Connect Arduino via USB** to your computer
2. **Note the COM port** (Windows: COM3, Linux: /dev/ttyUSB0, Mac: /dev/tty.usbmodem*)
3. **Configure the port** in your `.env` file:
   ```bash
   SERIAL_PORT=COM3          # Your Arduino's COM port
   SERIAL_BAUDRATE=9600      # Match Arduino's Serial.begin() rate
   ```
4. **Upload the Arduino sketch** and start sending data

### Docker Serial Port Configuration

**Linux/Mac:**
```bash
# Auto-detect serial port
./scripts/run.sh start

# Specify serial port
./scripts/run.sh start --serial /dev/ttyUSB0

# Using docker-compose
SERIAL_PORT=/dev/ttyUSB0 docker-compose up -d
```

**Windows:**
```bash
# Using Docker Desktop (requires port sharing)
scripts\run.bat start

# Or with docker-compose
set SERIAL_PORT=COM3 && docker-compose up -d
```

## 📁 Project Structure

```
arduino-sensor-processor/
├── app.py                      # Main Flask application
├── config.py                   # Configuration management
├── gemini_utils.py             # Gemini AI integration
├── sms_utils.py               # Africa's Talking SMS integration
├── serial_listener.py         # Arduino serial communication handler
├── serial_test_simulator.py   # Test simulator for development
├── requirements.txt            # Python dependencies
├── .env.example               # Environment variables template
├── arduino_example.ino        # Arduino sketch for sensor reading
├── sample_arduino_payload.json # Sample test data (legacy)
├── sample_sms_messages.json   # Example SMS messages farmers receive
├── test_requests.py           # Automated test suite
├── README.md                  # This file
├── Dockerfile                 # Production Docker image
├── Dockerfile.dev             # Development Docker image
├── docker-compose.yml         # Production Docker Compose
├── docker-compose.dev.yml     # Development Docker Compose
├── .dockerignore              # Docker build exclusions
├── docker/
│   ├── supervisord.conf       # Production supervisor config
│   ├── supervisord-dev.conf   # Development supervisor config
│   ├── start.sh               # Production startup script
│   └── start-dev.sh           # Development startup script
├── scripts/
│   ├── build.sh               # Docker build script (Linux/Mac)
│   ├── run.sh                 # Docker run script (Linux/Mac)
│   └── run.bat                # Docker run script (Windows)
├── logs/                      # Application logs (created at runtime)
├── sensor_data.log           # Main application logs
├── serial_listener.log       # Serial communication logs
└── sms_state.json            # SMS state tracking (created at runtime)
```

## 🔍 Logging

The application logs all activities to both console and `sensor_data.log`:

- Received sensor data with timestamps
- AI processing decisions and reasoning
- SMS alerts sent and delivery status
- Error conditions and fallback actions
- API request/response information
- State changes and cooldown periods

## ⚙️ Configuration Options

All settings can be customized via environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `GEMINI_API_KEY` | - | **Required** Google Gemini API key |
| `GEMINI_MODEL` | `gemini-pro` | Gemini model to use |
| `FLASK_HOST` | `0.0.0.0` | Flask server host |
| `FLASK_PORT` | `5000` | Flask server port |
| `TEMP_HOT_THRESHOLD` | `30.0` | Temperature for hot conditions (°C) |
| `TEMP_COLD_THRESHOLD` | `15.0` | Temperature for cold conditions (°C) |
| `GAS_ALERT_THRESHOLD` | `300` | Gas level for alerts (0-1023) |
| `HUMIDITY_HIGH_THRESHOLD` | `70.0` | High humidity threshold (%) |
| `HUMIDITY_LOW_THRESHOLD` | `30.0` | Low humidity threshold (%) |
| `LIGHT_BRIGHT_THRESHOLD` | `700` | Bright light threshold (0-1023) |
| `LIGHT_DIM_THRESHOLD` | `200` | Dim light threshold (0-1023) |
| `AT_USERNAME` | - | **Required** Africa's Talking username |
| `AT_API_KEY` | - | **Required** Africa's Talking API key |
| `AT_SENDER_ID` | - | Optional sender ID/shortcode |
| `AT_RECIPIENT_PHONE` | - | **Required** Farmer's phone number (+254...) |
| `AT_SANDBOX` | `True` | Use sandbox (True) or live (False) environment |
| `GAS_ALERT_COOLDOWN` | `300` | Minimum seconds between gas alerts |
| `SMS_ENABLED` | `True` | Enable/disable SMS functionality |
| `SERIAL_PORT` | `COM3` | Arduino serial port (COM3, /dev/ttyUSB0) |
| `SERIAL_BAUDRATE` | `9600` | Serial communication speed |
| `SERIAL_TIMEOUT` | `1.0` | Serial read timeout in seconds |
| `FORWARD_TO_FLASK` | `True` | Forward serial data to Flask server |
| `FLASK_REQUEST_TIMEOUT` | `10` | Timeout for Flask API requests |

## 🚨 Error Handling

The system includes comprehensive error handling:

- **Invalid JSON**: Returns 400 with error message
- **Missing fields**: Validates required sensor data fields
- **Out-of-range values**: Validates sensor data ranges
- **AI processing failure**: Falls back to rule-based decisions
- **SMS delivery failure**: Logs errors and continues operation
- **Serial disconnections**: Automatic reconnection with configurable delays
- **Invalid serial data**: Validates format and range checks
- **Network issues**: Proper timeout and retry handling
- **Invalid phone numbers**: Validates format and provides clear errors

## 🔒 Security Considerations

- Keep your `GEMINI_API_KEY` and `AT_API_KEY` secure and never commit to version control
- Use environment variables for all sensitive configuration
- Consider implementing authentication for production deployments
- Monitor API usage to prevent abuse
- Use sandbox environment for testing to avoid SMS charges
- Validate phone numbers to prevent SMS to invalid recipients

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

## 📄 License

This project is open source and available under the [MIT License](LICENSE).

## 🆘 Troubleshooting

### Common Issues

**"GEMINI_API_KEY is required but not set"**
- Ensure you've set the API key in your `.env` file
- Verify the `.env` file is in the same directory as `app.py`

**"AT_API_KEY is required when SMS is enabled"**
- Sign up for Africa's Talking account
- Get your API key from the dashboard
- Add it to your `.env` file as `AT_API_KEY`
- Set `AT_USERNAME=sandbox` for testing

**"AI processing failed"**
- Check your internet connection
- Verify your Gemini API key is valid
- Check the logs for detailed error messages
- The system will fall back to rule-based decisions

**"SMS service not enabled"**
- Check that `SMS_ENABLED=True` in your `.env` file
- Verify all Africa's Talking credentials are set
- Check SMS service status at `/sms/status` endpoint

**Serial communication issues**
- Verify Arduino is connected and COM port is correct
- Check that no other application is using the serial port
- Ensure baud rate matches between Arduino and Python (9600)
- Try different USB cable or port

**Docker serial port issues**
- On Linux: Ensure user is in `dialout` group: `sudo usermod -a -G dialout $USER`
- On Windows: Enable COM port sharing in Docker Desktop settings
- Check port exists in container: `docker exec -it container-name ls -la /dev/tty*`
- Use `--privileged` flag for serial access

**"No data received from Arduino"**
- Check Arduino is powered and running the correct sketch
- Verify sensor wiring connections
- Check serial monitor to see if Arduino is sending data
- Ensure sensors are functioning properly
- In Docker: Verify port is mounted correctly with `--device` flag

**Connection refused errors**
- Ensure the Flask server is running
- Check that the port (default 5000) is not blocked
- Verify the server host configuration

### Getting Help

- Check the application logs in `sensor_data.log`
- Run the test suite to verify functionality
- Review the API documentation above
- Check Google Gemini API status and quotas
- Verify Africa's Talking account balance and SMS credits
- Test SMS functionality with `/sms/test` endpoint
- Check serial communication logs in `serial_listener.log`
- Test with the Arduino simulator for debugging
- For Docker issues: Check container logs with `docker logs container-name`
- Verify Docker container health: `docker inspect container-name | grep Health`