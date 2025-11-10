import 'package:flutter/material.dart';
import 'package:gooner_app_pro/screens/e621_screen.dart';
import 'package:gooner_app_pro/screens/kemonocr_screen.dart';
import 'package:gooner_app_pro/screens/rule34_screen.dart';
import 'package:gooner_app_pro/screens/danbooru_screen.dart';
import 'package:provider/provider.dart';
import 'screens/settings_screen.dart';
import 'services/settings_service.dart';
import 'screens/waifupics_screen.dart';
import 'screens/waifuim_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;


class IconItem {
  final String iconPath;
  final String label;
  final Widget targetScreen;

  IconItem({required this.iconPath, required this.label, required this.targetScreen});
}

final List<IconItem> fakeProviders = [
  IconItem(iconPath: "assets/danbooru_icon.png", label: "Danbooru", targetScreen: DanbooruScreen()),
  IconItem(iconPath: "assets/e621_logo.png", label: "e621.net", targetScreen: E621Screen()),
  IconItem(iconPath: "assets/rule34_logo.png", label: "rule34.xxx", targetScreen: const Rule34Screen()),
  IconItem(iconPath: "assets/waifu_pics_logo.png", label: "waifu.pics", targetScreen: WaifuPicsScreen()),
  IconItem(iconPath: "assets/waifu_im_logo.png", label: "waifu.im", targetScreen: WaifuImScreen()),
  IconItem(iconPath: "assets/placeholder_logo.png", label: "kemono.cr", targetScreen: KemonoCrScreen())
];

// Placeholder list for the hidden "Real" content providers
final List<IconItem> realProviders = [
  
];


// 1. MainPage is now a StatefulWidget
class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState(); 
}


class _MainPageState extends State<MainPage> {
  
  void _onPageLoad() {
    // 1. Use addPostFrameCallback to safely access the context after the build phase
    WidgetsBinding.instance.addPostFrameCallback((_) {
      
      // 2. Safely get the service using Provider.of and listen: false
      final settingsService = Provider.of<SettingsService>(context, listen: false);
      
      // 3. Now, perform your switch logic on the detected platform
      String platformString;

      if (kIsWeb) {
        platformString = "web";
      } else {
        switch (defaultTargetPlatform) {
          case TargetPlatform.android:
            platformString = "android";
            break;
          case TargetPlatform.iOS:
            platformString = "ios";
            break;
          case TargetPlatform.macOS:
            platformString = "macos";
            break;
          case TargetPlatform.windows:
            platformString = "windows";
            break;
          case TargetPlatform.linux:
            platformString = "linux";
            break;
          default:
            platformString = "unknown";
            break;
        }
      }
      if (settingsService.deviceType != platformString) {
        settingsService.setDeviceType(platformString);
        print('Device detected and set as: $platformString');
      }
    });
  }
  
  @override
  void initState() {
    super.initState(); // MUST be called first
    _onPageLoad();
  }

  void _onProviderIconGridTapped(BuildContext context, IconItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => item.targetScreen,
      ),
    );
  }

  void _onSettingsButtonTapped(BuildContext context) {
    Navigator.push(context,
    MaterialPageRoute(
      builder: (context) => const SettingsScreen(),
    ));
  }

  Widget _buildProviderGrid(BuildContext context, List<IconItem> providers) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(), 
      itemCount: providers.length,
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 10.0,
        crossAxisSpacing: 10.0,
        childAspectRatio: 1.0,
      ),

      itemBuilder: (context, index) {
        final item = providers[index];
        return InkWell(
          onTap: () => _onProviderIconGridTapped(context, item),
          borderRadius: BorderRadius.circular(8),
          
          child: SizedBox(
            width: 50.0, 
            height: 50.0,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Image.asset(
                  item.iconPath,
                  width: 48, 
                  height: 48.0,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 8.0),
                Text(
                  item.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14.0),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 3. The build method is inside the State class
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Provider Selection"),
      ),
      body: Column(
        children: <Widget>[
          // Use Consumer to read the state and rebuild the content area when settings change
          Expanded(
            child: Consumer<SettingsService>(
              builder: (context, settings, child) {
                // Check for initial load to prevent immediate access before loading is complete
                if (settings.isInitialLoadComplete == false) {
                  return const Center(child: CircularProgressIndicator());
                }
                final bool showRealContent = settings.isRealContentShown;

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        "Animated/Furry Content", 
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20.0),
                      ),
                      const SizedBox(height: 10.0),
                      _buildProviderGrid(context, fakeProviders),

                      // Visibility is controlled by the state from the SettingsService
                      Visibility(
                        visible: showRealContent,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const SizedBox(height: 20.0),
                            
                            // Real Label
                            const Text(
                              "Real",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20.0),
                            ),
                            const SizedBox(height: 10.0),
                            
                            // Real Providers Grid is now conditionally rendered
                            _buildProviderGrid(context, realProviders),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          
          // Settings Button (Fixed at bottom)
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: ElevatedButton(
                onPressed: () => _onSettingsButtonTapped(context),
                child: const Text("Settings"),
              ),
            ),
          ),
        ],
      ),
    );
  }
}