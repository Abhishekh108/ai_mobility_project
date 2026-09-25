import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  final UserProfile profile;
  final Function(UserProfile) onProfileUpdate;

  const ProfileScreen({
    super.key,
    required this.profile,
    required this.onProfileUpdate,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiService _api = ApiService();
  late TextEditingController _nameController;
  late TextEditingController _urlController;
  late HealthCategory _selectedCategory;
  late double _threshold;
  bool _testingConnection = false;
  String? _connectionStatus;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.name);
    _urlController = TextEditingController(text: _api.baseUrl);
    _selectedCategory = widget.profile.healthCategory;
    _threshold = (widget.profile.customThreshold ?? widget.profile.effectiveThreshold).toDouble();
  }

  void _onCategoryChanged(HealthCategory cat) {
    setState(() {
      _selectedCategory = cat;
      _threshold = cat.defaultThreshold.toDouble();
    });
  }

  Future<void> _testConnection() async {
    setState(() {
      _testingConnection = true;
      _connectionStatus = null;
    });

    await _api.setBaseUrl(_urlController.text.trim());
    final ok = await _api.checkHealth();

    setState(() {
      _testingConnection = false;
      _connectionStatus = ok
          ? 'Connected to backend successfully!'
          : 'Failed to connect. Check IP/Port and server status.';
    });
  }

  Future<void> _save() async {
    final updated = UserProfile(
      id: widget.profile.id,
      name: _nameController.text.trim(),
      healthCategory: _selectedCategory,
      customThreshold: _threshold.round(),
      effectiveThreshold: _threshold.round(),
    );

    await _api.setBaseUrl(_urlController.text.trim());
    try {
      final res = await _api.createProfile(updated.toJson());
      widget.onProfileUpdate(res);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile and alert preferences saved successfully!'),
            backgroundColor: AppTheme.primary,
          ),
        );
      }
    } catch (e) {
      widget.onProfileUpdate(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved locally: $e'),
            backgroundColor: AppTheme.warning,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.shield_outlined, color: AppTheme.primary, size: 22),
            SizedBox(width: 8),
            Text('Health Persona & Connectivity'),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Commuter Health Persona Selection
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Commuter Health Profile',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Select your persona to automatically calibrate pollution exposure alert limits.',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: _nameController,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Commuter Name',
                    prefixIcon: Icon(Icons.person_outline, color: AppTheme.accent),
                  ),
                ),
                const SizedBox(height: 14),

                // Category selection tiles
                ...HealthCategory.values.map((cat) {
                  final isSel = _selectedCategory == cat;
                  return GestureDetector(
                    onTap: () => _onCategoryChanged(cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSel ? AppTheme.surfaceLight : AppTheme.cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSel ? AppTheme.primary : AppTheme.border,
                          width: isSel ? 1.8 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSel ? Icons.radio_button_checked : Icons.radio_button_off,
                            color: isSel ? AppTheme.primary : AppTheme.textMuted,
                            size: 18,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  cat.displayName,
                                  style: TextStyle(
                                    color: isSel ? AppTheme.primary : AppTheme.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  'Default alert threshold: ${cat.defaultThreshold} AQI',
                                  style: const TextStyle(
                                    color: AppTheme.textMuted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Custom Threshold Slider Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Custom Alert Threshold',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${_threshold.round()} AQI',
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Routes and current locations exceeding this AQI will trigger proactive warnings.',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 10),
                Slider(
                  value: _threshold,
                  min: 50,
                  max: 500,
                  divisions: 45,
                  activeColor: AppTheme.primary,
                  inactiveColor: AppTheme.surfaceLight,
                  onChanged: (val) {
                    setState(() {
                      _threshold = val;
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Backend Connection Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Backend Connectivity',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Default: 10.0.2.2:8000 (Android Emulator) or 127.0.0.1:8000 (Desktop/Web). For physical phone, enter your PC\'s Wi-Fi IP.',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _urlController,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'API Base URL',
                    prefixIcon: Icon(Icons.cloud_outlined, color: AppTheme.accent),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _testingConnection ? null : _testConnection,
                        icon: _testingConnection
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.wifi_tethering, size: 16),
                        label: const Text('Test Connection'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.accent,
                          side: const BorderSide(color: AppTheme.border),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_connectionStatus != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _connectionStatus!,
                    style: TextStyle(
                      color: _connectionStatus!.contains('success')
                          ? AppTheme.primary
                          : AppTheme.error,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Save Button
          ElevatedButton(
            onPressed: _save,
            child: const Text('Save Settings'),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
