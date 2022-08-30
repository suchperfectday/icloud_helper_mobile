import 'dart:convert';

import 'package:flutter/services.dart';

/// An implementation of [CloudHelperPlatform] that uses method channels.
class CloudHelper {
  CloudHelper._();

  static Future<CloudHelper> create(String containerId) async {
    final instance = CloudHelper._();
    await instance._initialize(containerId);

    return instance;
  }

  final _methodChannel = const MethodChannel('cloud_helper');

  Future<void> _initialize(String containerId) async {
    await _methodChannel.invokeMethod(
      'initialize',
      {
        'containerId': containerId,
      },
    );
  }

  Future<void> addRecord({
    required String id,
    required String type,
    required dynamic data,
  }) async {
    await _methodChannel.invokeMethod(
      'addRecord',
      {
        'id': id,
        'type': type,
        'data': jsonEncode(data),
      },
    );
  }

  Future<List<dynamic>?> getAllRecords({
    required String type,
  }) async {
    final data = await _methodChannel.invokeMethod(
      'getAllRecords',
      {
        'type': type,
      },
    ) as List<dynamic>?;
    return data?.map((e) => jsonDecode(e)).toList();
  }

  Future<void> deleteRecord({
    required String id,
  }) async {
    await _methodChannel.invokeMethod(
      'deleteRecord',
      {
        'id': id,
      },
    );
  }
}
