/// Utility class for parsing dates and times from SMS messages
/// 
/// Handles:
/// - Dates in formats: DD-MM-YYYY, DD/MM/YYYY, text formats (today, yesterday)
/// - Normalize dates to ISO 8601 format (YYYY-MM-DD)
/// - Times in various formats and normalize to HH:MM:SS
/// - Fallback to SMS receipt timestamp when time is not provided
class DateTimeParser {
  /// Regex pattern for DD-MM-YYYY or DD/MM/YYYY format
  static final RegExp _ddmmyyyyPattern = RegExp(
    r'\b(\d{1,2})[-/](\d{1,2})[-/](\d{4})\b',
  );
  
  /// Regex pattern for DD-MM-YY or DD/MM/YY format
  static final RegExp _ddmmyyPattern = RegExp(
    r'\b(\d{1,2})[-/](\d{1,2})[-/](\d{2})\b',
  );
  
  /// Regex pattern for YYYY-MM-DD format (ISO 8601)
  static final RegExp _yyyymmddPattern = RegExp(
    r'\b(\d{4})[-/](\d{1,2})[-/](\d{1,2})\b',
  );
  
  /// Regex pattern for time in various formats
  /// Matches: HH:MM:SS, HH:MM, HH:MM AM/PM, HH:MM:SS AM/PM
  static final RegExp _timePattern = RegExp(
    r'\b(\d{1,2}):(\d{2})(?::(\d{2}))?\s*(AM|PM|am|pm)?\b',
  );
  
  /// Regex pattern for text-based dates
  static final RegExp _textDatePattern = RegExp(
    r'\b(today|yesterday|tomorrow)\b',
    caseSensitive: false,
  );
  
  /// Regex pattern for dates like "on 15th Jan" or "on 15 January" or "15-Dec-2024"
  static final RegExp _dayMonthPattern = RegExp(
    r'\b(\d{1,2})(?:st|nd|rd|th)?[-\s]+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec|January|February|March|April|May|June|July|August|September|October|November|December)(?:[-\s]+(\d{2,4}))?\b',
    caseSensitive: false,
  );
  
  /// Map for converting month names to numbers
  static const Map<String, int> _monthNameToNumber = {
    'jan': 1, 'january': 1,
    'feb': 2, 'february': 2,
    'mar': 3, 'march': 3,
    'apr': 4, 'april': 4,
    'may': 5,
    'jun': 6, 'june': 6,
    'jul': 7, 'july': 7,
    'aug': 8, 'august': 8,
    'sep': 9, 'september': 9,
    'oct': 10, 'october': 10,
    'nov': 11, 'november': 11,
    'dec': 12, 'december': 12,
  };
  
  /// Extract and normalize date from SMS content
  /// 
  /// Returns date in ISO 8601 format (YYYY-MM-DD)
  /// Falls back to SMS receipt timestamp if no date found
  static String extractDate(String content, DateTime smsTimestamp) {
    if (content.trim().isEmpty) {
      return _formatDateToISO8601(smsTimestamp);
    }
    
    // Try text-based dates first (today, yesterday, tomorrow)
    final textDateMatch = _textDatePattern.firstMatch(content);
    if (textDateMatch != null) {
      final textDate = textDateMatch.group(1)!.toLowerCase();
      return _parseTextDate(textDate, smsTimestamp);
    }
    
    // Try DD-MM-YYYY or DD/MM/YYYY format
    final ddmmyyyyMatch = _ddmmyyyyPattern.firstMatch(content);
    if (ddmmyyyyMatch != null) {
      final day = int.parse(ddmmyyyyMatch.group(1)!);
      final month = int.parse(ddmmyyyyMatch.group(2)!);
      final year = int.parse(ddmmyyyyMatch.group(3)!);
      
      if (_isValidDate(day, month, year)) {
        return _formatDate(year, month, day);
      }
    }
    
    // Try YYYY-MM-DD format
    final yyyymmddMatch = _yyyymmddPattern.firstMatch(content);
    if (yyyymmddMatch != null) {
      final year = int.parse(yyyymmddMatch.group(1)!);
      final month = int.parse(yyyymmddMatch.group(2)!);
      final day = int.parse(yyyymmddMatch.group(3)!);
      
      if (_isValidDate(day, month, year)) {
        return _formatDate(year, month, day);
      }
    }
    
    // Try DD-MM-YY or DD/MM/YY format (2-digit year)
    final ddmmyyMatch = _ddmmyyPattern.firstMatch(content);
    if (ddmmyyMatch != null) {
      final day = int.parse(ddmmyyMatch.group(1)!);
      final month = int.parse(ddmmyyMatch.group(2)!);
      final year2Digit = int.parse(ddmmyyMatch.group(3)!);
      
      // Convert 2-digit year to 4-digit year
      // Assume 00-50 is 2000-2050, 51-99 is 1951-1999
      final year = year2Digit <= 50 ? 2000 + year2Digit : 1900 + year2Digit;
      
      if (_isValidDate(day, month, year)) {
        return _formatDate(year, month, day);
      }
    }
    
    // Try day-month format (e.g., "15th Jan", "15 January", "15-Dec-2024", "17-DEC-24")
    final dayMonthMatch = _dayMonthPattern.firstMatch(content);
    if (dayMonthMatch != null) {
      final day = int.parse(dayMonthMatch.group(1)!);
      final monthStr = dayMonthMatch.group(2)!.toLowerCase();
      final month = _monthNameToNumber[monthStr];
      
      if (month != null) {
        // Check if year is provided in the match
        final yearStr = dayMonthMatch.group(3);
        int year;
        
        if (yearStr != null) {
          final yearInt = int.parse(yearStr);
          // Convert 2-digit year to 4-digit year if needed
          if (yearInt < 100) {
            year = yearInt <= 50 ? 2000 + yearInt : 1900 + yearInt;
          } else {
            year = yearInt;
          }
        } else {
          // Use SMS timestamp year if no year provided
          year = smsTimestamp.year;
        }
        
        if (_isValidDate(day, month, year)) {
          return _formatDate(year, month, day);
        }
      }
    }
    
    // Fallback to SMS receipt timestamp
    return _formatDateToISO8601(smsTimestamp);
  }
  
  /// Extract and normalize time from SMS content
  /// 
  /// Returns time in 24-hour format (HH:MM:SS)
  /// Falls back to SMS receipt timestamp if no time found
  static String extractTime(String content, DateTime smsTimestamp) {
    if (content.trim().isEmpty) {
      return _formatTimeToHHMMSS(smsTimestamp);
    }
    
    final timeMatch = _timePattern.firstMatch(content);
    if (timeMatch != null) {
      int hour = int.parse(timeMatch.group(1)!);
      final minute = int.parse(timeMatch.group(2)!);
      final secondStr = timeMatch.group(3);
      final second = secondStr != null ? int.parse(secondStr) : 0;
      final meridiem = timeMatch.group(4)?.toUpperCase();
      
      // Convert to 24-hour format if AM/PM is present
      if (meridiem != null) {
        if (meridiem == 'PM' && hour != 12) {
          hour += 12;
        } else if (meridiem == 'AM' && hour == 12) {
          hour = 0;
        }
      }
      
      // Validate time
      if (hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59 && second >= 0 && second <= 59) {
        return _formatTime(hour, minute, second);
      }
    }
    
    // Fallback to SMS receipt timestamp
    return _formatTimeToHHMMSS(smsTimestamp);
  }
  
  /// Extract both date and time from SMS content
  /// 
  /// Returns a map with 'date' and 'time' keys
  static Map<String, String> extractDateTime(String content, DateTime smsTimestamp) {
    return {
      'date': extractDate(content, smsTimestamp),
      'time': extractTime(content, smsTimestamp),
    };
  }
  
  /// Parse text-based dates (today, yesterday, tomorrow)
  static String _parseTextDate(String textDate, DateTime referenceDate) {
    switch (textDate) {
      case 'today':
        return _formatDateToISO8601(referenceDate);
      case 'yesterday':
        final yesterday = referenceDate.subtract(const Duration(days: 1));
        return _formatDateToISO8601(yesterday);
      case 'tomorrow':
        final tomorrow = referenceDate.add(const Duration(days: 1));
        return _formatDateToISO8601(tomorrow);
      default:
        return _formatDateToISO8601(referenceDate);
    }
  }
  
  /// Format date to ISO 8601 format (YYYY-MM-DD)
  static String _formatDateToISO8601(DateTime date) {
    return _formatDate(date.year, date.month, date.day);
  }
  
  /// Format date components to ISO 8601 format (YYYY-MM-DD)
  static String _formatDate(int year, int month, int day) {
    final yearStr = year.toString().padLeft(4, '0');
    final monthStr = month.toString().padLeft(2, '0');
    final dayStr = day.toString().padLeft(2, '0');
    return '$yearStr-$monthStr-$dayStr';
  }
  
  /// Format time to HH:MM:SS format
  static String _formatTimeToHHMMSS(DateTime time) {
    return _formatTime(time.hour, time.minute, time.second);
  }
  
  /// Format time components to HH:MM:SS format
  static String _formatTime(int hour, int minute, int second) {
    final hourStr = hour.toString().padLeft(2, '0');
    final minuteStr = minute.toString().padLeft(2, '0');
    final secondStr = second.toString().padLeft(2, '0');
    return '$hourStr:$minuteStr:$secondStr';
  }
  
  /// Validate if date components form a valid date
  static bool _isValidDate(int day, int month, int year) {
    if (month < 1 || month > 12) {
      return false;
    }
    
    if (day < 1) {
      return false;
    }
    
    // Days in each month
    final daysInMonth = [
      31, // January
      _isLeapYear(year) ? 29 : 28, // February
      31, // March
      30, // April
      31, // May
      30, // June
      31, // July
      31, // August
      30, // September
      31, // October
      30, // November
      31, // December
    ];
    
    return day <= daysInMonth[month - 1];
  }
  
  /// Check if a year is a leap year
  static bool _isLeapYear(int year) {
    if (year % 4 != 0) {
      return false;
    } else if (year % 100 != 0) {
      return true;
    } else if (year % 400 != 0) {
      return false;
    } else {
      return true;
    }
  }
  
  /// Parse a complete DateTime from SMS content
  /// 
  /// Returns a DateTime object combining extracted date and time
  static DateTime parseDateTime(String content, DateTime smsTimestamp) {
    final dateStr = extractDate(content, smsTimestamp);
    final timeStr = extractTime(content, smsTimestamp);
    
    // Parse date components
    final dateParts = dateStr.split('-');
    final year = int.parse(dateParts[0]);
    final month = int.parse(dateParts[1]);
    final day = int.parse(dateParts[2]);
    
    // Parse time components
    final timeParts = timeStr.split(':');
    final hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);
    final second = int.parse(timeParts[2]);
    
    return DateTime(year, month, day, hour, minute, second);
  }
  
  /// Normalize a date string to ISO 8601 format
  /// 
  /// Accepts various date formats and returns YYYY-MM-DD
  static String? normalizeDateString(String dateStr, DateTime? referenceDate) {
    final ref = referenceDate ?? DateTime.now();
    
    if (dateStr.trim().isEmpty) {
      return null;
    }
    
    // If already in ISO 8601 format, validate and return
    if (_yyyymmddPattern.hasMatch(dateStr)) {
      final match = _yyyymmddPattern.firstMatch(dateStr)!;
      final year = int.parse(match.group(1)!);
      final month = int.parse(match.group(2)!);
      final day = int.parse(match.group(3)!);
      
      if (_isValidDate(day, month, year)) {
        return _formatDate(year, month, day);
      }
    }
    
    // Try to extract date from the string
    return extractDate(dateStr, ref);
  }
  
  /// Normalize a time string to HH:MM:SS format
  /// 
  /// Accepts various time formats and returns 24-hour format
  static String? normalizeTimeString(String timeStr, DateTime? referenceTime) {
    final ref = referenceTime ?? DateTime.now();
    
    if (timeStr.trim().isEmpty) {
      return null;
    }
    
    // Try to extract time from the string
    final extracted = extractTime(timeStr, ref);
    
    // If extraction returned the reference time, it means no time was found
    final refFormatted = _formatTimeToHHMMSS(ref);
    if (extracted == refFormatted && !timeStr.contains(':')) {
      return null;
    }
    
    return extracted;
  }
}
