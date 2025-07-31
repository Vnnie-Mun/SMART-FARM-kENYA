#!/usr/bin/env python3
"""
Serial Test Simulator for Arduino Sensor Data
Simulates Arduino serial output for testing the serial listener without physical hardware
"""

import time
import json
import random
from datetime import datetime
import threading
import sys

class ArduinoSimulator:
    """Simulates Arduino serial output with various sensor scenarios"""
    
    def __init__(self):
        self.running = False
        self.scenario_index = 0
        
        # Test scenarios matching the Arduino examples
        self.scenarios = [
            {
                "name": "Normal Conditions",
                "temperature": 22.5,
                "humidity": 45.0,
                "light_intensity": 400,
                "gas_level": 120
            },
            {
                "name": "Hot Conditions",
                "temperature": 32.1,
                "humidity": 65.2,
                "light_intensity": 800,
                "gas_level": 180
            },
            {
                "name": "Cold Conditions", 
                "temperature": 12.3,
                "humidity": 80.5,
                "light_intensity": 150,
                "gas_level": 95
            },
            {
                "name": "Gas Alert",
                "temperature": 25.0,
                "humidity": 55.0,
                "light_intensity": 600,
                "gas_level": 450
            },
            {
                "name": "Extreme Conditions",
                "temperature": 35.8,
                "humidity": 85.0,
                "light_intensity": 950,
                "gas_level": 520
            }
        ]
    
    def add_noise(self, value, noise_percent=5):
        """Add random noise to sensor values to simulate real sensor readings"""
        noise = random.uniform(-noise_percent/100, noise_percent/100)
        return value * (1 + noise)
    
    def generate_sensor_data(self, scenario_data, add_realistic_noise=True):
        """Generate sensor data with optional noise"""
        if add_realistic_noise:
            temp = round(self.add_noise(scenario_data["temperature"], 3), 1)
            humidity = round(self.add_noise(scenario_data["humidity"], 5), 1)
            light = int(self.add_noise(scenario_data["light_intensity"], 10))
            gas = int(self.add_noise(scenario_data["gas_level"], 8))
            
            # Ensure values stay within valid ranges
            temp = max(-50, min(100, temp))
            humidity = max(0, min(100, humidity))
            light = max(0, min(1023, light))
            gas = max(0, min(1023, gas))
        else:
            temp = scenario_data["temperature"]
            humidity = scenario_data["humidity"]
            light = scenario_data["light_intensity"]
            gas = scenario_data["gas_level"]
        
        return {
            "temperature": temp,
            "humidity": humidity,
            "light_intensity": light,
            "gas_level": gas
        }
    
    def format_json(self, data):
        """Format data as JSON string"""
        return json.dumps(data)
    
    def format_csv(self, data):
        """Format data as CSV string"""
        return f"{data['temperature']},{data['humidity']},{data['light_intensity']},{data['gas_level']}"
    
    def format_key_value(self, data):
        """Format data as key-value string"""
        return f"temp={data['temperature']},humidity={data['humidity']},light={data['light_intensity']},gas={data['gas_level']}"
    
    def run_scenario_cycle(self, output_format="json", interval=5, add_noise=True, cycles=None):
        """
        Run through all scenarios in a cycle
        
        Args:
            output_format: "json", "csv", or "key_value"
            interval: seconds between readings
            add_noise: whether to add realistic sensor noise
            cycles: number of complete cycles (None for infinite)
        """
        print(f"Starting Arduino simulator - Format: {output_format.upper()}, Interval: {interval}s")
        print("Press Ctrl+C to stop")
        print("-" * 60)
        
        self.running = True
        cycle_count = 0
        
        try:
            while self.running and (cycles is None or cycle_count < cycles):
                scenario = self.scenarios[self.scenario_index]
                data = self.generate_sensor_data(scenario, add_noise)
                
                # Format output based on selected format
                if output_format.lower() == "json":
                    output = self.format_json(data)
                elif output_format.lower() == "csv":
                    output = self.format_csv(data)
                elif output_format.lower() == "key_value":
                    output = self.format_key_value(data)
                else:
                    output = self.format_json(data)  # Default to JSON
                
                # Print with timestamp and scenario info
                timestamp = datetime.now().strftime("%H:%M:%S")
                print(f"[{timestamp}] {scenario['name']}: {output}")
                
                # Move to next scenario
                self.scenario_index = (self.scenario_index + 1) % len(self.scenarios)
                
                # If we completed a full cycle
                if self.scenario_index == 0:
                    cycle_count += 1
                    if cycles is not None:
                        print(f"Completed cycle {cycle_count}/{cycles}")
                
                time.sleep(interval)
                
        except KeyboardInterrupt:
            print("\nSimulator stopped by user")
        finally:
            self.running = False
    
    def run_continuous_mode(self, output_format="json", interval=2, base_scenario="normal"):
        """
        Run continuous mode with gradually changing values
        
        Args:
            output_format: output format
            interval: seconds between readings
            base_scenario: base scenario to start from
        """
        print(f"Starting continuous mode - Base: {base_scenario}, Format: {output_format.upper()}")
        print("Values will gradually change over time")
        print("Press Ctrl+C to stop")
        print("-" * 60)
        
        # Find base scenario
        base_data = None
        for scenario in self.scenarios:
            if base_scenario.lower() in scenario["name"].lower():
                base_data = scenario.copy()
                break
        
        if not base_data:
            base_data = self.scenarios[0].copy()  # Default to first scenario
        
        self.running = True
        reading_count = 0
        
        try:
            while self.running:
                # Add gradual changes and noise
                temp_drift = random.uniform(-0.5, 0.5)
                humidity_drift = random.uniform(-2, 2)
                light_drift = random.randint(-50, 50)
                gas_drift = random.randint(-20, 20)
                
                # Apply drifts with bounds checking
                base_data["temperature"] = max(-50, min(100, base_data["temperature"] + temp_drift))
                base_data["humidity"] = max(0, min(100, base_data["humidity"] + humidity_drift))
                base_data["light_intensity"] = max(0, min(1023, base_data["light_intensity"] + light_drift))
                base_data["gas_level"] = max(0, min(1023, base_data["gas_level"] + gas_drift))
                
                # Generate current reading
                data = self.generate_sensor_data(base_data, add_realistic_noise=True)
                
                # Format output
                if output_format.lower() == "json":
                    output = self.format_json(data)
                elif output_format.lower() == "csv":
                    output = self.format_csv(data)
                elif output_format.lower() == "key_value":
                    output = self.format_key_value(data)
                else:
                    output = self.format_json(data)
                
                timestamp = datetime.now().strftime("%H:%M:%S")
                print(f"[{timestamp}] Reading #{reading_count + 1}: {output}")
                
                reading_count += 1
                time.sleep(interval)
                
        except KeyboardInterrupt:
            print(f"\nContinuous mode stopped after {reading_count} readings")
        finally:
            self.running = False
    
    def stop(self):
        """Stop the simulator"""
        self.running = False

def main():
    """Main function with command line interface"""
    import argparse
    
    parser = argparse.ArgumentParser(description="Arduino Serial Data Simulator")
    parser.add_argument('--format', choices=['json', 'csv', 'key_value'], default='json',
                      help='Output format (default: json)')
    parser.add_argument('--interval', type=float, default=5.0,
                      help='Interval between readings in seconds (default: 5.0)')
    parser.add_argument('--mode', choices=['cycle', 'continuous'], default='cycle',
                      help='Simulation mode (default: cycle)')
    parser.add_argument('--cycles', type=int, default=None,
                      help='Number of cycles to run (default: infinite)')
    parser.add_argument('--base-scenario', default='normal',
                      help='Base scenario for continuous mode (default: normal)')
    parser.add_argument('--no-noise', action='store_true',
                      help='Disable realistic sensor noise')
    parser.add_argument('--test', action='store_true',
                      help='Run quick test with all formats')
    
    args = parser.parse_args()
    
    simulator = ArduinoSimulator()
    
    if args.test:
        print("Running quick test with all formats...")
        print("\n1. JSON Format:")
        simulator.run_scenario_cycle("json", 1, not args.no_noise, 1)
        
        print("\n2. CSV Format:")
        simulator.run_scenario_cycle("csv", 1, not args.no_noise, 1)
        
        print("\n3. Key-Value Format:")
        simulator.run_scenario_cycle("key_value", 1, not args.no_noise, 1)
        
        print("\nTest completed!")
        return
    
    if args.mode == 'cycle':
        simulator.run_scenario_cycle(
            output_format=args.format,
            interval=args.interval,
            add_noise=not args.no_noise,
            cycles=args.cycles
        )
    elif args.mode == 'continuous':
        simulator.run_continuous_mode(
            output_format=args.format,
            interval=args.interval,
            base_scenario=args.base_scenario
        )

if __name__ == "__main__":
    main()

"""
Usage Examples:

1. Basic simulation with JSON format:
   python serial_test_simulator.py

2. CSV format with 2-second intervals:
   python serial_test_simulator.py --format csv --interval 2

3. Continuous mode starting from hot conditions:
   python serial_test_simulator.py --mode continuous --base-scenario hot

4. Run 3 complete cycles only:
   python serial_test_simulator.py --cycles 3

5. Test all formats quickly:
   python serial_test_simulator.py --test

6. Key-value format without noise:
   python serial_test_simulator.py --format key_value --no-noise

Example Output:

JSON Format:
[14:30:15] Normal Conditions: {"temperature": 22.3, "humidity": 46.2, "light_intensity": 392, "gas_level": 118}
[14:30:20] Hot Conditions: {"temperature": 31.8, "humidity": 67.1, "light_intensity": 810, "gas_level": 175}
[14:30:25] Cold Conditions: {"temperature": 12.7, "humidity": 78.9, "light_intensity": 165, "gas_level": 102}

CSV Format:
[14:30:30] Normal Conditions: 22.1,44.8,405,125
[14:30:35] Hot Conditions: 32.5,64.7,795,182
[14:30:40] Cold Conditions: 11.9,82.1,148,89

Key-Value Format:
[14:30:45] Normal Conditions: temp=22.7,humidity=45.3,light=398,gas=122
[14:30:50] Hot Conditions: temp=31.6,humidity=66.4,light=788,gas=177
[14:30:55] Cold Conditions: temp=12.1,humidity=79.8,light=156,gas=97

Integration with Serial Listener:

To test the serial listener with this simulator:

1. Use a virtual serial port tool (like com0com on Windows)
2. Or redirect simulator output to the serial listener via pipes
3. Or modify the serial listener to read from a file instead of COM port

The simulator generates realistic data that matches the expected Arduino output formats,
making it perfect for testing the entire sensor processing pipeline.
"""