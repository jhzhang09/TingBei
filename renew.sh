#!/bin/bash
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVICE_UDID="00008140-001849602240801C"
DEVICE_NAME="iPhone-jhzhang"
LOG_DIR="$HOME/Library/Logs"
LOG_FILE="$LOG_DIR/TingBeiRenew.log"

mkdir -p "$LOG_DIR"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "=== 开始检查「停杯」续签状态 ==="

# 1. 检查设备是否在线 (USB connected 或 Wi-Fi available 局域网均可)
DEVICE_FOUND=$(xcrun devicectl list devices 2>/dev/null | grep "$DEVICE_UDID" | grep -E "connected|available" || true)

if [ -z "$DEVICE_FOUND" ]; then
    log "设备 $DEVICE_NAME ($DEVICE_UDID) 当前未连接或未处于同一局域网，跳过本次执行。"
    exit 0
fi

log "检测到设备 $DEVICE_NAME 在线，开始增量编译与签名..."

# 2. 若本地描述文件剩余有效期不足 2 天，清理旧缓存以触发向 Apple 申请新 7 天描述文件
PROFILES_DIR="$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"
if [ -d "$PROFILES_DIR" ]; then
    find "$PROFILES_DIR" -name "*.mobileprovision" -mtime +4 -delete 2>/dev/null || true
fi

# 2. 编译并打包应用（使用 generic/platform=iOS 避免无线连接休眠时 xcodebuild 找不到 destination）
xcodebuild -project "$SCRIPT_DIR/TingBei.xcodeproj" \
    -scheme TingBei \
    -destination "generic/platform=iOS" \
    -allowProvisioningUpdates \
    build \
    -quiet

APP_PATH=$(find "$HOME/Library/Developer/Xcode/DerivedData" -name "TingBei.app" -path "*/Build/Products/Debug-iphoneos/*" ! -path "*/Index.noindex/*" 2>/dev/null | head -n 1)

if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
    log "错误：未找到编译产物 TingBei.app"
    exit 1
fi

log "正在静默推送到设备..."

# 3. 安装到设备
xcrun devicectl device install app --device "$DEVICE_UDID" "$APP_PATH" > /dev/null

log "「停杯」续签安装成功！有效期已重置为 7 天。"

# 4. 发送 macOS 桌面通知
osascript -e 'display notification "已成功静默重新签名并安装，有效期重置为 7 天！" with title "停杯 自动续签成功"' 2>/dev/null || true
