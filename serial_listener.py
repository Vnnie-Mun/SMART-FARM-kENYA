#!/usr/bin/env python3
"""
Serial Listener for Arduino Sensor Data
Reads sensor data from Arduino Mega via serial port and forwards to Flask server
"""

import serial
import json
import time
import logging
import requests
import threading
from datetime import datetime
from typing import Dict, Any, Optional
from config import Config
import re

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('serial_listener.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

class ArduinoSerialListener:
    """Serial communication handler for Arduino Mega sensor data"""
    
    def __init__(self):
        """Initialize the serial listener"""
        self.serial_port = None
        self.is_running = False
        self.connection_attempts = 0
        self.last_data_time = None
        self.stats = {
            'messages_received': 0,
            'messages_parsed': 0,
            'messages_forwarded': 0,
            'parse_errors': 0,
            'connection_errors': 0,
            'api_errors': 0
        }
        
        logger.info(f"Initializing Arduino Serial Listener on port {Config.SERIAL_PORT}")
    
    def connect_arduino(self) -> bool:
        """
        Establish serial connection to Arduino
        
        Returns:
            bool: True if connection successful, False otherwise
        """
        try:
            if self.serial_port and self.serial_port.is_open:
                logger.info("Serial port already open")
                return True
            
            logger.info(f"Attempting to connect to Arduino on {Config.SERIAL_PORT} at {Config.SERIAL_BAUDRATE} baud")
            
            self.serial_port = serial.Serial(
                port=Config.SERIAL_PORT,
                baudrate=Config.SERIAL_BAUDRATE,
                timeout=Config.SERIAL_TIMEOUT,
                parity=serial.PARITY_NONE,
                stopbits=serial.STOPBITS_ONE,
                bytesize=serial.EIGHTBITS
            )
            
            # Wait for Arduino to initialize
            time.sleep(Config.SERIAL_INIT_DELAY)
            
            # Clear any existing data in buffer
            if self.serial_port.in_waiting:
                self.serial_port.reset_input_buffer()
                logger.info("Cleared serial input buffer")
            
            logger.info("Successfully connected to Arduino")
            self.connection_attempts = 0
            return True
            
        except serial.SerialException as e:
            self.connection_attempts += 1
            self.stats['connection_errors'] += 1
            logger.error(f"Failed to connect to Arduino (attempt {self.connection_attempts}): {e}")
            return False
        except Exception as e:
            self.connection_attempts += 1
            self.stats['connection_errors'] += 1
            logger.error(f"Unexpected error connecting to Arduino: {e}")
            return False
    
    def disconnect_arduino(self):
        """Safely disconnect from Arduino"""
        if self.serial_port and self.serial_port.is_open:
            try:
                self.serial_port.close()
                logger.info("Disconnected from Arduino")
            except Exception as e:
                logger.error(f"Error disconnecting from Arduino: {e}")
        self.serial_port = None
    
    def parse_sensor_data(self, raw_data: str) -> Optional[Dict[str, Any]]:
        """
        Parse raw serial data from Arduino into structured sensor data
        
        Supports multiple formats:
        1. JSON: {"temperature": 25.5, "humidity": 60.2, "light_intensity": 512, "gas_level": 150}
        2. CSV: 25.5,60.2,512,150
        3. Key-Value: temp=25.5,humidity=60.2,light=512,gas=150
        
        Args:
            raw_data: Raw string data from Arduino
            
        Returns:
            Dictionary with parsed sensor data or None if parsing fails
        """
        try:
            raw_data = raw_data.strip()
            
            if not raw_data:
                return None
            
            # Try JSON format first
            if raw_data.startswith('{') and raw_data.endswith('}'):
                try:
                    data = json.loads(raw_data)
                    
                    # Validate required fields
                    required_fields = ['temperature', 'humidity', 'light_intensity', 'gas_level']
                    if all(field in data for field in required_fields):
                        logger.debug(f"Parsed JSON data: {data}")
                        return self._validate_sensor_values(data)
                    else:
                        logger.warning(f"JSON data missing required fields: {data}")
                        return None
                        
                except json.JSONDecodeError as e:
                    logger.warning(f"Invalid JSON format: {e}")
            
            # Try CSV format: temp,humidity,light,gas
            if ',' in raw_data and not '=' in raw_data:
                parts = raw_data.split(',')
                if len(parts) == 4:
                    try:
                        data = {
                            'temperature': float(parts[0].strip()),
                            'humidity': float(parts[1].strip()),
                            'light_intensity': int(parts[2].strip()),
                            'gas_level': int(parts[3].strip())
                        }
                        logger.debug(f"Parsed CSV data: {data}")
                        return self._validate_sensor_values(data)
                    except (ValueError, IndexError) as e:
                        logger.warning(f"Invalid CSV format: {e}")
            
            # Try Key-Value format: temp=25.5,humidity=60.2,light=512,gas=150
            if '=' in raw_data:
                try:
                    data = {}
                    pairs = raw_data.split(',')
                    
                    for pair in pairs:
                        if '=' in pair:
                            key, value = pair.split('=', 1)
                            key = key.strip().lower()
                            value = value.strip()
                            
                            # Map common key variations
                            key_mapping = {
                                'temp': 'temperature',
                                'temperature': 'temperature',
                                'hum': 'humidity',
                                'humidity': 'humidity',
                                'light': 'light_intensity',
                                'light_intensity': 'light_intensity',
                                'gas': 'gas_level',
                                'gas_level': 'gas_level'
                            }
                            
                            if key in key_mapping:
                                mapped_key = key_mapping[key]
                                if mapped_key in ['temperature', 'humidity']:
                                    data[mapped_key] = float(value)
                                else:
                                    data[mapped_key] = int(value)
                    
                    # Check if we have all required fields
                    required_fields = ['temperature', 'humidity', 'light_intensity', 'gas_level']
                    if all(field in data for field in required_fields):
                        logger.debug(f"Parsed Key-Value data: {data}")
                        return self._validate_sensor_values(data)
                    else:
                        logger.warning(f"Key-Value data missing required fields: {data}")
                        
                except (ValueError, IndexError) as e:
                    logger.warning(f"Invalid Key-Value format: {e}")
            
            # If no format matched
            logger.warning(f"Unable to parse data format: {raw_data[:50]}...")
            return None
            
        except Exception as e:
            logger.error(f"Unexpected error parsing sensor data: {e}")
            return None
    
    def _validate_sensor_values(self, data: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """
        Validate sensor values are within expected ranges
        
        Args:
            data: Parsed sensor data dictionary
            
        Returns:
            Validated data dictionary or None if validation fails
        """
        try:
            # Validate temperature (reasonable range: -50 to 100°C)
            temp = float(data['temperature'])
            if not -50 <= temp <= 100:
                logger.warning(f"Temperature out of range: {temp}°C")
                return None
            
            # Validate humidity (0-100%)
            humidity = float(data['humidity'])
            if not 0 <= humidity <= 100:
                logger.warning(f"Humidity out of range: {humidity}%")
                return None
            
            # Validate light intensity (0-1023 for 10-bit ADC)
            light = int(data['light_intensity'])
            if not 0 <= light <= 1023:
                logger.warning(f"Light intensity out of range: {light}")
                return None
            
            # Validate gas level (0-1023 for 10-bit ADC)
            gas = int(data['gas_level'])
            if not 0 <= gas <= 1023:
                logger.warning(f"Gas level out of range: {gas}")
                return None
            
            # Return validated data with proper types
            validated_data = {
                'temperature': temp,
                'humidity': humidity,
                'light_intensity': light,
                'gas_level': gas,
                'timestamp': datetime.now().isoformat(),
                'source': 'arduino_serial'
            }
            
            return validated_data
            
        except (ValueError, TypeError, KeyError) as e:
            logger.warning(f"Data validation failed: {e}")
            return None
    
    def forward_to_flask(self, sensor_data: Dict[str, Any]) -> bool:
        """
        Forward parsed sensor data to Flask server
        
        Args:
            sensor_data: Validated sensor data dictionary
            
        Returns:
            bool: True if successfully forwarded, False otherwise
        """
        try:
            # Remove source and timestamp for API call (Flask will add its own)
            api_data = {
                'temperature': sensor_data['temperature'],
                'humidity': sensor_data['humidity'],
                'light_intensity': sensor_data['light_intensity'],
                'gas_level': sensor_data['gas_level']
            }
            
            url = f"http://{Config.FLASK_HOST}:{Config.FLASK_PORT}/submit-data"
            
            response = requests.post(
                url,
                json=api_data,
                headers={'Content-Type': 'application/json'},
                timeout=Config.FLASK_REQUEST_TIMEOUT
            )
            
            if response.status_code == 200:
                result = response.json()
                logger.info(f"Data forwarded successfully. AI Decision: {result.get('decision', {}).get('action', 'Unknown')}")
                
                # Log SMS alert status if available
                sms_result = result.get('sms_alert', {})
                if sms_result.get('success') and sms_result.get('alerts_sent'):
                    logger.info(f"SMS alerts sent: {sms_result['alerts_sent']}")
                
                self.stats['messages_forwarded'] += 1
                return True
            else:
                logger.error(f"Flask API returned status {response.status_code}: {response.text}")
                self.stats['api_errors'] += 1
                return False
                
        except requests.exceptions.Timeout:
            logger.error("Timeout forwarding data to Flask server")
            self.stats['api_errors'] += 1
            return False
        except requests.exceptions.ConnectionError:
            logger.error("Connection error forwarding data to Flask server")
            self.stats['api_errors'] += 1
            return False
        except Exception as e:
            logger.error(f"Unexpected error forwarding data to Flask: {e}")
            self.stats['api_errors'] += 1
            return False
    
    def read_arduino_data(self) -> Optional[str]:
        """
        Read a line of data from Arduino serial port
        
        Returns:
            String data from Arduino or None if error/timeout
        """
        try:
            if not self.serial_port or not self.serial_port.is_open:
                return None
            
            # Check if data is available
            if self.serial_port.in_waiting > 0:
                line = self.serial_port.readline()
                if line:
                    decoded_line = line.decode('utf-8', errors='ignore').strip()
                    if decoded_line:
                        self.last_data_time = datetime.now()
                        self.stats['messages_received'] += 1
                        return decoded_line
            
            return None
            
        except serial.SerialException as e:
            logger.error(f"Serial communication error: {e}")
            self.stats['connection_errors'] += 1
            return None
        except UnicodeDecodeError as e:
            logger.warning(f"Unicode decode error: {e}")
            return None
        except Exception as e:
            logger.error(f"Unexpected error reading Arduino data: {e}")
            return None
    
    def run(self):
        """Main loop for reading and processing Arduino data"""
        logger.info("Starting Arduino Serial Listener")
        self.is_running = True
        
        while self.is_running:
            try:
                # Ensure connection is established
                if not self.connect_arduino():
                    logger.warning(f"Failed to connect, retrying in {Config.SERIAL_RECONNECT_DELAY} seconds...")
                    time.sleep(Config.SERIAL_RECONNECT_DELAY)
                    continue
                
                # Read data from Arduino
                raw_data = self.read_arduino_data()
                
                if raw_data:
                    logger.debug(f"Received raw data: {raw_data}")
                    
                    # Parse sensor data
                    sensor_data = self.parse_sensor_data(raw_data)
                    
                    if sensor_data:
                        self.stats['messages_parsed'] += 1
                        logger.info(f"Parsed sensor data - Temp: {sensor_data['temperature']}°C, "
                                  f"Humidity: {sensor_data['humidity']}%, "
                                  f"Light: {sensor_data['light_intensity']}, "
                                  f"Gas: {sensor_data['gas_level']}")
                        
                        # Forward to Flask server
                        if Config.FORWARD_TO_FLASK:
                            self.forward_to_flask(sensor_data)
                    else:
                        self.stats['parse_errors'] += 1
                        logger.warning(f"Failed to parse data: {raw_data}")
                
                # Small delay to prevent overwhelming the system
                time.sleep(Config.SERIAL_READ_INTERVAL)
                
                # Check for connection timeout
                if (self.last_data_time and 
                    (datetime.now() - self.last_data_time).total_seconds() > Config.SERIAL_DATA_TIMEOUT):
                    logger.warning("No data received from Arduino for extended period, reconnecting...")
                    self.disconnect_arduino()
                
            except KeyboardInterrupt:
                logger.info("Received keyboard interrupt, shutting down...")
                break
            except Exception as e:
                logger.error(f"Unexpected error in main loop: {e}")
                time.sleep(1)
        
        self.stop()
    
    def stop(self):
        """Stop the serial listener and cleanup"""
        logger.info("Stopping Arduino Serial Listener")
        self.is_running = False
        self.disconnect_arduino()
        
        # Print final statistics
        logger.info("Final Statistics:")
        logger.info(f"  Messages received: {self.stats['messages_received']}")
        logger.info(f"  Messages parsed: {self.stats['messages_parsed']}")
        logger.info(f"  Messages forwarded: {self.stats['messages_forwarded']}")
        logger.info(f"  Parse errors: {self.stats['parse_errors']}")
        logger.info(f"  Connection errors: {self.stats['connection_errors']}")
        logger.info(f"  API errors: {self.stats['api_errors']}")
    
    def get_status(self) -> Dict[str, Any]:
        """Get current status of the serial listener"""
        return {
            'running': self.is_running,
            'connected': self.serial_port and self.serial_port.is_open if self.serial_port else False,
            'port': Config.SERIAL_PORT,
            'baudrate': Config.SERIAL_BAUDRATE,
            'last_data_time': self.last_data_time.isoformat() if self.last_data_time else None,
            'connection_attempts': self.connection_attempts,
            'statistics': self.stats.copy()
        }

def run_as_daemon():
    """Run the serial listener as a background daemon"""
    listener = ArduinoSerialListener()
    
    try:
        listener.run()
    except Exception as e:
        logger.error(f"Fatal error in serial listener: {e}")
    finally:
        listener.stop()

if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="Arduino Serial Listener for Sensor Data")
    parser.add_argument('--port', type=str, help='Serial port (e.g., COM3, /dev/ttyUSB0)')
    parser.add_argument('--baudrate', type=int, help='Serial baudrate (default: 9600)')
    parser.add_argument('--no-forward', action='store_true', help='Disable forwarding to Flask server')
    
    args = parser.parse_args()
    
    # Override config if command line arguments provided
    if args.port:
        Config.SERIAL_PORT = args.port
    if args.baudrate:
        Config.SERIAL_BAUDRATE = args.baudrate
    if args.no_forward:
        Config.FORWARD_TO_FLASK = False
    
    logger.info(f"Starting with port: {Config.SERIAL_PORT}, baudrate: {Config.SERIAL_BAUDRATE}")
    
    run_as_daemon()