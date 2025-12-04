# iOS 編譯指南

## 問題診斷：module 'flutter_secure_storage' not found

### 根本原因
此錯誤發生是因為 CocoaPods 依賴尚未安裝。`flutter_secure_storage` 是一個需要原生平台支持的 Flutter 插件，它的 iOS 原生代碼必須通過 CocoaPods 進行安裝。

### 解決方案

#### 首次設置或依賴更新後
```bash
# 1. 獲取 Flutter 依賴
flutter pub get

# 2. 進入 iOS 目錄並安裝 CocoaPods 依賴
cd ios
pod install
cd ..
```

#### 清理構建（如果遇到問題）
```bash
# 清理 Flutter 構建緩存
flutter clean

# 重新獲取依賴
flutter pub get

# 清理並重新安裝 Pods
cd ios
rm -rf Pods Podfile.lock
pod install
cd ..
```

## 本地編譯

### 方法 1: 使用 Flutter CLI
```bash
# Debug 模式
flutter build ios --debug

# Release 模式（需要 Apple 開發者證書）
flutter build ios --release

# Release 模式（無代碼簽名，僅用於測試構建）
flutter build ios --release --no-codesign
```

### 方法 2: 使用 Xcode
1. 確保已運行 `pod install`
2. 打開 `ios/Runner.xcworkspace`（**注意：不是 .xcodeproj**）
3. 選擇目標設備或模擬器
4. 點擊 Run 按鈕或按 Cmd+R

## CI/CD 自動構建

### GitHub Actions 工作流程

項目已配置自動 iOS 構建流程，觸發條件：
- Push 到 `main` 分支
- Pull Request
- 手動觸發 (workflow_dispatch)

#### 構建步驟
1. **環境設置**：macOS runner + Flutter 3.32.4
2. **依賴安裝**：`flutter pub get` + `pod install`
3. **代碼檢查**：`flutter analyze`
4. **測試運行**：`flutter test`
5. **iOS 構建**：`flutter build ios --release --no-codesign`
6. **產物上傳**：構建的 .app 文件作為 artifact 保存 30 天

#### 查看構建產物
1. 前往 GitHub Actions 頁面
2. 選擇對應的 workflow run
3. 下載 `ios-build-unsigned` artifact

**注意**：CI 構建的版本未經代碼簽名，無法直接安裝到真實設備上。

## 代碼簽名和發布

### 配置代碼簽名
要發布到 App Store 或安裝到真實設備，需要：

1. **Apple 開發者帳號**（個人或企業）
2. **開發者證書**
   - 開發證書（Development）
   - 發布證書（Distribution）
3. **Provisioning Profile**
4. **App ID** 在 Apple Developer Portal 註冊

### 在 Xcode 中配置
1. 打開 `ios/Runner.xcworkspace`
2. 選擇 Runner target
3. 前往 "Signing & Capabilities" 標籤
4. 設置 Team（需要登錄 Apple ID）
5. 設置 Bundle Identifier
6. Xcode 會自動管理證書和 Provisioning Profile

### 構建用於發布的 IPA
```bash
# 使用 Xcode 構建並存檔
flutter build ipa --release

# IPA 文件位置
# build/ios/ipa/*.ipa
```

## 系統要求

### 開發環境
- macOS 12.0 或更高版本
- Xcode 14.0 或更高版本
- CocoaPods 1.11 或更高版本
- Flutter 3.32.4（推薦）

### iOS 最低版本
- iOS 12.0（在 `ios/Podfile` 中定義）

## 常見問題

### Q: 為什麼要用 .xcworkspace 而不是 .xcodeproj？
A: 當項目使用 CocoaPods 時，Pod 依賴會被組織到一個單獨的 Xcode project 中。`.xcworkspace` 文件包含了主項目和 Pods 項目，必須使用它來確保所有依賴都被正確加載。

### Q: 更新 pubspec.yaml 後需要做什麼？
A: 每次添加或更新依賴後，需要運行：
```bash
flutter pub get
cd ios && pod install && cd ..
```

### Q: CI 構建失敗怎麼辦？
A: 常見原因：
1. Flutter 版本不匹配
2. 依賴衝突
3. Pod 安裝失敗
4. 代碼分析或測試失敗

檢查 GitHub Actions 日誌獲取詳細錯誤信息。

### Q: 如何在 CI 中進行代碼簽名？
A: 需要配置 GitHub Secrets：
- Apple 證書（.p12 格式，base64 編碼）
- Provisioning Profile
- 證書密碼
- Keychain 設置

這需要額外的配置步驟，目前 CI 使用 `--no-codesign` 選項進行無簽名構建。

## 相關文檔

- [Flutter iOS 部署文檔](https://docs.flutter.dev/deployment/ios)
- [CocoaPods 官方指南](https://guides.cocoapods.org/)
- [Apple 開發者文檔](https://developer.apple.com/documentation/)
- [flutter_secure_storage 插件文檔](https://pub.dev/packages/flutter_secure_storage)
