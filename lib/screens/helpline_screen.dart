import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

// HELPLINE MODEL

class Helpline {
  final String title;
  final String subtitle;
  final String number;
  final String website;
  final IconData icon;
  final Color color;

  const Helpline({
    required this.title,
    required this.subtitle,
    required this.number,
    required this.website,
    required this.icon,
    required this.color,
  });
}

// HARDCODED HELPLINE DATA

const List<Helpline> _helplines = [
  Helpline(
    title: 'Women Helpline',
    subtitle: 'National Commission for Women',
    number: '181',
    website: 'http://www.ncw.nic.in',
    icon: Icons.female,
    color: Color(0xFFE91E63),
  ),
  Helpline(
    title: 'Police',
    subtitle: 'Emergency Police Assistance',
    number: '100',
    website: 'https://www.police.gov.in',
    icon: Icons.local_police,
    color: Color(0xFF1565C0),
  ),
  Helpline(
    title: 'Child Helpline',
    subtitle: 'Child Welfare & Protection',
    number: '1098',
    website: 'https://www.childlineindia.org',
    icon: Icons.child_care,
    color: Color(0xFFFF9800),
  ),
  Helpline(
    title: 'Cyber Crime',
    subtitle: 'Report Cyber Crimes Online',
    number: '1930',
    website: 'https://cybercrime.gov.in',
    icon: Icons.security,
    color: Color(0xFF7B1FA2),
  ),
  Helpline(
    title: 'Senior Citizen',
    subtitle: 'Elder Abuse & Assistance',
    number: '14567',
    website: 'https://elderline.in',
    icon: Icons.elderly,
    color: Color(0xFF00897B),
  ),
];

// HELPLINE SCREEN

class HelplineScreen extends StatefulWidget {
  const HelplineScreen({super.key});

  @override
  State<HelplineScreen> createState() => _HelplineScreenState();
}

class _HelplineScreenState extends State<HelplineScreen> {
  static const _prefKey = 'helpline_primary_number';

  String? _selectedPrimary;

  // LIFECYCLE
  @override
  void initState() {
    super.initState();
    _loadPrimary();
  }

  Future<void> _loadPrimary() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    if (saved != null && mounted) {
      setState(() => _selectedPrimary = saved);
    }
  }

  Future<void> _savePrimary(String number) async {
    setState(() => _selectedPrimary = number);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, number);
  }

  // --------------------------------------------------------------------------
  // LAUNCHERS
  // --------------------------------------------------------------------------
  Future<void> _launchCall(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    if (!await launchUrl(uri)) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(
            content: Text('Could not open dialer.'),
            behavior: SnackBarBehavior.floating,
          ));
      }
    }
  }

  Future<void> _launchWebsite(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(
            content: Text('Could not open website.'),
            behavior: SnackBarBehavior.floating,
          ));
      }
    }
  }

  // BUILD

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF81C784),
        foregroundColor: Colors.white,
        title: const Text('Helpline Numbers'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          // ---- Section header ----
          const Text(
            'Emergency Helplines',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap the radio button to set a primary helpline for SOS alerts.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),

          // ---- Helpline cards ----
          for (final helpline in _helplines) ...[
            _HelplineCard(
              helpline: helpline,
              isSelected: _selectedPrimary == helpline.number,
              onSelect: () => _savePrimary(helpline.number),
              onCall: () => _launchCall(helpline.number),
              onWebsite: () => _launchWebsite(helpline.website),
            ),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

// HELPLINE CARD (private widget)

class _HelplineCard extends StatelessWidget {
  final Helpline helpline;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback onCall;
  final VoidCallback onWebsite;

  const _HelplineCard({
    required this.helpline,
    required this.isSelected,
    required this.onSelect,
    required this.onCall,
    required this.onWebsite,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected
              ? helpline.color.withValues(alpha: 0.5)
              : Colors.grey.shade300,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            //TOP ROW avatar + texts + radio 
            Row(
              children: [
                // Circle icon avatar
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: helpline.color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(helpline.icon, color: helpline.color, size: 26),
                ),
                const SizedBox(width: 14),

                // Title + subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        helpline.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        helpline.subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),

                // Radio button
                Radio<String>(
                  value: helpline.number,
                  groupValue: isSelected ? helpline.number : null,
                  activeColor: helpline.color,
                  onChanged: (_) => onSelect(),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // BOTTOM ROW: Call + Website buttons 
            Row(
              children: [
                // Call button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onCall,
                    icon: const Icon(Icons.call, size: 18),
                    label: Text('Call ${helpline.number}'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: helpline.color,
                      side: BorderSide(color: helpline.color.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Website button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onWebsite,
                    icon: const Icon(Icons.language, size: 18),
                    label: const Text('Website'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey.shade700,
                      side: BorderSide(color: Colors.grey.shade400),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}