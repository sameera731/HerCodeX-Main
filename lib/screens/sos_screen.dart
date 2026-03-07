import 'package:flutter/material.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  /// 0 = Send SOS Alert, 1 = Share Location
  int _selectedAction = 0;

  // ========================================================================
  // PLACEHOLDER CALLBACKS — no real logic yet
  // ========================================================================
  void _onSendSms() {
    debugPrint('SOS SMS pressed (action=$_selectedAction)');
  }

  void _onSendWhatsApp() {
    debugPrint('SOS WhatsApp pressed (action=$_selectedAction)');
  }

  void _onCallEmergency() {
    debugPrint('SOS Call Emergency pressed');
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
                onPressed: _onSendSms,
              ),
              const SizedBox(height: 10),

              // ---- WhatsApp ----
              _CommunicationButton(
                icon: Icons.chat_outlined,
                label: 'Send via WhatsApp',
                color: const Color(0xFF25D366),
                onPressed: _onSendWhatsApp,
              ),
              const SizedBox(height: 10),

              // ---- Call ----
              _CommunicationButton(
                icon: Icons.phone_in_talk_outlined,
                label: 'Call Emergency Contact',
                color: Colors.red.shade400,
                onPressed: _onCallEmergency,
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
  final VoidCallback onPressed;

  const _CommunicationButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label),
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
