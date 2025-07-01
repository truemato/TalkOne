import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io' show Platform;

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
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
      
      // Google認証フローを開始（iPad対応）
      print('Google認証フロー開始...');
      
      // iPad/iOS環境での安定化
      if (Platform.isIOS) {
        print('🍎 iOS/iPad環境でのGoogle認証準備');
        await Future.delayed(const Duration(milliseconds: 150));
      }
      
      GoogleSignInAccount? googleUser;
      try {
        // タイムアウト付きでGoogle Sign Inを実行
        googleUser = await _googleSignIn.signIn().timeout(
          const Duration(seconds: 45),
          onTimeout: () {
            print('❌ 通常Google Sign Inがタイムアウトしました（45秒）');
            throw TimeoutException('Google Sign Inがタイムアウトしました', const Duration(seconds: 45));
          },
        );
      } catch (signInError) {
        print('❌ Google Sign In初期エラー: $signInError');
        print('エラータイプ: ${signInError.runtimeType}');
        
        // タイムアウトエラーの場合は再試行しない
        if (signInError is TimeoutException) {
          print('⏰ 通常認証でタイムアウト - 再試行せずに終了');
          return null;
        }
        
        // iPad特有エラーの詳細ログ
        if (Platform.isIOS && signInError.toString().contains('7')) {
          print('🍎 iPad特有エラー(7)検出 - リトライ実行');
          try {
            await _googleSignIn.signOut();
            await Future.delayed(const Duration(milliseconds: 500));
            
            // リトライもタイムアウト付き
            googleUser = await _googleSignIn.signIn().timeout(
              const Duration(seconds: 30),
              onTimeout: () {
                print('❌ 通常認証リトライもタイムアウトしました（30秒）');
                throw TimeoutException('Google Sign Inリトライがタイムアウトしました', const Duration(seconds: 30));
              },
            );
          } catch (retryError) {
            print('❌ 通常認証リトライも失敗: $retryError');
            return null;
          }
        } else {
          print('❌ Google Sign Inエラー: $signInError');
          if (signInError.toString().contains('sign_in_failed')) {
            print('Google Play Servicesの問題またはOAuth設定の問題');
          }
          return null;
        }
      }
      
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
      
      // iPad/iOS特有のエラーハンドリング
      if (Platform.isIOS && e.toString().contains('7')) {
        print('🍎 iPad特有エラー(7): Google Sign Inサービスの初期化問題');
        print('解決策: アプリ再起動またはGoogle Sign Inの再初期化');
      } else if (e.toString().contains('DEVELOPER_ERROR')) {
        print('🔧 DEVELOPER_ERROR: SHA-1フィンガープリントまたはOAuth設定を確認してください');
      } else if (e.toString().contains('SIGN_IN_CANCELLED')) {
        print('👤 SIGN_IN_CANCELLED: ユーザーがサインインをキャンセルしました');
      } else if (e.toString().contains('SIGN_IN_FAILED')) {
        print('⚠️ SIGN_IN_FAILED: Google Play Servicesの問題の可能性があります');
      } else if (e.toString().contains('network') || e.toString().contains('Network')) {
        print('🌐 ネットワークエラー: インターネット接続を確認してください');
      }
      print('=== Google Sign In Debug End ===');
      return null;
    }
  }

  // Apple IDでサインイン
  Future<UserCredential?> signInWithApple() async {
    try {
      print('=== Apple Sign In Debug Start ===');
      print('Platform: ${Platform.operatingSystem}');
      print('Platform version: ${Platform.operatingSystemVersion}');
      
      // Apple認証が利用可能かチェック
      if (!Platform.isIOS && !Platform.isAndroid) {
        print('❌ Apple Sign InはiOSとAndroidでのみ利用可能です');
        throw Exception('Apple Sign InはiOSとAndroidでのみ利用可能です');
      }
      
      print('🔍 Apple Sign In可用性チェック中...');
      final isAvailable = await SignInWithApple.isAvailable();
      print('Apple Sign In可用性: $isAvailable');
      
      if (!isAvailable) {
        print('❌ Apple Sign Inが利用できません');
        if (Platform.isAndroid) {
          print('Android用Apple Sign In要件:');
          print('1. Android 6.0 (API 23) 以上');
          print('2. Google Play Services');
          print('3. 適切なManifest設定');
          print('4. Apple Developer設定');
        }
        throw Exception('Apple Sign Inが利用できません');
      }
      
      // Apple認証フローを開始
      print('🍎 Apple認証フロー開始...');
      print('要求スコープ: email, fullName');
      
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        webAuthenticationOptions: Platform.isAndroid ? WebAuthenticationOptions(
          clientId: 'com.truemato.TalkOne.signinwithapple',
          redirectUri: Uri.parse('https://myproject-c8034.firebaseapp.com/__/auth/handler'),
        ) : null,
      );
      
      print('✅ Apple認証レスポンス受信');
      print('ユーザーID: ${appleCredential.userIdentifier}');
      print('Email: ${appleCredential.email ?? 'メールアドレス未取得'}');
      print('名前: ${appleCredential.givenName} ${appleCredential.familyName}');
      print('Identity Token有無: ${appleCredential.identityToken != null}');
      print('Authorization Code有無: ${appleCredential.authorizationCode != null}');
      
      // トークンの詳細確認
      if (appleCredential.identityToken?.isEmpty ?? true) {
        print('❌ Identity Tokenが取得できませんでした');
        throw Exception('Apple認証でIdentity Tokenが取得できませんでした');
      }
      
      if (appleCredential.authorizationCode?.isEmpty ?? true) {
        print('❌ Authorization Codeが取得できませんでした');
        throw Exception('Apple認証でAuthorization Codeが取得できませんでした');
      }
      
      // Firebase認証用のクレデンシャルを作成
      print('🔑 Firebase認証用クレデンシャル作成中...');
      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );
      
      print('Firebase認証試行中...');
      // Firebaseにサインイン
      final UserCredential userCredential = await _auth.signInWithCredential(oauthCredential);
      
      print('Firebase認証成功! UID: ${userCredential.user?.uid}');
      print('Email: ${userCredential.user?.email}');
      print('Display Name: ${userCredential.user?.displayName}');
      print('Provider Data: ${userCredential.user?.providerData.map((p) => p.providerId).toList()}');
      
      // 既存プロフィールの確認（上書きを絶対に防ぐ）
      await _ensureUserProfileExists(userCredential.user!);
      
      print('✅ Apple Sign In完全成功: ${userCredential.user?.uid}');
      print('=== Apple Sign In Debug End ===');
      return userCredential;
    } catch (e, stackTrace) {
      print('❌ Apple Sign Inエラー: $e');
      print('エラータイプ: ${e.runtimeType}');
      print('スタックトレース: $stackTrace');
      
      // 詳細なエラー分析
      if (e.toString().contains('SignInWithAppleAuthorizationError')) {
        print('👤 AUTHORIZATION_ERROR: ユーザーがサインインをキャンセルしました');
      } else if (e.toString().contains('NotSupported')) {
        print('⚠️ NOT_SUPPORTED: Apple Sign Inがサポートされていません');
      } else if (e.toString().contains('InvalidCredential')) {
        print('🔑 INVALID_CREDENTIAL: 認証情報が無効です');
      } else if (e.toString().contains('NetworkError')) {
        print('🌐 NETWORK_ERROR: ネットワーク接続の問題です');
      } else if (e.toString().contains('UserNotFound')) {
        print('👤 USER_NOT_FOUND: ユーザーが見つかりません');
      } else {
        print('❓ 未知のエラー: $e');
      }
      
      print('=== Apple Sign In Debug End ===');
      rethrow; // エラーを再度投げて詳細情報をUIに表示
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

  // 匿名アカウントをGoogleアカウントにリンク（データ保持）
  Future<UserCredential?> linkAnonymousWithGoogle() async {
    try {
      if (currentUser == null || !currentUser!.isAnonymous) {
        print('匿名ユーザーではありません');
        return null;
      }

      print('=== 匿名アカウントからGoogleアカウントへの移行開始 ===');
      final String anonymousUid = currentUser!.uid;
      print('匿名UID: $anonymousUid');
      
      // 匿名ユーザーのデータをバックアップ
      print('📦 匿名ユーザーデータのバックアップ中...');
      final guestData = await _backupAnonymousUserData(anonymousUid);

      // Google Sign Inが利用可能かチェック（iPad対応）
      print('🔍 Google Sign In初期化チェック中...');
      try {
        if (!await GoogleSignIn.standard().isSignedIn()) {
          print('Google Sign Inの初期化確認完了');
        } else {
          print('既存のGoogle Sign Inセッションを検出');
        }
      } catch (initError) {
        print('⚠️ Google Sign In初期化エラー: $initError');
      }

      // Google認証フローを開始（iPad安全モード + タイムアウト）
      GoogleSignInAccount? googleUser;
      try {
        print('🔐 Google Sign In開始（iPad対応モード + 45秒タイムアウト）...');
        
        // タイムアウト付きでGoogle Sign Inを実行
        googleUser = await _googleSignIn.signIn().timeout(
          const Duration(seconds: 45),
          onTimeout: () {
            print('❌ Google Sign Inがタイムアウトしました（45秒）');
            throw TimeoutException('Google Sign Inがタイムアウトしました', const Duration(seconds: 45));
          },
        );
      } catch (signInError) {
        print('❌ Google Sign Inエラー (詳細): $signInError');
        print('エラータイプ: ${signInError.runtimeType}');
        
        // タイムアウトエラーの場合は再試行しない
        if (signInError is TimeoutException) {
          print('⏰ タイムアウトエラー - 再試行せずに終了');
          rethrow;
        }
        
        // iPad特有のエラーをチェック
        if (signInError.toString().contains('7') || 
            signInError.toString().contains('SIGN_IN_CANCELLED') ||
            signInError.toString().contains('SIGN_IN_FAILED')) {
          print('🔄 iPad用フォールバック認証を試行中...');
          
          try {
            // GoogleSignInをリセットして再試行
            await _googleSignIn.signOut();
            await Future.delayed(const Duration(milliseconds: 500));
            
            // 再試行もタイムアウト付き
            googleUser = await _googleSignIn.signIn().timeout(
              const Duration(seconds: 30),
              onTimeout: () {
                print('❌ リトライもタイムアウトしました（30秒）');
                throw TimeoutException('Google Sign Inリトライがタイムアウトしました', const Duration(seconds: 30));
              },
            );
          } catch (retryError) {
            print('❌ リトライ認証も失敗: $retryError');
            rethrow;
          }
        } else {
          rethrow;
        }
      }
      
      if (googleUser == null) {
        print('Googleサインインがキャンセルされました');
        return null;
      }

      print('✅ Google Sign In成功: ${googleUser.email}');

      // Google認証の詳細を取得（安全チェック付き）
      GoogleSignInAuthentication? googleAuth;
      try {
        googleAuth = await googleUser.authentication;
        
        if (googleAuth.accessToken == null || googleAuth.idToken == null) {
          print('❌ Google認証トークンが無効です');
          throw Exception('Google認証トークンの取得に失敗しました');
        }
        
        print('✅ Google認証トークン取得成功');
      } catch (authError) {
        print('❌ Google認証詳細取得エラー: $authError');
        throw Exception('Google認証の詳細取得に失敗しました: $authError');
      }

      // Firebase認証用のクレデンシャルを作成
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 匿名アカウントにGoogleアカウントをリンク（安全チェック付き）
      UserCredential? userCredential;
      try {
        print('🔗 Firebase アカウントリンク実行中...');
        userCredential = await currentUser!.linkWithCredential(credential);
        print('✅ アカウントリンク成功: ${userCredential.user?.uid}');
      } catch (linkError) {
        print('❌ アカウントリンクエラー: $linkError');
        
        // リンクエラーの詳細分析
        if (linkError is FirebaseAuthException) {
          print('Firebase認証エラーコード: ${linkError.code}');
          print('Firebase認証エラーメッセージ: ${linkError.message}');
        }
        
        rethrow;
      }
      
      // データが保持されているか確認（UIDは変わらないはず）
      if (guestData != null) {
        print('✅ ゲストデータが保持されました');
        await _markDataAsMigrated(userCredential.user!.uid);
      }
      
      return userCredential;
    } catch (e) {
      print('❌ アカウントリンクエラー: $e');
      
      // 既に同じメールアドレスでアカウントが存在する場合の処理
      if (e is FirebaseAuthException && e.code == 'credential-already-in-use') {
        print('🔄 既存のGoogleアカウントに移行します');
        
        // 現在の匿名データをバックアップ
        final anonymousUid = currentUser?.uid;
        Map<String, dynamic>? guestData;
        if (anonymousUid != null) {
          guestData = await _backupAnonymousUserData(anonymousUid);
        }
        
        // 既存アカウントでサインイン
        final existingUserCredential = await signInWithGoogle();
        
        // ゲストデータがあれば、既存ユーザーデータと統合
        if (existingUserCredential != null && guestData != null) {
          await _mergeGuestDataToExistingUser(existingUserCredential.user!.uid, guestData);
        }
        
        return existingUserCredential;
      }
      
      return null;
    }
  }
  
  // 匿名ユーザーデータのバックアップ
  Future<Map<String, dynamic>?> _backupAnonymousUserData(String anonymousUid) async {
    try {
      print('📋 匿名ユーザーデータ読み取り: $anonymousUid');
      
      // プロフィールデータ取得
      final profileDoc = await _firestore.collection('userProfiles').doc(anonymousUid).get();
      final ratingDoc = await _firestore.collection('userRatings').doc(anonymousUid).get();
      
      if (!profileDoc.exists) {
        print('ℹ️ 匿名ユーザーのプロフィールデータが見つかりません');
        return null;
      }
      
      final profileData = profileDoc.data() as Map<String, dynamic>;
      final ratingData = ratingDoc.exists ? ratingDoc.data() as Map<String, dynamic> : null;
      
      print('✅ バックアップ完了 - プロフィール: ${profileData.keys}, レーティング: ${ratingData?.keys}');
      
      return {
        'profile': profileData,
        'rating': ratingData,
        'originalUid': anonymousUid,
      };
    } catch (e) {
      print('❌ 匿名ユーザーデータバックアップエラー: $e');
      return null;
    }
  }
  
  // データ移行完了フラグの設定
  Future<void> _markDataAsMigrated(String uid) async {
    try {
      await _firestore.collection('userProfiles').doc(uid).update({
        'migratedFromGuest': true,
        'migrationTimestamp': FieldValue.serverTimestamp(),
      });
      print('✅ データ移行フラグ設定完了');
    } catch (e) {
      print('❌ 移行フラグ設定エラー: $e');
    }
  }
  
  // ゲストデータを既存ユーザーにマージ
  Future<void> _mergeGuestDataToExistingUser(String existingUid, Map<String, dynamic> guestData) async {
    try {
      print('🔀 ゲストデータを既存ユーザーにマージ開始: $existingUid');
      
      final guestProfile = guestData['profile'] as Map<String, dynamic>?;
      final guestRating = guestData['rating'] as Map<String, dynamic>?;
      
      if (guestProfile == null) return;
      
      // 既存ユーザーデータを確認
      final existingProfileDoc = await _firestore.collection('userProfiles').doc(existingUid).get();
      final existingRatingDoc = await _firestore.collection('userRatings').doc(existingUid).get();
      
      // 設定可能なデータのみマージ（重要なデータは既存を優先）
      Map<String, dynamic> mergeData = {};
      
      // AIメモリがあれば統合
      if (guestProfile['aiMemory'] != null && guestProfile['aiMemory'].toString().isNotEmpty) {
        mergeData['aiMemory'] = guestProfile['aiMemory'];
      }
      
      // テーマ設定があれば適用
      if (guestProfile['themeIndex'] != null) {
        mergeData['themeIndex'] = guestProfile['themeIndex'];
      }
      
      // アイコン設定があれば適用
      if (guestProfile['iconPath'] != null && guestProfile['iconPath'] != 'aseets/icons/Woman 1.svg') {
        mergeData['iconPath'] = guestProfile['iconPath'];
      }
      
      if (mergeData.isNotEmpty) {
        mergeData['lastMergedFromGuest'] = FieldValue.serverTimestamp();
        await _firestore.collection('userProfiles').doc(existingUid).update(mergeData);
        print('✅ プロフィールデータマージ完了: ${mergeData.keys}');
      }
      
      // レーティングデータの統合（より高い方を採用）
      if (guestRating != null && existingRatingDoc.exists) {
        final existingRatingData = existingRatingDoc.data() as Map<String, dynamic>;
        final guestRatingValue = guestRating['rating'] as int? ?? 1000;
        final existingRatingValue = existingRatingData['rating'] as int? ?? 1000;
        
        if (guestRatingValue > existingRatingValue) {
          await _firestore.collection('userRatings').doc(existingUid).update({
            'rating': guestRatingValue,
            'mergedFromGuest': FieldValue.serverTimestamp(),
          });
          print('✅ より高いゲストレーティングを適用: $guestRatingValue');
        }
      }
      
      print('✅ ゲストデータマージ完了');
      
    } catch (e) {
      print('❌ ゲストデータマージエラー: $e');
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

  // データベースのユーザーデータ確認と適切な移行処理
  Future<void> _ensureUserProfileExists(User user) async {
    try {
      print('=== ユーザーデータ確認・移行処理開始 ===');
      print('ユーザーUID: ${user.uid}');
      print('匿名ユーザー: ${user.isAnonymous}');
      
      final userDoc = _firestore.collection('userProfiles').doc(user.uid);
      final docSnapshot = await userDoc.get();
      
      if (docSnapshot.exists) {
        // 既存ユーザーデータが存在する場合
        print('✅ 既存ユーザーデータが見つかりました: ${user.uid}');
        final existingData = docSnapshot.data() as Map<String, dynamic>;
        print('既存ニックネーム: ${existingData['nickname'] ?? '未設定'}');
        print('既存レーティング確認中...');
        
        // レーティングデータも確認
        final ratingDoc = _firestore.collection('userRatings').doc(user.uid);
        final ratingSnapshot = await ratingDoc.get();
        if (ratingSnapshot.exists) {
          final ratingData = ratingSnapshot.data() as Map<String, dynamic>;
          print('既存レーティング: ${ratingData['rating'] ?? 1000}');
        }
        
        print('既存データを使用します');
        return;
      }
      
      // 新規ユーザーの場合：ゲストデータがあれば移行、なければ新規作成
      print('🆕 新規ユーザーです。ゲストデータの確認を行います...');
      
      // 現在のデバイスの匿名ユーザーからデータを移行する機能
      await _migrateFromGuestIfNeeded(user);
      
    } catch (e) {
      print('❌ ユーザーデータ確認エラー: $e');
    }
  }
  
  // ゲストユーザーからのデータ移行処理
  Future<void> _migrateFromGuestIfNeeded(User newUser) async {
    try {
      print('📦 ゲストデータ移行処理開始');
      
      // 現在ローカルに保存されている可能性のあるデータを確認
      // まずは新規プロフィールを作成してから、後でローカルデータで上書きする戦略
      
      await _createNewUserProfile(newUser);
      
      print('✅ 新規ユーザープロフィール作成完了');
      print('💡 ヒント: ローカルデータがある場合は、設定画面から手動で移行してください');
      
    } catch (e) {
      print('❌ ゲストデータ移行エラー: $e');
    }
  }
  
  // 新規ユーザープロフィール作成
  Future<void> _createNewUserProfile(User user) async {
    try {
      print('🎯 新規プロフィール作成: ${user.uid}');
      
      // プロフィール作成
      final userDoc = _firestore.collection('userProfiles').doc(user.uid);
      await userDoc.set({
        'nickname': null,
        'email': null,
        'iconPath': 'aseets/icons/Woman 1.svg',
        'gender': null,
        'birthday': null,
        'comment': null,
        'aiMemory': null,
        'themeIndex': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
        'isAnonymous': user.isAnonymous,
        'migratedFromGuest': false, // 移行フラグ
      });

      // レーティング初期化
      final ratingDoc = _firestore.collection('userRatings').doc(user.uid);
      await ratingDoc.set({
        'rating': 1000, // 初期レーティング
        'totalGames': 0,
        'winStreak': 0,
        'maxWinStreak': 0,
        'lastGameAt': null,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      print('✅ 新規プロフィール・レーティング作成完了');
      
    } catch (e) {
      print('❌ 新規プロフィール作成エラー: $e');
      rethrow;
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