import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'dart:async';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'services/turboscan_service.dart';

void main() {
  runApp(const ReceiptApp());
}

class ReceiptApp extends StatelessWidget {
  const ReceiptApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '529 Receipt Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        // Base color scheme seeded from light blue for subtle accents
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.lightBlue,
          brightness: Brightness.light,
        ),
        // Make all icons black by default
        iconTheme: const IconThemeData(color: Colors.black),
        // Make all text black (headlines + body)
        textTheme: ThemeData.light()
            .textTheme
            .apply(bodyColor: Colors.black, displayColor: Colors.black),
        // Top app bars: light blue background with black content
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.lightBlue.shade100,
          foregroundColor: Colors.black,
          iconTheme: const IconThemeData(color: Colors.black),
          titleTextStyle: const TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        // Bottom app bars/navigation: light blue background with black items
        bottomAppBarTheme: BottomAppBarTheme(
          color: Colors.lightBlue.shade100,
          elevation: 2,
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: Colors.lightBlue.shade100,
          selectedItemColor: Colors.black,
          unselectedItemColor: Colors.black,
          selectedIconTheme: const IconThemeData(color: Colors.black),
          unselectedIconTheme: const IconThemeData(color: Colors.black),
        ),
        // Ensure buttons use black foreground (text/icon)
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.black,
          ),
        ),
      ),
      home: const MainNavigation(),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  // Files shared back from TurboScan (or other apps)
  List<SharedMediaFile> _sharedFiles = const [];
  StreamSubscription? _intentDataStreamSubscription;

  @override
  void initState() {
    super.initState();
    _setupSharingIntent();
  }

  void _setupSharingIntent() {
    // Only wire up on Android/iOS so desktop/web builds succeed
    if (!(Platform.isAndroid || Platform.isIOS)) return;
    final rsi = ReceiveSharingIntent.instance;
    // Stream for when app is already in memory
    _intentDataStreamSubscription = rsi.getMediaStream().listen(
      (files) {
        if (!mounted) return;
        setState(() => _sharedFiles = files);
      },
      onError: (err) {
        // ignore errors silently to avoid breaking UI
      },
    );
    // When app is launched by a share intent
    rsi.getInitialMedia().then((files) {
      if (!mounted) return;
      if (files.isNotEmpty) {
        setState(() {
          _currentIndex = 1; // Jump to Receipts tab
          _sharedFiles = files;
        });
      }
    });
  }

  @override
  void dispose() {
    _intentDataStreamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget body;
    switch (_currentIndex) {
      case 0:
        body = const HomePage();
        break;
      case 1:
        body = ReceiptsPage(sharedFiles: _sharedFiles);
        break;
      case 2:
        body = const AddReceiptPage();
        break;
      default:
        body = const SettingsPage();
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.lightBlue.shade100,
        type: BottomNavigationBarType.fixed, // prevent shifting
        selectedIconTheme: const IconThemeData(size: 28, color: Colors.indigo),
        unselectedIconTheme: const IconThemeData(size: 24, color: Colors.black),
        // Keep label colors identical so only the icon changes
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.black,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'Receipts'),
          BottomNavigationBarItem(icon: Icon(Icons.add_box), label: 'Add'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: const Center(
        child: Text('Total spent: \$0.00 / \$6,350 allowance'),
      ),
    );
  }
}

class ReceiptsPage extends StatelessWidget {
  final List<SharedMediaFile> sharedFiles;

  const ReceiptsPage({super.key, this.sharedFiles = const []});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Receipts')),
      body: sharedFiles.isEmpty
          ? const Center(
              child: Text('List of scanned receipts will appear here'),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: sharedFiles.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final f = sharedFiles[index];
                return ListTile(
                  leading: const Icon(Icons.insert_drive_file),
                  title: Text(f.path.split('/').last),
                  subtitle: Text(f.type.name),
                  onTap: () {
                    // TODO: open/view file, upload, etc.
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Selected: ${f.path}')),
                    );
                  },
                );
              },
            ),
    );
  }
}

class AddReceiptPage extends StatelessWidget {
  const AddReceiptPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Receipt')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: () async {
                final ok = await TurboScanService.openTurboScan();
                if (!ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('TurboScan not available. Please install it.'),
                    ),
                  );
                } else if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('TurboScan opened. Share the scan back to this app.'),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.camera_alt),
              label: const Text('Scan with TurboScan'),
            ),
            const SizedBox(height: 12),
            const Text(
              'Tip: After scanning, use Share in TurboScan and choose this app to import the PDF.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: const Center(
        child: Text('Settings go here'),
      ),
    );
  }
}
