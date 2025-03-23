# AIO Scanner Example App

This example application demonstrates how to use the AIO Scanner Flutter plugin for document and barcode scanning.

## Features Demonstrated

- Document scanning with automatic edge detection
- Barcode scanning for QR codes and various barcode formats
- Text extraction (OCR) from scanned documents
- Handling of permissions for Android and iOS
- Displaying and using scan results

## Getting Started

### Prerequisites

1. Ensure Flutter is properly installed on your system
2. Make sure you have a physical device (scanning features require a camera)
3. Dependencies are properly configured in the pubspec.yaml

### Running the Example

1. Connect a physical device (Android phone or iPhone)
2. Clone the repository and navigate to the example directory:

```bash
git clone https://github.com/troyvnit/aio_scanner.git
cd aio_scanner/example
```

3. Install the dependencies:

```bash
flutter pub get
```

4. Run the example app:

```bash
flutter run
```

## Using the Example App

The example app provides a simple interface with two main features:

1. **Document Scanner**: Scans multi-page documents with automatic edge detection
2. **Barcode Scanner**: Scans various barcode formats including QR codes

After scanning, the app will display:
- For documents: Thumbnails of the scanned images and extracted text
- For barcodes: The decoded barcode values and their formats

## Permissions

The example app demonstrates how to handle permissions properly for both Android and iOS:

- **Android**: Camera and storage permissions (with proper handling for Android 13+)
- **iOS**: Camera and photo library permissions

The app includes a permissions helper that adapts to different Android versions, using the appropriate permission requests based on the Android SDK version.

## Troubleshooting

- **Permission Issues**: If scanning doesn't work, check that you've granted all required permissions
- **No Camera Access**: Ensure you're using a physical device, not an emulator/simulator
- **Build Errors**: Make sure you've properly configured the plugin in your pubspec.yaml

## Additional Resources

For more information about the AIO Scanner plugin, refer to the [main README](https://github.com/troyvnit/aio_scanner/blob/main/README.md) in the repository root.
