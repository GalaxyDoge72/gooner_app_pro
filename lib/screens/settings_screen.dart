import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gooner_app_pro/services/settings_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Scaffold for the page structure
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
      ),
      // The Consumer will handle the loading state, so we use a direct Consumer here
      body: const SettingsContent(),
    );
  }
}

class SettingsContent extends StatelessWidget {
  const SettingsContent({super.key});

  // Helper widget for a text input field for API/User IDs
  Widget _buildAuthInputField({
    required BuildContext context,
    required String label,
    required String initialValue,
    required ValueChanged<String> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 8.0),
      child: TextFormField(
        initialValue: initialValue,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        ),
        onChanged: onChanged,
        // Ensure it's treated as a single line of text
        textInputAction: TextInputAction.done,
        keyboardType: TextInputType.text,
      ),
    );
  }
  
  // Function to show the special alert for "Real Content"
  Future<void> _handleRealContentToggle(BuildContext context, SettingsService settings, bool newValue) async {
    if (newValue == true) {
      // Show MAUI's DisplayAlert equivalent: a standard Flutter AlertDialog
      bool accepted = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text("Warning!"),
            content: const Text(
              "You are enabling content from providers that feature real people.\n" "It's a fair warning that you may see some of the most scarring shit of your life here.",
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(true), // User chose "OK"
                child: const Text('OK'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false), // User chose "I WANT OUT!"
                child: const Text('I WANT OUT!'),
              ),
            ],
          );
        },
      ) ?? false;

      if (accepted) {
        settings.setShowRealContent(true);
      } else {
        // If user rejects, or closes dialog, set back to false
        settings.setShowRealContent(false);
      }
    } else {
      // Switch is being turned OFF, save the false state
      settings.setShowRealContent(false);
    }
  }

  // Helper for limit sliders
  Widget _buildLimitSlider(
    BuildContext context, 
    String title, 
    int currentValue, 
    ValueChanged<int> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15.0),
            child: Text(
              '$title: ${currentValue.round()}',
              style: const TextStyle(fontSize: 16.0),
            ),
          ),
          Slider(
            value: currentValue.toDouble(),
            min: 1,
            max: 100,
            divisions: 99,
            label: currentValue.round().toString(),
            onChanged: (double newValue) => onChanged(newValue.round()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsService>(
      builder: (context, settings, child) {
        if (!settings.isInitialLoadComplete) {
          return const Center(child: CircularProgressIndicator());
        }

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.fromLTRB(10, 20, 10, 5),
                child: Center(
                  child: Text(
                    "General Settings",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20.0),
                  ),
                ),
              ),

              // --- Dark Mode Switch ---
              SwitchListTile(
                title: const Text("Enable Dark Mode"),
                value: settings.isDarkModeEnabled,
                onChanged: settings.setDarkMode,
              ),

              // --- WEBM Warning Switch ---
              SwitchListTile(
                title: const Text("Show WEBM warning"),
                value: settings.isShowWebmWarningEnabled,
                onChanged: settings.setShowWebmWarn,
              ),

              // --- Rule34 API Settings ---
              const Padding(
                padding: EdgeInsets.fromLTRB(10, 20, 10, 5),
                child: Center(
                  child: Text(
                    "rule34.xxx Authentication",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20.0),
                  ),
                ),
              ),

              // NEW: Rule34 User ID Input
              _buildAuthInputField(
                context: context,
                label: "Rule34 User ID (user_id)",
                initialValue: settings.r34UserId,
                onChanged: settings.setR34UserId,
              ),

              // NEW: Rule34 API Key Input
              _buildAuthInputField(
                context: context,
                label: "Rule34 API Key (api_key)",
                initialValue: settings.r34ApiKey,
                onChanged: settings.setR34ApiKey,
              ),

              // --- E621 Post Limit Slider ---
              _buildLimitSlider(
                context, 
                "e621.net Post Limit (per page)", 
                settings.e621PostAmount, 
                settings.setE621PostLimit
              ),

              // --- rule34.xxx Post Limit Slider ---
              _buildLimitSlider(
                context, 
                "rule34.xxx Post Limit (per page)", 
                settings.r34PostAmount, 
                settings.setR34PostLimit
              ),

              // --- danbooru.donmai Post Limit Slider ---
              _buildLimitSlider(
                context, 
                "danbooru.donmai Post Limit (per page)", 
                settings.danbooruPostAmount, 
                settings.setDanbooruPostLimit
              ),

              const Padding(
                padding: EdgeInsets.fromLTRB(10, 20, 10, 5),
                child: Center(
                  child: Text(
                    "Danbooru Authentication",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20.0),
                  ),
                ),
              ),

              _buildAuthInputField(
                context: context,
                label: "Danbooru User ID",
                initialValue: settings.danbooruUserID,
                onChanged: settings.setDanbooruUserId,
              ),

              _buildAuthInputField(
                context: context,
                label: "Danbooru API Key",
                initialValue: settings.danbooruApiKey,
                onChanged: settings.setDanbooruApiKey,
              ),

              // --- Content Settings Label ---
              const Padding(
                padding: EdgeInsets.fromLTRB(10, 20, 10, 5),
                child: Center(
                  child: Text(
                    "Content Settings",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20.0),
                  ),
                ),
              ),

              // --- Show Real Content Switch (with warning logic) ---
              SwitchListTile(
                title: const Text("Show content from real people"),
                value: settings.isRealContentShown,
                onChanged: (newValue) => _handleRealContentToggle(context, settings, newValue),
              ),

              SwitchListTile(
                title: const Text("Show AI content (ethical gooning mode)"),
                value: settings.showAIContent,
                onChanged: settings.setShowAIContent,
              ),

              const Padding(
                padding: EdgeInsets.fromLTRB(10, 20, 10, 5),
                child: Center(
                  child: Text(
                    "Developer Settings",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20.0),
                  ),
                ),
              ),

              SwitchListTile(
                title: const Text("Enable debug mode"),
                value: settings.isdebugMode,
                onChanged: settings.setDebugMode,
              )

            ],
          ),
        );
      },
    );
  }
}