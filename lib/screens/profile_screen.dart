import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final _userNameController = TextEditingController();
  final _userPhoneController = TextEditingController();
  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();

  bool _isLoading = true;

  // SharedPreferences keys
  static const _keyUserName = 'profile_user_name';
  static const _keyUserPhone = 'profile_user_phone';
  static const _keyEmergencyName = 'profile_emergency_name';
  static const _keyEmergencyPhone = 'profile_emergency_phone';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _userNameController.dispose();
    _userPhoneController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    super.dispose();
  }

  // ========================================================================
  // LOAD saved profile data
  // ========================================================================
  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    _userNameController.text = prefs.getString(_keyUserName) ?? '';
    _userPhoneController.text = prefs.getString(_keyUserPhone) ?? '';
    _emergencyNameController.text = prefs.getString(_keyEmergencyName) ?? '';
    _emergencyPhoneController.text = prefs.getString(_keyEmergencyPhone) ?? '';
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  // ========================================================================
  // SAVE profile data
  // ========================================================================
  Future<void> _saveProfile() async {
    // ---- Validate via Form ----
    if (!_formKey.currentState!.validate()) return;

    final userPhone = _userPhoneController.text.trim();
    final emergencyPhone = _emergencyPhoneController.text.trim();

    // ---- Check: emergency != user phone ----
    if (emergencyPhone == userPhone) {
      _showSnack('You cannot set your own number as emergency contact.');
      return;
    }

    // ---- Persist ----
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserName, _userNameController.text.trim());
    await prefs.setString(_keyUserPhone, userPhone);
    await prefs.setString(_keyEmergencyName, _emergencyNameController.text.trim());
    await prefs.setString(_keyEmergencyPhone, emergencyPhone);

    if (!mounted) return;
    _showSnack('Profile saved successfully.');
  }

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
  // BUILD
  // ========================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ======================================================
                    // SECTION A — User Info
                    // ======================================================
                    Text(
                      'User Info',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),

                    // User Name
                    TextFormField(
                      controller: _userNameController,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),

                    // User Phone
                    TextFormField(
                      controller: _userPhoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        prefixIcon: Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Phone number is required';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 28),

                    // ======================================================
                    // SECTION B — Emergency Contact
                    // ======================================================
                    Text(
                      'Emergency Contact',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),

                    // Emergency Contact Name
                    TextFormField(
                      controller: _emergencyNameController,
                      decoration: const InputDecoration(
                        labelText: 'Contact Name',
                        prefixIcon: Icon(Icons.contact_emergency_outlined),
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),

                    // Emergency Contact Phone
                    TextFormField(
                      controller: _emergencyPhoneController,
                      decoration: const InputDecoration(
                        labelText: 'Contact Phone Number',
                        prefixIcon: Icon(Icons.phone_in_talk_outlined),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Emergency phone number is required';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 28),

                    // ======================================================
                    // SAVE BUTTON
                    // ======================================================
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _saveProfile,
                        icon: const Icon(Icons.save),
                        label: const Text('Save Profile'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF81C784),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
