<!--
This README describes the package. If you publish this package to pub.dev,
this README's contents appear on the landing page for your package.

For information about how to write a good package README, see the guide for
[writing package pages](https://dart.dev/tools/pub/writing-package-pages).

For general information about developing packages, see the Dart guide for
[creating packages](https://dart.dev/guides/libraries/create-packages)
and the Flutter guide for
[developing packages and plugins](https://flutter.dev/to/develop-packages).
-->

# AIO Scanner

A powerful cross-platform document scanning package for Flutter that leverages native scanning capabilities:

- **iOS**: Uses Apple's VisionKit for document scanning and text recognition
- **Android**: Uses Google's ML Kit for document scanning and text recognition

## Features

- 📝 **Document Scanning**: Automatic edge detection and perspective correction
- 📇 **Business Card Scanning**: Optimized for capturing contact information
- 📱 **Cross-platform Support**: Works seamlessly on iOS and Android
- 🔍 **Text Recognition (OCR)**: Extract text from scanned documents
- 📐 **Image Enhancement**: Automatic lighting and color correction
- 📚 **Multi-page Support**: Scan multiple pages in one session
- 📷 **Gallery Import**: Import existing images for processing
- 🎨 **Customizable UI**: Tailor the scanning experience
- ⚡ **High Performance**: Utilizes native capabilities for optimal results

## Demo

### iOS
https://github.com/user-attachments/assets/dee1c729-fbf7-43d1-870b-e31346d69acc

### Android
https://github.com/user-attachments/assets/fb36e9d8-b9c6-47d4-adf2-2d5797fb6380

## Requirements

- Flutter SDK: ^3.7.2
- iOS: 13.0 or higher (for VisionKit support)
- Android: API level 21 or higher (for ML Kit support)
- Xcode: 14.0 or higher (for iOS development)
- Android Studio: Latest version (for Android development)

## Installation

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  aio_scanner: ^0.0.1
```

### iOS Setup

Add the following keys to your `ios/Runner/Info.plist` file:

```xml
<key>NSCameraUsageDescription</key>
<string>This app needs camera access to scan documents</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>This app needs photos access to save scanned documents</string>
```

### Android Setup

Add the following permissions to your `android/app/src/main/AndroidManifest.xml` file:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-feature android:name="android.hardware.camera" />
```

For Android 13+ (API level 33+), add:

```xml
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
```

For Android 12 and below, add:

```xml
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
```

## Usage

### Document Scanning

```dart
import 'package:aio_scanner/aio_scanner.dart';

Future<void> scanDocument() async {
  try {
    // Start document scanning
    ScanResult? result = await AioScanner.startDocumentScanning(
      maxNumPages: 5,
      initialMessage: 'Position document in frame',
      scanningMessage: 'Hold still...',
      allowGalleryImport: true,
    );

    if (result != null && result.isSuccessful) {
      // Access scanned images
      final scannedImages = result.scannedImages;

      // Access extracted text
      final extractedText = result.extractedText;

      // Process the results as needed
      print('Scanned ${scannedImages.length} pages');
      print('Extracted text: $extractedText');
    }
  } catch (e) {
    print('Error scanning document: $e');
  }
}
```

### Business Card Scanning

```dart
import 'package:aio_scanner/aio_scanner.dart';

Future<void> scanBusinessCard() async {
  try {
    // Start business card scanning
    ScanResult? result = await AioScanner.startBusinessCardScanning(
      initialMessage: 'Position card in frame',
      scanningMessage: 'Capturing...',
    );

    if (result != null && result.isSuccessful) {
      // Access scanned image
      final cardImage = result.scannedImages.first;

      // Access extracted text
      final contactInfo = result.extractedText;

      // Process the results as needed
      print('Business card scanned successfully');
      print('Contact information: $contactInfo');
    }
  } catch (e) {
    print('Error scanning business card: $e');
  }
}
```

### Requesting Permissions

Before scanning, ensure you have the necessary permissions:

```dart
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

Future<void> requestScannerPermissions() async {
  if (Platform.isAndroid) {
    // Get Android SDK version using device_info_plus
    final deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;
    final sdkVersion = androidInfo.version.sdkInt;

    final bool isAndroid13OrHigher = sdkVersion >= 33; // SDK 33 = Android 13
    final bool isAndroid10OrHigher = sdkVersion >= 29; // SDK 29 = Android 10

    // Determine which permissions to request based on Android version
    final permissionsToRequest = <Permission>[
      Permission.camera,
      if (isAndroid13OrHigher)
        // Android 13+ uses more granular storage permissions
        Permission.photos
      else if (isAndroid10OrHigher)
        // Android 10-12 uses general storage permission but with scoped storage
        Permission.storage
      else
        // Android < 10 uses general storage permission
        Permission.storage,
    ];

    // Request all required permissions
    final statuses = await permissionsToRequest.request();

    // Check if any permission was denied
    if (statuses.values.any((status) => status.isDenied || status.isPermanentlyDenied)) {
      // Handle denied permissions
      print('Required permissions were denied');
      return false;
    }
    return true;
  }

  // iOS permissions are requested automatically when using the scanner
  return true;
}
```

### Complete Example

Check out the `example` directory for a full working example that demonstrates both document and business card scanning features.

## Configuration Options

The AIO Scanner plugin provides several configuration options:

### Document Scanning Options

| Parameter            | Type     | Description                                    |
| -------------------- | -------- | ---------------------------------------------- |
| `outputDirectory`    | `String` | Directory where scanned images will be saved   |
| `maxNumPages`        | `int`    | Maximum number of pages to scan (default: 1)   |
| `initialMessage`     | `String` | Message displayed before scanning starts       |
| `scanningMessage`    | `String` | Message displayed during scanning              |
| `allowGalleryImport` | `bool`   | Whether to allow importing images from gallery |

### Business Card Scanning Options

| Parameter         | Type     | Description                                |
| ----------------- | -------- | ------------------------------------------ |
| `outputDirectory` | `String` | Directory where scanned card will be saved |
| `initialMessage`  | `String` | Message displayed before scanning starts   |
| `scanningMessage` | `String` | Message displayed during scanning          |

## Scan Result

The `ScanResult` object provides access to the scanning results:

| Property        | Type         | Description                                                   |
| --------------- | ------------ | ------------------------------------------------------------- |
| `isSuccessful`  | `bool`       | Whether the scan was successful                               |
| `scannedImages` | `List<File>` | List of scanned image files                                   |
| `extractedText` | `String?`    | Text extracted from the scanned images (if OCR was performed) |
| `errorMessage`  | `String?`    | Error message if the scan failed                              |

## Platform-specific Implementation Details

### iOS Implementation

On iOS, the plugin uses Apple's VisionKit framework for document scanning, which provides built-in edge detection, perspective correction, and image enhancement. Text recognition is performed using the Vision framework.

### Android Implementation

On Android, the plugin uses Google's ML Kit Document Scanner API for document scanning and ML Kit Text Recognition API for OCR. These provide similar capabilities to the iOS implementation, ensuring a consistent experience across platforms.

## Troubleshooting

### iOS Issues

1. **Scanner not working on simulator**: The document scanner requires a physical device with a camera.
2. **Permission errors**: Ensure you've added the necessary privacy descriptions in Info.plist.

### Android Issues

1. **ML Kit initialization failure**: Make sure Google Play Services are up to date on the device.
2. **Permission issues**: For Android 13+, ensure you're requesting the correct granular permissions (READ_MEDIA_IMAGES instead of storage).

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contributing

Contributions are welcome! If you find a bug or want to add a feature, please open an issue or submit a pull request.
