import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  static const String _darkModeKey = "isDarkMode";
  static const bool _darkModeDefault = true;

  static const String _showWebmWarningKey = "showWEBMWarning";
  static const bool _showWebmWarningDefault = true;

  static const String _showRealContentKey = "showRealContent";
  static const bool _showRealContentDefault = false;

  static const String _e621PostLimitKey = "e621PostLimit";
  static const int _e621PostLimitDefault = 25;

  static const String _r34PostLimitKey = "r34PostLimit";
  static const int _r34PostLimitDefault = 20;

  static const String _danbooruPostLimitKey = "danbooruPostLimit";
  static const int _danbooruPostLimitDefault = 20;

  // NEW: Rule34 Auth Keys
  static const String _r34UserIdKey = "r34UserId";
  static const String _r34ApiKeyKey = "r34ApiKey";

  static const String _DanbooruUserIdKey = "danbooruUserID";
  static const String _DanbooruApiKeyKey = "danbooruApiKey";

  static const String _showAIContentKey = "showAIContent";
  static const bool _showAIContentDefault = false;

  static const String _debugModeKey = "isDebugMode";
  static const bool _debugModeDefault = false;

  static const String _deviceTypeKey = "knownDevices";
  static const String _deviceTypeDefault = "unknown";

  // State properties
  bool isDarkModeEnabled = _darkModeDefault;
  bool isShowWebmWarningEnabled = _showWebmWarningDefault;
  bool isRealContentShown = _showRealContentDefault;
  int e621PostAmount = _e621PostLimitDefault;
  int r34PostAmount = _r34PostLimitDefault;
  int danbooruPostAmount = _danbooruPostLimitDefault;
  bool showAIContent = _showAIContentDefault;
  bool isdebugMode = _debugModeDefault;
  String deviceType = _deviceTypeDefault;
  
  // NEW: Rule34 Auth State
  String r34UserId = '';
  String r34ApiKey = '';

  String danbooruUserID = '';
  String danbooruApiKey = '';

  // Added for initial load check (from previous suggestion)
  bool _isInitialLoadComplete = false;
  bool get isInitialLoadComplete => _isInitialLoadComplete; 

  late SharedPreferences _prefs;

  Future<void> loadSettings() async {
    _prefs = await SharedPreferences.getInstance();

    isDarkModeEnabled = _prefs.getBool(_darkModeKey) ?? _darkModeDefault;
    isShowWebmWarningEnabled = _prefs.getBool(_showWebmWarningKey) ?? _showWebmWarningDefault;
    isRealContentShown = _prefs.getBool(_showRealContentKey) ?? _showRealContentDefault;

    e621PostAmount = _prefs.getInt(_e621PostLimitKey) ?? _e621PostLimitDefault;
    r34PostAmount = _prefs.getInt(_r34PostLimitKey) ?? _r34PostLimitDefault;
    danbooruPostAmount = _prefs.getInt(_danbooruPostLimitKey) ?? _danbooruPostLimitDefault;
    
    // NEW: Load Rule34 Auth
    r34UserId = _prefs.getString(_r34UserIdKey) ?? '';
    r34ApiKey = _prefs.getString(_r34ApiKeyKey) ?? '';

    danbooruUserID = _prefs.getString(_DanbooruUserIdKey) ?? '';
    danbooruApiKey = _prefs.getString(_DanbooruApiKeyKey) ?? '';

    deviceType = _prefs.getString(_deviceTypeKey) ?? _deviceTypeDefault;
    
    _isInitialLoadComplete = true; 
    notifyListeners();
  }

  void setDarkMode(bool isEnabled) {
    isDarkModeEnabled = isEnabled;
    _prefs.setBool(_darkModeKey, isEnabled);
    notifyListeners();
  }

  void setShowWebmWarn(bool isEnabled) {
    isShowWebmWarningEnabled = isEnabled;
    _prefs.setBool(_showWebmWarningKey, isEnabled);
    notifyListeners();
  }
  
  void setShowRealContent(bool isEnabled) {
    isRealContentShown = isEnabled;
    _prefs.setBool(_showRealContentKey, isEnabled);
    notifyListeners();
  }
  
  void setE621PostLimit(int amount) {
    if (amount > 0) {
      e621PostAmount = amount;
      _prefs.setInt(_e621PostLimitKey, amount);
      notifyListeners();
    }
  }

  void setR34PostLimit(int amount) {
    if (amount > 0) {
      r34PostAmount = amount;
      _prefs.setInt(_r34PostLimitKey, amount);
      notifyListeners();
    }
  }

  void setDanbooruPostLimit(int amount) {
    if (amount > 0) {
      danbooruPostAmount = amount;
      _prefs.setInt(_danbooruPostLimitKey, amount);
      notifyListeners();
    }
  }

  // NEW: Rule34 Auth Setters
  void setR34UserId(String id) {
    r34UserId = id.trim();
    _prefs.setString(_r34UserIdKey, r34UserId);
    notifyListeners();
  }

  void setR34ApiKey(String key) {
    r34ApiKey = key.trim();
    _prefs.setString(_r34ApiKeyKey, r34ApiKey);
    notifyListeners();
  }

  void setDanbooruUserId(String id) {
    danbooruUserID = id.trim();
    _prefs.setString(_DanbooruUserIdKey, danbooruUserID);
    notifyListeners();
  }

  void setDanbooruApiKey(String key) {
    danbooruApiKey = key.trim();
    _prefs.setString(_DanbooruApiKeyKey, danbooruApiKey);
  }

  void setShowAIContent(bool isEnabled) {
    showAIContent = isEnabled;
    _prefs.setBool(_showAIContentKey, isEnabled);
    notifyListeners();
  }

  void setDebugMode(bool isEnabled){
    isdebugMode = isEnabled;
    _prefs.setBool(_debugModeKey, isEnabled);
    notifyListeners();
  }

  void setDeviceType(String type) {
    deviceType = type;
    _prefs.setString(_deviceTypeKey, type);
    notifyListeners();
  }

}