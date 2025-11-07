import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class SettingsScreen extends StatefulWidget {
  final ValueChanged<ThemeMode>? onThemeChanged;
  const SettingsScreen({super.key, this.onThemeChanged});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool notificationsEnabled = true;
  ThemeMode themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadSettingsFromHive();
  }

  Future<void> _loadSettingsFromHive() async {
    final box = await Hive.openBox('userSettings');
    setState(() {
      notificationsEnabled = box.get('notificationsEnabled', defaultValue: true);
      final themeString = box.get('themeMode', defaultValue: 'system');
      if (themeString == 'dark') {
        themeMode = ThemeMode.dark;
      } else if (themeString == 'light') {
        themeMode = ThemeMode.light;
      } else {
        themeMode = ThemeMode.system;
      }
    });
    widget.onThemeChanged?.call(themeMode);
  }

  Future<void> _saveSettingsToHive() async {
    final box = await Hive.openBox('userSettings');
    await box.put('notificationsEnabled', notificationsEnabled);
    await box.put('themeMode', themeMode.name);
  }

  void _showChangePasswordDialog() {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldPasswordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Old Password'),
            ),
            TextField(
              controller: newPasswordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New Password'),
            ),
            TextField(
              controller: confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirm New Password'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (newPasswordController.text != confirmPasswordController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('New passwords do not match')),
                );
                return;
              }
              Hive.openBox('userSettings').then((box) {
                box.put('password', newPasswordController.text);
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Password changed (saved locally)')),
              );
            },
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help & Support'),
        content: const Text(
          'For support, contact us at:\n\nsupport@deliveryapp.com\n\n'
                    'Developers:\n'
                    'Ashiru Yusuf Aminu\n'
                    '(Ashiruyusufaminu78@gmail.com)\n\n'
                    'Ajeje Musa Boyi\n'
                    '(Ajejemusaboyi@gmail.com)',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showNotificationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notification Preferences'),
        content: SwitchListTile(
          title: const Text('Enable Notifications'),
          value: notificationsEnabled,
          onChanged: (val) async {
            setState(() => notificationsEnabled = val);
            await _saveSettingsToHive();
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  notificationsEnabled
                      ? 'Notifications enabled'
                      : 'Notifications disabled',
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showThemeDialog() {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Choose Theme'),
        children: [
          RadioListTile<ThemeMode>(
            value: ThemeMode.system,
            groupValue: themeMode,
            title: const Text('System Default'),
            onChanged: (val) async {
              setState(() => themeMode = val!);
              await _saveSettingsToHive();
              widget.onThemeChanged?.call(themeMode);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Theme changed to System Default')),
              );
            },
          ),
          RadioListTile<ThemeMode>(
            value: ThemeMode.light,
            groupValue: themeMode,
            title: const Text('Light'),
            onChanged: (val) async {
              setState(() => themeMode = val!);
              await _saveSettingsToHive();
              widget.onThemeChanged?.call(themeMode); 
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Theme changed to Light')),
              );
            },
          ),
          RadioListTile<ThemeMode>(
            value: ThemeMode.dark,
            groupValue: themeMode,
            title: const Text('Dark'),
            onChanged: (val) async {
              setState(() => themeMode = val!);
              await _saveSettingsToHive();
              widget.onThemeChanged?.call(themeMode);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Theme changed to Dark')),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.lock),
            title: const Text('Change Password'),
            onTap: _showChangePasswordDialog,
          ),
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('Notification Preferences'),
            onTap: _showNotificationDialog,
            trailing: Switch(
              value: notificationsEnabled,
              onChanged: (val) async {
                setState(() => notificationsEnabled = val);
                await _saveSettingsToHive();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      notificationsEnabled
                          ? 'Notifications enabled'
                          : 'Notifications disabled',
                    ),
                  ),
                );
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.palette),
            title: const Text('App Theme'),
            subtitle: Text(
              themeMode == ThemeMode.system
                  ? 'System Default'
                  : themeMode == ThemeMode.light
                      ? 'Light'
                      : 'Dark',
            ),
            onTap: _showThemeDialog,
          ),
          ListTile(
            leading: const Icon(Icons.help),
            title: const Text('Help & Support'),
            onTap: _showHelpDialog,
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('About'),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'Delivery App',
                applicationVersion: '1.0.0',
                applicationLegalese: '© 2025 ABU\n\n'
                    'Developers:\n'
                    'Ashiru Yusuf Aminu\n'
                    '(Ashiruyusufaminu78@gmail.com)\n'
                    'Ajeje Musa Boyi\n'
                    '(Ajejemusaboyi@gmail.com)',
              );
            },
          ),
        ],
      ),
    );
  }
}