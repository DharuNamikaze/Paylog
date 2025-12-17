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
      'message': 'Meeting scheduled 