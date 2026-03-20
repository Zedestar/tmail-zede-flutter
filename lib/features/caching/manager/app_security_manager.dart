import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:core/utils/app_logger.dart';
import 'package:hive_ce/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tmail_ui_user/features/caching/config/secure_storage_factory.dart';
import 'package:tmail_ui_user/features/caching/config/secure_storage_keys.dart';

class AppSecurityManager {
  static final instance = AppSecurityManager._();

  AppSecurityManager._();

  final _storage = SecureStorageFactory.create();

  Uint8List? _cachedKey;

  Future<void> init() async {
    log('AppSecurityManager::init: Start initialization');

    try {
      final storedKey = await _readStoredKey();
      final hiveExists = await _doesHiveExistSafe();

      await _handleInconsistentState(
        hiveExists: hiveExists,
        storedKey: storedKey,
      );

      await _ensureKeyExists(storedKey);

      log('AppSecurityManager::init: Initialization completed');
    } catch (e) {
      logWarning(
        'AppSecurityManager::init: Initialization failed, Exception $e',
      );
    }
  }

  Future<Uint8List?> getKey() async {
    if (_cachedKey != null) {
      log('AppSecurityManager::getKey: Returning cached key');
      return _cachedKey;
    }

    try {
      final key = await _loadKeySafe();
      _cachedKey = key;
      return key;
    } catch (e, st) {
      logError(
        'AppSecurityManager::getKey: Failed to load key',
        exception: e,
        stackTrace: st,
      );
      return null;
    }
  }

  void clearKey() {
    log('AppSecurityManager::clearKey: Clearing cached key');
    _cachedKey = null;
  }

  Future<String?> _readStoredKey() async {
    try {
      final key = await _storage.read(
        key: SecureStorageKeys.hiveEncryptionKey,
      );
      log('AppSecurityManager::_readStoredKey: Key exists: ${key != null}');
      return key;
    } catch (e) {
      logWarning(
        'AppSecurityManager::_readStoredKey: Read failed, Exception $e',
      );
      return null;
    }
  }

  Future<void> _handleInconsistentState({
    required bool hiveExists,
    required String? storedKey,
  }) async {
    if (hiveExists && storedKey == null) {
      logWarning(
        'AppSecurityManager::_handleInconsistentState: '
        'Hive exists but key missing → wiping Hive, SharePreference',
      );
      await _wipeLocalStorageSafe();
    }
  }

  Future<void> _ensureKeyExists(String? storedKey) async {
    if (storedKey != null) {
      log('AppSecurityManager::_ensureKeyExists: Key already exists');
      return;
    }

    log('AppSecurityManager::_ensureKeyExists: Generating new key');

    try {
      final newKey = Hive.generateSecureKey();

      await _storage.write(
        key: SecureStorageKeys.hiveEncryptionKey,
        value: base64UrlEncode(newKey),
      );

      log('AppSecurityManager::_ensureKeyExists: Key stored successfully');
    } catch (e, st) {
      logError(
        'AppSecurityManager::_ensureKeyExists: Failed to store key',
        exception: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<Uint8List> _loadKeySafe() async {
    final key = await _readStoredKey();

    if (key == null) {
      throw StateError('Encryption key not found');
    }

    try {
      return base64Url.decode(key);
    } catch (e, st) {
      logError(
        'AppSecurityManager::_loadKeySafe: Decode failed',
        exception: e,
        stackTrace: st,
      );
      throw StateError('Invalid encryption key format');
    }
  }

  Future<bool> _doesHiveExistSafe() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final files = Directory(dir.path).listSync();

      final exists = files.any((f) => f.path.endsWith('.hive'));

      log('AppSecurityManager::_doesHiveExistSafe: Exists = $exists');
      return exists;
    } catch (e) {
      logWarning(
        'AppSecurityManager::_doesHiveExistSafe: Check failed, Exception $e',
      );
      return false;
    }
  }

  Future<void> _wipeLocalStorageSafe() async {
    try {
      logWarning('AppSecurityManager::_wipeLocalStorageSafe: Deleting local storage data');
      await Future.wait([
        _wipeHiveSafe(),
        _wipeSharePreferenceSafe(),
      ]);
    } catch (e, st) {
      logError(
        'AppSecurityManager::_wipeLocalStorageSafe: Delete failed',
        exception: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<void> _wipeHiveSafe() async {
    try {
      logWarning('AppSecurityManager::_wipeHiveSafe: Deleting Hive data');
      await Hive.deleteFromDisk();
    } catch (e) {
      logWarning('AppSecurityManager::_wipeHiveSafe: Delete failed, Exception $e');
      rethrow;
    }
  }

  Future<void> _wipeSharePreferenceSafe() async {
    try {
      logWarning('AppSecurityManager::_wipeSharePreferenceSafe: Deleting SharePreference data');
      final sharedPreferences = await SharedPreferences.getInstance();
      await sharedPreferences.clear();
    } catch (e) {
      logWarning('AppSecurityManager::_wipeSharePreferenceSafe: Delete failed, Exception $e');
      rethrow;
    }
  }
}
