import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/geocode.dart' as geo;
import '../services/location_service.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  /// 0 = Send SOS Alert, 1 = Share Location
  int _selectedAction = 0;

  /// True while location is being fetched.
  bool _isBusy = false;

  // SharedPreferences key (must match profile_screen.dart)
  static const _keyEmergencyPhone = 'profile_emergency_phone';

  // ---- snackbar helper ----
  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ));
  }

  // ========================================================================
  // EMERGENCY PHONE — read from SharedPreferences
  // ========================================================================
  Future<String?> _getEmergencyPhone() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString(_keyEmergencyPhone)?.trim();
    if (phone == null || phone.isEmpty) return null;
    return phone;
  }

  // ========================================================================
  // MESSAGE BUILDER
  // ========================================================================
  String _buildMessage(double lat, double lon, String code) {
    final mapsUrl = 'https://maps.google.com/?q=$lat,$lon';

    if (_selectedAction == 0) {
      return 'SOS EMERGENCY 🚨\n\n'
          'I need help immediately.\n\n'
          'Latitude: $lat\n'
          'Longitude: $lon\n'
          'HerCodeX: $code\n\n'
          'Open in Google Maps:\n'
          '$mapsUrl';
    } else {
      return '📍 Location Shared via HerCodeX\n\n'
          'Sharing my location for safety.\n\n'
          'Latitude: $lat\n'
          'Longitude: $lon\n'
          'HerCodeX: $code\n\n'
          'Open in Google Maps:\n'
          '$mapsUrl';
    }
  }

  // ========================================================================
  // CORE: fetch location + phone, then run the action
  // ========================================================================
  Future<void> _executeAction(_LaunchMode mode) async {
    if (_isBusy) return;
    setState(() => _isBusy = true);

    try {
      // ---- Check emergency contact ----
      final phone = await _getEmergencyPhone();
      if (phone == null) {
        _showSnack('Please set emergency contact in Profile.');
        return;
      }

      // ---- Fetch location (on-demand, via centralized service) ----
      final position = await LocationService.getCurrentLocation();
      if (position == null) {
        _showSnack('Location permission required.');
        return;
      }

      final lat = position.latitude;
      final lon = position.longitude;
      final code = geo.latlonToCode(lat, lon);
      final message = _buildMessage(lat, lon, code);

      debugPrint('SOS action=$_selectedAction mode=$mode');
      debugPrint('  Phone: $phone');
      debugPrint('  Code:  $code');
      debugPrint('  Lat:   $lat  Lon: $lon');

      // ---- Launch ----
      switch (mode) {
        case _LaunchMode.sms:
          await _launchSms(phone, message);
          break;
        case _LaunchMode.whatsapp:
          await _launchWhatsApp(phone, message);
          break;
        case _LaunchMode.call:
          await _launchCall(phone);
          break;
      }
    } catch (e) {
      debugPrint('SOS error: $e');
      _showSnack('Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  // ========================================================================
  // LAUNCHERS
  // ========================================================================
  Future<void> _launchSms(String phone, String message) async {
    final uri = Uri(
      scheme: 'sms',
      path: '+91$phone',
      queryParameters: {'body': message},
    );
    if (!await launchUrl(uri)) {
      _showSnack('Could not open SMS app.');
    }
  }

  Future<void> _launchWhatsApp(String phone, String message) async {
    final encoded = Uri.encodeComponent(message);
    final uri = Uri.parse('https://wa.me/91$phone?text=$encoded');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showSnack('Could not open WhatsApp.');
    }
  }

  Future<void> _launchCall(String phone) async {
    final uri = Uri(scheme: 'tel', path: '+91$phone');
    if (!await launchUrl(uri)) {
      _showSnack('Could not open dialer.');
    }
  }

  // ========================================================================
  // BUILD
  // ========================================================================
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SOS'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ============================================================
              // HEADER
              // ============================================================
              Text(
                'Choose an Action',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Select what you need, then choose how to send it.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 20),

              // ============================================================
              // ACTION CARD 1 — Send SOS Alert
              // ============================================================
              _ActionCard(
                icon: Icons.sos,
                iconColor: Colors.red,
                title: 'Send SOS Alert',
                description:
                    'Emergency alert with location and HerCodeX code.',
                selected: _selectedAction == 0,
                onTap: () => setState(() => _selectedAction = 0),
              ),

              const SizedBox(height: 12),

              // ============================================================
              // ACTION CARD 2 — Share Location
              // ============================================================
              _ActionCard(
                icon: Icons.share_location,
                iconColor: Colors.blue,
                title: 'Share Location',
                description: 'Share your live location for safety.',
                selected: _selectedAction == 1,
                onTap: () => setState(() => _selectedAction = 1),
              ),

              const SizedBox(height: 28),

              // ============================================================
              // COMMUNICATION OPTIONS
              // ============================================================
              Text(
                'Send Via',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),

              // ---- SMS ----
              _CommunicationButton(
                icon: Icons.sms_outlined,
                label: 'Send via SMS',
                color: const Color(0xFF81C784),
                busy: _isBusy,
                onPressed: () => _executeAction(_LaunchMode.sms),
              ),
              const SizedBox(height: 10),

              // ---- WhatsApp ----
              _CommunicationButton(
                icon: Icons.chat_outlined,
                label: 'Send via WhatsApp',
                color: const Color(0xFF25D366),
                busy: _isBusy,
                onPressed: () => _executeAction(_LaunchMode.whatsapp),
              ),
              const SizedBox(height: 10),

              // ---- Call ----
              _CommunicationButton(
                icon: Icons.phone_in_talk_outlined,
                label: 'Call Emergency Contact',
                color: Colors.red.shade400,
                busy: _isBusy,
                onPressed: () => _executeAction(_LaunchMode.call),
              ),

              const SizedBox(height: 28),

              // ============================================================
              // SAFETY TIP
              // ============================================================
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lightbulb_outline,
                        color: Colors.amber.shade700, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Tip: Set up your emergency contact in the '
                        'Profile tab before using SOS.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.amber.shade900,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// INTERNAL ENUM
// ===========================================================================
enum _LaunchMode { sms, whatsapp, call }

// ===========================================================================
// REUSABLE WIDGETS (private to this file)
// ===========================================================================

/// Selectable action card with icon, title, and description.
class _ActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? iconColor : Colors.grey.shade300;
    final bgColor =
        selected ? iconColor.withValues(alpha: 0.07) : Colors.white;

    return Material(
      elevation: selected ? 2 : 0,
      borderRadius: BorderRadius.circular(12),
      color: bgColor,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: selected ? 2 : 1),
          ),
          child: Row(
            children: [
              // Icon circle
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),

              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              // Selection indicator
              if (selected)
                Icon(Icons.check_circle, color: iconColor, size: 24)
              else
                Icon(Icons.radio_button_unchecked,
                    color: Colors.grey.shade400, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-width communication button with icon and label.
class _CommunicationButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool busy;
  final VoidCallback onPressed;

  const _CommunicationButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.busy,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: busy ? null : onPressed,
        icon: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : Icon(icon, size: 20),
        label: Text(busy ? 'Please wait…' : label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
