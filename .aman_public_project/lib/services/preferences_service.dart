import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const _favoritesKey = 'favorites';
  static const _recentKey = 'recent';
  static const _historyEnabledKey = 'history_enabled';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<Set<String>> favorites() async {
    return ((await _prefs).getStringList(_favoritesKey) ?? const []).toSet();
  }

  Future<void> toggleFavorite(String id) async {
    final prefs = await _prefs;
    final values = (prefs.getStringList(_favoritesKey) ?? const []).toSet();
    if (!values.add(id)) values.remove(id);
    await prefs.setStringList(_favoritesKey, values.toList());
  }

  Future<bool> isFavorite(String id) async {
    return (await favorites()).contains(id);
  }

  Future<bool> historyEnabled() async {
    return (await _prefs).getBool(_historyEnabledKey) ?? true;
  }

  Future<void> setHistoryEnabled(bool value) async {
    await (await _prefs).setBool(_historyEnabledKey, value);
  }

  Future<List<String>> recent() async {
    return (await _prefs).getStringList(_recentKey) ?? const [];
  }

  Future<void> markRecent(String id) async {
    if (!await historyEnabled()) return;
    final prefs = await _prefs;
    final list = (prefs.getStringList(_recentKey) ?? <String>[]).toList();
    list.remove(id);
    list.insert(0, id);
    if (list.length > 80) list.removeRange(80, list.length);
    await prefs.setStringList(_recentKey, list);
  }

  Future<void> clearRecent() async {
    await (await _prefs).remove(_recentKey);
  }
}
