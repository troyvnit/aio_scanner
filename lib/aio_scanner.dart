/// AIO Scanner provides a cross-platform document scanning solution.
/// 
/// This package leverages VisionKit on iOS and ML Kit on Android to provide
/// document scanning capabilities in Flutter applications.
library aio_scanner;

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// Result of a document or business card scanning operation
///
/// This class encapsulates all data returned from a scanning session,
/// including success status, scanned images, extracted text, and any error messages.
/// It provides a convenient way to handle and process scan results in the application.
class ScanResult {
  /// Whether the scan was successfully completed.
  ///
  /// A value of `true` indicates that the scanning process completed without errors
  /// and images were captured. A value of `false` indicates that an error occurred
  /// or the user cancelled the scanning process.
  final bool isSuccessful;

  /// List of captured document images as [File] objects.
  ///
  /// Each file represents a page of the scanned document or a business card.
  /// The files are stored in the output directory specified when starting the scan.
  final List<File> scannedImages;

  /// Text extracted from the scanned document using OCR.
  ///
  /// This field contains the recognized text content from all scanned pages.
  /// May be null if no text could be extracted or if OCR failed.
  final String? extractedText;

  /// Error message if the scan was not successful.
  ///
  /// Contains a description of what went wrong if [isSuccessful] is `false`.
  /// May be null if the scan was successful or if the error was unspecified.
  final String? errorMessage;

  /// Creates a new [ScanResult] instance.
  ///
  /// [isSuccessful] indicates whether the scan completed successfully.
  /// [scannedImages] contains the list of captured image files.
  /// [extractedText] contains the recognized text from the document (optional).
  /// [errorMessage] provides error details if the scan failed (optional).
  ScanResult({
    required this.isSuccessful,
    required this.scannedImages,
    this.extractedText,
    this.errorMessage,
  });

  /// Creates a [ScanResult] from a map returned by the platform channel.
  ///
  /// This factory constructor handles the conversion from the raw platform data
  /// to a strongly-typed Dart object. It processes the image paths from the native
  /// implementation and converts them to [File] objects.
  ///
  /// [map] is the raw data map returned from the platform-specific implementation.
  factory ScanResult.fromMap(Map<dynamic, dynamic> map) {
    final List<File> images = [];
    if (map['imagePaths'] != null) {
      for (String path in map['imagePaths']) {
        images.add(File(path));
      }
    }

    return ScanResult(
      isSuccessful: map['isSuccessful'] ?? false,
      scannedImages: images,
      extractedText: map['extractedText'],
      errorMessage: map['errorMessage'],
    );
  }
}

/// The main class for interacting with document and business card scanning functionality.
///
/// This class provides methods to check for scanning support on the current platform
/// and to initiate different types of scanning operations (documents and business cards).
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
      return await _channel.invokeMethod('isDocumentScanningSupported') ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Starts the document scanning process.
  ///
  /// This method launches the native document scanner UI, allowing the user to
  /// capture document pages. The captured images are saved to the specified
  /// output directory, and text is extracted from the images using OCR.
  ///
  /// Parameters:
  /// - [outputDirectory]: Directory where scanned images will be saved. This directory
  ///   will be created if it doesn't exist.
  /// - [maxNumPages]: Maximum number of pages to scan (default: 5, 0 = unlimited)
  /// - [initialMessage]: Message to display when scanning starts (platform-specific)
  /// - [scanningMessage]: Message to display during scanning (platform-specific)
  /// - [allowGalleryImport]: Whether to allow importing images from the device gallery
  ///
  /// Returns a [ScanResult] object containing the scan status, captured images,
  /// and extracted text. Returns `null` if the scan could not be started.
  ///
  /// Example usage:
  /// ```dart
  /// final result = await AioScanner.startDocumentScanning(
  ///   outputDirectory: '${documentsDir.path}/scans',
  ///   maxNumPages: 3,
  /// );
  ///
  /// if (result?.isSuccessful == true) {
  ///   for (var image in result!.scannedImages) {
  ///     // Process each image
  ///   }
  ///   if (result.extractedText != null) {
  ///     // Use the extracted text
  ///   }
  /// }
  /// ```
  static Future<ScanResult?> startDocumentScanning({
    required String outputDirectory,
    int maxNumPages = 5,
    String initialMessage = 'Position document in frame',
    String scanningMessage = 'Hold still...',
    bool allowGalleryImport = true,
  }) async {
    try {
      // Create output directory if it doesn't exist
      final directory = Directory(outputDirectory);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final Map<String, dynamic> args = {
        'outputDirectory': outputDirectory,
        'maxNumPages': maxNumPages,
        'initialMessage': initialMessage,
        'scanningMessage': scanningMessage,
        'allowGalleryImport': allowGalleryImport,
      };

      final result = await _channel.invokeMethod('startDocumentScanning', args);
      
      if (result == null) return null;
      
      return ScanResult.fromMap(Map<dynamic, dynamic>.from(result));
    } catch (e) {
      return ScanResult(
        isSuccessful: false,
        scannedImages: [],
        errorMessage: e.toString(),
      );
    }
  }

  /// Starts the business card scanning process.
  ///
  /// This method launches a specialized scanner UI optimized for business cards.
  /// It captures a single image of the business card and extracts relevant information
  /// using OCR. The scanner UI and processing are optimized for the smaller format
  /// and structured content typical of business cards.
  ///
  /// Parameters:
  /// - [outputDirectory]: Directory where the scanned card image will be saved. This
  ///   directory will be created if it doesn't exist.
  /// - [initialMessage]: Message to display when scanning starts (platform-specific)
  /// - [scanningMessage]: Message to display during scanning (platform-specific)
  ///
  /// Returns a [ScanResult] object containing the scan status, captured image,
  /// and extracted text. Returns `null` if the scan could not be started.
  ///
  /// Example usage:
  /// ```dart
  /// final result = await AioScanner.startBusinessCardScanning(
  ///   outputDirectory: '${documentsDir.path}/business_cards',
  /// );
  ///
  /// if (result?.isSuccessful == true) {
  ///   final cardImage = result!.scannedImages.first;
  ///   final extractedInfo = result.extractedText;
  ///   // Process business card data
  /// }
  /// ```
  static Future<ScanResult?> startBusinessCardScanning({
    required String outputDirectory,
    String initialMessage = 'Position card in frame',
    String scanningMessage = 'Capturing...',
  }) async {
    try {
      // Create output directory if it doesn't exist
      final directory = Directory(outputDirectory);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final Map<String, dynamic> args = {
        'outputDirectory': outputDirectory,
        'initialMessage': initialMessage,
        'scanningMessage': scanningMessage,
      };

      final result = await _channel.invokeMethod('startBusinessCardScanning', args);
      
      if (result == null) return null;
      
      return ScanResult.fromMap(Map<dynamic, dynamic>.from(result));
    } catch (e) {
      return ScanResult(
        isSuccessful: false,
        scannedImages: [],
        errorMessage: e.toString(),
      );
    }
  }
}
