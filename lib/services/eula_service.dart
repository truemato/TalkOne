import 'package:shared_preferences/shared_preferences.dart';

class EulaService {
  static const String _eulaAcceptedKey = 'eula_accepted_timestamp';
  
  /// Check if EULA needs to be shown (after GMT 0:00)
  static Future<bool> needsToShowEula() async {
    final prefs = await SharedPreferences.getInstance();
    final acceptedTimestamp = prefs.getInt(_eulaAcceptedKey);
    
    if (acceptedTimestamp == null) {
      // Never accepted before
      return true;
    }
    
    final acceptedDate = DateTime.fromMillisecondsSinceEpoch(acceptedTimestamp, isUtc: true);
    final now = DateTime.now().toUtc();
    
    // Get today's GMT 0:00
    final todayMidnightGmt = DateTime.utc(now.year, now.month, now.day);
    
    // If accepted before today's GMT 0:00, need to show again
    return acceptedDate.isBefore(todayMidnightGmt);
  }
  
  /// Save EULA acceptance timestamp
  static Future<void> saveEulaAcceptance() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_eulaAcceptedKey, DateTime.now().toUtc().millisecondsSinceEpoch);
  }
  
  /// Clear EULA acceptance (for testing)
  static Future<void> clearEulaAcceptance() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_eulaAcceptedKey);
  }
  
  /// Get last acceptance date for debugging
  static Future<DateTime?> getLastAcceptanceDate() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(_eulaAcceptedKey);
    if (timestamp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true);
  }
}