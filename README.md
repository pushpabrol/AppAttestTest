# AppAttestTest

## Overview
`AppAttestTest` is a Swift-based iOS application designed to demonstrate the Apple App Attestation process. The app showcases key generation, attestation, and assertion functionalities, interfacing with a Node.js server for verification.

## Features
- Generation of attestation keys using `DeviceCheck`.
- Fetching attestation and assertion challenges from a server.
- Creating attestation objects and assertions, then sending them to the server for verification.
- SwiftUI-based user interface with status alerts and data presentation.

## Usage
1. Run the server capable of handling attestation and assertion verification.
2. Launch the app to generate an attestation key and create an attestation object.
3. The app interacts with the server to verify attestation and assertion data.

## Key Components
- `ContentView.swift`: Contains the SwiftUI view for the app's user interface.
- `AppAttestViewModel`: The ObservableObject that handles the attestation and assertion logic.

## Dependencies
- SwiftUI
- DeviceCheck
- CryptoKit

Ensure the server URL in the `AppAttestViewModel` is correctly set to your server's address for attestation and assertion handling.
