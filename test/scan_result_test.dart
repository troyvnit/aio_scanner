import 'dart:io';

import 'package:aio_scanner/aio_scanner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ScanResult', () {
    test('creates valid ScanResult from constructor', () {
      // Use mock paths instead of actual file system
      final mockImagePaths = ['/mock/image1.jpg', '/mock/image2.jpg'];
      
      final result = ScanResult(
        isSuccessful: true,
        scannedImages: mockImagePaths.map((path) => File(path)).toList(),
        extractedText: 'Test extracted text',
      );
      
      expect(result.isSuccessful, true);
      expect(result.scannedImages.length, 2);
      expect(result.scannedImages[0].path, '/mock/image1.jpg');
      expect(result.scannedImages[1].path, '/mock/image2.jpg');
      expect(result.extractedText, 'Test extracted text');
      expect(result.errorMessage, null);
    });
    
    test('creates valid ScanResult with error message', () {
      final result = ScanResult(
        isSuccessful: false,
        scannedImages: [],
        extractedText: null,
        errorMessage: 'Test error message',
      );
      
      expect(result.isSuccessful, false);
      expect(result.scannedImages, isEmpty);
      expect(result.extractedText, null);
      expect(result.errorMessage, 'Test error message');
    });
    
    test('fromMap creates valid ScanResult from map', () {
      final mockImagePaths = ['/mock/image1.jpg', '/mock/image2.jpg'];
      
      final Map<String, dynamic> map = {
        'isSuccessful': true,
        'imagePaths': mockImagePaths,
        'extractedText': 'Test extracted text',
      };
      
      final result = ScanResult.fromMap(map);
      
      expect(result.isSuccessful, true);
      expect(result.scannedImages.length, 2);
      expect(result.scannedImages[0].path, '/mock/image1.jpg');
      expect(result.scannedImages[1].path, '/mock/image2.jpg');
      expect(result.extractedText, 'Test extracted text');
      expect(result.errorMessage, null);
    });
    
    test('fromMap handles empty image paths', () {
      final Map<String, dynamic> map = {
        'isSuccessful': true,
        'imagePaths': [],
        'extractedText': 'Test extracted text',
      };
      
      final result = ScanResult.fromMap(map);
      
      expect(result.isSuccessful, true);
      expect(result.scannedImages, isEmpty);
      expect(result.extractedText, 'Test extracted text');
      expect(result.errorMessage, null);
    });
    
    test('fromMap handles null image paths', () {
      final Map<String, dynamic> map = {
        'isSuccessful': true,
        'imagePaths': null,
        'extractedText': 'Test extracted text',
      };
      
      final result = ScanResult.fromMap(map);
      
      expect(result.isSuccessful, true);
      expect(result.scannedImages, isEmpty);
      expect(result.extractedText, 'Test extracted text');
      expect(result.errorMessage, null);
    });
    
    test('fromMap handles null extracted text', () {
      final mockImagePaths = ['/mock/image1.jpg'];
      
      final Map<String, dynamic> map = {
        'isSuccessful': true,
        'imagePaths': mockImagePaths,
        'extractedText': null,
      };
      
      final result = ScanResult.fromMap(map);
      
      expect(result.isSuccessful, true);
      expect(result.scannedImages.length, 1);
      expect(result.scannedImages[0].path, '/mock/image1.jpg');
      expect(result.extractedText, null);
      expect(result.errorMessage, null);
    });
    
    test('fromMap handles error message', () {
      final Map<String, dynamic> map = {
        'isSuccessful': false,
        'imagePaths': [],
        'extractedText': null,
        'errorMessage': 'Test error message',
      };
      
      final result = ScanResult.fromMap(map);
      
      expect(result.isSuccessful, false);
      expect(result.scannedImages, isEmpty);
      expect(result.extractedText, null);
      expect(result.errorMessage, 'Test error message');
    });
    
    test('fromMap handles missing fields', () {
      final Map<String, dynamic> map = {
        'isSuccessful': true,
        // Missing imagePaths
        // Missing extractedText
        // Missing errorMessage
      };
      
      final result = ScanResult.fromMap(map);
      
      expect(result.isSuccessful, true);
      expect(result.scannedImages, isEmpty);
      expect(result.extractedText, null);
      expect(result.errorMessage, null);
    });
    
    test('fromMap handles null success status', () {
      final Map<String, dynamic> map = {
        'isSuccessful': null,
        'imagePaths': ['/mock/image1.jpg'],
        'extractedText': 'Test text',
      };
      
      final result = ScanResult.fromMap(map);
      
      // Should default to false when isSuccessful is null
      expect(result.isSuccessful, false);
      expect(result.scannedImages.length, 1);
      expect(result.extractedText, 'Test text');
      expect(result.errorMessage, null);
    });
    
    test('fromMap handles empty map', () {
      final Map<String, dynamic> map = {};
      
      final result = ScanResult.fromMap(map);
      
      // Should create a default unsuccessful result
      expect(result.isSuccessful, false);
      expect(result.scannedImages, isEmpty);
      expect(result.extractedText, null);
      expect(result.errorMessage, null);
    });
  });
} 