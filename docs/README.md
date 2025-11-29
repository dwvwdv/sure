# Sure Mobile - 移动端应用技术文档

## 项目简介

Sure Mobile 是 [Sure 个人财务管理系统](https://github.com/we-promise/sure) 的移动端应用，基于 Flutter 框架开发，支持 Android 和 iOS 平台。本应用提供了 Sure 财务管理系统的核心移动功能，允许用户随时随地查看和管理自己的财务账户。

### 与后端的关系

本应用是 Sure 财务管理系统的客户端应用，需要连接到 Sure 后端服务器（Rails API）才能正常使用。后端项目地址：https://github.com/we-promise/sure

## 核心功能

### 1. 后端配置
- **配置服务器地址**：首次启动时需要配置 Sure 后端服务器的 URL
- **连接测试**：提供连接测试功能，验证服务器是否可用
- **地址持久化**：服务器地址保存在本地，下次启动自动加载

### 2. 用户认证
- **登录功能**：支持邮箱和密码登录
- **双因素认证（MFA）**：支持 OTP 验证码二次验证
- **用户注册**：支持新用户注册（后端支持）
- **Token 管理**：
  - Access Token 用于 API 请求认证
  - Refresh Token 用于刷新过期的 Access Token
  - Token 安全存储在设备的安全存储空间
- **自动登录**：应用启动时自动检查本地 Token，如果有效则自动登录
- **设备信息追踪**：登录时记录设备信息，方便后端管理用户会话

### 3. 账户管理
- **账户列表展示**：显示用户的所有财务账户
- **账户分类**：
  - **资产账户（Assets）**：银行账户、投资账户、加密货币、房产、车辆等
  - **负债账户（Liabilities）**：信用卡、贷款等
  - **其他账户**：未分类的账户
- **账户类型支持**：
  - 存款账户（Depository）
  - 信用卡（Credit Card）
  - 投资账户（Investment）
  - 贷款（Loan）
  - 房产（Property）
  - 车辆（Vehicle）
  - 加密货币（Crypto）
  - 其他资产/负债
- **余额显示**：显示每个账户的当前余额和货币类型
- **下拉刷新**：支持下拉刷新账户数据

## 技术架构

### 技术栈
- **框架**：Flutter 3.0+
- **语言**：Dart 3.0+
- **状态管理**：Provider
- **网络请求**：http
- **本地存储**：
  - shared_preferences（非敏感数据，如服务器 URL）
  - flutter_secure_storage（敏感数据，如 Token）

### 项目结构

```
lib/
├── main.dart                      # 应用入口
├── models/                        # 数据模型
│   ├── account.dart              # 账户模型
│   ├── auth_tokens.dart          # 认证 Token 模型
│   └── user.dart                 # 用户模型
├── providers/                     # 状态管理
│   ├── auth_provider.dart        # 认证状态管理
│   └── accounts_provider.dart    # 账户状态管理
├── screens/                       # 页面
│   ├── backend_config_screen.dart # 后端配置页面
│   ├── login_screen.dart         # 登录页面
│   └── dashboard_screen.dart     # 主页面（账户列表）
├── services/                      # 业务服务
│   ├── api_config.dart           # API 配置
│   ├── auth_service.dart         # 认证服务
│   ├── accounts_service.dart     # 账户服务
│   └── device_service.dart       # 设备信息服务
└── widgets/                       # 可复用组件
    └── account_card.dart         # 账户卡片组件
```

## 应用流程详解

### 启动流程

```
应用启动
    ↓
初始化 ApiConfig（加载保存的后端 URL）
    ↓
检查是否配置后端 URL
    ├─ 否 → 显示后端配置页面
    │         ↓
    │       输入并测试 URL
    │         ↓
    │       保存配置
    │         ↓
    └─ 是 → 检查 Token
            ├─ 无效或不存在 → 显示登录页面
            │                    ↓
            │                  用户登录
            │                    ↓
            │                  保存 Token 和用户信息
            │                    ↓
            └─ 有效 → 进入主页面（Dashboard）
```

### 认证流程

#### 1. 登录流程（login_screen.dart）

```
用户输入邮箱和密码
    ↓
点击登录按钮
    ↓
AuthProvider.login()
    ↓
收集设备信息（DeviceService）
    ↓
调用 AuthService.login()
    ↓
发送 POST /api/v1/auth/login
    ├─ 成功（200）
    │   ↓
    │  保存 Access Token 和 Refresh Token
    │   ↓
    │  保存用户信息
    │   ↓
    │  跳转到主页面
    │
    ├─ MFA 要求（401 + mfa_required）
    │   ↓
    │  显示 OTP 输入框
    │   ↓
    │  用户输入验证码
    │   ↓
    │  重新登录（带 OTP）
    │
    └─ 失败
        ↓
       显示错误信息
```

#### 2. Token 刷新流程（auth_provider.dart）

```
需要访问 API
    ↓
检查 Access Token 是否过期
    ├─ 未过期 → 直接使用
    │
    └─ 已过期
        ↓
       获取 Refresh Token
        ↓
       调用 AuthService.refreshToken()
        ↓
       发送 POST /api/v1/auth/refresh
        ├─ 成功
        │   ↓
        │  保存新的 Token
        │   ↓
        │  返回新的 Access Token
        │
        └─ 失败
            ↓
           清除 Token
            ↓
           返回登录页面
```

### 账户数据流程

#### 1. 获取账户列表（dashboard_screen.dart）

```
进入主页面
    ↓
_loadAccounts()
    ↓
从 AuthProvider 获取有效的 Access Token
    ├─ Token 无效
    │   ↓
    │  登出并返回登录页面
    │
    └─ Token 有效
        ↓
       AccountsProvider.fetchAccounts()
        ↓
       调用 AccountsService.getAccounts()
        ↓
       发送 GET /api/v1/accounts
        ├─ 成功（200）
        │   ↓
        │  解析账户数据
        │   ↓
        │  按分类（资产/负债）分组
        │   ↓
        │  更新 UI 显示
        │
        ├─ 未授权（401）
        │   ↓
        │  清除本地数据
        │   ↓
        │  返回登录页面
        │
        └─ 其他错误
            ↓
           显示错误信息
```

#### 2. 账户分类逻辑（accounts_provider.dart）

```dart
// 资产账户：classification == 'asset'
List<Account> get assetAccounts =>
    accounts.where((a) => a.isAsset).toList();

// 负债账户：classification == 'liability'
List<Account> get liabilityAccounts =>
    accounts.where((a) => a.isLiability).toList();

// 未分类账户
List<Account> get uncategorizedAccounts =>
    accounts.where((a) => !a.isAsset && !a.isLiability).toList();
```

### UI 状态管理

应用使用 Provider 进行状态管理，主要有两个 Provider：

#### AuthProvider（auth_provider.dart）
负责管理认证相关状态：
- `isAuthenticated`: 是否已登录
- `isLoading`: 是否正在加载
- `user`: 当前用户信息
- `errorMessage`: 错误信息
- `mfaRequired`: 是否需要 MFA 验证

#### AccountsProvider（accounts_provider.dart）
负责管理账户数据状态：
- `accounts`: 所有账户列表
- `isLoading`: 是否正在加载
- `errorMessage`: 错误信息
- `assetAccounts`: 资产账户列表
- `liabilityAccounts`: 负债账户列表

## API 接口

应用与后端通过以下 API 端点交互：

### 认证相关
- `POST /api/v1/auth/login` - 用户登录
- `POST /api/v1/auth/signup` - 用户注册
- `POST /api/v1/auth/refresh` - 刷新 Token

### 账户相关
- `GET /api/v1/accounts` - 获取账户列表（支持分页）

### 健康检查
- `GET /sessions/new` - 验证后端服务可用性

## 数据模型

### Account（账户模型）
```dart
class Account {
  final String id;              // 账户 ID（UUID）
  final String name;            // 账户名称
  final String balance;         // 余额（字符串格式）
  final String currency;        // 货币类型（如 USD, TWD）
  final String? classification; // 分类（asset/liability）
  final String accountType;     // 账户类型（depository, credit_card 等）
}
```

### AuthTokens（认证 Token）
```dart
class AuthTokens {
  final String accessToken;     // 访问令牌
  final String refreshToken;    // 刷新令牌
  final int expiresIn;          // 过期时间（秒）
  final DateTime expiresAt;     // 过期时间戳
}
```

### User（用户模型）
```dart
class User {
  final String id;              // 用户 ID（UUID）
  final String email;           // 邮箱
  final String firstName;       // 名字
  final String lastName;        // 姓氏
}
```

## 安全机制

### 1. Token 安全存储
- 使用 `flutter_secure_storage` 加密存储 Token
- Token 不会以明文形式保存在普通存储中
- 应用卸载时自动清除敏感数据

### 2. Token 过期处理
- Access Token 过期后自动使用 Refresh Token 刷新
- Refresh Token 失效时要求重新登录
- 所有 API 请求都会检查 Token 有效性

### 3. 设备追踪
- 每次登录记录设备信息（设备 ID、型号、操作系统）
- 后端可以基于设备信息管理用户会话

### 4. HTTPS 支持
- 生产环境强制使用 HTTPS
- 开发环境支持 HTTP（仅用于本地测试）

## 主题与 UI

### Material Design 3
应用采用 Material Design 3 设计规范：
- 动态颜色方案（基于种子颜色 #6366F1）
- 圆角卡片（12px 圆角）
- 自适应布局
- 深色模式支持（跟随系统）

### 响应式设计
- 支持下拉刷新
- 加载状态指示器
- 错误状态展示
- 空状态提示

## 开发与调试

### 环境配置

#### Android 模拟器
```dart
// lib/services/api_config.dart
static String _baseUrl = 'http://10.0.2.2:3000';
```

#### iOS 模拟器
```dart
static String _baseUrl = 'http://localhost:3000';
```

#### 真实设备
```dart
static String _baseUrl = 'http://YOUR_COMPUTER_IP:3000';
// 或使用生产环境 URL
static String _baseUrl = 'https://your-domain.com';
```

### 常用命令

```bash
# 安装依赖
flutter pub get

# 运行应用
flutter run

# 构建 APK
flutter build apk --release

# 构建 App Bundle
flutter build appbundle --release

# 构建 iOS
flutter build ios --release

# 代码分析
flutter analyze

# 运行测试
flutter test
```

### 调试技巧

1. **查看网络请求**：
   - Android Studio: 使用 Network Profiler
   - 或在代码中添加 `print()` 语句

2. **查看存储数据**：
   ```dart
   // 在需要调试的地方添加
   final prefs = await SharedPreferences.getInstance();
   print('Backend URL: ${prefs.getString('backend_url')}');
   ```

3. **清除本地数据**：
   ```bash
   # Android
   adb shell pm clear com.example.sure_mobile

   # iOS 模拟器
   # 长按应用图标 -> 删除应用 -> 重新安装
   ```

## CI/CD

项目配置了 GitHub Actions 自动构建：

### 触发条件
- Push 到 `main` 分支
- 创建 Pull Request 到 `main` 分支
- 仅当 Flutter 相关文件变更时触发

### 构建流程
1. 代码检查（`flutter analyze`）
2. 运行测试（`flutter test`）
3. Android Release 构建（APK + AAB）
4. iOS Release 构建（未签名）
5. 上传构建产物

### 下载构建产物
在 GitHub Actions 页面可以下载：
- `app-release-apk`：Android APK 文件
- `app-release-aab`：Android App Bundle（用于 Google Play）
- `ios-release`：iOS 应用包（需要签名才能分发）

## 未来扩展功能

### 计划中的功能
- **交易记录**：查看和管理交易历史
- **账户同步**：支持银行账户自动同步
- **预算管理**：设置和追踪预算
- **投资追踪**：查看投资收益
- **AI 助手**：财务建议和分析
- **推送通知**：交易提醒和账户变动通知
- **生物识别**：指纹/Face ID 快速登录
- **多语言支持**：中文、英文界面切换
- **图表分析**：财务数据可视化

### 技术改进
- 离线模式支持
- 数据缓存优化
- 更完善的错误处理
- 单元测试和集成测试
- 性能优化

## 许可证

本项目采用 AGPLv3 许可证分发。

## 贡献

欢迎提交 Issue 和 Pull Request！

## 相关链接

- **后端项目**：https://github.com/we-promise/sure
- **Flutter 官方文档**：https://docs.flutter.dev
- **Dart 语言文档**：https://dart.dev/guides
