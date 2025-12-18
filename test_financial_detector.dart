// Simple verification script for Financial Context Detector
import 'lib/domain/usecases/detect_financial_context.dart';

void main() {
  final detector = FinancialContextDetector();
  
  print('=== Financial Context Detector Verification ===\n');
  
  // Test cases based on requirements
  final testCases = [
    // Requirement 2.1: Analyze message content for financial context
    {
      'message': 'Your account has been credited with Rs. 1000',
      'expected': true,
      'description': 'Credit transaction message'
    },
    {
      'message': 'Your account has been debited with Rs. 500',
      'expected': true,
      'description': 'Debit transaction message'
    },
    {
      'message': 'Hello, how are you today?',
      'expected': false,
      'description': 'Non-financial message'
    },
    
    // Requirement 2.2: Keywords like "credited", "debited", "transferred", "payment", "rupees", "amount"
    {
      'message': 'Payment of Rs. 2000 successful',
      'expected': true,
      'description': 'Payment keyword'
    },
    {
      'message': 'Amount transferred: 1500 rupees',
      'expected': true,
      'description': 'Transfer and amount keywords'
    },
    
    // Requirement 2.3: Discard non-financial messages
    {
      'message': 'Meeting scheduled for tomorrow',
      'expected': false,
      'description': 'Non-financial message'
    },
  ];

  print('Running ${testCases.length} test cases...\n');
  
  int passed = 0;
  int failed = 0;
  
  for (int i = 0; i < testCases.length; i++) {
    final testCase = testCases[i];
    final message = testCase['message'] as String;
    final expected = testCase['expected'] as bool;
    final description = testCase['description'] as String;
    
    final result = detector.isFinancialMessage(message);
    final success = result == expected;
    
    if (success) {
      passed++;
      print('✅ Test ${i + 1}: $description - PASSED');
    } else {
      failed++;
      print('❌ Test ${i + 1}: $description - FAILED');
      print('   Expected: $expected, Got: $result');
      print('   Message: "$message"');
    }
  }
  
  print('\n=== Results ===');
  print('Passed: $passed');
  print('Failed: $failed');
  print('Total: ${testCases.length}');
  
  if (failed == 0) {
    print('\n🎉 All tests passed!');
  } else {
    print('\n⚠️  Some tests failed. Check implementation.');
  }
}
