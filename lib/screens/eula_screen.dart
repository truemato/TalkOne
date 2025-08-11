import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/font_size_utils.dart';
import '../services/localization_service.dart';
import '../main.dart';

class EulaScreen extends StatefulWidget {
  const EulaScreen({super.key});

  @override
  State<EulaScreen> createState() => _EulaScreenState();
}

class _EulaScreenState extends State<EulaScreen> {
  bool _isAgreed = false;
  final ScrollController _scrollController = ScrollController();
  bool _hasScrolledToEnd = false;
  final LocalizationService _localizationService = LocalizationService();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _localizationService.loadLanguagePreference();
    _localizationService.addListener(_onLanguageChanged);
  }

  void _onLanguageChanged() {
    if (mounted) {
      setState(() {
        _hasScrolledToEnd = false; // 言語変更時はスクロール状態をリセット
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _localizationService.removeListener(_onLanguageChanged);
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.atEdge) {
      if (_scrollController.position.pixels != 0) {
        // スクロールが最下部に到達
        setState(() {
          _hasScrolledToEnd = true;
        });
      }
    }
  }

  Future<void> _acceptEula() async {
    if (_isAgreed && _hasScrolledToEnd) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('eula_accepted', true);
      
      if (mounted) {
        // AuthWrapperに戻って認証フローを通す
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const AuthWrapper(),
          ),
          (route) => false,
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF5A64ED),
      appBar: AppBar(
        title: Text(
          _localizationService.translate('eula_title'),
          style: FontSizeUtils.notoSans(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          // 言語切り替えボタン
          PopupMenuButton<String>(
            icon: const Icon(Icons.language, color: Colors.white),
            tooltip: _localizationService.translate('eula_language_switch'),
            onSelected: (String languageCode) {
              _localizationService.setLanguage(languageCode);
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'ja',
                child: Row(
                  children: [
                    if (_localizationService.isJapanese) 
                      const Icon(Icons.check, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(_localizationService.translate('eula_japanese')),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'en',
                child: Row(
                  children: [
                    if (_localizationService.isEnglish) 
                      const Icon(Icons.check, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(_localizationService.translate('eula_english')),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              // EULA テキスト
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Scrollbar(
                    controller: _scrollController,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _localizationService.translate('eula_content_title'),
                            style: FontSizeUtils.notoSans(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildEulaContent(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // スクロール完了メッセージ
              if (!_hasScrolledToEnd)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.vertical_align_bottom,
                        color: Colors.orange,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _localizationService.translate('eula_scroll_instruction'),
                          style: FontSizeUtils.notoSans(
                            fontSize: 14,
                            color: Colors.orange[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              
              if (_hasScrolledToEnd) ...[
                // 同意チェックボックス
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: CheckboxListTile(
                    title: Text(
                      _localizationService.translate('eula_agreement_checkbox'),
                      style: FontSizeUtils.notoSans(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    value: _isAgreed,
                    onChanged: (bool? value) {
                      setState(() {
                        _isAgreed = value ?? false;
                      });
                    },
                    activeColor: Colors.white,
                    checkColor: const Color(0xFF5A64ED),
                    side: const BorderSide(color: Colors.white),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              // 同意ボタンのみ
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isAgreed && _hasScrolledToEnd ? _acceptEula : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isAgreed && _hasScrolledToEnd 
                        ? Colors.green 
                        : Colors.grey[400],
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    _localizationService.translate('eula_agree_button'),
                    style: FontSizeUtils.notoSans(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEulaContent() {
    if (_localizationService.isJapanese) {
      return Text(
        '''エンドユーザーライセンス契約（EULA）

第1条（目的）
本エンドユーザーライセンス契約（以下「本EULA」）は、TalkOne（以下「本アプリ」）の利用に関する条件を定めるものです。

第2条（利用条件・年齢制限）
本アプリは18歳以上の方のみご利用いただけます。18歳未満の方はご利用になれません。
本アプリの利用により、あなたが18歳以上であることを確認・同意したものとみなします。

第3条（禁止事項）
本アプリの利用において、以下の行為を禁止します：
・他のユーザーに対する嫌がらせ、脅迫、差別的発言
・わいせつ、暴力的、または違法な内容の発信
・個人情報の無断開示
・商用目的での利用
・アプリの機能を妨害する行為
・なりすまし行為

第4条（通報システム）
不適切な行為を発見した場合は、通報機能をご利用ください。24時間以内に対応いたします。

第5条（プライバシー）
本アプリは匿名性を重視しており、個人を特定する情報は収集いたしません。ただし、サービス向上のため通話内容をAI学習に使用する場合があります。

第6条（コンテンツフィルタリング）
本アプリではAIによる自動コンテンツフィルタリングを実施しています。不適切な内容は自動的に検出・制限されます。

第7条（アカウント停止）
本EULAに違反した場合、事前通知なくアカウントを停止する場合があります。

第8条（免責事項）
本アプリの利用により生じた損害について、当社は一切の責任を負いません。

第9条（規約の変更）
本EULAは事前通知により変更する場合があります。

第10条（準拠法）
本EULAは日本法に準拠します。

第11条（ゼロトレランスポリシー）
当社は不快なコンテンツおよび不適切なユーザーを一切許容いたしません。違反が確認された場合、即座にアカウント停止等の措置を実施いたします。

第12条（お問い合わせ）
本EULAおよび本アプリに関するご質問・ご意見は下記までお問い合わせください：
メール：mail@yoshida.com

最終更新：2025年7月''',
        style: FontSizeUtils.notoSans(
          fontSize: 14,
          color: Colors.black87,
          height: 1.6,
        ),
      );
    } else {
      return Text(
        '''End User License Agreement (EULA)

Article 1 (Purpose)
This End User License Agreement (hereinafter referred to as "this EULA") defines the terms and conditions for using TalkOne (hereinafter referred to as "this App").

Article 2 (Terms of Use & Age Restriction)
This App is available only to users aged 18 and above. Users under 18 are not permitted to use this App.
By using this App, you confirm and agree that you are 18 years of age or older.

Article 3 (Prohibited Activities)
The following activities are prohibited when using this App:
• Harassment, threats, or discriminatory remarks toward other users
• Transmission of obscene, violent, or illegal content
• Unauthorized disclosure of personal information
• Commercial use
• Activities that interfere with the app's functions
• Impersonation

Article 4 (Reporting System)
If you discover inappropriate behavior, please use the reporting function. We will respond within 24 hours.

Article 5 (Privacy)
This App emphasizes anonymity and does not collect personally identifiable information. However, call content may be used for AI learning to improve services.

Article 6 (Content Filtering)
This App implements automatic content filtering using AI. Inappropriate content is automatically detected and restricted.

Article 7 (Account Suspension)
In case of violation of this EULA, accounts may be suspended without prior notice.

Article 8 (Disclaimer)
We assume no responsibility for any damages arising from the use of this App.

Article 9 (Changes to the Agreement)
This EULA may be changed with prior notice.

Article 10 (Governing Law)
This EULA is governed by Japanese law.

Article 11 (Zero Tolerance Policy)
We have zero tolerance for offensive content and inappropriate users. Any confirmed violations will result in immediate account suspension and other appropriate measures.

Article 12 (Contact Information)
For any questions or concerns regarding this EULA or the App, please contact us at:
Email: mail@yoshida.com

Last Updated: July 2025''',
        style: FontSizeUtils.notoSans(
          fontSize: 14,
          color: Colors.black87,
          height: 1.6,
        ),
      );
    }
  }
}