# Rachel iOS App

This is the native iOS client for Rachel, built with LiveView Native and SwiftUI.

## Requirements

- Xcode 15.0+
- iOS 16.0+
- Swift 5.9+

## Setup

1. Open `Rachel.xcodeproj` in Xcode
2. Make sure your Phoenix server is running locally (`mix phx.server`)
3. Build and run the app in the simulator

## Architecture

The app uses LiveView Native to render native SwiftUI views from the Phoenix server:

- **RachelApp.swift** - Main app entry point and LiveView coordinator setup
- **Package.swift** - Swift Package Manager dependencies
- **Native Templates** - Server-side `.swiftui.heex` files define the UI

## Development

When developing:

1. Make changes to the `.swiftui.heex` templates on the server
2. The app will automatically reload when connected to the dev server
3. Use Xcode for debugging native iOS issues

## Features

- ✅ Native SwiftUI interface
- ✅ Real-time updates via WebSocket
- ✅ Haptic feedback for card interactions
- ✅ Native animations and transitions
- 🚧 Push notifications for turn reminders
- 🚧 Offline mode with sync

## Troubleshooting

If the app can't connect to the server:
- Make sure the Phoenix server is running on `http://localhost:4000`
- Check that your computer and iOS device/simulator are on the same network
- For device testing, update the URL in `RachelApp.swift` to your computer's IP address