// ignore_for_file: avoid_print

import 'dart:io';

import 'package:aio_scanner/aio_scanner.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

@GenerateMocks([MethodChannel])
import 'aio_scanner_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockMethodChannel mockChannel;

  setUp(() {
    mockChannel = MockMethodChannel();
    // Set up the mock channel
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('aio_scanner'),
      (call) async => await mockChannel.invokeMethod(call.method, call.arguments),
    );
  });

  group('AioScanner', () {
    test('isDocumentScanningSupported returns true when supported', () async {
      when(mockChannel.invokeMethod('isDocumentScanningSupported'))
          .thenAnswer((_) async => true);

      final result = await AioScanner.isDocumentScanningSupported();
      expect(result, true);
    });

    test('isDocumentScanningSupported returns false when not supported', () async {
      when(mockChannel.invokeMethod('isDocumentScanningSupported'))
          .thenAnswer((_) async => false);

      final result = await AioScanner.isDocumentScanningSupported();
      expect(result, false);
    });

    test('startDocumentScanning with default parameters', () async {
      final expectedArgs = {
        'outputDirectory': argThat(isA<String>()),
        'maxNumPages': 5,
        'initialMessage': 'Position document in frame',
        'scanningMessage': 'Hold still...',
        'allowGalleryImport': true,
        'outputFormat': 'image',
        'mergePDF': true,
      };

      when(mockChannel.invokeMethod('startDocumentScanning', expectedArgs))
          .thenAnswer((_) async => {
                'isSuccessful': true,
                'filePaths': ['/path/to/image1.jpg', '/path/to/image2.jpg'],
                'extractedText': 'Sample text',
              });

      final result = await AioScanner.startDocumentScanning();
      expect(result?.isSuccessful, true);
      expect(result?.scannedFiles.length, 2);
      expect(result?.extractedText, 'Sample text');
    });

    test('startDocumentScanning with PDF output and merged PDF', () async {
      final expectedArgs = {
        'outputDirectory': argThat(isA<String>()),
        'maxNumPages': 3,
        'initialMessage': 'Position document in frame',
        'scanningMessage': 'Hold still...',
        'allowGalleryImport': true,
        'outputFormat': 'pdf',
        'mergePDF': true,
      };

      when(mockChannel.invokeMethod('startDocumentScanning', expectedArgs))
          .thenAnswer((_) async => {
                'isSuccessful': true,
                'filePaths': ['/path/to/merged.pdf'],
                'extractedText': 'Sample text',
              });

      final result = await AioScanner.startDocumentScanning(
        maxNumPages: 3,
        outputFormat: ScanOutputFormat.pdf,
        mergePDF: true,
      );
      expect(result?.isSuccessful, true);
      expect(result?.scannedFiles.length, 1);
      expect(result?.scannedFiles.first.path, '/path/to/merged.pdf');
      expect(result?.extractedText, 'Sample text');
    });

    test('startDocumentScanning with PDF output and individual PDFs', () async {
      final expectedArgs = {
        'outputDirectory': argThat(isA<String>()),
        'maxNumPages': 3,
        'initialMessage': 'Position document in frame',
        'scanningMessage': 'Hold still...',
        'allowGalleryImport': true,
        'outputFormat': 'pdf',
        'mergePDF': false,
      };

      when(mockChannel.invokeMethod('startDocumentScanning', expectedArgs))
          .thenAnswer((_) async => {
                'isSuccessful': true,
                'filePaths': [
                  '/path/to/page1.pdf',
                  '/path/to/page2.pdf',
                  '/path/to/page3.pdf'
                ],
                'extractedText': 'Sample text',
              });

      final result = await AioScanner.startDocumentScanning(
        maxNumPages: 3,
        outputFormat: ScanOutputFormat.pdf,
        mergePDF: false,
      );
      expect(result?.isSuccessful, true);
      expect(result?.scannedFiles.length, 3);
      expect(result?.scannedFiles[0].path, '/path/to/page1.pdf');
      expect(result?.scannedFiles[1].path, '/path/to/page2.pdf');
      expect(result?.scannedFiles[2].path, '/path/to/page3.pdf');
      expect(result?.extractedText, 'Sample text');
    });

    test('startDocumentScanning handles errors', () async {
      when(mockChannel.invokeMethod('startDocumentScanning', any))
          .thenThrow(PlatformException(code: 'ERROR', message: 'Test error'));

      final result = await AioScanner.startDocumentScanning();
      expect(result?.isSuccessful, false);
      expect(result?.errorMessage, 'Test error');
    });

    test('isBarcodeScanningSupported returns true when supported', () async {
      when(mockChannel.invokeMethod('isBarcodeScanningSupported'))
          .thenAnswer((_) async => true);

      final result = await AioScanner.isBarcodeScanningSupported();
      expect(result, true);
    });

    test('isBarcodeScanningSupported returns false when not supported', () async {
      when(mockChannel.invokeMethod('isBarcodeScanningSupported'))
          .thenAnswer((_) async => false);

      final result = await AioScanner.isBarcodeScanningSupported();
      expect(result, false);
    });

    test('startBarcodeScanning with default parameters', () async {
      final expectedArgs = {
        'recognizedFormats': [],
        'scanningMessage': 'Point camera at a barcode',
      };

      when(mockChannel.invokeMethod('startBarcodeScanning', expectedArgs))
          .thenAnswer((_) async => {
                'isSuccessful': true,
                'barcodeValues': ['123456', '789012'],
                'barcodeFormats': ['qr', 'code128'],
              });

      final result = await AioScanner.startBarcodeScanning();
      expect(result?.isSuccessful, true);
      expect(result?.barcodeValues, ['123456', '789012']);
      expect(result?.barcodeFormats, ['qr', 'code128']);
    });

    test('startBarcodeScanning with specific formats', () async {
      final expectedArgs = {
        'recognizedFormats': ['qr', 'code128'],
        'scanningMessage': 'Point camera at a barcode',
      };

      when(mockChannel.invokeMethod('startBarcodeScanning', expectedArgs))
          .thenAnswer((_) async => {
                'isSuccessful': true,
                'barcodeValues': ['123456'],
                'barcodeFormats': ['qr'],
              });

      final result = await AioScanner.startBarcodeScanning(
        recognizedFormats: ['qr', 'code128'],
      );
      expect(result?.isSuccessful, true);
      expect(result?.barcodeValues, ['123456']);
      expect(result?.barcodeFormats, ['qr']);
    });

    test('startBarcodeScanning handles errors', () async {
      when(mockChannel.invokeMethod('startBarcodeScanning', any))
          .thenThrow(PlatformException(code: 'ERROR', message: 'Test error'));

      final result = await AioScanner.startBarcodeScanning();
      expect(result?.isSuccessful, false);
      expect(result?.barcodeValues, []);
      expect(result?.barcodeFormats, []);
      expect(result?.errorMessage, 'Test error');
    });
  });

  group('ScanResult', () {
    test('creates ScanResult from valid map', () {
      final tempDir = Directory.systemTemp;
      final imagePath1 = '${tempDir.path}/image1.jpg';
      final imagePath2 = '${tempDir.path}/image2.jpg';

      final Map<dynamic, dynamic> resultMap = {
        'isSuccessful': true,
        'filePaths': [imagePath1, imagePath2],
        'extractedText': 'Sample extracted text',
        'errorMessage': null,
      };

      final result = ScanResult.fromMap(resultMap);

      expect(result.isSuccessful, true);
      expect(result.scannedFiles.length, 2);
      expect(result.scannedFiles[0].path, imagePath1);
      expect(result.scannedFiles[1].path, imagePath2);
      expect(result.extractedText, 'Sample extracted text');
      expect(result.errorMessage, null);
    });

    test('handles missing fields gracefully', () {
      final Map<dynamic, dynamic> resultMap = {
        'isSuccessful': true,
        // Missing 'filePaths'
        // Missing 'extractedText'
        // Missing 'errorMessage'
      };

      final result = ScanResult.fromMap(resultMap);

      expect(result.isSuccessful, true);
      expect(result.scannedFiles, isEmpty);
      expect(result.extractedText, null);
      expect(result.errorMessage, null);
    });

    test('handles null values gracefully', () {
      final Map<dynamic, dynamic> resultMap = {
        'isSuccessful': null,
        'filePaths': null,
        'extractedText': null,
        'errorMessage': null,
      };

      final result = ScanResult.fromMap(resultMap);

      expect(result.isSuccessful, false); // Defaults to false when null
      expect(result.scannedFiles, isEmpty);
      expect(result.extractedText, null);
      expect(result.errorMessage, null);
    });
  });

  group('BarcodeScanResult', () {
    test('creates BarcodeScanResult from valid map', () {
      final Map<dynamic, dynamic> resultMap = {
        'isSuccessful': true,
        'barcodeValues': ['https://example.com', '12345678'],
        'barcodeFormats': ['qr', 'code128'],
        'errorMessage': null,
      };

      final result = BarcodeScanResult.fromMap(resultMap);

      expect(result.isSuccessful, true);
      expect(result.barcodeValues.length, 2);
      expect(result.barcodeValues[0], 'https://example.com');
      expect(result.barcodeValues[1], '12345678');
      expect(result.barcodeFormats[0], 'qr');
      expect(result.barcodeFormats[1], 'code128');
      expect(result.errorMessage, null);
    });

    test('handles missing fields gracefully', () {
      final Map<dynamic, dynamic> resultMap = {
        'isSuccessful': true,
        // Missing 'barcodeValues'
        // Missing 'barcodeFormats'
        // Missing 'errorMessage'
      };

      final result = BarcodeScanResult.fromMap(resultMap);

      expect(result.isSuccessful, true);
      expect(result.barcodeValues, isEmpty);
      expect(result.barcodeFormats, isEmpty);
      expect(result.errorMessage, null);
    });

    test('handles null values gracefully', () {
      final Map<dynamic, dynamic> resultMap = {
        'isSuccessful': null,
        'barcodeValues': null,
        'barcodeFormats': null,
        'errorMessage': null,
      };

      final result = BarcodeScanResult.fromMap(resultMap);

      expect(result.isSuccessful, false); // Defaults to false when null
      expect(result.barcodeValues, isEmpty);
      expect(result.barcodeFormats, isEmpty);
      expect(result.errorMessage, null);
    });
  });
}
