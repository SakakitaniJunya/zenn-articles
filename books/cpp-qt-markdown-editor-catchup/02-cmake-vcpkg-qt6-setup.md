---
title: "CMake + vcpkg + Qt6 で 3 OS ビルドを 1 日で通す"
---

Qt6 + QWebEngine の最大の罠は、**ビルドが通るまでに 1 日溶ける** ことだ。本章のゴールは「macOS / Windows / Linux で同じ CMake コマンドが通る最小プロジェクト」を立てることに絞る。

## 結論: 依存解決を 2 系統に分ける

- **macOS / Windows のローカル開発** → **vcpkg** で Qt をビルド (時間はかかるが管理が楽)
- **Linux (Codespaces / CI / Docker)** → **apt** の Qt6 パッケージ (即時、Chromium ビルド回避)

これを `CMakeLists.txt` 側で意識しなくて済むようにする。`find_package(Qt6 ...)` だけで両方を吸収する。

## トップレベル CMakeLists.txt

```cmake
cmake_minimum_required(VERSION 3.25)

# vcpkg toolchain (project() 呼び出し前に有効化)
if(DEFINED ENV{VCPKG_ROOT} AND NOT DEFINED CMAKE_TOOLCHAIN_FILE)
    set(CMAKE_TOOLCHAIN_FILE "$ENV{VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake"
        CACHE STRING "Vcpkg toolchain file")
endif()

project(YourEditor VERSION 0.1.0 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Qt の moc / rcc / uic を自動化
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

# Qt6 必須コンポーネント
find_package(Qt6 6.8 REQUIRED COMPONENTS
    Core Gui Widgets
    Network OpenGL
    Qml Quick QuickWidgets
    WebEngineCore WebEngineWidgets WebChannel
    Svg PrintSupport Concurrent
    Positioning
)

# その他ライブラリ
find_package(spdlog CONFIG REQUIRED)
find_package(nlohmann_json CONFIG REQUIRED)

# Web 側のビルド済みアセット位置
set(EDITOR_DIST_DIR "${CMAKE_SOURCE_DIR}/editor/dist")

# サブディレクトリ
add_subdirectory(src)

# テスト (オプション)
option(BUILD_TESTS "Build unit tests" ON)
if(BUILD_TESTS AND EXISTS "${CMAKE_SOURCE_DIR}/tests/CMakeLists.txt")
    enable_testing()
    find_package(GTest CONFIG REQUIRED)
    add_subdirectory(tests)
endif()
```

ポイント:

- `WebEngineCore` / `WebEngineWidgets` / `WebChannel` の 3 つが揃わないと WebView + bridge が動かない
- `Qml` / `Quick` / `QuickWidgets` は WebEngine が内部依存しているので必須
- `Positioning` は QWebEngine の geolocation 機能の依存 (使わなくても link で要求される)

## src/CMakeLists.txt (実行可能ファイル)

```cmake
add_executable(youreditor
    main.cpp
    ui/MainWindow.cpp
    ui/MainWindow.h
    ui/EditorPane.cpp
    ui/EditorPane.h
    core/DocumentManager.cpp
    core/DocumentManager.h
    bridge/EditorBridge.cpp
    bridge/EditorBridge.h
)

target_link_libraries(youreditor PRIVATE
    Qt6::Core Qt6::Gui Qt6::Widgets
    Qt6::WebEngineCore Qt6::WebEngineWidgets Qt6::WebChannel
    spdlog::spdlog
    nlohmann_json::nlohmann_json
)

# Web 側アセットをバイナリと同じディレクトリにコピー
add_custom_command(TARGET youreditor POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_directory
        "${EDITOR_DIST_DIR}"
        "$<TARGET_FILE_DIR:youreditor>/editor"
)

# macOS は .app bundle として扱う
if(APPLE)
    set_target_properties(youreditor PROPERTIES MACOSX_BUNDLE TRUE)
endif()
```

## vcpkg.json (manifest mode)

```json
{
  "name": "your-editor",
  "version-string": "0.1.0",
  "dependencies": [
    "qtbase",
    "qtwebengine",
    "qttools",
    "qtsvg",
    "spdlog",
    "nlohmann-json",
    { "name": "gtest", "host": true }
  ]
}
```

**注意**: `qtwebengine` は Chromium をビルドするため **初回 20-40GB / 3-5 時間** かかる。ローカル開発で 1 回だけ。CI では避ける。

## CMakePresets.json

```json
{
  "version": 4,
  "configurePresets": [
    {
      "name": "macos-debug",
      "generator": "Ninja",
      "binaryDir": "${sourceDir}/build/macos-debug",
      "cacheVariables": {
        "CMAKE_BUILD_TYPE": "Debug",
        "CMAKE_PREFIX_PATH": "$env{HOMEBREW_PREFIX}/opt/qt"
      }
    },
    {
      "name": "linux-debug",
      "generator": "Ninja",
      "binaryDir": "${sourceDir}/build/linux-debug",
      "cacheVariables": {
        "CMAKE_BUILD_TYPE": "Debug"
      }
    },
    {
      "name": "windows-msvc",
      "generator": "Visual Studio 17 2022",
      "binaryDir": "${sourceDir}/build/windows-msvc",
      "cacheVariables": {
        "VCPKG_TARGET_TRIPLET": "x64-windows",
        "CMAKE_PREFIX_PATH": "C:/Qt/6.8.3/msvc2022_64"
      }
    }
  ]
}
```

`cmake --preset macos-debug` で OS ごとに切り替え。

## OS 別セットアップ手順

### macOS (Homebrew + vcpkg なし、Qt は Homebrew)

```bash
brew install qt ninja
cmake --preset macos-debug
cmake --build build/macos-debug
./build/macos-debug/src/youreditor
```

Homebrew の Qt は LGPL 動的リンクで配布する分には合法 (詳細は第 8 章)。

### Linux (Codespaces / Ubuntu apt)

```bash
sudo apt install -y \
    qt6-base-dev qt6-webengine-dev qt6-webchannel-dev \
    qt6-svg-dev \
    libspdlog-dev nlohmann-json3-dev libgtest-dev \
    ninja-build cmake
cmake --preset linux-debug
cmake --build build/linux-debug
./build/linux-debug/src/youreditor
```

**Codespaces 2-core 4GB で十分動く**。Chromium ビルドが不要なので、初回 5-10 分で起動できる (GitHub Codespaces の Free / Pro 各プランの無料枠は変動するため、最新は公式 pricing を参照すること)。

### Windows (vcpkg + Visual Studio)

```powershell
# vcpkg のインストール
git clone https://github.com/microsoft/vcpkg C:\vcpkg
C:\vcpkg\bootstrap-vcpkg.bat
$env:VCPKG_ROOT = "C:\vcpkg"

# Qt6 と依存をインストール (時間がかかる)
C:\vcpkg\vcpkg install qtbase qtwebengine spdlog nlohmann-json gtest --triplet x64-windows

# Configure & Build
cmake --preset windows-msvc
cmake --build build/windows-msvc --config Debug
```

Windows は **Qt Online Installer で Qt 6.8 を入れる手段** もあり、その場合は vcpkg の qtbase / qtwebengine をスキップして `CMAKE_PREFIX_PATH` を Qt Installer の path にすれば良い。

## Web 側 (editor/) のビルド

```bash
cd editor
npm install
npm run build   # editor/dist/ に静的ファイルが出る
```

`add_custom_command(POST_BUILD ...)` で `editor/dist/` をビルド成果物ディレクトリにコピーするので、`npm run build` を CMake build より前に走らせる。CI 上では順序を厳密に制御する。

## .devcontainer (Codespaces 用)

```jsonc
// .devcontainer/devcontainer.json
{
  "name": "qt6-cpp-dev",
  "image": "mcr.microsoft.com/devcontainers/cpp:ubuntu-22.04",
  "postCreateCommand": "bash .devcontainer/post-create.sh",
  "customizations": {
    "vscode": {
      "extensions": [
        "ms-vscode.cpptools",
        "ms-vscode.cmake-tools",
        "twxs.cmake"
      ]
    }
  }
}
```

```bash
# .devcontainer/post-create.sh
sudo apt-get update
sudo apt-get install -y \
    qt6-base-dev qt6-webengine-dev qt6-webchannel-dev \
    qt6-svg-dev libspdlog-dev nlohmann-json3-dev \
    libgtest-dev ninja-build cmake
cd editor && npm install && npm run build && cd ..
cmake --preset linux-debug
```

ローカル Mac に Qt + Chromium を入れずに Codespaces だけで開発が完結する。GitHub Codespaces の無料枠 (個人 Free / Pro 各プランの Core 時間) は変動するため、最新は公式 pricing を参照。

## 落とし穴

1. **`find_package(Qt6 ... QUIET)` で REQUIRED を付け忘れる** と、依存欠落でリンクエラーが分かりにくい場所で出る。最初は REQUIRED で書く
2. **`MACOSX_BUNDLE TRUE` を忘れる** と、macOS で `.app` でなく単体 binary になり Finder からダブルクリックで起動しない
3. **Web 側のビルドを忘れて CMake だけ走らせる** と、`editor/dist/` が無くて起動時に真っ白の WebView が出る
4. **vcpkg manifest mode で `VCPKG_MANIFEST_MODE=OFF`** を渡すと classic mode に落ちる。manifest mode を使うなら明示的に ON

## 次の章

第 3 章では QMainWindow ベースのネイティブシェル (メニューバー、ステータスバー、ドックウィジェット) を実装する。
