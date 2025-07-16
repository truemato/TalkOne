import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/font_size_utils.dart';
import '../services/localization_service.dart';
import 'home_screen.dart';

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
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
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
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const HomeScreen(),
          ),
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
              
              // ボタン
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // アプリを終了
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[600],
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        _localizationService.translate('eula_disagree_button'),
                        style: FontSizeUtils.notoSans(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEulaContent() {
    return Text(
      '''第1条（目的）
本規約は、TalkOne（以下「本アプリ」）の利用に関する条件を定めるものです。

第2条（利用条件）
本アプリは13歳以上の方のみご利用いただけます。未成年者は保護者の同意が必要です。

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
本規約に違反した場合、事前通知なくアカウントを停止する場合があります。

第8条（免責事項）
本アプリの利用により生じた損害について、当社は一切の責任を負いません。

第9条（規約の変更）
本規約は事前通知により変更する場合があります。

第10条（準拠法）
本規約は日本法に準拠します。

最終更新：2025年1月

お問い合わせ：support@talkone.jp''',
      style: FontSizeUtils.notoSans(
        fontSize: 14,
        color: Colors.black87,
        height: 1.6,
      ),
    );
  }
}