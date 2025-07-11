import 'package:flutter/material.dart';
import '../services/enhanced_reporting_service.dart';
import '../utils/font_size_utils.dart';

/// 強化された通報ダイアログ
class EnhancedReportDialog extends StatefulWidget {
  final String reportedUserId;
  final String? callId;
  final VoidCallback? onReportSubmitted;

  const EnhancedReportDialog({
    super.key,
    required this.reportedUserId,
    this.callId,
    this.onReportSubmitted,
  });

  @override
  State<EnhancedReportDialog> createState() => _EnhancedReportDialogState();
}

class _EnhancedReportDialogState extends State<EnhancedReportDialog> {
  final EnhancedReportingService _reportingService = EnhancedReportingService();
  final TextEditingController _detailsController = TextEditingController();
  
  ReportType? _selectedType;
  bool _isSubmitting = false;
  
  final Map<ReportType, String> _reportTypeLabels = {
    ReportType.harassment: '嫌がらせ・誹謗中傷',
    ReportType.inappropriate: '不適切なコンテンツ',
    ReportType.personalInfo: '個人情報の漏洩',
    ReportType.spam: 'スパム・迷惑行為',
    ReportType.violence: '暴力的な内容',
    ReportType.adult: '成人向けコンテンツ',
    ReportType.hate: 'ヘイトスピーチ',
    ReportType.other: 'その他',
  };

  final Map<ReportType, String> _reportTypeDescriptions = {
    ReportType.harassment: '侮辱、脅迫、いじめ等の行為',
    ReportType.inappropriate: '規約に違反する不適切な内容',
    ReportType.personalInfo: '住所、電話番号等の個人情報の要求・開示',
    ReportType.spam: '繰り返しの迷惑行為、商用利用',
    ReportType.violence: '暴力を推奨・描写する内容',
    ReportType.adult: '性的なコンテンツや表現',
    ReportType.hate: '差別的発言、ヘイトスピーチ',
    ReportType.other: '上記に該当しないその他の問題',
  };

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (_selectedType == null) {
      _showErrorMessage('通報理由を選択してください');
      return;
    }

    if (_detailsController.text.trim().isEmpty) {
      _showErrorMessage('詳細内容を入力してください');
      return;
    }

    if (_detailsController.text.trim().length < 10) {
      _showErrorMessage('詳細内容は10文字以上で入力してください');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final success = await _reportingService.submitReport(
        reportedUserId: widget.reportedUserId,
        type: _selectedType!,
        reason: _reportTypeLabels[_selectedType!]!,
        details: _detailsController.text.trim(),
        callId: widget.callId,
      );

      if (success) {
        if (mounted) {
          Navigator.of(context).pop();
          _showSuccessMessage();
          widget.onReportSubmitted?.call();
        }
      } else {
        _showErrorMessage('通報の送信に失敗しました。しばらく経ってから再度お試しください。');
      }
    } catch (e) {
      _showErrorMessage(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showErrorMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: FontSizeUtils.notoSans(fontSize: 14),
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showSuccessMessage() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '通報を送信しました。24時間以内にサポートチームから対応結果をお知らせします。',
            style: FontSizeUtils.notoSans(fontSize: 14),
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ヘッダー
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.report,
                    color: Colors.white,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ユーザーを通報',
                    style: FontSizeUtils.notoSans(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '不適切な行為があった場合は通報してください',
                    style: FontSizeUtils.notoSans(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            
            // コンテンツ
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 通報理由選択
                    Text(
                      '通報理由',
                      style: FontSizeUtils.notoSans(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    ...ReportType.values.map((type) => 
                      _buildReportTypeOption(type)
                    ).toList(),
                    
                    const SizedBox(height: 20),
                    
                    // 詳細入力
                    Text(
                      '詳細内容',
                      style: FontSizeUtils.notoSans(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    TextField(
                      controller: _detailsController,
                      maxLines: 4,
                      maxLength: 500,
                      decoration: InputDecoration(
                        hintText: '具体的な状況を詳しく説明してください（10文字以上）',
                        hintStyle: FontSizeUtils.notoSans(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      style: FontSizeUtils.notoSans(fontSize: 14),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // 注意事項
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '注意事項',
                            style: FontSizeUtils.notoSans(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[800],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '• 虚偽の通報は禁止されています\n• 通報内容は管理者が確認します\n• 24時間以内に対応結果をお知らせします\n• 緊急性が高い場合は優先対応します',
                            style: FontSizeUtils.notoSans(
                              fontSize: 12,
                              color: Colors.blue[700],
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // ボタン
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        'キャンセル',
                        style: FontSizeUtils.notoSans(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitReport,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              '通報する',
                              style: FontSizeUtils.notoSans(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportTypeOption(ReportType type) {
    final isSelected = _selectedType == type;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(
          color: isSelected ? Colors.red : Colors.grey[300]!,
          width: isSelected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
        color: isSelected ? Colors.red[50] : Colors.white,
      ),
      child: RadioListTile<ReportType>(
        value: type,
        groupValue: _selectedType,
        onChanged: (value) => setState(() => _selectedType = value),
        activeColor: Colors.red,
        title: Text(
          _reportTypeLabels[type]!,
          style: FontSizeUtils.notoSans(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.red[800] : Colors.black87,
          ),
        ),
        subtitle: Text(
          _reportTypeDescriptions[type]!,
          style: FontSizeUtils.notoSans(
            fontSize: 12,
            color: isSelected ? Colors.red[600] : Colors.grey[600],
          ),
        ),
        dense: true,
      ),
    );
  }
}