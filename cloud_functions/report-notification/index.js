const functions = require('firebase-functions');
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');

// Firebase Admin初期化
admin.initializeApp();

// Gmail設定（環境変数から取得）
const gmailEmail = functions.config().gmail.email;
const gmailPassword = functions.config().gmail.password;
const adminEmail = functions.config().admin.email || 'your-admin-email@example.com';

// Nodemailer設定
const transporter = nodemailer.createTransporter({
  service: 'gmail',
  auth: {
    user: gmailEmail,
    pass: gmailPassword
  }
});

/**
 * 新しい通報が作成されたときに実行されるCloud Function
 */
exports.sendReportNotification = functions.firestore
  .document('reports/{reportId}')
  .onCreate(async (snap, context) => {
    try {
      const reportData = snap.data();
      const reportId = context.params.reportId;
      
      console.log('新しい通報を受信:', reportId);
      
      // 通報者と被通報者の情報を取得
      const [reporterData, reportedUserData] = await Promise.all([
        getUserProfile(reportData.reporterId),
        getUserProfile(reportData.reportedUserId)
      ]);
      
      // メール内容を作成
      const emailContent = createEmailContent(reportData, reporterData, reportedUserData, reportId);
      
      // メールを送信
      await sendEmail(emailContent);
      
      // Slack通知（オプション）
      // await sendSlackNotification(reportData, reportId);
      
      console.log('通報通知を正常に送信しました:', reportId);
      
    } catch (error) {
      console.error('通報通知エラー:', error);
      throw error;
    }
  });

/**
 * ユーザープロフィールを取得
 */
async function getUserProfile(userId) {
  try {
    const userDoc = await admin.firestore().collection('userProfiles').doc(userId).get();
    return userDoc.exists ? userDoc.data() : { nickname: 'My Name', uid: userId };
  } catch (error) {
    console.error('ユーザープロフィール取得エラー:', error);
    return { nickname: 'My Name', uid: userId };
  }
}

/**
 * メール内容を作成
 */
function createEmailContent(reportData, reporterData, reportedUserData, reportId) {
  const timestamp = reportData.reportedAt ? reportData.reportedAt.toDate().toLocaleString('ja-JP') : '不明';
  
  return {
    subject: `【TalkOne】新しい通報が届きました - ${reportData.categoryDisplayName}`,
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h2 style="color: #d32f2f;">🚨 TalkOne - 新しい通報</h2>
        
        <div style="background-color: #fff3cd; border: 1px solid #ffeaa7; padding: 15px; border-radius: 5px; margin: 20px 0;">
          <h3 style="color: #856404; margin-top: 0;">通報概要</h3>
          <p><strong>通報ID:</strong> ${reportId}</p>
          <p><strong>通報時刻:</strong> ${timestamp}</p>
          <p><strong>通報理由:</strong> ${reportData.categoryDisplayName}</p>
          <p><strong>通話ID:</strong> ${reportData.callId || '不明'}</p>
        </div>
        
        <div style="background-color: #f8f9fa; border: 1px solid #dee2e6; padding: 15px; border-radius: 5px; margin: 20px 0;">
          <h3 style="color: #495057; margin-top: 0;">関係者情報</h3>
          <p><strong>通報者:</strong> ${reporterData.nickname} (ID: ${reportData.reporterId})</p>
          <p><strong>被通報者:</strong> ${reportedUserData.nickname} (ID: ${reportData.reportedUserId})</p>
        </div>
        
        ${reportData.details ? `
        <div style="background-color: #e7f3ff; border: 1px solid #b3d9ff; padding: 15px; border-radius: 5px; margin: 20px 0;">
          <h3 style="color: #0c5aa6; margin-top: 0;">詳細情報</h3>
          <p>${reportData.details}</p>
        </div>
        ` : ''}
        
        ${reportData.timestamp ? `
        <div style="background-color: #fff; border: 1px solid #ddd; padding: 15px; border-radius: 5px; margin: 20px 0;">
          <h3 style="color: #333; margin-top: 0;">通話情報</h3>
          <p><strong>通話時間:</strong> ${Math.floor(reportData.timestamp / 60)}分${reportData.timestamp % 60}秒経過時点</p>
        </div>
        ` : ''}
        
        <div style="background-color: #f8d7da; border: 1px solid #f5c6cb; padding: 15px; border-radius: 5px; margin: 20px 0;">
          <h3 style="color: #721c24; margin-top: 0;">⚠️ 重要</h3>
          <p>この通報により、被通報者は通報者によって自動的にブロックされました。</p>
          <p>必要に応じて追加の調査・対応を行ってください。</p>
        </div>
        
        <div style="text-align: center; margin: 30px 0;">
          <a href="https://console.firebase.google.com/project/your-project-id/firestore/data/reports/${reportId}" 
             style="background-color: #1976d2; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px;">
            Firestoreで詳細を確認
          </a>
        </div>
        
        <hr style="margin: 30px 0;">
        <p style="color: #666; font-size: 12px; text-align: center;">
          このメールはTalkOneアプリの自動通知システムから送信されています。<br>
          返信不要です。
        </p>
      </div>
    `
  };
}

/**
 * メールを送信
 */
async function sendEmail(emailContent) {
  const mailOptions = {
    from: `TalkOne通報システム <${gmailEmail}>`,
    to: adminEmail,
    subject: emailContent.subject,
    html: emailContent.html
  };
  
  await transporter.sendMail(mailOptions);
  console.log('管理者メール送信完了:', adminEmail);
}

/**
 * Slack通知（オプション - 将来実装用）
 */
async function sendSlackNotification(reportData, reportId) {
  // TODO: Slack Webhook URLを使用してSlackに通知
  // const slackWebhookUrl = functions.config().slack.webhook_url;
  // if (slackWebhookUrl) {
  //   // Slack通知を送信
  // }
}

/**
 * 緊急通報処理（高優先度の通報）
 */
exports.handleEmergencyReport = functions.firestore
  .document('reports/{reportId}')
  .onCreate(async (snap, context) => {
    const reportData = snap.data();
    
    // 緊急性の高い通報カテゴリーをチェック
    const emergencyCategories = ['violence', 'harassment', 'hateSpeech'];
    
    if (emergencyCategories.includes(reportData.category)) {
      console.log('緊急通報を検出:', context.params.reportId);
      
      // 緊急通知メールを送信
      await sendEmergencyEmail(reportData, context.params.reportId);
      
      // 必要に応じて追加の緊急処理
      // - 被通報者の一時停止
      // - 管理者への即座の通知
    }
  });

/**
 * 緊急メールを送信
 */
async function sendEmergencyEmail(reportData, reportId) {
  const mailOptions = {
    from: `TalkOne緊急通報 <${gmailEmail}>`,
    to: adminEmail,
    subject: `🚨【緊急】TalkOne - ${reportData.categoryDisplayName}の通報`,
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; border: 3px solid #d32f2f;">
        <div style="background-color: #d32f2f; color: white; padding: 20px; text-align: center;">
          <h1>🚨 緊急通報アラート</h1>
          <p style="margin: 0; font-size: 18px;">即座の対応が必要です</p>
        </div>
        
        <div style="padding: 20px;">
          <p><strong>通報ID:</strong> ${reportId}</p>
          <p><strong>通報理由:</strong> ${reportData.categoryDisplayName}</p>
          <p><strong>被通報者ID:</strong> ${reportData.reportedUserId}</p>
          <p><strong>通報時刻:</strong> ${reportData.reportedAt ? reportData.reportedAt.toDate().toLocaleString('ja-JP') : '不明'}</p>
          
          <div style="background-color: #ffebee; padding: 15px; border-radius: 5px; margin: 20px 0;">
            <p style="color: #c62828; font-weight: bold;">
              この通報は緊急性が高いと判断されました。速やかに確認・対応してください。
            </p>
          </div>
        </div>
      </div>
    `
  };
  
  await transporter.sendMail(mailOptions);
  console.log('緊急メール送信完了');
}