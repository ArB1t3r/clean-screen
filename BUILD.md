# 构建独立应用

如果你想要一个独立的`.app`文件来直接使用（而不是通过Raycast），可以按照以下步骤构建：

## 快速构建

在项目根目录运行：

```bash
# 编译Swift helper
cd assets/clean-screen-helper
swift build -c release

# 创建.app bundle
cd ../..
mkdir -p CleanScreenHelper.app/Contents/MacOS
mkdir -p CleanScreenHelper.app/Contents/Resources
cp assets/clean-screen-helper/.build/release/CleanScreenHelper CleanScreenHelper.app/Contents/MacOS/
cp assets/icon.png CleanScreenHelper.app/Contents/Resources/AppIcon.png

# 创建Info.plist（如果还不存在）
cat > CleanScreenHelper.app/Contents/Info.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>CleanScreenHelper</string>
    <key>CFBundleIdentifier</key>
    <string>com.eigenlicht.CleanScreenHelper</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Clean Screen Helper</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
</dict>
</plist>
EOF

# 确保可执行
chmod +x CleanScreenHelper.app/Contents/MacOS/CleanScreenHelper

# 签名（ad-hoc签名）
codesign -s - CleanScreenHelper.app
```

## 使用独立应用

构建完成后：

1. **双击打开** `CleanScreenHelper.app`
2. 首次运行时，系统会要求授予**辅助功能权限**
3. 按照提示在系统设置中授权
4. 再次运行即可开始清洁模式

## 退出方式

- 点击屏幕中央的 **"End Cleaning Session"** 按钮
- 按下 **Control-U** 快捷键

## 注意事项

- `.app`文件已添加到`.gitignore`，不会被提交到git
- 这是一个ad-hoc签名的应用，仅供个人使用
- 如果要分发给他人，需要使用Apple开发者证书签名
- 应用大小约为 **321KB**

## 自动化构建脚本

你也可以创建一个脚本来自动化构建过程：

```bash
#!/bin/bash
set -e

echo "🔨 Building Clean Screen Helper..."

# 编译
cd assets/clean-screen-helper
swift build -c release
cd ../..

# 清理旧的.app
rm -rf CleanScreenHelper.app

# 创建.app结构
mkdir -p CleanScreenHelper.app/Contents/MacOS
mkdir -p CleanScreenHelper.app/Contents/Resources

# 复制文件
cp assets/clean-screen-helper/.build/release/CleanScreenHelper CleanScreenHelper.app/Contents/MacOS/
cp assets/icon.png CleanScreenHelper.app/Contents/Resources/AppIcon.png

# 创建Info.plist
cat > CleanScreenHelper.app/Contents/Info.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>CleanScreenHelper</string>
    <key>CFBundleIdentifier</key>
    <string>com.eigenlicht.CleanScreenHelper</string>
    <key>CFBundleName</key>
    <string>Clean Screen Helper</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

# 设置权限
chmod +x CleanScreenHelper.app/Contents/MacOS/CleanScreenHelper

# 签名
codesign -s - CleanScreenHelper.app

echo "✅ Build complete! CleanScreenHelper.app is ready."
echo "📦 App size: $(du -sh CleanScreenHelper.app | cut -f1)"
```

保存为`build-app.sh`并运行：
```bash
chmod +x build-app.sh
./build-app.sh
```
