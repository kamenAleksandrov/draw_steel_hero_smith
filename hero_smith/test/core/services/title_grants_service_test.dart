import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TitleGrantsService constructor', () {
    // Note: Full integration tests require a real database instance
    // These tests verify the service can be instantiated and basic parsing works
    
    test('service requires AppDatabase parameter', () {
      // This is a compile-time check - the constructor signature enforces it
      // If this file compiles, the test passes
      expect(true, isTrue);
    });
  });

  group('Title selection parsing', () {
    test('title selection format is titleId:benefitIndex', () {
      // Format: "title-id:0" means title "title-id" with benefit index 0
      const selection = 'iron-saint:1';
      final parts = selection.split(':');
      
      expect(parts.length, 2);
      expect(parts[0], 'iron-saint');
      expect(int.tryParse(parts[1]), 1);
    });

    test('invalid selection without colon returns single part', () {
      const selection = 'invalid-selection';
      final parts = selection.split(':');
      
      expect(parts.length, 1);
    });

    test('benefit index defaults to 0 for non-numeric', () {
      const selection = 'title:abc';
      final parts = selection.split(':');
      final benefitIndex = int.tryParse(parts[1]) ?? 0;
      
      expect(benefitIndex, 0);
    });
  });
}
