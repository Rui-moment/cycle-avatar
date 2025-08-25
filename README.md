# CycleAvatar

筋肉の回復状態に基づいてアバターが成長するスマートフィットネストラッキングアプリ

A smart fitness tracking app with recovery-based avatar growth system.

## Project Structure

This project follows Clean Architecture principles with the following structure:

```
lib/
├── core/                           # Core functionality
│   ├── app/                       # App configuration
│   │   └── app_router.dart        # GoRouter configuration
│   ├── constants/                 # App constants
│   │   └── muscle_group_constants.dart
│   ├── l10n/                      # Localization
│   │   └── app_localizations.dart
│   ├── providers/                 # Global providers
│   │   └── providers.dart
│   └── theme/                     # App theming
│       └── app_theme.dart
├── data/                          # Data layer
│   ├── datasources/               # Data sources
│   │   └── local/
│   │       └── database_helper.dart
│   └── repositories/              # Repository implementations
│       └── user_repository_impl.dart
├── domain/                        # Domain layer
│   └── entities/                  # Domain entities
│       ├── exercise.dart
│       ├── muscle_group.dart
│       ├── user.dart
│       └── workout_session.dart
├── presentation/                  # Presentation layer
│   └── pages/                     # App pages
│       ├── avatar/
│       ├── history/
│       ├── home/
│       ├── settings/
│       └── workout/
└── l10n/                          # Localization files
    ├── app_en.arb
    └── app_ja.arb
```

## 主な機能 / Features

### 🎯 **コア機能**
- **アニメ調アバターシステム**: 筋群の疲労状態に応じて色が変化するリアルタイムアバター
- **疲労・回復追跡**: 科学的根拠に基づく筋群別疲労度計算
- **スマートワークアウトログ**: 重量・回数・RPEの高速入力
- **多言語対応**: 日本語・英語サポート

### 🏗️ **技術的特徴**
- **Offline-first architecture** with SQLite local storage
- **Multi-language support** (English/Japanese)
- **Clean Architecture** with separation of concerns
- **State management** using Riverpod
- **Material Design 3** theming
- **Cross-platform** (Android/iOS/Web)

## Key Dependencies

- `flutter_riverpod`: State management
- `sqflite`: Local database
- `go_router`: Navigation
- `dio`: HTTP client
- `freezed`: Immutable data classes
- `json_annotation`: JSON serialization

## 起動方法 / Getting Started

### 📱 **クイックスタート（シンプル版）**

```bash
# 1. 依存関係をインストール
flutter pub get

# 2. Webブラウザで起動（推奨）
flutter run -d chrome --web-port=3000 lib/main_simple.dart

# 3. モバイルデバイスで起動
flutter run lib/main_simple.dart
```

### 🔧 **フル機能版の起動**

```bash
# 1. 依存関係をインストール
flutter pub get

# 2. コード生成を実行
flutter pub run build_runner build

# 3. アプリを起動
flutter run lib/main.dart
```

### 🌐 **Web版の起動**

```bash
# ローカルネットワークでアクセス可能にする場合
flutter run -d chrome --web-port=3000 --web-hostname=0.0.0.0 lib/main_simple.dart

# アクセスURL: http://[あなたのIPアドレス]:3000
```

### 📋 **よく使うCLIコマンド**

```bash
# ホットリロード
r

# ホットリスタート  
R

# デバッグ情報表示
d

# アプリ終了
q

# 利用可能なデバイス一覧
flutter devices

# パッケージの更新
flutter pub upgrade

# ビルド（Android APK）
flutter build apk

# ビルド（iOS）
flutter build ios

# テスト実行
flutter test
```

## Architecture Layers

### Domain Layer
Contains business entities and core business logic. Independent of external frameworks.

### Data Layer
Handles data persistence and external API communication. Implements repository interfaces defined in the domain layer.

### Presentation Layer
Contains UI components, pages, and state management. Depends on domain layer through dependency injection.

## 🎮 **アバターシステム**

### 疲労状態の可視化
- **緑色**: 準備完了（疲労度 0-39%）
- **オレンジ色**: ウォーミング（疲労度 40-79%）  
- **赤色**: 疲労状態（疲労度 80%以上）

### 筋群マッピング
- **胸部**: ベンチプレス、プッシュアップ等
- **背中**: デッドリフト、ローイング等
- **脚部**: スクワット、ランジ等
- **肩部**: ショルダープレス等
- **腕部**: カール、エクステンション等

## 🛠️ **開発ガイドライン**

- Clean Architectureの原則に従う
- Riverpodを使用した状態管理
- 適切なエラーハンドリングの実装
- ビジネスロジックの単体テスト作成
- Freezedを使用した不変データクラス
- Flutter/Dartスタイルガイドラインの遵守

## 📁 **ファイル構成**

### 重要なファイル
- `lib/main_simple.dart`: シンプル版のエントリーポイント
- `lib/main.dart`: フル機能版のエントリーポイント
- `lib/presentation/widgets/avatar/anime_avatar_widget.dart`: アニメアバターウィジェット
- `lib/domain/entities/recovery_state.dart`: 回復状態エンティティ

## 🔧 **トラブルシューティング**

### よくある問題と解決方法

#### ポートが使用中のエラー
```bash
# 使用中のポートを確認・停止
lsof -ti:3000 | xargs kill -9

# 別のポートを使用
flutter run -d chrome --web-port=3001 lib/main_simple.dart
```

#### ビルドエラー
```bash
# キャッシュをクリア
flutter clean
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

#### デバイスが認識されない
```bash
# デバイス一覧を確認
flutter devices

# Chromeが見つからない場合
flutter config --enable-web
```

#### 依存関係の問題
```bash
# 依存関係を再インストール
flutter clean
rm pubspec.lock
flutter pub get
```

## 📞 **サポート**

問題が発生した場合は、以下を確認してください：
1. Flutter SDKのバージョン（推奨: 3.16.0以上）
2. Dart SDKのバージョン（推奨: 3.2.0以上）
3. 依存関係が正しくインストールされているか

## 🚀 **今後の予定**

- [ ] プッシュ通知機能
- [ ] ソーシャル機能（友達との比較）
- [ ] より詳細な統計とグラフ
- [ ] カスタムワークアウトプラン
- [ ] ウェアラブルデバイス連携