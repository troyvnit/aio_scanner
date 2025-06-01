/// AIO Scanner provides a cross-platform document scanning solution.
///
/// This package leverages VisionKit on iOS and ML Kit on Android to provide
/// document scanning capabilities in Flutter applications.
library aio_scanner;

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Output format for scanned documents
enum ScanOutputFormat {
  /// Save scanned pages as individual image files
  image,
  
  /// Save scanned pages as PDF files
  pdf
}

/// Represents a scanned file with its path and thumbnail
class ScanFile {
  /// The path to the scanned file (image or PDF)
  final String filePath;

  /// The path to the thumbnail of the scanned file
  final String thumbnailPath;

  /// Creates a new [ScanFile] instance
  const ScanFile({
    required this.filePath,
    required this.thumbnailPath,
  });

  /// Creates a [ScanFile] from a JSON map
  factory ScanFile.fromJson(Map<String, dynamic> json) {
    return ScanFile(
      filePath: json['filePath'] as String,
      thumbnailPath: json['thumbnailPath'] as String,
    );
  }

  /// Converts this [ScanFile] to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'filePath': filePath,
      'thumbnailPath': thumbnailPath,
    };
  }
}

/// Result of a document scanning operation
///
/// This class encapsulates all data returned from a scanning session,
/// including success status, scanned files, extracted text, and any error messages.
/// It provides a convenient way to handle and process scan results in the application.
class ScanResult {
  /// Whether the scan was successful
  final bool isSuccessful;

  /// List of scanned files with their paths and thumbnails
  final List<ScanFile> scannedFiles;

  /// Text extracted from the scanned documents (if OCR was performed)
  final String? extractedText;

  /// Error message if the scan failed
  final String? errorMessage;

  /// Creates a new [ScanResult] instance
  const ScanResult({
    required this.isSuccessful,
    required this.scannedFiles,
    this.extractedText,
    this.errorMessage,
  });

  /// Creates a [ScanResult] from a JSON map
  factory ScanResult.fromJson(Map<String, dynamic> json) {
    final List<dynamic> filePaths = json['filePaths'] as List<dynamic>;
    final List<dynamic> thumbnailPaths = json['thumbnailPaths'] as List<dynamic>;
    
    final List<ScanFile> scannedFiles = List.generate(
      filePaths.length,
      (index) => ScanFile(
        filePath: filePaths[index] as String,
        thumbnailPath: thumbnailPaths[index] as String,
      ),
    );

    return ScanResult(
      isSuccessful: json['isSuccessful'] as bool,
      scannedFiles: scannedFiles,
      extractedText: json['extractedText'] as String?,
      errorMessage: json['errorMessage'] as String?,
    );
  }

  /// Converts this [ScanResult] to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'isSuccessful': isSuccessful,
      'filePaths': scannedFiles.map((f) => f.filePath).toList(),
      'thumbnailPaths': scannedFiles.map((f) => f.thumbnailPath).toList(),
      'extractedText': extractedText,
      'errorMessage': errorMessage,
    };
  }
}

/// Result of a barcode scanning operation
///
/// This class encapsulates all data returned from a barcode scanning session,
/// including success status, barcode values, formats, and any error messages.
class BarcodeScanResult {
  /// Whether the scan was successfully completed.
  ///
  /// A value of `true` indicates that the scanning process completed without errors
  /// and at least one barcode was detected. A value of `false` indicates that an error occurred,
  /// no barcodes were found, or the user cancelled the scanning process.
  final bool isSuccessful;

  /// List of barcode values detected.
  ///
  /// Each string represents the decoded content of a barcode.
  final List<String> barcodeValues;

  /// List of barcode format strings detected.
  ///
  /// Each string represents the format of a corresponding barcode in [barcodeValues].
  /// Examples include 'qr', 'code128', 'ean13', etc.
  final List<String> barcodeFormats;

  /// Error message if the scan was not successful.
  ///
  /// Contains a description of what went wrong if [isSuccessful] is `false`.
  /// May be null if the scan was successful or if the error was unspecified.
  final String? errorMessage;

  /// Creates a new [BarcodeScanResult] instance.
  ///
  /// [isSuccessful] indicates whether the scan completed successfully.
  /// [barcodeValues] contains the list of decoded barcode content.
  /// [barcodeFormats] contains the list of barcode formats detected.
  /// [errorMessage] provides error details if the scan failed (optional).
  BarcodeScanResult({
    required this.isSuccessful,
    required this.barcodeValues,
    required this.barcodeFormats,
    this.errorMessage,
  });

  /// Creates a [BarcodeScanResult] from a map returned by the platform channel.
  ///
  /// This factory constructor handles the conversion from the raw platform data
  /// to a strongly-typed Dart object.
  ///
  /// [map] is the raw data map returned from the platform-specific implementation.
  factory BarcodeScanResult.fromMap(Map<dynamic, dynamic> map) {
    final List<String> values = List<String>.from(map['barcodeValues'] ?? []);
    final List<String> formats = List<String>.from(map['barcodeFormats'] ?? []);

    return BarcodeScanResult(
      isSuccessful: map['isSuccessful'] ?? false,
      barcodeValues: values,
      barcodeFormats: formats,
      errorMessage: map['errorMessage'],
    );
  }
}

/// The main class for interacting with document and barcode scanning functionality.
///
/// This class provides methods to check for scanning support on the current platform
/// and to initiate different types of scanning operations (documents and barcodes).
/// It communicates with platform-specific implementations via method channels.
class AioScanner {
  /// The method channel used for communication with platform-specific implementations.
  static const MethodChannel _channel = MethodChannel('aio_scanner');

  /// Checks if the current platform supports document scanning functionality.
  ///
  /// Returns `true` if document scanning is supported on the current device,
  /// `false` otherwise. This can be used to conditionally enable or disable
  /// scanning features in the application UI.
  ///
  /// On iOS, this checks for VisionKit availability.
  /// On Android, this checks for Google ML Kit availability.
  ///
  /// Example usage:
  /// ```dart
  /// bool isSupported = await AioScanner.isDocumentScanningSupported();
  /// if (isSupported) {
  ///   // Show scanning button
  /// } else {
  ///   // Hide scanning button or show alternative
  /// }
  /// ```
  static Future<bool> isDocumentScanningSupported() async {
    try {
      return await _channel.invokeMethod('isDocumentScanningSupported') ??
          false;
    } catch (e) {
      return false;
    }
  }

  /// Checks if the current platform supports barcode scanning functionality.
  ///
  /// Returns `true` if barcode scanning is supported on the current device,
  /// `false` otherwise. This can be used to conditionally enable or disable
  /// barcode scanning features in the application UI.
  ///
  /// On iOS, this checks for VisionKit barcode scanning availability.
  /// On Android, this checks for Google ML Kit barcode scanning availability.
  ///
  /// Example usage:
  /// ```dart
  /// bool isSupported = await AioScanner.isBarcodeScanningSupported();
  /// if (isSupported) {
  ///   // Show barcode scanning button
  /// } else {
  ///   // Hide barcode scanning button or show alternative
  /// }
  /// ```
  static Future<bool> isBarcodeScanningSupported() async {
    try {
      return await _channel.invokeMethod('isBarcodeScanningSupported') ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Starts the document scanning process.
  ///
  /// This method launches the native document scanner UI, allowing the user to
  /// capture document pages. The captured files are saved to the specified
  /// output directory, and text is extracted from the images using OCR.
  ///
  /// Parameters:
  /// - [outputDirectory]: Directory where scanned files will be saved. This directory
  ///   will be created if it doesn't exist.
  /// - [maxNumPages]: Maximum number of pages to scan (default: 5, 0 = unlimited)
  /// - [initialMessage]: Message to display when scanning starts (platform-specific)
  /// - [scanningMessage]: Message to display during scanning (platform-specific)
  /// - [allowGalleryImport]: Whether to allow importing images from the device gallery
  /// - [outputFormat]: The format to save the scanned documents in (default: image)
  /// - [mergePDF]: Whether to merge all pages into a single PDF when output format is PDF (default: true)
  ///
  /// Returns a [ScanResult] object containing the scan status, captured files,
  /// and extracted text. Returns `null` if the scan could not be started.
  ///
  /// Example usage:
  /// ```dart
  /// final result = await AioScanner.startDocumentScanning(
  ///   outputDirectory: 'scanned_documents',
  ///   maxNumPages: 3,
  ///   outputFormat: ScanOutputFormat.pdf,
  ///   mergePDF: false, // Generate separate PDFs for each page
  /// );
  ///
  /// if (result?.isSuccessful == true) {
  ///   for (var file in result!.scannedFiles) {
  ///     // Process each file
  ///   }
  ///   if (result.extractedText != null) {
  ///     // Use the extracted text
  ///   }
  /// }
  /// ```
  static Future<ScanResult?> startDocumentScanning({
    String outputDirectory = 'scanned_documents',
    int maxNumPages = 5,
    String initialMessage = 'Position document in frame',
    String scanningMessage = 'Hold still...',
    bool allowGalleryImport = true,
    ScanOutputFormat outputFormat = ScanOutputFormat.image,
    bool mergePDF = true,
  }) async {
    try {
      final documentsDirectory = await getApplicationDocumentsDirectory();

      // Make sure the outputDirectory doesn't start with a slash
      String sanitizedPath = outputDirectory;
      if (sanitizedPath.startsWith('/')) {
        sanitizedPath = sanitizedPath.substring(1);
      }

      final outputPath = '${documentsDirectory.path}/$sanitizedPath';
      final directory = Directory(outputPath);

      // Create directory if it doesn't exist
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final Map<String, dynamic> args = {
        'outputDirectory': directory.path,
        'maxNumPages': maxNumPages,
        'initialMessage': initialMessage,
        'scanningMessage': scanningMessage,
        'allowGalleryImport': allowGalleryImport,
        'outputFormat': outputFormat == ScanOutputFormat.pdf ? 'pdf' : 'image',
        'mergePDF': mergePDF,
      };

      final result = await _channel.invokeMethod('startDocumentScanning', args);

      if (result == null) return null;

      return ScanResult.fromJson(Map<String, dynamic>.from(result));
    } catch (e) {
      return ScanResult(
        isSuccessful: false,
        scannedFiles: [],
        errorMessage: e.toString(),
      );
    }
  }

  /// Starts the barcode scanning process.
  ///
  /// This method launches a barcode scanner UI, allowing the user to
  /// capture and decode barcodes of various formats. On iOS, this uses VisionKit's
  /// DataScannerViewController with barcode recognition. On Android, it uses
  /// ML Kit's barcode scanning capabilities.
  ///
  /// Parameters:
  ///   This directory will be created if it doesn't exist.
  /// - [recognizedFormats]: List of barcode formats to recognize. If empty, all
  ///   supported formats will be recognized.
  /// - [scanningMessage]: Message to display during scanning (platform-specific)
  ///
  /// Returns a [BarcodeScanResult] object containing the scan status, barcode values,
  /// and formats. Returns `null` if the scan could not be started.
  ///
  /// Example usage:
  /// ```dart
  /// final result = await AioScanner.startBarcodeScanning(
  ///   recognizedFormats: ['qr', 'code128'],
  /// );
  ///
  /// if (result?.isSuccessful == true) {
  ///   for (var value in result!.barcodeValues) {
  ///     debugPrint('Scanned barcode: $value');
  ///   }
  /// }
  /// ```
  static Future<BarcodeScanResult?> startBarcodeScanning({
    List<String> recognizedFormats = const [],
    String scanningMessage = 'Point camera at a barcode',
  }) async {
    try {
      final Map<String, dynamic> args = {
        'recognizedFormats': recognizedFormats,
        'scanningMessage': scanningMessage,
      };

      final result = await _channel.invokeMethod('startBarcodeScanning', args);

      if (result == null) return null;

      return BarcodeScanResult.fromMap(Map<dynamic, dynamic>.from(result));
    } catch (e) {
      return BarcodeScanResult(
        isSuccessful: false,
        barcodeValues: [],
        barcodeFormats: [],
        errorMessage: e.toString(),
      );
    }
  }

  /// Generates a thumbnail for a file (image or PDF)
  ///
  /// Returns a map containing the thumbnail path if successful.
  /// The thumbnail will be saved in a 'thumbnails' directory next to the original file.
  static Future<Map<String, dynamic>> generateThumbnail(String filePath) async {
    final Map<dynamic, dynamic>? result = await _channel.invokeMethod('generateThumbnail', {
      'filePath': filePath,
    });
    return result?.cast<String, dynamic>() ?? {};
  }
}
