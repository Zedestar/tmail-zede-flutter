import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:tmail_ui_user/main/utils/app_config.dart';

class SecureStorageFactory {
  const SecureStorageFactory._();

  static FlutterSecureStorage create() {
    return const FlutterSecureStorage(
      iOptions: IOSOptions(
        groupId: AppConfig.iOSKeychainSharingGroupId,
        accountName: AppConfig.iOSKeychainSharingService,
        accessibility: KeychainAccessibility.first_unlock_this_device,
      ),
    );
  }
}
