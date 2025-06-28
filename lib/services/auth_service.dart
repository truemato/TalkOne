import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io' show Platform;

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    // Androidでのテスト用設定
    scopes: ['email', 'profile'],
  );
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 現在のユーザーを取得
  User? get currentUser => _auth.currentUser;

  // 認証状態の変更を監視
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Googleアカウントでサインイン
  Future<UserCredential?> signInWithGoogle() async {
    try {
      print('=== Google Sign In Debug Start ===');
      print('Google Sign In開始');
      print('GoogleSignIn設定: ${_googleSignIn.toString()}');
      
      // Google Play Services の可用性を確認
      try {
        final isAvailable = await _googleSignIn.isSignedIn();
        print('Google Sign In Service 状態: $isAvailable');
      } catch (e) {
        print('Google Sign In Service 確認エラー: $e');
      }
      
      // Google認証フローを開始
      print('Google認証フロー開始...');
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        print('❌ Googleサインインがキャンセルされました');
        print('考えられる原因:');
        print('1. ユーザーがキャンセルボタンを押した');
        print('2. Google Play Services が利用できない');
        print('3. OAuth設定が正しくない');
        print('4. エミュレーターにGoogleアカウントが設定されていない');
        return null;
      }

      print('✅ Google認証成功: ${googleUser.email}');
      print('ユーザーID: ${googleUser.id}');
      print('表示名: ${googleUser.displayName}');

      // Google認証の詳細を取得
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Firebase認証用のクレデンシャルを作成
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Firebaseにサインイン
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      
      // 既存プロフィールの確認（上書きを絶対に防ぐ）
      await _ensureUserProfileExists(userCredential.user!);

      print('✅ Firebase認証成功: ${userCredential.user?.uid}');
      print('=== Google Sign In Debug End ===');
      return userCredential;
    } catch (e) {
      print('❌ Google Sign Inエラー: $e');
      print('エラータイプ: ${e.runtimeType}');
      if (e.toString().contains('DEVELOPER_ERROR')) {
        print('🔧 DEVELOPER_ERROR: SHA-1フィンガープリントまたはOAuth設定を確認してください');
      } else if (e.toString().contains('SIGN_IN_CANCELLED')) {
        print('👤 SIGN_IN_CANCELLED: ユーザーがサインインをキャンセルしました');
      } else if (e.toString().contains('SIGN_IN_FAILED')) {
        print('⚠️ SIGN_IN_FAILED: Google Play Servicesの問題の可能性があります');
      }
      print('=== Google Sign In Debug End ===');
      return null;
    }
  }

  // Apple IDでサインイン
  Future<UserCredential?> signInWithApple() async {
    try {
      print('=== Apple Sign In Debug Start ===');
      print('Apple Sign In開始');
      
      // Apple認証が利用可能かチェック
      if (!Platform.isIOS) {
        print('❌ Apple Sign InはiOSでのみ利用可能です');
        return null;
      }
      
      final isAvailable = await SignInWithApple.isAvailable();
      if (!isAvailable) {
        print('❌ Apple Sign Inが利用できません');
        return null;
      }
      
      // Apple認証フローを開始
      print('Apple認証フロー開始...');
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      
      print('✅ Apple認証成功: ${appleCredential.email ?? 'メールアドレス未取得'}');
      print('ユーザーID: ${appleCredential.userIdentifier}');
      print('表示名: ${appleCredential.givenName} ${appleCredential.familyName}');
      
      // Firebase認証用のクレデンシャルを作成
      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );
      
      // Firebaseにサインイン
      final UserCredential userCredential = await _auth.signInWithCredential(oauthCredential);
      
      // 既存プロフィールの確認（上書きを絶対に防ぐ）
      await _ensureUserProfileExists(userCredential.user!);
      
      print('✅ Firebase認証成功: ${userCredential.user?.uid}');
      print('=== Apple Sign In Debug End ===');
      return userCredential;
    } catch (e) {
      print('❌ Apple Sign Inエラー: $e');
      print('エラータイプ: ${e.runtimeType}');
      if (e.toString().contains('SignInWithAppleAuthorizationError')) {
        print('👤 AUTHORIZATION_ERROR: ユーザーがサインインをキャンセルしました');
      } else if (e.toString().contains('NotSupported')) {
        print('⚠️ NOT_SUPPORTED: Apple Sign Inがサポートされていません');
      }
      print('=== Apple Sign In Debug End ===');
      return null;
    }
  }

  // 匿名認証でサインイン
  Future<UserCredential?> signInAnonymously() async {
    try {
      print('匿名認証開始');
      final UserCredential userCredential = await _auth.signInAnonymously();
      
      // 匿名ユーザーのプロフィールを初期化
      await _ensureUserProfileExists(userCredential.user!);
      
      print('匿名認証成功: ${userCredential.user?.uid}');
      return userCredential;
    } catch (e) {
      print('匿名認証エラー: $e');
      return null;
    }
  }

  // 匿名アカウントをGoogleアカウントにリンク
  Future<UserCredential?> linkAnonymousWithGoogle() async {
    try {
      if (currentUser == null || !currentUser!.isAnonymous) {
        print('匿名ユーザーではありません');
        return null;
      }

      print('匿名アカウントをGoogleアカウントにリンク開始');

      // Google認証フローを開始
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        print('Googleサインインがキャンセルされました');
        return null;
      }

      // Google認証の詳細を取得
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Firebase認証用のクレデンシャルを作成
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 匿名アカウントにGoogleアカウントをリンク
      final UserCredential userCredential = await currentUser!.linkWithCredential(credential);
      
      print('アカウントリンク成功: ${userCredential.user?.uid}');
      return userCredential;
    } catch (e) {
      print('アカウントリンクエラー: $e');
      
      // 既に同じメールアドレスでアカウントが存在する場合の処理
      if (e is FirebaseAuthException && e.code == 'credential-already-in-use') {
        print('既存のGoogleアカウントに移行します');
        return await signInWithGoogle();
      }
      
      return null;
    }
  }

  // サインアウト
  Future<void> signOut() async {
    try {
      // Googleサインアウト
      await _googleSignIn.signOut();
      
      // Firebaseサインアウト
      await _auth.signOut();
      
      print('サインアウト成功');
    } catch (e) {
      print('サインアウトエラー: $e');
    }
  }

  // 既存プロフィールの確認（絶対に上書きしない）
  Future<void> _ensureUserProfileExists(User user) async {
    try {
      final userDoc = _firestore.collection('userProfiles').doc(user.uid);
      final docSnapshot = await userDoc.get();
      
      if (!docSnapshot.exists) {
        // 新規ユーザーのみ、空のプロフィールで初期化
        print('新規ユーザー検出: ${user.uid}');
        
        await userDoc.set({
          'nickname': null,
          'email': null, // メールアドレスも保存しない
          'iconPath': 'aseets/icons/Woman 1.svg',
          'gender': null,
          'birthday': null,
          'comment': null,
          'aiMemory': null,
          'themeIndex': 0,
          'createdAt': FieldValue.serverTimestamp(),
          'lastUpdated': FieldValue.serverTimestamp(),
          'isAnonymous': user.isAnonymous,
        });

        // レーティング初期化（新規ユーザーのみ）
        final ratingDoc = _firestore.collection('userRatings').doc(user.uid);
        final ratingSnapshot = await ratingDoc.get();
        
        if (!ratingSnapshot.exists) {
          await ratingDoc.set({
            'rating': 1000, // 初期レーティング
            'totalGames': 0,
            'winStreak': 0,
            'maxWinStreak': 0,
            'lastGameAt': null,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        print('新規ユーザープロフィール初期化完了: ${user.uid}');
      } else {
        // 既存ユーザーの場合は何もしない（絶対に上書きしない）
        print('既存ユーザー検出: ${user.uid} - プロフィール保持');
        final existingData = docSnapshot.data() as Map<String, dynamic>;
        print('既存ニックネーム: ${existingData['nickname'] ?? '未設定'}');
      }
    } catch (e) {
      print('プロフィール確認エラー: $e');
    }
  }

  // 匿名ユーザーかどうかを確認
  bool get isAnonymous => currentUser?.isAnonymous ?? true;

  // サインイン済みかどうかを確認
  bool get isSignedIn => currentUser != null;

  // Googleアカウントでサインイン済みかどうかを確認
  bool get isGoogleSignedIn => currentUser != null && !currentUser!.isAnonymous && currentUser!.email != null;
  
  // Apple IDでサインイン済みかどうかを確認
  bool get isAppleSignedIn => currentUser != null && !currentUser!.isAnonymous && 
      currentUser!.providerData.any((provider) => provider.providerId == 'apple.com');
}