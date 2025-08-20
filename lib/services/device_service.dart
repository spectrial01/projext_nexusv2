import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class DeviceService {
  static final DeviceService _instance = DeviceService._internal();
  factory DeviceService() => _instance;
  DeviceService._internal();

  final Battery _battery = Battery();
  final Connectivity _connectivity = Connectivity();

  StreamSubscription<BatteryState>? _batterySubscription;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  int _batteryLevel = 0;
  BatteryState _batteryState = BatteryState.unknown;
  ConnectivityResult _connectivityResult = ConnectivityResult.none;
  String _signalStrength = 'poor';

  // Getters
  int get batteryLevel => _batteryLevel;
  BatteryState get batteryState => _batteryState;
  ConnectivityResult get connectivityResult => _connectivityResult;
  String get signalStrength => _signalStrength;

  Future<void> initialize() async {
    await _updateBatteryInfo();
    await _updateConnectivityInfo();
    _startListening();
  }

  Future<void> _updateBatteryInfo() async {
    try {
      _batteryLevel = await _battery.batteryLevel;
      _batteryState = await _battery.batteryState;
    } catch (e) {
      print('Error updating battery info: $e');
    }
  }

  Future<void> _updateConnectivityInfo() async {
    try {
      _connectivityResult = await _connectivity.checkConnectivity();
      _signalStrength = _getSignalStrengthFromConnectivity(_connectivityResult);
    } catch (e) {
      print('Error updating connectivity info: $e');
      _signalStrength = 'poor';
    }
  }

  String _getSignalStrengthFromConnectivity(ConnectivityResult result) {
    switch (result) {
      case ConnectivityResult.wifi:
      case ConnectivityResult.ethernet:
        return 'strong';
      case ConnectivityResult.mobile:
      case ConnectivityResult.vpn:
      case ConnectivityResult.other:
        return 'weak';
      case ConnectivityResult.bluetooth:
      case ConnectivityResult.none:
      default:
        return 'poor';
    }
  }

  void _startListening() {
    _batterySubscription = _battery.onBatteryStateChanged.listen((state) {
      _batteryState = state;
    });

    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((result) {
      _connectivityResult = result;
      _signalStrength = _getSignalStrengthFromConnectivity(result);
    });
  }

  void dispose() {
    _batterySubscription?.cancel();
    _connectivitySubscription?.cancel();
  }
}