# Real Battery Tester

A comprehensive battery testing tool for macOS that helps diagnose battery health and performance. Unlike standard battery indicators that rely on estimations, this tool is designed to realistically simulate real-life scenarios and measure actual battery strength. It allows you to determine precisely how long your computer will operate on battery power until shutdown under various usage conditions.

![Real Battery Tester Screenshot](real-battery-tester-screenshot.png)

## Features

- Real-time battery monitoring
- Multiple test workload options
- Detailed test history
- Battery drain rate analysis
- Extrapolated battery life calculations
- Visual status indicators with SF Symbols

## Workload Modes

The app provides four distinct workload modes to simulate different usage scenarios:

1. **Screen On**: Keeps the display active without additional processing load. Ideal for measuring base power consumption and display impact on battery life.

2. **Browsing**: Simulates web browsing activity by periodically making network requests to common websites. This provides insights into battery consumption during typical web browsing sessions.

3. **Video**: Simulates video playback by performing continuous image processing operations at 30 FPS. This helps measure battery life during media consumption.

4. **Heavy Load**: Maximizes CPU and memory usage to test battery drain under intensive workloads:
   - Utilizes all available CPU cores with complex mathematical calculations
   - Creates memory pressure through large data allocations
   - Simulates real-world intensive tasks like video rendering or data processing

## Metrics and Measurements

The app tracks and analyzes several key metrics during battery tests:

- **Battery Level**: Current charge percentage and real-time monitoring of level changes
- **Drain Rate**: Percentage of battery consumed per minute
- **Extrapolated Battery Life**: Projected total battery life based on current drain rate
- **Test Duration**: Actual time elapsed since test start
- **Estimated Time**: System's estimated remaining battery time
- **Initial vs Current Estimates**: Comparison of initial and current battery life projections

Additional technical metrics recorded for each test:
- Power source status
- Battery temperature
- Cycle count
- Maximum and design capacity
- Voltage and amperage readings
- Battery health and condition

The app automatically saves test reports and maintains a detailed log of battery behavior, including intermediate measurements at significant battery level changes (every 5% or at critical levels).

## Requirements

- macOS 13.0 or later
- Apple Silicon or Intel Mac

## Installation

Download the latest release DMG file from the [Releases](https://github.com/bpetrynski/real-battery-tester/releases) page.

## Building from Source

1. Clone the repository
2. Open the project in Xcode
3. Build and run

## Author

Bartosz Petrynski

## License

This project is licensed under the MIT License.
