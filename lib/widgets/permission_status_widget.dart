import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionStatusWidget extends StatelessWidget {
  final PermissionStatus status;
  final String title;
  final String description;
  final VoidCallback? onRequest;

  const PermissionStatusWidget({
    super.key,
    required this.status,
    required this.title,
    required this.description,
    this.onRequest,
  });

  Color get statusColor {
    switch (status) {
      case PermissionStatus.granted:
        return Colors.green;
      case PermissionStatus.denied:
        return Colors.orange;
      case PermissionStatus.permanentlyDenied:
        return Colors.red;
      case PermissionStatus.restricted:
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData get statusIcon {
    switch (status) {
      case PermissionStatus.granted:
        return Icons.check_circle;
      case PermissionStatus.denied:
        return Icons.warning;
      case PermissionStatus.permanentlyDenied:
        return Icons.block;
      case PermissionStatus.restricted:
        return Icons.lock;
      default:
        return Icons.help;
    }
  }

  String get statusText {
    switch (status) {
      case PermissionStatus.granted:
        return 'GRANTED';
      case PermissionStatus.denied:
        return 'DENIED';
      case PermissionStatus.permanentlyDenied:
        return 'PERMANENTLY DENIED';
      case PermissionStatus.restricted:
        return 'RESTRICTED';
      default:
        return 'UNKNOWN';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (status != PermissionStatus.granted && onRequest != null)
                  ElevatedButton(
                    onPressed: onRequest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.tealAccent,
                      foregroundColor: Colors.black,
                    ),
                    child: const Text('Grant'),
                  ),
              ],
            ),
            if (status != PermissionStatus.granted) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[900]?.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        description,
                        style: TextStyle(
                          color: Colors.orange[100],
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}