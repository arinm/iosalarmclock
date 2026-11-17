# Punctual - App Store listing (v1.0.3, Japanese / ja)

Since 1.0.3 the app UI is in Japanese too (String Catalogs, see
`market-research-localization.md`, Japan). v1.0.2 shipped this listing with a
note that the UI was English-only; that note is gone now. UI words quoted here
match `App/Localizable.xcstrings`. Same rules as the English listing: no
price, no discount, no "free" (無料) outside the description, no other platform
names. Translated by Claude and **not yet checked by a native speaker**. Get one
pass from a native speaker before relying on it beyond a first test.

Character limits: name 30 · subtitle 30 · promo 170 · keywords 100 · description 4000.
Counts below were measured with Python `len()`, which is how App Store Connect counts.

## App Name (22/30)
Punctual - 目覚まし時計・アラーム

## Subtitle (24/30)
祝日・休みの日だけスキップ。仕事の日はいつも通り

<!-- 1.0.5 (16 Nov 2026), was 「祝日・休みの日だけスキップ。シフト勤務にも」. Same change as en-US: holidays and days off
     are skipped, workdays ring as usual, and no promise of shift work (Punctual has no rotations). 「アラーム 仕事」 is a
     real App Store search (autocomplete); 仕事の日 also reads better than 平日, which can clash with a weekday holiday. -->

## Promotional Text (110/170)
アプリが日本語表示に対応しました。アラームが鳴るまでの残り時間をいつでも表示。鳴る前に通知でお知らせし、休みの日はワンタップで今日だけスキップ。明日のアラームはそのまま有効です。AppleのAlarmKitで動作します。

## Keywords (99/100)
起床,朝,振替休日,連休,休日,平日,シフト,旅行,休暇,スヌーズ,カウントダウン,通知,リマインダー,寝坊,二度寝,目覚ましアプリ,カレンダー,ゴールデンウィーク,土日,有給,早起き,マナーモード

<!-- None of these repeat a word from the name or subtitle (目覚まし時計, アラーム, 祝日, 休み, スキップ, 仕事, いつも通り).
     1.0.5: 夜勤 + 交代制 → シフト (one shift word; 「シフト アラーム」 is searched), タイマー → マナーモード (Punctual has no
     timer; it rings in silent mode, and 「マナーモード アラーム」 is searched). -->

## Description
Punctualは、アラームが「いつ鳴るか」がひと目でわかり、鳴る前にお知らせしてくれる目覚ましアプリです。休みの日は今日だけスキップ。明日のアラームはそのまま有効です。

アラームのよくある悩み
iPhoneでスキップできるのは、睡眠スケジュールの起床アラームだけ。それ以外のアラームは、祝日や休みの前日にオフにして、また忘れずにオンに戻すしかありません。Punctualなら、すべてのアラームを1日だけスキップできます。

今日だけスキップ、明日は忘れない
ワンタップで今日の1回だけをスキップ。アラームは翌日以降も有効のまま、緑色の「今日はスキップ・有効のまま」で確認でき、取り消しもできます。アラームのカード、事前通知、ロック画面のどこからでもスキップできます。

いつ鳴るか、いつでもわかる
すべてのアラームに、鳴るまでの残り時間（例：「鳴るまであと7時間42分」）をリアルタイムで表示。時刻を選んでいる間も更新されるので、夜中に計算する必要はありません。

鳴る前のお知らせ
アラームの前に静かな通知が届き、そのままスキップできます。布団の中で決められます。

消音モードや集中モードでも鳴ります
AppleのAlarmKitで作られているため、標準の時計アプリと同じように、消音モードや集中モード中でも鳴ります。

基本機能はずっと無料
アラームの数は無制限。残り時間の表示、事前通知、今日だけスキップ、15分までのスヌーズ時間の設定が無料で使えます。広告なし、アカウント不要、トラッキングなし。データはすべて端末内に保存されます。

PUNCTUAL PRO
• 祝日の自動スキップ：選んだカレンダー（例：「日本の祝日」）の終日予定がある日はアラームをスキップ。前日にお知らせが届き、「それでも鳴らす」でその日だけ鳴らすこともできます
• 休暇中の一時停止：期間を指定してアラームを止め、終わると自動で再開
• 事前通知のタイミングや回数、メッセージのカスタマイズ
• 長めのスヌーズ：システム上限の15分を超えて最大60分まで
• アラームのグループ：まとめてスキップや一時停止
• テーマ、アクセントカラー、別のアプリアイコン
• カスタムサウンド：事前通知とアラームに好きな音声を使えます

お支払いは月額、年額、または買い切りから選べます。サブスクリプションが苦手な方は、買い切りなら一度の購入でずっと使えます。

プライバシー
アカウント、分析、トラッキングは一切ありません。アラームのデータが端末の外に送られることはありません。

信頼性についての正直なお知らせ
アラームが必ず鳴ることを保証できるアプリはありません。アラームがいつ鳴るかは最終的にiOSが決めており、電源が切れている端末や電池切れの端末では鳴りません。絶対に遅れられない予定には、別のアラームも設定してください。

iOS 26以降が必要です（AppleのAlarmKitを使用しています）。

サブスクリプションについて
Punctual Proは、自動更新の月額・年額サブスクリプション、または買い切りでご利用いただけます。お支払いは購入確定時にApple Accountに請求されます。現在の期間が終了する24時間前までに自動更新をオフにしない限り、サブスクリプションは自動的に更新されます。管理や解約はApple Accountの設定からいつでも行えます。現在の価格は、購入前にアプリ内で表示されます。

利用規約：https://punctualalarm.com/terms.html
プライバシーポリシー：https://punctualalarm.com/privacy.html
サポート・よくある質問：https://punctualalarm.com/support.html

お問い合わせ：contact@arinitsolutions.com · punctualalarm.com

## What's New (v1.0.3)
• アプリの表示が日本語に対応しました。曜日、時刻、残り時間、通知、ウィジェット、Siriのショートカットもすべて日本語で表示されます。

## What's New (v1.0.2, shipped)
• カレンダーによる自動スキップは、選んだカレンダーだけを使うようになり、スキップされる日がはっきり表示されます。誕生日のカレンダーは対象外です。
• 休みの日の前に、静かなお知らせが1回だけ届きます（アラームごとではなく、祝日や休暇ごとに1回）。「それでも鳴らす」で鳴らすこともできます。
• 自動スキップをオフにすると、すぐに反映されるようになりました。

## Screenshot captions (ja)
Rendered by `motion/duo/duo.py --lang ja` (6.9" and Duo). Since 1.0.3 the frames use the
Japanese UI captures in `app-store-screenshots/iphone-17-pro-max-ja/png`; upload the `-v2`
files from `iphone-69/ja` and `iphone-duo/ja` (the files without `-vN` show the English UI).
1. 今日だけスキップ。明日は忘れない。 / 鳴る前に知らせてくれる目覚まし。
2. いつ鳴るか、ひと目でわかる / すべてのアラームに残り時間を表示。
3. ワンタップで、1日だけお休み。 / 翌日のアラームはそのまま有効。
4. 必要になったらProへ / 祝日の自動スキップ、休暇中の一時停止、アラームのグループなど。
