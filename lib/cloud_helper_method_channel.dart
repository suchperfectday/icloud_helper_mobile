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
    try {
      await _methodChannel.invokeMethod(
        'initialize',
        {
          'containerId': containerId,
        },
      );
    } catch (err) {}
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

  Future<void> editRecord({
    required String id,
    required String type,
    required dynamic data,
  }) async {
    final result = await _methodChannel.invokeMethod(
      'editRecord',
      {
        'id': id,
        'data': jsonEncode(data),
      },
    );
    print(result);
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
