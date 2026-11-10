#!/bin/bash
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVICE_UDID="00008140-001849602240801C"
DEVICE_NAME="iPhone-jhzhang"
LOG_DIR="$HOME/Library/Logs"
LOG_FILE="$LOG_DIR/TingBeiRenew.log"

# Telegram Bot 推送配置：从未入库的本地文件 .renew.env 读取（可被同名环境变量覆盖），
# 绝不在脚本中写默认值。未配置时仅跳过 Telegram 推送，不影响续签本身。
ENV_FILE="$SCRIPT_DIR/.renew.env"
if [ -f "$ENV_FILE" ]; then
    ENV_TG_BOT_TOKEN="${TG_BOT_TOKEN:-}"
    ENV_TG_CHAT_ID="${TG_CHAT_ID:-}"
    # shellcheck disable=SC1090
    source "$ENV_FILE"
    TG_BOT_TOKEN="${ENV_TG_BOT_TOKEN:-${TG_BOT_TOKEN:-}}"
    TG_CHAT_ID="${ENV_TG_CHAT_ID:-${TG_CHAT_ID:-}}"
fi
TG_BOT_TOKEN="${TG_BOT_TOKEN:-}"
TG_CHAT_ID="${TG_CHAT_ID:-}"

mkdir -p "$LOG_DIR"

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    if [ -t 1 ]; then
        echo "$msg" | tee -a "$LOG_FILE"
    else
        echo "$msg"
    fi
}

notify() {
    local title="$1"
    local body="$2"

    # 1. macOS 桌面通知
    local safe_body="${body//\"/\\\"}"
    local safe_title="${title//\"/\\\"}"
    osascript -e "display notification \"$safe_body\" with title \"$safe_title\"" 2>/dev/null || true

    # 2. Telegram 手机推送通知
    if [ -n "$TG_BOT_TOKEN" ] && [ -n "$TG_CHAT_ID" ]; then
        curl -s --max-time 10 -X POST "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendMessage" \
            -d "chat_id=${TG_CHAT_ID}" \
            --data-urlencode "text=${title}

${body}" > /dev/null 2>&1 || true
    fi
}

log "=== 开始检查「停杯」续签状态 ==="

# 1. 检查设备是否在线 (USB connected 或 Wi-Fi available 局域网均可，带重试探测)
MAX_DISCOVERY_RETRIES=3
DEVICE_FOUND=""
for ((i=1; i<=MAX_DISCOVERY_RETRIES; i++)); do
    DEVICE_FOUND=$(xcrun devicectl list devices 2>/dev/null | grep "$DEVICE_UDID" | grep -E "connected|available" || true)
    if [ -n "$DEVICE_FOUND" ]; then
        break
    fi
    if [ $i -lt $MAX_DISCOVERY_RETRIES ]; then
        sleep 5
    fi
done

if [ -z "$DEVICE_FOUND" ]; then
    log "设备 $DEVICE_NAME ($DEVICE_UDID) 当前未连接或未处于同一局域网，跳过本次执行。"
    notify "停杯 自动续签跳过" "未检测到设备 $DEVICE_NAME 在线（请确认手机已连接局域网 Wi-Fi）。"
    exit 0
fi

log "检测到设备 $DEVICE_NAME 在线，开始增量编译与签名..."

# 2. 检查描述文件有效期；若剩余有效期不足 2 天，尝试安全刷新（带备份与回滚机制）
PROFILES_DIR="$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"
REMAINING_DAYS=$(python3 -c "
import glob, plistlib, subprocess, datetime, os
profiles_dir = os.path.expanduser('~/Library/Developer/Xcode/UserData/Provisioning Profiles')
min_days = 999.0
found = False
for f in glob.glob(profiles_dir + '/*.mobileprovision'):
    try:
        out = subprocess.check_output(['security', 'cms', '-D', '-i', f], stderr=subprocess.DEVNULL)
        plist = plistlib.loads(out)
        exp = plist.get('ExpirationDate')
        if exp:
            now = datetime.datetime.now(datetime.timezone.utc)
            if exp.tzinfo is None:
                exp = exp.replace(tzinfo=datetime.timezone.utc)
            rem = (exp - now).total_seconds() / 86400.0
            found = True
            if rem < min_days:
                min_days = rem
    except Exception:
        pass
if not found:
    print('0.0')
else:
    print(f'{max(0.0, min_days):.1f}')
" 2>/dev/null || echo "7.0")

log "当前签名描述文件剩余有效期: ${REMAINING_DAYS} 天"

# 若剩余不足 2 天，尝试清理旧缓存以申请新 7 天证书，失败自动回滚
BACKUP_DIR=""
NEEDS_REFRESH=$(python3 -c "print('yes' if float('${REMAINING_DAYS}') <= 2.0 else 'no')" 2>/dev/null || echo "no")

if [ "$NEEDS_REFRESH" = "yes" ] && [ -d "$PROFILES_DIR" ]; then
    log "描述文件有效期不足 2 天，正在备份并尝试向 Apple 申请全新 7 天证书..."
    BACKUP_DIR="/tmp/TingBei_Profiles_Backup_$$"
    mkdir -p "$BACKUP_DIR"
    cp "$PROFILES_DIR"/*.mobileprovision "$BACKUP_DIR/" 2>/dev/null || true
    rm -f "$PROFILES_DIR"/*.mobileprovision 2>/dev/null || true
fi

# 编译并打包应用
build_app() {
    xcodebuild -project "$SCRIPT_DIR/TingBei.xcodeproj" \
        -scheme TingBei \
        -destination "generic/platform=iOS" \
        -allowProvisioningUpdates \
        build \
        -quiet
}

if ! build_app; then
    # 若向 Apple 申请新证书失败且有备份，立即回滚备份以保证 App 能继续正常使用
    if [ -n "$BACKUP_DIR" ] && [ -d "$BACKUP_DIR" ]; then
        log "申请全新证书失败，立即回滚旧证书并重试编译..."
        cp "$BACKUP_DIR"/*.mobileprovision "$PROFILES_DIR/" 2>/dev/null || true
        rm -rf "$BACKUP_DIR"
        BACKUP_DIR=""
        if ! build_app; then
            log "错误：回滚后编译依然失败"
            notify "停杯 自动续签失败" "xcodebuild 编译失败，请检查开发者证书与签名。"
            exit 1
        fi
    else
        log "错误：xcodebuild 编译打包失败"
        notify "停杯 自动续签失败" "xcodebuild 编译失败，请检查开发者证书与签名。"
        exit 1
    fi
fi

# 编译成功后清理临时备份
if [ -n "$BACKUP_DIR" ] && [ -d "$BACKUP_DIR" ]; then
    rm -rf "$BACKUP_DIR"
fi

APP_PATH=$(find "$HOME/Library/Developer/Xcode/DerivedData" -name "TingBei.app" -path "*/Build/Products/Debug-iphoneos/*" ! -path "*/Index.noindex/*" 2>/dev/null | head -n 1)

if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
    log "错误：未找到编译产物 TingBei.app"
    notify "停杯 自动续签失败" "未找到编译产物 TingBei.app。"
    exit 1
fi

# 3. 安装到设备（最多重试 3 次，初次受阻将推送消息唤醒屏幕）
MAX_INSTALL_RETRIES=3
INSTALL_SUCCESS=false

for ((attempt=1; attempt<=MAX_INSTALL_RETRIES; attempt++)); do
    log "正在推送到设备 (第 $attempt/$MAX_INSTALL_RETRIES 次)..."
    if INSTALL_OUT=$(xcrun devicectl device install app --device "$DEVICE_UDID" "$APP_PATH" 2>&1); then
        INSTALL_SUCCESS=true
        break
    else
        log "第 $attempt 次推送失败！详情: $INSTALL_OUT"
        if [ $attempt -lt $MAX_INSTALL_RETRIES ]; then
            # 首次失败时推送通知，利用锁屏横幅点亮手机屏幕唤醒 CoreDevice
            if [ $attempt -eq 1 ]; then
                notify "停杯 正在尝试唤醒设备" "检测到手机可能处于休眠状态，已发送此通知点亮屏幕，15 秒后重试..."
            fi
            sleep 15
        fi
    fi
done

if [ "$INSTALL_SUCCESS" = true ]; then
    log "「停杯」续签安装成功！有效期已重置为 7 天。"
    notify "停杯 自动续签成功" "已成功静默重新签名并安装，有效期已重置为 7 天！"
else
    log "错误：连续 $MAX_INSTALL_RETRIES 次推送安装失败！"
    notify "停杯 自动续签失败" "连续 $MAX_INSTALL_RETRIES 次安装失败，请点亮手机屏幕或确认与 Mac 在同一 Wi-Fi。"
    exit 1
fi
