# npm-menubar

*[English](README.en.md)*

npmのグローバルパッケージ(`npm install -g`)とnpm本体の更新をmacOSのメニュー
バーで監視し、ワンクリックでupgradeできる常駐アプリ。

Volta・nvm・fnmなど主要なバージョンマネージャに対応している。

## ダウンロード

ビルドせずに使いたい場合は、[Releases](https://github.com/n0r1h0/npm-menubar/releases)
から最新版の `NpmMenuBar-*.zip` をダウンロードして展開し、
`NpmMenuBar.app` を `/Applications` に移動するだけで使える。

配布物はApple公証を受けていないため、初回起動時にGatekeeperが
「開発元を確認できないため開けません」と表示することがある。その場合は
Finderでアプリを右クリックして「開く」を選ぶか、以下のコマンドで
隔離属性を外してから起動する。

```sh
xattr -cr /Applications/NpmMenuBar.app
```

## 使い方

メニューバーのアイコン(📦)をクリックすると、以下が表示される。

- npm本体・グローバルパッケージそれぞれの更新状況。個別にupgradeするか、
  まとめて「すべて更新」できる。
- 更新したくないパッケージがある場合は「このバージョンで据え置く」で
  バージョン固定できる。据え置き中のものは「据え置き中」に移動し、
  一覧・解除は環境設定からも行える。
- Volta環境の場合、Node.js本体に同梱されたnpm/パッケージ専用の
  「Node同梱」サブメニューが出ることがある(通常は使わなくてよい)。
- 「今すぐチェック」「環境設定...」「終了」

ステータスバーのアイコンは、平常時は📦、npm本体に更新があると📦!、
グローバルパッケージに更新があるとその件数を表示する。チェック中は
アイコンが明滅する。件数が0件から増えたときだけ通知が届く。

## 環境設定

メニューの「環境設定...」から開く。

- **全般**: ログイン時に自動起動するか、表示言語(システムに従う / 日本語 / English)
- **npm本体 / グローバルパッケージ**: それぞれ独立してチェック頻度
  (15分〜24時間)と、検出時に自動でupgradeするか(OFFなら通知のみ)を設定できる
- **据え置き中**: バージョン固定しているパッケージの一覧と解除

デフォルトはチェック頻度3時間、自動upgradeはOFF(通知のみ)。

## ビルドと起動

前提: Xcodeコマンドラインツール(`swift`コマンド)が使えること。npmが
ログインシェルのPATH上で解決できること(`zsh -l -c "which npm"` などで確認可能)。

```sh
cd npm-menubar
./Scripts/build-app.sh
open NpmMenuBar.app
```

常用する場合は `NpmMenuBar.app` を `/Applications` に移動することを推奨する。
アプリはDockに表示されず、メニューバーにのみ常駐する。

## 既知の制限

- 初回起動時に通知の許可を求めるダイアログが出る。`/Applications` に
  置いていないと許可がうまく通らないことがある(その場合もステータスバーの
  表示自体は問題なく機能する)。
- コマンド実行のたびにログインシェルを起動するため、`.zshrc` などの
  初期化処理が重い環境ではチェックに数百ms〜数秒かかることがある。
- npmが見つからない場合はメニューにその旨を表示するが、npm自体の
  インストールは行わない。
- upgradeが失敗した場合(バージョンマネージャ側の制約など)は、通知と
  メニュー内の表示でエラー内容を知らせる。

## アンインストール

```sh
# ログイン項目に登録していた場合は先に環境設定でOFFにするか:
osascript -e 'tell application "System Events" to delete login item "NpmMenuBar"' 2>/dev/null

rm -rf "/Applications/NpmMenuBar.app"   # /Applicationsに置いた場合
defaults delete com.local.npmmenubar 2>/dev/null
```
