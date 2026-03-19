import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_translator/models/translation_state.dart';

class HistoryService {
  static const String _historyKey = 'translation_history_v1';

  Future<void> saveHistory(List<TranslationEntry> history) async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedHistory = jsonEncode(
      history.map((e) => e.toJson()).toList(),
    );
    await prefs.setString(_historyKey, encodedHistory);
  }

  Future<List<TranslationEntry>> loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? encodedHistory = prefs.getString(_historyKey);

      if (encodedHistory == null) {
        return [];
      }

      final List<dynamic> decodedList = jsonDecode(encodedHistory);
      return decodedList
          .map(
            (item) => TranslationEntry.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      print('Error loading history: $e');
      return [];
    }
  }

  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }
}
