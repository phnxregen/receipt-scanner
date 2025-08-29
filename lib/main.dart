import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'services/turboscan_service.dart';
import 'services/receipt_storage.dart';
import 'package:open_filex/open_filex.dart';

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
  // Files imported into app storage
  List<FileSystemEntity> _receipts = const [];
  StreamSubscription? _intentDataStreamSubscription;

  @override
  void initState() {
    super.initState();
    _setupSharingIntent();
    _loadExistingReceipts();
  }

  void _setupSharingIntent() {
    // Only wire up on Android/iOS so desktop/web builds succeed
    if (!(Platform.isAndroid || Platform.isIOS)) return;
    final rsi = ReceiveSharingIntent.instance;
    // Stream for when app is already in memory
    _intentDataStreamSubscription = rsi.getMediaStream().listen(
      (files) {
        if (!mounted) return;
        _importAndShow(files);
      },
      onError: (err) {
        // ignore errors silently to avoid breaking UI
      },
    );
    // When app is launched by a share intent
    rsi.getInitialMedia().then((files) {
      if (!mounted) return;
      if (files.isNotEmpty) _importAndShow(files);
    });
  }

  Future<void> _loadExistingReceipts() async {
    final list = await ReceiptStorage.listReceipts();
    if (!mounted) return;
    setState(() => _receipts = list);
  }

  Future<void> _importAndShow(List<SharedMediaFile> files) async {
    final imported = await ReceiptStorage.importSharedFiles(files);
    final list = await ReceiptStorage.listReceipts();
    if (!mounted) return;
    setState(() {
      _currentIndex = 1; // Jump to Receipts tab
      _receipts = list;
    });
    if (imported > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported $imported file${imported == 1 ? '' : 's'}')),
      );
    }
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
        body = ReceiptsPage(receipts: _receipts);
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
        onTap: (index) async {
          setState(() => _currentIndex = index);
          if (index == 1) {
            await _loadExistingReceipts();
          }
        },
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
  final List<FileSystemEntity> receipts;

  const ReceiptsPage({super.key, this.receipts = const []});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Receipts')),
      body: receipts.isEmpty
          ? const Center(
              child: Text('List of scanned receipts will appear here'),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: receipts.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final f = receipts[index];
                final path = f.path;
                final name = path.split('/').last;
                return ListTile(
                  leading: const Icon(Icons.insert_drive_file),
                  title: Text(name),
                  subtitle: Text(path),
                  onTap: () async {
                    await OpenFilex.open(path);
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
