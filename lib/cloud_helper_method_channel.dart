import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// An implementation of [CloudHelperPlatform] that uses method channels.
class CloudHelper {
  @visibleForTesting
  final methodChannel = const MethodChannel('cloud_helper');

  Future<void> initial(String containerId) async {
    await methodChannel.invokeMethod('initialize', {'containerId': containerId});
  }

  Future<void> uploadData({
    required String name,
    required String phrase,
    required String publicKey,
  }) async {
    await methodChannel.invokeMethod('upload', {
      name,
      phrase,
      publicKey,
    });
  }

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
