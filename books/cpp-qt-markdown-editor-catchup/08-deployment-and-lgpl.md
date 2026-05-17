---
title: "3 OS 配布 — macdeployqt / windeployqt / AppImage と LGPL §4(d)(1) 実務"
---

「ローカルで動いた」と「ユーザーに配布できる」の間には **2 つのギャップ** がある。

1. Qt フレームワークを実行可能ファイルと一緒にパッケージする (deploy ツール)
2. **Qt の LGPL に従って必要な権利表示・ソース提供を行う** (法務)

本章では実務として必要な手順を OS ごとに示し、最後に LGPL 義務を明確化する。

## macOS — macdeployqt + dmg

```bash
# 1. Release ビルド (CMake)
cmake -S . -B build-release -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_PREFIX_PATH="$(brew --prefix qt)"
cmake --build build-release -j$(sysctl -n hw.ncpu)

# 2. .app バンドルに Qt フレームワークを埋め込む
APP="build-release/src/YourEditor.app"
"$(brew --prefix qt)/bin/macdeployqt" "$APP" -always-overwrite

# 3. 不要な dSYM (デバッグシンボル) を削除
find "$APP" -name "*.dSYM" -exec rm -rf {} + 2>/dev/null || true

# 4. (任意) ストリップでさらに軽量化
strip -r "$APP/Contents/MacOS/YourEditor" || true

# 5. DMG を作る
hdiutil create \
    -volname "YourEditor" \
    -srcfolder "$APP" \
    -ov -format UDZO \
    "YourEditor-macOS.dmg"
```

サイズ目安: **約 80-120MB** (QtWebEngineCore + Chromium が大半)。

### Apple Silicon と Intel の universal binary

`CMAKE_OSX_ARCHITECTURES="arm64;x86_64"` を指定すれば universal binary を吐ける。だが、Homebrew Qt は arm64 only なので vcpkg + 自前 build が必要。最初は arm64 only でリリースして、需要があれば universal を考えるほうが現実的。

### コード署名 + Notarization

App Store の外で配布する場合も、macOS Gatekeeper が「未署名 = 開けない」を出す。

```bash
# 0. 初回のみ: notarytool の credentials プロファイルを keychain に作る
xcrun notarytool store-credentials "AC_PROFILE" \
    --apple-id "you@example.com" \
    --team-id  "XXXXXXXXXX" \
    --password "app-specific-password-xxxx-xxxx-xxxx"

# 1. 署名 (Developer ID Application 証明書が必要、Apple Developer Program USD $99/年、JP 表示は ¥13,000 台で為替変動あり)
codesign --deep --force --verify --verbose \
    --sign "Developer ID Application: YOUR NAME (XXXXXXXXXX)" \
    --options runtime \
    --entitlements entitlements.plist \
    "YourEditor.app"

# 2. Notarize (Apple のサーバで通す、credentials プロファイル参照)
xcrun notarytool submit "YourEditor-macOS.dmg" \
    --keychain-profile "AC_PROFILE" \
    --wait

# 3. Notarization の staple
xcrun stapler staple "YourEditor-macOS.dmg"
```

> 旧 `altool` 時代の `--password "@keychain:..."` 記法は `notarytool` では動かないバージョンがある。`store-credentials` でプロファイルを作って `--keychain-profile` で参照する形が現在の正攻法。

これを通さないと、ユーザーが「開発元が未確認のため開けません」エラーで右クリック → 開く手順を踏む必要がある (UX 大幅低下)。

## Windows — windeployqt + Inno Setup

```cmd
:: 1. Release ビルド
cmake --preset windows-msvc
cmake --build build/windows-msvc --config Release

:: 2. Qt DLL と plugin を deploy
C:\Qt\6.8.3\msvc2022_64\bin\windeployqt.exe ^
    --release ^
    --no-translations ^
    --no-system-d3d-compiler ^
    --no-opengl-sw ^
    build/windows-msvc/src/Release/YourEditor.exe

:: 3. Inno Setup でインストーラを作る (.iss スクリプト)
"C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer.iss
```

`installer.iss` の最小例:

```iss
[Setup]
AppName=YourEditor
AppVersion=0.1.0
DefaultDirName={pf}\YourEditor
OutputBaseFilename=YourEditor-Setup
Compression=lzma
SolidCompression=yes

[Files]
Source: "build\windows-msvc\src\Release\*"; DestDir: "{app}"; Flags: recursesubdirs
Source: "build\windows-msvc\src\Release\editor\*"; DestDir: "{app}\editor"; Flags: recursesubdirs

[Icons]
Name: "{commonprograms}\YourEditor"; Filename: "{app}\YourEditor.exe"
```

サイズ目安: **約 100-150MB** (compressed)。

Windows でも EV コードサイニング証明書があると SmartScreen 警告を回避できるが、ベンダー別で概ね年 USD $300-500 相当と個人開発には高い (2026-05 時点)。最初は無署名で配り、Defender SmartScreen の警告を覚悟する。

## Linux — AppImage / Flatpak

AppImage が一番手軽で、1 ファイル配布できる。

```bash
# 1. Release ビルド
cmake --preset linux-debug -DCMAKE_BUILD_TYPE=Release
cmake --build build/linux-debug

# 2. AppDir 構造を作る
mkdir -p AppDir/usr/{bin,lib,share/applications,share/icons/hicolor/256x256/apps}
cp build/linux-debug/src/youreditor AppDir/usr/bin/
cp -r build/linux-debug/src/editor AppDir/usr/bin/

cat > AppDir/usr/share/applications/youreditor.desktop <<EOF
[Desktop Entry]
Type=Application
Name=YourEditor
Exec=youreditor
Icon=youreditor
Categories=Office;
EOF

cp resources/icon-256.png AppDir/usr/share/icons/hicolor/256x256/apps/youreditor.png

# 3. linuxdeploy + linuxdeploy-plugin-qt で Qt を bundle
./linuxdeploy-x86_64.AppImage \
    --appdir AppDir \
    --plugin qt \
    --output appimage

# YourEditor-x86_64.AppImage が出る
```

サイズ目安: **約 200MB** (Linux は SO の動的リンクが多い)。

## LGPL ソース提供義務 — 法務の本丸

Qt は **LGPL v3** で配布されており、商用ライセンス無しで使う場合は LGPL の義務を負う。Markdown エディタを proprietary (有償・閉鎖ソース) で売る場合の **押さえるべき主要な義務** を整理する。

> **免責**: 以下は実務で踏みやすい主要項目をまとめたチェックリストであり、完全な遵守は LGPL v3 本文 (§4 等) を直接参照し、必要に応じて法務専門家に確認すること。本書は法務助言ではない。

### 義務 1: 動的リンクのみ

Qt と自分のアプリは **動的リンク (.dylib / .dll / .so)** で繋ぐ。静的リンクは LGPL では原則禁止 (再リンクできなくなるため)。`macdeployqt` / `windeployqt` は自動で動的リンク化するのでデフォルトで OK。

### 義務 2: LGPL ライセンス本文の同梱

配布パッケージに `LICENSES/LGPL-3.0.txt` を含める。GPL/LGPL の本文を README や About ダイアログにリンク表示する。

### 義務 3: Qt の改造をしたら、改造部分のソースを公開

Qt 本体のソースを変更してビルドしている場合、その diff を公開する義務がある。**普通のアプリ開発では Qt 本体は無改造で使うため、これは該当しない** が、念のため README に「Qt は無改造の公式ビルドを使用」と明記しておくとリスク回避になる。

### 義務 4: ユーザーが Qt を別バージョンに差し替えられること

LGPL の核心は「ユーザーが Qt を別バージョンに置き換える権利」。動的リンクで配ること自体がこの権利を保証している。**Qt フレームワークを Bundle 内部の固定 path に hardcode してリンクしている場合は要注意**。`@rpath` / `$ORIGIN` を使った相対リンクなら問題なし (macdeployqt / linuxdeploy が自動でやる)。

### 義務 5: 自分のアプリのコードは LGPL を継承しなくて良い

LGPL は「動的リンクなら自分のコードは別ライセンスで配って良い」。ここが GPL との最大の違いで、これがあるから商用配布できる。

### 義務 6 (見落とし注意): ユーザーが Qt を差し替えた変更版を実行できる手段の提供 (§4 (d)(1))

LGPL v3 §4 (d)(1) は「ユーザーが LGPL ライブラリを変更版に差し替えても、結合された Combined Work を実行できる手段を提供すること」を求めている。具体的には、

- アプリのオブジェクトファイル (relinkable form) を要求に応じて提供する、または
- 動的リンク + ユーザーが Qt のみを差し替えれば動く配布形態にする

のどちらかが必要。**動的リンクで配っていれば後者を自動的に満たす**ことが多いが、README で「ユーザーは Qt 部分のみを別バージョンに差し替えて実行できる」「relinkable な object files は問い合わせで提供」と明示しておくと安全側に倒れる。

### 実務まとめ — README に貼るテンプレ

> 以下は **proprietary (有償・閉鎖ソース) で配布する場合のサンプル**。あなたのプロダクトのライセンス方針 (OSS / proprietary / dual) に合わせて文言を選択すること。OSS で出すなら最初の 1 行を該当ライセンス名 (例: GPLv3) に差し替える。

```markdown
## License & Third-Party Notices

YourEditor is proprietary software. Source code of YourEditor itself is not publicly available.

### Third-party libraries

This product uses the following open-source software:

- **Qt 6.8** — LGPL v3 (https://www.qt.io/licensing/)
  Qt framework is dynamically linked. The unmodified official Qt build is used.
  Source code for Qt is available at https://download.qt.io/
  Users may replace the Qt libraries shipped with this product with a modified
  version. Object files of this application suitable for relinking against a
  modified Qt are available upon request to <contact@example.com>.

- **TipTap** — MIT (https://github.com/ueberdosis/tiptap)
- **CodeMirror 6** — MIT (https://github.com/codemirror/dev)
- **KaTeX** — MIT (https://github.com/KaTeX/KaTeX)
- **Mermaid** — MIT (https://github.com/mermaid-js/mermaid)
- **highlight.js** — BSD-3-Clause (https://github.com/highlightjs/highlight.js)
- **spdlog** — MIT (https://github.com/gabime/spdlog)
- **nlohmann/json** — MIT (https://github.com/nlohmann/json)

Full license texts are included in LICENSES/ directory of this distribution.
```

About ダイアログから上記 URL に飛べる UI を付け、relinkable form 提供窓口を一つ作っておけば、LGPL §4(d)(1) 関連の主要な要件は実務的にカバーしやすい。最終確認は法務専門家へ。

## 配布チェックリスト

- [ ] release build で animation が落ちないか
- [ ] 起動時の真っ白 WebView (`editor/dist/` 同梱忘れ) が無いか
- [ ] アイコンが 16/32/64/128/256/512 サイズで揃っているか (macOS は .icns, Windows は .ico)
- [ ] About ダイアログにバージョン番号 + ライセンス情報
- [ ] macOS の Gatekeeper / Windows の SmartScreen 警告の対処手順を Readme に
- [ ] LGPL 3rd-party notice を README + About に同梱
- [ ] auto-update メカニズム (Sparkle / WinSparkle) の検討 — 後追いで OK

## 次の章

最終章でハマりどころのまとめと、Colason 本体の ideation 状況、6/15 PMF 判定後のロードマップを示す。
