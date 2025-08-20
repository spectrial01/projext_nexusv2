import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/location_service.dart';
import '../services/api_service.dart';
import '../services/background_service.dart';
import '../services/watchdog_service.dart';
import '../utils/constants.dart';
import 'dashboard_screen.dart';
import 'location_screen.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  bool _isPopped = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text('Scan QR Code', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1E1E1E),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
          ),
        ),
        child: Stack(
          children: [
            MobileScanner(
              onDetect: (capture) {
                if (_isPopped) return;

                final List<Barcode> barcodes = capture.barcodes;
                if (barcodes.isNotEmpty) {
                  final String? code = barcodes.first.rawValue;
                  if (code != null) {
                    _isPopped = true;
                    Navigator.pop(context, code);
                  }
                }
              },
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withOpacity(0.3),
                  ],
                ),
              ),
            ),
            Center(
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF26C6DA), width: 3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Container(
                  margin: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 50,
              left: 0,
              right: 0,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Text(
                  'Position the QR code within the frame to scan',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _tokenController = TextEditingController();
  final _deploymentCodeController = TextEditingController();
  final _locationService = LocationService();
  final _watchdogService = WatchdogService();
  final _imagePicker = ImagePicker();
  final _qrScannerController = MobileScannerController();

  bool _isDeploymentCodeVisible = false;
  bool _isLoading = false;
  bool _isLocationChecking = false;
  String _appVersion = '';
  bool _hasStoredCredentials = false;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeScreen();
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _deploymentCodeController.dispose();
    _qrScannerController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _initializeScreen() async {
    await _getAppVersion();
    await _loadStoredCredentials();
    await _initializeWatchdog();
  }

  Future<void> _getAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() => _appVersion = packageInfo.version);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _appVersion = '1.0.0');
      }
    }
  }

  Future<void> _loadStoredCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedToken = prefs.getString('token');
      final storedDeploymentCode = prefs.getString('deploymentCode');

      if (storedToken != null && storedDeploymentCode != null) {
        if (mounted) {
          setState(() {
            _tokenController.text = storedToken;
            _deploymentCodeController.text = storedDeploymentCode;
            _hasStoredCredentials = true;
          });
        }
      }
    } catch (e) {
      print('LoginScreen: Error loading credentials: $e');
    }
  }

  Future<void> _initializeWatchdog() async {
    try {
      await _watchdogService.initialize();
      await _watchdogService.markAppAsAlive();
      if (await _watchdogService.wasAppDead() && mounted) {
        _showSnackBar('App monitoring was interrupted. Please login again.', Colors.orange);
      }
    } catch (e) {
      print('LoginScreen: Error initializing watchdog: $e');
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _scanQRCode(TextEditingController controller) async {
    try {
      final scannedCode = await Navigator.push<String>(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const QRScannerScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: animation.drive(
                Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
                    .chain(CurveTween(curve: Curves.easeInOut)),
              ),
              child: child,
            );
          },
        ),
      );

      if (scannedCode != null && mounted) {
        setState(() {
          controller.text = scannedCode;
        });
        _showSnackBar('QR Code scanned successfully!', Colors.green);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to scan QR code: $e', Colors.red);
      }
    }
  }

  Future<void> _uploadAndScanQRCode(TextEditingController controller) async {
    try {
      final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      final BarcodeCapture? barcodes = await _qrScannerController.analyzeImage(image.path);

      if (barcodes != null && barcodes.barcodes.isNotEmpty && mounted) {
        final String? qrCodeValue = barcodes.barcodes.first.rawValue;
        if (qrCodeValue != null) {
          setState(() {
            controller.text = qrCodeValue;
          });
          _showSnackBar('QR Code from image loaded successfully!', Colors.green);
        } else {
          throw Exception('No data found in QR code.');
        }
      } else {
        throw Exception('No QR code found in the selected image.');
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to read QR from image: $e', Colors.red);
      }
    }
  }

  Future<void> _login() async {
    if (!mounted || !_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final hasLocationAccess = await _checkLocationRequirements();
      if (!hasLocationAccess) {
        _showLocationRequirementDialog();
        setState(() => _isLoading = false);
        return;
      }

      final response = await ApiService.login(
        _tokenController.text.trim(),
        _deploymentCodeController.text.trim(),
      );

      if (!mounted) return;

      if (response.success) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', _tokenController.text.trim());
        await prefs.setString('deploymentCode', _deploymentCodeController.text.trim());
        
        await startBackgroundServiceSafely();
        _watchdogService.startWatchdog();

        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => DashboardScreen(
                token: _tokenController.text.trim(),
                deploymentCode: _deploymentCodeController.text.trim(),
              ),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
            (route) => false,
          );
        }
      } else {
        _showSnackBar(response.message, Colors.red);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Login failed: $e', Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<bool> _checkLocationRequirements() async {
    setState(() => _isLocationChecking = true);
    try {
      return await _locationService.checkLocationRequirements();
    } catch (e) {
      return false;
    } finally {
      if(mounted) {
        setState(() => _isLocationChecking = false);
      }
    }
  }

  void _showLocationRequirementDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        backgroundColor: const Color(0xFF1E1E1E),
        title: Row(
          children: [
            Icon(Icons.location_off, color: Colors.red[400], size: 24),
            const SizedBox(width: 12),
            const Text('Location Required', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This app requires location access to function properly.',
              style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text('Please ensure:', style: TextStyle(color: Colors.white70)),
            SizedBox(height: 8),
            Text('• Location permission is granted', style: TextStyle(color: Colors.white54)),
            Text('• Location services are enabled', style: TextStyle(color: Colors.white54)),
            Text('• GPS is turned on', style: TextStyle(color: Colors.white54)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LocationScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF26C6DA),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Setup Location'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1A1A2E),
                Color(0xFF16213E),
                Color(0xFF0F3460),
                Color(0xFF1A1A2E),
              ],
            ),
          ),
          child: SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        const SizedBox(height: 40),
                        _buildHeader(),
                        const SizedBox(height: 40),
                        _buildCredentialsSection(),
                        const SizedBox(height: 32),
                        _buildInputFields(),
                        const SizedBox(height: 32),
                        _buildLoginButton(),
                        const SizedBox(height: 24),
                        _buildInfoCard(),
                        const SizedBox(height: 32),
                        _buildFooter(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 360 || screenHeight < 640;
    final isVerySmallScreen = screenWidth < 320;
    
    // Adaptive sizing
    final logoSize = isVerySmallScreen ? 36.0 : isSmallScreen ? 42.0 : 48.0;
    final titleFontSize = isVerySmallScreen ? 14.0 : isSmallScreen ? 16.0 : 18.0;
    final mottoFontSize = isVerySmallScreen ? 10.0 : isSmallScreen ? 11.0 : 12.0;
    final containerPadding = isVerySmallScreen ? 16.0 : isSmallScreen ? 20.0 : 24.0;
    final logoPadding = isVerySmallScreen ? 12.0 : 16.0;
    
    return Container(
      padding: EdgeInsets.all(containerPadding),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryRed.withOpacity(0.1),
            AppColors.primaryRed.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(isVerySmallScreen ? 16 : 20),
        border: Border.all(color: AppColors.primaryRed.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryRed.withOpacity(0.2),
            blurRadius: isVerySmallScreen ? 15 : 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(logoPadding),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/pnp_logo.png',
                width: logoSize,
                height: logoSize,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  print('Error loading PNP logo: $error');
                  return Icon(
                    Icons.shield,
                    color: AppColors.primaryRed,
                    size: logoSize,
                  );
                },
              ),
            ),
          ),
          SizedBox(height: isVerySmallScreen ? 12 : 16),
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [Colors.white, Colors.white70],
            ).createShader(bounds),
            child: Text(
              AppConstants.appTitle.toUpperCase(),
              style: TextStyle(
                fontSize: titleFontSize,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
              textAlign: TextAlign.center,
              maxLines: isVerySmallScreen ? 2 : 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(height: isVerySmallScreen ? 8 : 12),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isVerySmallScreen ? 12 : 16, 
              vertical: isVerySmallScreen ? 6 : 8
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primaryGreen, AppColors.primaryGreen.withOpacity(0.8)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryGreen.withOpacity(0.3),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Text(
              AppConstants.appMotto,
              style: TextStyle(
                fontSize: mottoFontSize,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.8,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCredentialsSection() {
    return Column(
      children: [
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [AppColors.primaryRed, Colors.red[300]!],
          ).createShader(bounds),
          child: const Text(
            'Secure Access Required',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _hasStoredCredentials 
            ? 'Credentials loaded from previous session'
            : 'Enter your authentication credentials',
          style: TextStyle(
            color: _hasStoredCredentials ? Colors.green[400] : Colors.white54,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildInputFields() {
    return Column(
      children: [
        _buildTokenField(),
        const SizedBox(height: 20),
        _buildDeploymentCodeField(),
      ],
    );
  }

  Widget _buildTokenField() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: TextFormField(
        controller: _tokenController,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: 'Authentication Token',
          labelStyle: TextStyle(color: Colors.white60),
          hintText: 'Enter or scan your token',
          hintStyle: TextStyle(color: Colors.white30),
          prefixIcon: Icon(Icons.vpn_key, color: AppColors.primaryRed),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: const Icon(Icons.file_upload, color: Colors.white70, size: 20),
                  onPressed: () => _uploadAndScanQRCode(_tokenController),
                  tooltip: 'Upload QR from Gallery',
                ),
              ),
              Container(
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF26C6DA).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: const Icon(Icons.qr_code_scanner, color: Color(0xFF26C6DA), size: 20),
                  onPressed: () => _scanQRCode(_tokenController),
                  tooltip: 'Scan QR with Camera',
                ),
              ),
            ],
          ),
          filled: true,
          fillColor: Colors.white.withOpacity(0.08),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.primaryRed, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
        ),
        validator: (value) => value == null || value.isEmpty ? 'Please input your token' : null,
        maxLines: 1,
      ),
    );
  }

  Widget _buildDeploymentCodeField() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: TextFormField(
        controller: _deploymentCodeController,
        obscureText: !_isDeploymentCodeVisible,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: 'Deployment Code',
          labelStyle: TextStyle(color: Colors.white60),
          hintText: 'Enter your deployment code',
          hintStyle: TextStyle(color: Colors.white30),
          prefixIcon: Icon(Icons.badge, color: AppColors.primaryRed),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF26C6DA).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: const Icon(Icons.qr_code_scanner, color: Color(0xFF26C6DA), size: 20),
                  onPressed: () => _scanQRCode(_deploymentCodeController),
                  tooltip: 'Scan Deployment Code',
                ),
              ),
              Container(
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: Icon(
                    _isDeploymentCodeVisible ? Icons.visibility : Icons.visibility_off,
                    color: Colors.white70,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _isDeploymentCodeVisible = !_isDeploymentCodeVisible),
                ),
              ),
            ],
          ),
          filled: true,
          fillColor: Colors.white.withOpacity(0.08),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.primaryRed, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
        ),
        validator: (value) => value == null || value.isEmpty ? 'Please enter your deployment code' : null,
      ),
    );
  }

  Widget _buildLoginButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryRed.withOpacity(0.3),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: (_isLoading || _isLocationChecking) ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryRed,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: _isLoading || _isLocationChecking
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  _isLocationChecking ? 'Checking Location...' : 'Authenticating...',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            )
          : const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.security, size: 24),
                SizedBox(width: 12),
                Text(
                  'Secure Login',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
      ),
    );
  }

  Widget _buildStoredCredentialsInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green[900]!.withOpacity(0.3),
            Colors.green[800]!.withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[400]!.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green[400], size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Previous login credentials loaded automatically',
                  style: TextStyle(
                    color: Colors.green[100],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _clearStoredCredentials,
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('Clear Stored', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _useStoredCredentials,
                  icon: const Icon(Icons.login, size: 16),
                  label: const Text('Quick Login', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Add new method to clear stored credentials
  Future<void> _clearStoredCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('token');
      await prefs.remove('deploymentCode');
      await prefs.remove('qr_code');
      
      if (mounted) {
        setState(() {
          _tokenController.clear();
          _deploymentCodeController.clear();
          _hasStoredCredentials = false;
        });
        
        _showSnackBar('Stored credentials cleared', Colors.orange);
      }
    } catch (e) {
      print('LoginScreen: Error clearing credentials: $e');
      _showSnackBar('Failed to clear credentials', Colors.red);
    }
  }

  // Add new method to use stored credentials for quick login
  Future<void> _useStoredCredentials() async {
    if (_hasStoredCredentials && _tokenController.text.isNotEmpty && _deploymentCodeController.text.isNotEmpty) {
      _login(); // Use the existing login method
    } else {
      _showSnackBar('No valid stored credentials found', Colors.orange);
    }
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue[900]!.withOpacity(0.3),
            Colors.blue[800]!.withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[400]!.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.lightBlueAccent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Contact your administrator if you don\'t have a token or deployment code',
              style: TextStyle(
                color: Colors.lightBlueAccent[100],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.copyright, color: Colors.white54, size: 16),
              const SizedBox(width: 8),
              const Text(
                '2025 Philippine National Police',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryRed.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primaryRed.withOpacity(0.3)),
            ),
            child: const Text(
              AppConstants.developerCredit,
              style: TextStyle(
                color: Colors.red,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'v$_appVersion',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }
}