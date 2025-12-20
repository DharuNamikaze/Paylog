import 'package:flutter/material.dart';
import '../../core/services/background_sms_service.dart';

/// Settings page for PayLog app configuration
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _backgroundMonitoringEnabled = false;
  bool _batteryOptimizationIgnored = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final backgroundActive = await BackgroundSmsService.isBackgroundMonitoringActive();
      final batteryOptimized = await BackgroundSmsService.isBatteryOptimizationIgnored();
      
      setState(() {
        _backgroundMonitoringEnabled = backgroundActive;
        _batteryOptimizationIgnored = batteryOptimized;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading settings: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleBackgroundMonitoring(bool enabled) async {
    try {
      setState(() {
        _isLoading = true;
      });

      bool success;
      if (enabled) {
        success = await BackgroundSmsService.startBackgroundMonitoring();
      } else {
        success = await BackgroundSmsService.stopBackgroundMonitoring();
      }

      if (success) {
        setState(() {
          _backgroundMonitoringEnabled = enabled;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(enabled 
                ? 'Background monitoring started' 
                : 'Background monitoring stopped'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to ${enabled ? 'start' : 'stop'} background monitoring'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error toggling background monitoring: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _requestBatteryOptimization() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final success = await BackgroundSmsService.requestBatteryOptimizationExemption();
      
      if (success) {
        // Check the status again after the request
        final isIgnored = await BackgroundSmsService.isBatteryOptimizationIgnored();
        setState(() {
          _batteryOptimizationIgnored = isIgnored;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isIgnored 
                ? 'Battery optimization disabled successfully' 
                : 'Battery optimization request completed'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error requesting battery optimization: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error requesting battery optimization: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // Background Monitoring Section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.settings_backup_restore,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Background Monitoring',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SwitchListTile(
                          title: const Text('Auto-start on Boot'),
                          subtitle: const Text('Automatically monitor SMS messages when device starts'),
                          value: _backgroundMonitoringEnabled,
                          onChanged: _toggleBackgroundMonitoring,
                          secondary: Icon(
                            _backgroundMonitoringEnabled ? Icons.play_circle : Icons.pause_circle,
                            color: _backgroundMonitoringEnabled ? Colors.green : Colors.grey,
                          ),
                        ),
                        if (_backgroundMonitoringEnabled) ...[
                          const Divider(),
                          ListTile(
                            leading: Icon(
                              _batteryOptimizationIgnored ? Icons.battery_full : Icons.battery_alert,
                              color: _batteryOptimizationIgnored ? Colors.green : Colors.orange,
                            ),
                            title: const Text('Battery Optimization'),
                            subtitle: Text(_batteryOptimizationIgnored 
                              ? 'Disabled - background monitoring protected'
                              : 'Enabled - may affect background monitoring'),
                            trailing: _batteryOptimizationIgnored 
                              ? const Icon(Icons.check_circle, color: Colors.green)
                              : ElevatedButton(
                                  onPressed: _requestBatteryOptimization,
                                  child: const Text('Disable'),
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Information Section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'How it Works',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          '• PayLog runs a background service to monitor SMS messages\n'
                          '• The service starts automatically when your device boots\n'
                          '• Financial transactions are detected and saved automatically\n'
                          '• Battery optimization should be disabled for reliable operation\n'
                          '• You can manually start/stop monitoring anytime',
                          style: TextStyle(height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Privacy Section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.privacy_tip_outlined,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Privacy & Security',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          '• Only financial SMS messages are processed\n'
                          '• Non-financial messages are completely ignored\n'
                          '• All data is stored locally on your device\n'
                          '• No SMS content is shared with third parties\n'
                          '• You can stop monitoring at any time',
                          style: TextStyle(height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}