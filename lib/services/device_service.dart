// services/device_service.dart
import 'dart:async';
import 'dart:io';
import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';

class DeviceService {
  static final DeviceService _instance = DeviceService._internal();
  factory DeviceService() => _instance;
  DeviceService._internal();

  final Battery _battery = Battery();
  final Connectivity _connectivity = Connectivity();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  StreamSubscription<BatteryState>? _batterySubscription;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  Timer? _batteryUpdateTimer;
  Timer? _signalUpdateTimer;

  // Battery data
  int _batteryLevel = 0;
  BatteryState _batteryState = BatteryState.unknown;
  bool _isCharging = false;
  String _batteryHealth = 'unknown';

  // Connectivity data
  ConnectivityResult _connectivityResult = ConnectivityResult.none;
  String _signalStrength = 'poor';
  String _networkOperator = 'Unknown';
  String _networkType = 'unknown';
  bool _isConnected = false;
  double? _signalStrengthDbm;

  // Device info
  String _deviceModel = 'Unknown';
  String _deviceBrand = 'Unknown';
  String _osVersion = 'Unknown';

  // Getters for battery
  int get batteryLevel => _batteryLevel;
  BatteryState get batteryState => _batteryState;
  bool get isCharging => _isCharging;
  String get batteryHealth => _batteryHealth;
  String get batteryStateString => _getBatteryStateString();

  // Getters for connectivity
  ConnectivityResult get connectivityResult => _connectivityResult;
  String get signalStrength => _signalStrength;
  String get networkOperator => _networkOperator;
  String get networkType => _networkType;
  bool get isConnected => _isConnected;
  double? get signalStrengthDbm => _signalStrengthDbm;

  // Getters for device info
  String get deviceModel => _deviceModel;
  String get deviceBrand => _deviceBrand;
  String get osVersion => _osVersion;

  Future<void> initialize() async {
    print('DeviceService: Initializing...');
    
    // Initialize device info first
    await _loadDeviceInfo();
    
    // Initialize battery and connectivity
    await _updateBatteryInfo();
    await _updateConnectivityInfo();
    
    // Start listening to changes
    _startListening();
    
    // Start periodic updates for more accurate data
    _startPeriodicUpdates();
    
    print('DeviceService: Initialization complete');
    print('DeviceService: Battery: $_batteryLevel%, Signal: $_signalStrength, Device: $_deviceBrand $_deviceModel');
  }

  Future<void> _loadDeviceInfo() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        _deviceModel = androidInfo.model;
        _deviceBrand = androidInfo.brand;
        _osVersion = 'Android ${androidInfo.version.release}';
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        _deviceModel = iosInfo.model;
        _deviceBrand = 'Apple';
        _osVersion = 'iOS ${iosInfo.systemVersion}';
      }
      
      print('DeviceService: Device info loaded - $_deviceBrand $_deviceModel ($_osVersion)');
    } catch (e) {
      print('DeviceService: Error loading device info: $e');
    }
  }

  Future<void> _updateBatteryInfo() async {
    try {
      _batteryLevel = await _battery.batteryLevel;
      _batteryState = await _battery.batteryState;
      _isCharging = _batteryState == BatteryState.charging || _batteryState == BatteryState.full;
      _batteryHealth = _getBatteryHealth(_batteryLevel);
      
      print('DeviceService: Battery updated - Level: $_batteryLevel%, State: $_batteryState, Charging: $_isCharging');
    } catch (e) {
      print('DeviceService: Error updating battery info: $e');
    }
  }

  Future<void> _updateConnectivityInfo() async {
    try {
      _connectivityResult = await _connectivity.checkConnectivity();
      _isConnected = _connectivityResult != ConnectivityResult.none;
      
      // Update network type and signal strength based on connectivity
      _updateNetworkDetails(_connectivityResult);
      
      print('DeviceService: Connectivity updated - Type: $_connectivityResult, Signal: $_signalStrength, Connected: $_isConnected');
    } catch (e) {
      print('DeviceService: Error updating connectivity info: $e');
      _signalStrength = 'poor';
      _isConnected = false;
    }
  }

  void _updateNetworkDetails(ConnectivityResult result) {
    switch (result) {
      case ConnectivityResult.wifi:
        _networkType = 'WiFi';
        _signalStrength = 'strong'; // WiFi typically has good signal
        _networkOperator = 'WiFi Network';
        _signalStrengthDbm = -30.0; // Simulated good WiFi signal
        break;
        
      case ConnectivityResult.mobile:
        _networkType = 'Mobile Data';
        _signalStrength = _getMobileSignalStrength();
        _networkOperator = _getMobileOperator();
        _signalStrengthDbm = _getMobileSignalDbm();
        break;
        
      case ConnectivityResult.ethernet:
        _networkType = 'Ethernet';
        _signalStrength = 'strong';
        _networkOperator = 'Wired Network';
        _signalStrengthDbm = null;
        break;
        
      case ConnectivityResult.vpn:
        _networkType = 'VPN';
        _signalStrength = 'weak'; // VPN can be slower
        _networkOperator = 'VPN Connection';
        _signalStrengthDbm = null;
        break;
        
      case ConnectivityResult.bluetooth:
        _networkType = 'Bluetooth';
        _signalStrength = 'weak';
        _networkOperator = 'Bluetooth Network';
        _signalStrengthDbm = -70.0;
        break;
        
      case ConnectivityResult.other:
        _networkType = 'Other';
        _signalStrength = 'weak';
        _networkOperator = 'Unknown Network';
        _signalStrengthDbm = null;
        break;
        
      case ConnectivityResult.none:
      default:
        _networkType = 'No Connection';
        _signalStrength = 'poor';
        _networkOperator = 'No Network';
        _signalStrengthDbm = null;
        _isConnected = false;
        break;
    }
  }

  String _getMobileSignalStrength() {
    // Simulate signal strength based on time and some randomization
    final now = DateTime.now();
    final factor = (now.millisecond % 100) / 100.0;
    
    if (factor > 0.7) return 'strong';
    if (factor > 0.3) return 'weak';
    return 'poor';
  }

  String _getMobileOperator() {
    // In a real implementation, you would use telephony packages to get actual operator
    // For Philippines, common operators:
    final operators = ['Globe', 'Smart', 'DITO', 'Sun Cellular'];
    final index = DateTime.now().day % operators.length;
    return operators[index];
  }

  double _getMobileSignalDbm() {
    // Simulate signal strength in dBm
    // Good: -50 to -70 dBm
    // Fair: -70 to -90 dBm  
    // Poor: -90 to -110 dBm
    switch (_signalStrength) {
      case 'strong':
        return -60.0;
      case 'weak':
        return -80.0;
      default:
        return -100.0;
    }
  }

  String _getBatteryHealth(int level) {
    if (level > 80) return 'excellent';
    if (level > 60) return 'good';
    if (level > 40) return 'fair';
    if (level > 20) return 'poor';
    return 'critical';
  }

  String _getBatteryStateString() {
    switch (_batteryState) {
      case BatteryState.full:
        return 'Full';
      case BatteryState.charging:
        return 'Charging';
      case BatteryState.discharging:
        return 'Discharging';
      case BatteryState.unknown:
      default:
        return 'Unknown';
    }
  }

  void _startListening() {
    // Listen to battery state changes
    _batterySubscription = _battery.onBatteryStateChanged.listen((state) {
      _batteryState = state;
      _isCharging = state == BatteryState.charging || state == BatteryState.full;
      print('DeviceService: Battery state changed to: $state');
    });

    // Listen to connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((result) {
      _connectivityResult = result;
      _isConnected = result != ConnectivityResult.none;
      _updateNetworkDetails(result);
      print('DeviceService: Connectivity changed to: $result');
    });
  }

  void _startPeriodicUpdates() {
    // Update battery info every 30 seconds
    _batteryUpdateTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      await _updateBatteryInfo();
    });

    // Update signal strength every 15 seconds
    _signalUpdateTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      await _updateConnectivityInfo();
    });
  }

  // Get comprehensive device status
  Map<String, dynamic> getDeviceStatus() {
    return {
      'battery': {
        'level': _batteryLevel,
        'state': _batteryState.toString(),
        'isCharging': _isCharging,
        'health': _batteryHealth,
        'stateString': _getBatteryStateString(),
      },
      'connectivity': {
        'result': _connectivityResult.toString(),
        'signalStrength': _signalStrength,
        'networkOperator': _networkOperator,
        'networkType': _networkType,
        'isConnected': _isConnected,
        'signalStrengthDbm': _signalStrengthDbm,
      },
      'device': {
        'model': _deviceModel,
        'brand': _deviceBrand,
        'osVersion': _osVersion,
      },
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  // Get signal strength as bars (1-4)
  int getSignalBars() {
    switch (_signalStrength) {
      case 'strong':
        return 4;
      case 'weak':
        return 2;
      default:
        return 1;
    }
  }

  // Get signal strength as percentage
  int getSignalPercentage() {
    switch (_signalStrength) {
      case 'strong':
        return 85;
      case 'weak':
        return 45;
      default:
        return 15;
    }
  }

  // Get battery icon name for UI
  String getBatteryIcon() {
    if (_isCharging) return 'battery_charging';
    
    if (_batteryLevel > 80) return 'battery_full';
    if (_batteryLevel > 60) return 'battery_6_bar';
    if (_batteryLevel > 40) return 'battery_4_bar';
    if (_batteryLevel > 20) return 'battery_2_bar';
    return 'battery_1_bar';
  }

  // Get signal icon name for UI
  String getSignalIcon() {
    switch (_connectivityResult) {
      case ConnectivityResult.wifi:
        return 'wifi';
      case ConnectivityResult.mobile:
        return 'signal_cellular_alt';
      case ConnectivityResult.ethernet:
        return 'ethernet';
      case ConnectivityResult.bluetooth:
        return 'bluetooth';
      default:
        return 'signal_cellular_off';
    }
  }

  // Check if device has good connectivity for data transmission
  bool hasGoodConnectivity() {
    return _isConnected && (_signalStrength == 'strong' || _signalStrength == 'weak');
  }

  // Check if battery is at critical level
  bool isBatteryCritical() {
    return _batteryLevel <= 10;
  }

  // Check if battery is low
  bool isBatteryLow() {
    return _batteryLevel <= 20;
  }

  // Force refresh all device data
  Future<void> refreshDeviceStatus() async {
    print('DeviceService: Force refreshing device status...');
    await _updateBatteryInfo();
    await _updateConnectivityInfo();
    print('DeviceService: Device status refreshed');
  }

  // Get detailed status for logging/debugging
  String getDetailedStatus() {
    return '''
DeviceService Status:
  Battery: $_batteryLevel% ($_batteryState) ${_isCharging ? '[CHARGING]' : '[NOT CHARGING]'}
  Signal: $_signalStrength ($_connectivityResult) 
  Network: $_networkType via $_networkOperator
  Device: $_deviceBrand $_deviceModel ($_osVersion)
  Connected: $_isConnected
  Signal dBm: ${_signalStrengthDbm ?? 'N/A'}
  Last Update: ${DateTime.now()}
''';
  }

  void dispose() {
    print('DeviceService: Disposing...');
    _batterySubscription?.cancel();
    _connectivitySubscription?.cancel();
    _batteryUpdateTimer?.cancel();
    _signalUpdateTimer?.cancel();
  }
}

// Extension for connectivity result to get user-friendly names
extension ConnectivityResultExtension on ConnectivityResult {
  String get displayName {
    switch (this) {
      case ConnectivityResult.wifi:
        return 'WiFi';
      case ConnectivityResult.mobile:
        return 'Mobile Data';
      case ConnectivityResult.ethernet:
        return 'Ethernet';
      case ConnectivityResult.vpn:
        return 'VPN';
      case ConnectivityResult.bluetooth:
        return 'Bluetooth';
      case ConnectivityResult.other:
        return 'Other';
      case ConnectivityResult.none:
        return 'No Connection';
    }
  }
}

// Extension for battery state to get user-friendly names
extension BatteryStateExtension on BatteryState {
  String get displayName {
    switch (this) {
      case BatteryState.full:
        return 'Full';
      case BatteryState.charging:
        return 'Charging';
      case BatteryState.discharging:
        return 'Discharging';
      case BatteryState.unknown:
        return 'Unknown';
    }
  }
}