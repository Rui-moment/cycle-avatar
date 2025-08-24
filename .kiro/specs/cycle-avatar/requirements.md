# CycleAvatar Requirements Document

## Introduction

CycleAvatarは、初心者が継続しやすいように設計されたモバイルファーストの筋トレアプリです。回復サイクルをシンプルなゲームとして可視化し、「賢く（smart）トレーニングしたときに」アバターが成長する仕組みを提供します。オフライン優先のアーキテクチャにより、通信が不安定な環境でも安定して利用できます。

## Requirements

### Requirement 1: クイックログ機能

**User Story:** As a 筋トレ初心者, I want to log my workout sets in under 10 seconds per exercise, so that I can focus on training rather than data entry.

#### Acceptance Criteria

1. WHEN ユーザーがセット追加ボタンをタップ THEN システム SHALL 前回の重量と回数を自動入力として表示する
2. WHEN ユーザーが重量と回数を入力 THEN システム SHALL 150ms以内にセットを保存する
3. WHEN ユーザーがRPE（主観的運動強度）を選択 THEN システム SHALL 1-10のスケールで入力を受け付ける
4. WHEN ユーザーがオフライン状態でログを記録 THEN システム SHALL ローカルDBに安全に保存し、オンライン復帰時に同期する
5. IF ユーザーが同じ種目を連続で記録 THEN システム SHALL ワンタップでセット追加を可能にする

### Requirement 2: 筋群別疲労・回復システム

**User Story:** As a トレーニング継続に悩むユーザー, I want to see the fatigue and recovery status of different muscle groups, so that I can train optimally and avoid overtraining.

#### Acceptance Criteria

1. WHEN ユーザーがセットを完了 THEN システム SHALL 対象筋群の疲労スコアを体積・強度・RPEから算出する
2. WHEN 時間が経過 THEN システム SHALL 指数減衰モデルで各筋群の回復を計算する
3. WHEN ユーザーがホーム画面を表示 THEN システム SHALL 各筋群を「Ready（緑）」「Warm（黄）」「Fatigued（赤）」で表示する
4. WHEN 筋群が回復完了 THEN システム SHALL 通知でユーザーに知らせる
5. IF 複数筋群が同時にトレーニング対象 THEN システム SHALL 主働筋と補助筋を適切に重み付けして疲労を配分する

### Requirement 3: アバター成長システム

**User Story:** As a モチベーション維持に苦労するユーザー, I want my avatar to grow when I train smartly, so that I feel rewarded for proper training progression.

#### Acceptance Criteria

1. WHEN ユーザーが最適回復ウィンドウ内で漸進を達成 THEN システム SHALL 対応する筋群領域のアバターレベルを上昇させる
2. WHEN ユーザーがオーバートレーニング状態でトレーニング THEN システム SHALL アバター成長にクールダウンを適用する
3. WHEN アバターがレベルアップ THEN システム SHALL 視覚的なセレブレーションアニメーションを表示する
4. WHEN ユーザーがアバター画面を表示 THEN システム SHALL 各筋群領域のレベルと次のレベルまでの進捗を表示する
5. IF ユーザーが長期間トレーニングを休止 THEN システム SHALL アバターの成長速度を段階的に減速させる

### Requirement 4: スマートプラン提案

**User Story:** As a トレーニングプランに迷うユーザー, I want the app to suggest my next workout based on my recovery status and goals, so that I can train effectively without overthinking.

#### Acceptance Criteria

1. WHEN ユーザーがプラン画面を開く THEN システム SHALL 直近のボリューム・回復状態・目標から次回セッションを提案する
2. WHEN ユーザーが筋肥大目標を設定 THEN システム SHALL 8-12回レンジでのトレーニングを優先提案する
3. WHEN ユーザーが筋力目標を設定 THEN システム SHALL 1-5回レンジでのトレーニングを優先提案する
4. WHEN 複数筋群がReady状態 THEN システム SHALL Upper/Lower または Push/Pull/Legs の分割を提案する
5. IF 全体的な疲労が高い THEN システム SHALL デロード週を提案する

### Requirement 5: 進捗追跡と動機付け

**User Story:** As a 長期的な成長を実感したいユーザー, I want to see my progress highlights and achievements, so that I stay motivated to continue training.

#### Acceptance Criteria

1. WHEN 週が終了 THEN システム SHALL 週次ハイライト（総ボリューム、PR、連続記録）を表示する
2. WHEN ユーザーがPR（個人記録）を達成 THEN システム SHALL 即座に祝福メッセージとバッジを表示する
3. WHEN ユーザーが連続トレーニング記録を更新 THEN システム SHALL ストリークカウンターを更新し、マイルストーンで特別バッジを付与する
4. WHEN ユーザーが履歴画面を表示 THEN システム SHALL 過去4週間のボリューム推移をグラフで表示する
5. IF ユーザーが目標達成 THEN システム SHALL マイクロバッジとして記録し、アバター装飾として反映する

### Requirement 6: オフライン優先同期

**User Story:** As a 通信環境が不安定な場所でトレーニングするユーザー, I want to record my workouts completely offline, so that I never lose my training data.

#### Acceptance Criteria

1. WHEN ユーザーがオフライン状態 THEN システム SHALL 全ての機能を完全にローカルで動作させる
2. WHEN ユーザーがオンラインに復帰 THEN システム SHALL バックグラウンドで自動同期を開始する
3. WHEN 同期中に競合が発生 THEN システム SHALL クライアント優先で解決し、サーバーデータを上書きする
4. WHEN 同期が失敗 THEN システム SHALL リトライキューに追加し、次回オンライン時に再試行する
5. IF 長期間オフライン THEN システム SHALL ローカルデータの整合性を保持し、同期時にバッチ処理する

### Requirement 7: 通知システム

**User Story:** As a トレーニングタイミングを最適化したいユーザー, I want to receive smart notifications about my recovery status, so that I can train at the optimal time.

#### Acceptance Criteria

1. WHEN 筋群が回復完了 THEN システム SHALL 「背中＆二頭が8時間後にReady」などの具体的通知を送信する
2. WHEN デロード推奨状態 THEN システム SHALL 「今週はデロード推奨」通知を送信する
3. WHEN ユーザーが通知設定を変更 THEN システム SHALL 個別筋群・時間帯・頻度の設定を保存する
4. WHEN ユーザーが就寝時間帯 THEN システム SHALL 通知を自動的に停止する
5. IF ユーザーが通知を無視し続ける THEN システム SHALL 通知頻度を段階的に減少させる

### Requirement 8: 多言語対応

**User Story:** As a 日本語または英語を使用するユーザー, I want the app to display in my preferred language, so that I can use it comfortably.

#### Acceptance Criteria

1. WHEN アプリが初回起動 THEN システム SHALL デバイス言語設定から日本語/英語を自動選択する
2. WHEN ユーザーが言語を変更 THEN システム SHALL 全てのUI要素を即座に切り替える
3. WHEN 種目名が表示される THEN システム SHALL 選択言語に対応した名称を表示する
4. WHEN 筋群名が表示される THEN システム SHALL ローカライズされた筋群名を使用する
5. IF 翻訳が存在しない項目 THEN システム SHALL 英語をフォールバックとして表示する

### Requirement 9: データエクスポート・削除

**User Story:** As a プライバシーを重視するユーザー, I want to export or delete my personal data, so that I have control over my information.

#### Acceptance Criteria

1. WHEN ユーザーがデータエクスポートを要求 THEN システム SHALL 全トレーニングデータをJSON形式で提供する
2. WHEN ユーザーがアカウント削除を要求 THEN システム SHALL 30日以内に全個人データを完全削除する
3. WHEN データ削除が完了 THEN システム SHALL ユーザーに削除完了通知を送信する
4. WHEN ユーザーがローカルデータクリアを実行 THEN システム SHALL デバイス上の全データを安全に削除する
5. IF データエクスポート中にエラー THEN システム SHALL 部分データでも利用可能な形式で提供する

### Requirement 10: アクセシビリティ

**User Story:** As a 視覚・聴覚・運動機能に制約があるユーザー, I want the app to be accessible, so that I can use all features effectively.

#### Acceptance Criteria

1. WHEN スクリーンリーダーが有効 THEN システム SHALL 全UI要素に適切なラベルを提供する
2. WHEN ユーザーが大きなフォントを設定 THEN システム SHALL レイアウトを動的に調整する
3. WHEN ユーザーがハイコントラストモード THEN システム SHALL 色彩を適切に調整する
4. WHEN ユーザーがボタンをタップ THEN システム SHALL 触覚フィードバックを提供する
5. IF ユーザーが音声入力を使用 THEN システム SHALL 重量・回数の音声認識を サポートする