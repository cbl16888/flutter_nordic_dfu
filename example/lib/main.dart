import 'dart:async';

import 'package:bluetooth_helper/bluetooth_device.dart';
import 'package:flutter/material.dart';
import 'package:flutter_nordic_dfu/flutter_nordic_dfu.dart';
import 'package:bluetooth_helper/bluetooth_helper.dart';

import 'debug_log.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  BluetoothDevice _device;
  String _commandReadNotifyCharacter;
  String _commandReadWriteCharacter;
  bool _isConnected = false;
  bool _isOta = false;
  var deviceName = "ZLY_2012080145693";
  static const String serviceId = "00001523-39cb-4c61-a082-38bfd3717074";
  static const String commandReadNotifyCharactersId =
      "00001526-39cb-4c61-a082-38bfd3717074";
  static const String commandReadWriteCharactersId =
      "00001525-39cb-4c61-a082-38bfd3717074";

  @override
  void initState() {
    super.initState();
  }

  void startScan() async {
    if (_isOta) {
      DebugLog.logDebug("正在ota升级....");
      return;
    }
    if (_isConnected) {
      DebugLog.logDebug("设备已连接");
      return;
    }
    await _device?.disconnect();
    DebugLog.logDebug("开始搜索设备...");
    await BluetoothHelper.me
        .scan(deviceName: deviceName, timeout: 10, serviceId: serviceId)
        .then((_scanResult) {
      for (var _item in _scanResult) {
        if (deviceName == _item.deviceName) {
          _device = _item;
          break;
        }
      }
      if (null != _device) {
        return _connect();
      } else {
        DebugLog.logDebug("没有找到设备");
      }
    }).catchError((onError) {
      DebugLog.logDebug("查找设备失败: $onError");
    });
  }

  void _otaDevice() async {
    if (!_isConnected) {
      _isOta = false;
      DebugLog.logDebug("蓝牙设备还未连接");
      return;
    }
    var address = _device.deviceId;
    _isOta = true;
    try {
      var s = await FlutterNordicDfu.startDfu(
        address,
        'assets/file.zip',
        fileInAsset: true,
        progressListener:
            DefaultDfuProgressListenerAdapter(onProgressChangedHandle: (
          deviceAddress,
          percent,
          speed,
          avgSpeed,
          currentPart,
          partsTotal,
        ) {
          DebugLog.logDebug('deviceAddress: $deviceAddress, percent: $percent');
        }),
      );
      _isOta = false;
      DebugLog.logDebug(s);
    } catch (e) {
      _isOta = false;
      DebugLog.logDebug(e.toString());
    }
  }

  _connect({int timeout = 5}) async {
    DebugLog.logDebug("修改蓝牙连接状态为: 连接中");
    try {
      bool isSuccess = await _device.connect(timeout).then((value) {
        if (value) {
          DebugLog.logDebug("连接设备成功");
          _device.eventCallback = (BluetoothEvent event) {
            if (event is BluetoothEventNotifyData) {
              return;
            } else if (event is BluetoothEventDeviceStateChange) {
              if (BluetoothEventDeviceStateChange.STATE_DISCONNECTED ==
                  event.state) {
                _disconnectDevice();
                return;
              }
            } else if (event is BluetoothEventStateChange) {
              if (BluetoothEventStateChange.STATE_OFF == event.state) {
                _disconnectDevice();
                return;
              }
            }
          };
          return _discoverServices();
        } else {
          DebugLog.logDebug("连接设备失败: 超时");
        }
      }).catchError((onError) {
        DebugLog.logDebug("连接设备失败: $onError");
      });
      return isSuccess;
    } catch (error) {
      DebugLog.logDebug("连接设备失败: $error");
    }
  }

  _discoverServices() async {
    await _device.discoverCharacteristics().then((characteristics) async {
      for (String _characteristic in characteristics) {
        if (_characteristic.toLowerCase() == commandReadNotifyCharactersId) {
          _commandReadNotifyCharacter = _characteristic;
        } else if (_characteristic.toLowerCase() ==
            commandReadWriteCharactersId) {
          _commandReadWriteCharacter = _characteristic;
        }
      }
      if (null == _commandReadNotifyCharacter ||
          null == _commandReadWriteCharacter) {
        DebugLog.logDebug("服务发现失败: 未知原因");
        await _disconnectDevice();
      } else {
        setState(() {
          _isConnected = true;
        });
        DebugLog.logDebug("服务发现成功");
      }
    }).catchError((onError) async {
      DebugLog.logDebug("服务发现失败: $onError");
      await _disconnectDevice();
    });
  }

  _disconnectDevice() async {
    if (_isOta) {
      DebugLog.logDebug("正在ota升级....");
      return;
    }
    await _device?.disconnect();
    _device?.eventCallback = null;
    setState(() {
      _isConnected = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Nordic Dfu'),
          centerTitle: true,
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Center(
                child: Text(deviceName),
              ),
            ),
            Center(
              child: Text('${_isConnected ? "已连接" : "未连接"}'),
            ),
            RaisedButton(child: Text('连接蓝牙'), onPressed: startScan),
            RaisedButton(child: Text('断开蓝牙'), onPressed: _disconnectDevice),
            RaisedButton(child: Text('OTA升级'), onPressed: _otaDevice),
          ],
        ),
      ),
    );
  }
}

class ProgressListenerListener extends DfuProgressListenerAdapter {
  @override
  void onProgressChanged(String deviceAddress, int percent, double speed,
      double avgSpeed, int currentPart, int partsTotal) {
    super.onProgressChanged(
        deviceAddress, percent, speed, avgSpeed, currentPart, partsTotal);
    print('deviceAddress: $deviceAddress, percent: $percent');
  }
}
