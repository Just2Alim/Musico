import 'package:flutter/services.dart';

class DeviceInfoService {
  static const _channel = MethodChannel('app.musico/device');

  Future<int?> batteryLevel() async {
    try {
      return await _channel.invokeMethod<int>('getBatteryLevel');
    } on PlatformException {
      return null;
    }
  }
}
