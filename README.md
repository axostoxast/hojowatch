# 補助金ウォッチ（HojoWatch）— B3

受付中の補助金をjGrants公開APIから探し、ウォッチした補助金の締切前にローカル通知で知らせるiOSアプリ。
サーバーなし（端末からAPIを直接呼ぶ）。無料はウォッチ3件まで・通知は7日前／3日前／前日。プロ版（買い切り¥480）でウォッチ無制限・通知タイミング（30日前〜当日）を設定できる。

## 構成
```
project.yml             XcodeGen定義（.xcodeprojはここから生成）
HojoWatch.storekit      ローカル購入テスト用（com.sidebiz.hojowatch.pro ¥480）
HojoWatch/Models        Subsidy（API応答。一覧と詳細の書式差を吸収）、WatchedSubsidy（SwiftData）
HojoWatch/Services      JGrantsClient、Deadline（日数・金額表示、通知計画、無料枠）、ProStore（StoreKit 2）
HojoWatch/Views         探す／ウォッチ／設定のタブ、課金画面
HojoWatchTests          Swift Testing
```

## jGrants APIの注意（2026-10実測）
- 一覧 `/exp/v1/public/subsidies`: keywordは2文字以上必須（短いと400）。`sort=acceptance_end_datetime` は締切順にならないことがあるので手元で並べ直す
- 詳細は `/exp/v1/public/subsidies/id/{id}` を使う（v2には締切がない）。金額が文字列、日時が `T14:59Z`（秒なし）
- 1秒10回まで。ウォッチの締切更新は0.3秒間隔
- 利用規約により、出典・加工の明示・政府が保証しない旨の表示が必須（探す画面のフッターと設定画面に表示）

## 開発
- 生成: `xcodegen generate` ／ テスト: `xcodebuild test -project HojoWatch.xcodeproj -scheme HojoWatch -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -derivedDataPath build`
- `-autoSearch` 起動引数（DEBUGのみ）で起動時に検索を実行（スクリーンショット・動作確認用）
- 通知は締切日（日本時間）の n 日前の朝9時。iOSの予約上限64件に対し60件まで

## 未着手
- 実機での通知・購入確認、App Store Connect登録（アプリ・IAP）、サポートページ・プライバシーポリシー、スクリーンショット、GitHubリポジトリ
