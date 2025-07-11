import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'screens/page_view_container.dart';
import 'screens/login_screen.dart';
import 'screens/eula_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'utils/permission_util.dart';
import 'services/auth_service.dart';
import 'services/version_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 環境変数を読み込み
  await dotenv.load(fileName: ".env");

  // 縦向き固定
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    // Firebase App Check 初期化（AI用）
    try {
      await FirebaseAppCheck.instance.activate(
        webProvider: ReCaptchaV3Provider('recaptcha-v3-site-key'),
        androidProvider: AndroidProvider.debug,
        appleProvider: AppleProvider.debug,
      );
      print('Firebase App Check初期化完了');
    } catch (e) {
      print('Firebase App Check初期化エラー（スキップ）: $e');
    }

    // 初回起動時の権限処理
    print('main: 権限処理を開始します');

    // デバッグ：初回起動フラグをリセット（権限を再表示するため）
    await PermissionUtil.resetFirstLaunchFlag();

    final permissionGranted =
        await PermissionUtil.handleFirstLaunchPermissions();
    print('main: 権限処理結果 - permissionGranted: $permissionGranted');

    runApp(MyApp(permissionGranted: permissionGranted));
  } catch (e) {
    print('Firebase初期化エラー: $e');
    runApp(ErrorApp(message: 'アプリの初期化に失敗しました: $e'));
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.permissionGranted});
  final bool permissionGranted;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TalkOne',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
      ),
      home: permissionGranted
          ? const AuthWrapper() // 権限が許可されていれば認証チェック
          : const LoginScreen(), // 権限が拒否されていればログイン画面へ
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final AuthService _authService = AuthService();
  final VersionNotificationService _versionService = VersionNotificationService();
  bool? _eulaAccepted;

  @override
  void initState() {
    super.initState();
    _checkEulaAcceptance();
    _initializeVersionNotifications();
  }

  Future<void> _initializeVersionNotifications() async {
    // ユーザーがログイン済みの場合のみバージョン通知をチェック
    _authService.authStateChanges.listen((user) {
      if (user != null) {
        _versionService.checkAndNotifyVersionUpdate();
      }
    });
  }

  Future<void> _checkEulaAcceptance() async {
    final prefs = await SharedPreferences.getInstance();
    final accepted = prefs.getBool('eula_accepted') ?? false;
    setState(() {
      _eulaAccepted = accepted;
    });
  }

  @override
  Widget build(BuildContext context) {
    // EULA確認中
    if (_eulaAccepted == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // EULAが未承認の場合
    if (!_eulaAccepted!) {
      return const EulaScreen();
    }

    // EULAが承認済みの場合、認証チェック
    return StreamBuilder<User?>(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        // 認証状態の読み込み中
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        // ユーザーがサインイン済みの場合
        if (snapshot.hasData) {
          return const PageViewContainer();
        }
        
        // ユーザーがサインインしていない場合
        return const LoginScreen();
      },
    );
  }
}

class ErrorApp extends StatelessWidget {
  final String message;

  const ErrorApp({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                Text(
                  'エラーが発生しました',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
