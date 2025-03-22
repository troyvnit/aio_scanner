import 'dart:io';

import 'package:aio_scanner/aio_scanner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ScanResult', () {
    test('constructor sets all properties correctly', () {
      final scannedImages = [
        File('/temp/image1.jpg'),
        File('/temp/image2.jpg'),
      ];
      
      final result = ScanResult(
        isSuccessful: true,
        scannedImages: scannedImages,
        extractedText: 'Sample text',
        errorMessage: 'Some error',
      );
      
      expect(result.isSuccessful, true);
      expect(result.scannedImages, equals(scannedImages));
      expect(result.extractedText, 'Sample text');
      expect(result.errorMessage, 'Some error');
    });
    
    test('fromMap creates instance with proper values', () {
      final Map<dynamic, dynamic> map = {
        'isSuccessful': true,
        'imagePaths': ['/test/path1.jpg', '/test/path2.jpg'],
        'extractedText': 'Extracted content',
        'errorMessage': null,
      };
      
      final result = ScanResult.fromMap(map);
      
      expect(result.isSuccessful, true);
      expect(result.scannedImages.length, 2);
      expect(result.scannedImages[0].path, '/test/path1.jpg');
      expect(result.scannedImages[1].path, '/test/path2.jpg');
      expect(result.extractedText, 'Extracted content');
      expect(result.errorMessage, null);
    });
    
    test('fromMap handles empty image paths', () {
      final Map<dynamic, dynamic> map = {
        'isSuccessful': true,
        'imagePaths': [],
        'extractedText': 'Content with no images',
        'errorMessage': null,
      };
      
      final result = ScanResult.fromMap(map);
      
      expect(result.isSuccessful, true);
      expect(result.scannedImages, isEmpty);
      expect(result.extractedText, 'Content with no images');
    });
    
    test('fromMap handles null fields gracefully', () {
      final Map<dynamic, dynamic> map = {
        'isSuccessful': null,
        'imagePaths': null,
        'extractedText': null,
        'errorMessage': null,
      };
      
      final result = ScanResult.fromMap(map);
      
      expect(result.isSuccessful, false); // Default when null
      expect(result.scannedImages, isEmpty);
      expect(result.extractedText, null);
      expect(result.errorMessage, null);
    });
    
    test('fromMap works with minimal map', () {
      final Map<dynamic, dynamic> map = {
        'isSuccessful': true,
      };
      
      final result = ScanResult.fromMap(map);
      
      expect(result.isSuccessful, true);
      expect(result.scannedImages, isEmpty);
      expect(result.extractedText, null);
      expect(result.errorMessage, null);
    });
    
    test('fromMap preserves false success status', () {
      final Map<dynamic, dynamic> map = {
        'isSuccessful': false,
        'imagePaths': ['/test/path1.jpg'],
        'extractedText': 'Some text',
        'errorMessage': 'Operation failed',
      };
      
      final result = ScanResult.fromMap(map);
      
      expect(result.isSuccessful, false);
      expect(result.scannedImages.length, 1);
      expect(result.extractedText, 'Some text');
      expect(result.errorMessage, 'Operation failed');
    });
  });
} 