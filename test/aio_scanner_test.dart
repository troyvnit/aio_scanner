import 'dart:io';

import 'package:aio_scanner/aio_scanner.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('aio_scanner');
  final List<MethodCall> log = <MethodCall>[];
  dynamic returnValue = true;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        log.add(methodCall);
        return returnValue;
      },
    );
    log.clear();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      null,
    );
  });

  group('isDocumentScanningSupported', () {
    test('returns true when platform returns true', () async {
      returnValue = true;
      final bool result = await AioScanner.isDocumentScanningSupported();
      
      expect(result, true);
      expect(log, hasLength(1));
      expect(log.first.method, 'isDocumentScanningSupported');
    });

    test('returns false when platform returns false', () async {
      returnValue = false;
      final bool result = await AioScanner.isDocumentScanningSupported();
      
      expect(result, false);
      expect(log, hasLength(1));
      expect(log.first.method, 'isDocumentScanningSupported');
    });

    test('returns false when platform throws exception', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (MethodCall methodCall) async {
          throw PlatformException(code: 'TEST_ERROR');
        },
      );
      
      final bool result = await AioScanner.isDocumentScanningSupported();
      
      expect(result, false);
    });
  });

  group('ScanResult', () {
    test('creates ScanResult from valid map', () {
      final tempDir = Directory.systemTemp;
      final imagePath1 = '${tempDir.path}/image1.jpg';
      final imagePath2 = '${tempDir.path}/image2.jpg';
      
      final Map<dynamic, dynamic> resultMap = {
        'isSuccessful': true,
        'imagePaths': [imagePath1, imagePath2],
        'extractedText': 'Sample extracted text',
        'errorMessage': null,
      };
      
      final result = ScanResult.fromMap(resultMap);
      
      expect(result.isSuccessful, true);
      expect(result.scannedImages.length, 2);
      expect(result.scannedImages[0].path, imagePath1);
      expect(result.scannedImages[1].path, imagePath2);
      expect(result.extractedText, 'Sample extracted text');
      expect(result.errorMessage, null);
    });
    
    test('handles missing fields gracefully', () {
      final Map<dynamic, dynamic> resultMap = {
        'isSuccessful': true,
        // Missing 'imagePaths'
        // Missing 'extractedText'
        // Missing 'errorMessage'
      };
      
      final result = ScanResult.fromMap(resultMap);
      
      expect(result.isSuccessful, true);
      expect(result.scannedImages, isEmpty);
      expect(result.extractedText, null);
      expect(result.errorMessage, null);
    });
    
    test('handles null values gracefully', () {
      final Map<dynamic, dynamic> resultMap = {
        'isSuccessful': null,
        'imagePaths': null,
        'extractedText': null,
        'errorMessage': null,
      };
      
      final result = ScanResult.fromMap(resultMap);
      
      expect(result.isSuccessful, false); // Defaults to false when null
      expect(result.scannedImages, isEmpty);
      expect(result.extractedText, null);
      expect(result.errorMessage, null);
    });
  });
  
  group('startDocumentScanning', () {
    setUp(() {
      returnValue = {
        'isSuccessful': true,
        'imagePaths': ['/temp/scan1.jpg', '/temp/scan2.jpg'],
        'extractedText': 'Lorem ipsum dolor sit amet',
        'errorMessage': null,
      };
    });
    
    test('calls platform method with correct arguments', () async {
      final result = await AioScanner.startDocumentScanning(
        outputDirectory: '/test/output',
        maxNumPages: 3,
        initialMessage: 'Test initial message',
        scanningMessage: 'Test scanning message',
        allowGalleryImport: false,
      );
      
      expect(log, hasLength(1));
      expect(log.first.method, 'startDocumentScanning');
      
      final args = log.first.arguments as Map<String, dynamic>;
      expect(args['outputDirectory'], '/test/output');
      expect(args['maxNumPages'], 3);
      expect(args['initialMessage'], 'Test initial message');
      expect(args['scanningMessage'], 'Test scanning message');
      expect(args['allowGalleryImport'], false);
      
      expect(result!.isSuccessful, true);
      expect(result.scannedImages.length, 2);
      expect(result.extractedText, 'Lorem ipsum dolor sit amet');
    });
    
    test('creates output directory if it does not exist', () async {
      // Create a temporary directory path that doesn't exist yet
      final tempDir = await Directory.systemTemp.createTemp('aio_scanner_test_');
      final nonExistingDir = '${tempDir.path}/nonexistent_dir';
      
      // Verify directory doesn't exist yet
      expect(await Directory(nonExistingDir).exists(), false);
      
      await AioScanner.startDocumentScanning(
        outputDirectory: nonExistingDir,
      );
      
      // Directory should be created
      expect(await Directory(nonExistingDir).exists(), true);
      
      // Clean up
      await tempDir.delete(recursive: true);
    });
    
    test('returns null when platform returns null', () async {
      returnValue = null;
      
      final result = await AioScanner.startDocumentScanning(
        outputDirectory: '/test/output',
      );
      
      expect(result, isNull);
    });
    
    test('returns ScanResult with error when platform throws exception', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (MethodCall methodCall) async {
          throw PlatformException(code: 'SCAN_ERROR', message: 'Test error message');
        },
      );
      
      final result = await AioScanner.startDocumentScanning(
        outputDirectory: '/test/output',
      );
      
      expect(result!.isSuccessful, false);
      expect(result.scannedImages, isEmpty);
      expect(result.errorMessage, contains('Test error message'));
    });
  });
  
  group('startBusinessCardScanning', () {
    setUp(() {
      returnValue = {
        'isSuccessful': true,
        'imagePaths': ['/temp/card.jpg'],
        'extractedText': 'John Doe\nCEO\nEmail: john@example.com',
        'errorMessage': null,
      };
    });
    
    test('calls platform method with correct arguments', () async {
      final result = await AioScanner.startBusinessCardScanning(
        outputDirectory: '/test/cards',
        initialMessage: 'Test card message',
        scanningMessage: 'Test card scanning',
      );
      
      expect(log, hasLength(1));
      expect(log.first.method, 'startBusinessCardScanning');
      
      final args = log.first.arguments as Map<String, dynamic>;
      expect(args['outputDirectory'], '/test/cards');
      expect(args['initialMessage'], 'Test card message');
      expect(args['scanningMessage'], 'Test card scanning');
      
      expect(result!.isSuccessful, true);
      expect(result.scannedImages.length, 1);
      expect(result.extractedText, contains('John Doe'));
    });
    
    test('creates output directory if it does not exist', () async {
      // Create a temporary directory path that doesn't exist yet
      final tempDir = await Directory.systemTemp.createTemp('aio_scanner_test_');
      final nonExistingDir = '${tempDir.path}/nonexistent_cards';
      
      // Verify directory doesn't exist yet
      expect(await Directory(nonExistingDir).exists(), false);
      
      await AioScanner.startBusinessCardScanning(
        outputDirectory: nonExistingDir,
      );
      
      // Directory should be created
      expect(await Directory(nonExistingDir).exists(), true);
      
      // Clean up
      await tempDir.delete(recursive: true);
    });
    
    test('returns null when platform returns null', () async {
      returnValue = null;
      
      final result = await AioScanner.startBusinessCardScanning(
        outputDirectory: '/test/cards',
      );
      
      expect(result, isNull);
    });
    
    test('returns ScanResult with error when platform throws exception', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (MethodCall methodCall) async {
          throw PlatformException(code: 'SCAN_ERROR', message: 'Test card error');
        },
      );
      
      final result = await AioScanner.startBusinessCardScanning(
        outputDirectory: '/test/cards',
      );
      
      expect(result!.isSuccessful, false);
      expect(result.scannedImages, isEmpty);
      expect(result.errorMessage, contains('Test card error'));
    });
  });
}
