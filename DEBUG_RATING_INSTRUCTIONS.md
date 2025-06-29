# 🚨 TEMPORARY DEBUG FUNCTIONS - RATING MANAGEMENT

## ⚠️ IMPORTANT WARNING
**These are temporary debug functions created specifically for updating serveman520@gmail.com user's rating to 1.**
**MUST BE DELETED AFTER USE - DO NOT LEAVE IN PRODUCTION CODE**

## Files Modified/Created

### 1. `/lib/services/rating_service.dart`
**Added 3 temporary debug functions:**
- `debugSetUserRatingToOne(String targetEmail)` - Set rating to 1 by email
- `debugSetUserRatingToOneByUid(String userId)` - Set rating to 1 by UID (recommended)
- `debugListAllUsersWithEmail()` - List all users with their emails and UIDs

### 2. `/lib/screens/rating_debug_screen.dart` 
**Created new debug screen with UI for:**
- Listing all users to find the target UID
- Setting rating by email or UID
- Real-time debug output display

### 3. `/lib/screens/settings_screen.dart`
**Added debug menu option:**
- Red-colored debug option in settings screen
- Navigates to RatingDebugScreen

## How to Use

### Step 1: Access Debug Screen
1. Launch the app
2. Go to Settings screen (swipe right from home)
3. Scroll down to find the red "⚠️ DEBUG: Rating Management" option
4. Tap to open the debug screen

### Step 2: Find Target User UID
1. In the debug screen, tap "1. 全ユーザーリスト表示（コンソールログ確認）"
2. Check the console/debug logs for output
3. Look for the target email `serveman520@gmail.com`
4. Copy the UID associated with that email

### Step 3: Update Rating
**Method A: By Email (may not work if email not stored)**
1. Enter `serveman520@gmail.com` in the email field
2. Tap "2. メールアドレスでレーティングを1に設定"

**Method B: By UID (recommended)**
1. Paste the copied UID in the UID field
2. Tap "3. UIDでレーティングを1に設定（推奨）"

### Step 4: Verify Success
- Check the debug output for success messages
- The rating should be updated in both:
  - `userRatings/{userId}` collection
  - `userProfiles/{userId}` collection

## Firebase Firestore Structure

### userRatings Collection
```
userRatings/{userId}
├── currentRating: 1
├── consecutiveUp: 0
├── consecutiveDown: 0
└── lastUpdated: timestamp
```

### userProfiles Collection  
```
userProfiles/{userId}
├── rating: 1 (synchronized)
├── email: "serveman520@gmail.com"
├── nickname: "..."
└── ... other fields
```

## Cleanup Instructions

### AFTER COMPLETING THE TASK, DELETE THE FOLLOWING:

1. **Remove debug functions from rating_service.dart:**
   - Delete `debugSetUserRatingToOne()`
   - Delete `debugSetUserRatingToOneByUid()`
   - Delete `debugListAllUsersWithEmail()`

2. **Delete debug screen file:**
   - Delete `/lib/screens/rating_debug_screen.dart`

3. **Remove debug option from settings:**
   - Remove the import: `import 'rating_debug_screen.dart';`
   - Remove the red debug ListTile container

4. **Delete this instruction file:**
   - Delete `DEBUG_RATING_INSTRUCTIONS.md`

## Debug Function Details

### debugSetUserRatingToOneByUid(String userId)
- **Purpose**: Most reliable method to update rating
- **Process**: 
  1. Validates user exists
  2. Gets current rating data
  3. Creates new RatingData with rating=1
  4. Saves to both userRatings and userProfiles collections
- **Returns**: bool indicating success

### Logging
All debug functions include comprehensive logging:
- ✅ Success indicators
- ❌ Error indicators  
- 📝 Process steps
- 🎯 Target user identification

## Troubleshooting

### If email search fails:
- The email might not be stored in userProfiles
- Use the "list all users" function to find the correct UID
- Use the UID method instead

### If UID method fails:
- Check if the UID is correct (Firebase Auth UID format)
- Verify user exists in Firestore
- Check console logs for detailed error messages

---

**🔥 CRITICAL REMINDER: DELETE ALL DEBUG CODE AFTER USE 🔥**