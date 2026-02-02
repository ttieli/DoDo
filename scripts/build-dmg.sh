#!/bin/bash
# DoDo DMG 打包脚本
# 用法: ./scripts/build-dmg.sh

set -e

# 配置
APP_NAME="DoDo"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/.build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
DMG_DIR="$BUILD_DIR/dmg"
DMG_NAME="$APP_NAME.dmg"
DMG_PATH="$BUILD_DIR/$DMG_NAME"
VOLUME_NAME="$APP_NAME"

cd "$PROJECT_DIR"

echo "📦 DoDo DMG 打包工具"
echo "===================="

# 1. 构建 Release 版本
echo ""
echo "🔨 构建 Release 版本..."
swift build -c release

# 2. 更新 App Bundle
echo ""
echo "📱 更新 App Bundle..."
cp "$BUILD_DIR/release/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"

# 3. 清理旧的 DMG
echo ""
echo "🧹 清理旧文件..."
rm -rf "$DMG_DIR"
rm -f "$DMG_PATH"

# 4. 创建 DMG 临时目录
echo ""
echo "📁 准备 DMG 内容..."
mkdir -p "$DMG_DIR"

# 复制 App Bundle
cp -R "$APP_BUNDLE" "$DMG_DIR/"

# 创建 Applications 快捷方式
ln -s /Applications "$DMG_DIR/Applications"

# 5. 创建 DMG
echo ""
echo "💿 创建 DMG..."
hdiutil create -volname "$VOLUME_NAME" \
    -srcfolder "$DMG_DIR" \
    -ov -format UDZO \
    "$DMG_PATH"

# 6. 清理临时目录
rm -rf "$DMG_DIR"

# 7. 完成
echo ""
echo "✅ 打包完成!"
echo "   DMG 位置: $DMG_PATH"
echo ""
echo "💡 提示: 双击 DMG 后将 DoDo 拖到 Applications 即可安装"

# 打开 DMG 所在目录
open -R "$DMG_PATH"
