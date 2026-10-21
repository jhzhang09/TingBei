# 停杯 (TingBei)

<p align="left">
  <img src="https://img.shields.io/badge/Version-v1.1.0-C9A96E.svg?style=flat" alt="Version" />
  <img src="https://github.com/jhzhang09/TingBei/actions/workflows/ci.yml/badge.svg" alt="Build Status" />
  <img src="https://img.shields.io/badge/Platform-iOS%2027.0+-000000.svg?style=flat&logo=apple" alt="Platform" />
  <img src="https://img.shields.io/badge/Language-Swift%206-FA7343.svg?style=flat&logo=swift" alt="Language" />
  <img src="https://img.shields.io/badge/UI-SwiftUI%20%7C%20WidgetKit-007AFF.svg?style=flat" alt="UI" />
  <img src="https://img.shields.io/badge/Live%20Activity-Dynamic%20Island-orange.svg?style=flat" alt="Dynamic Island" />
  <img src="https://img.shields.io/badge/Dependencies-Zero-success.svg?style=flat" alt="Dependencies" />
  <img src="https://img.shields.io/badge/License-MIT-blue.svg?style=flat" alt="License" />
</p>

> **“懂得节制，方得从容。”**  
> 一款专注饮酒节奏管理、节制适度饮酒（Mindful Drinking / Pacing）的高端原生 iOS 应用。

---

## 🌟 产品哲学与设计理念

喝酒往往是在欢愉或社交氛围中逐渐失去节奏。传统的禁酒工具充满冷冰冰的说教，且往往要求用户每次都掏出手机手动记杯——在真实的酒桌上，这不仅繁琐，而且极为扫兴。

「停杯」是一位**沉静、温和、克制**的酒桌副驾：

1. **客观度量，不凭感觉**：引入世界卫生组织（WHO）通用的 **「标准杯」（Standard Drink）** 换算标准（以 14 克纯乙醇为基准），不论啤酒、葡萄酒、白酒或自调鸡尾酒，都能归一化比较。
2. **主动提醒为主，手动记录为辅**：开喝后放下手机即可。系统按你预定的节奏主动提醒；酒桌不便看手机时，系统会自动标记「**节奏估算**」，避免醉酒断片后无迹可寻。
3. **阶梯式紧迫感（Escalating Urgency）**：随着时间推移与摄入量逼近警戒线，提醒的**频率递增、烈度加剧**（超限后每 4 分钟高频催促，伴随强物理震动与突破专注模式的时效性横幅），真正在彻底醉酒前把人拉住。
4. **锁屏免解锁互动（Actionable Notification & Deep Links）**：收到推送长按即可在锁屏一键确认「喝了一杯 / 还没喝 / 我收杯了」，无需解锁屏幕。
5. **暗夜黑金腕表美学（Night Champagne & Horology Design）**：
   - 采用纯粹暗夜微暖黑（`#0A0908`）、香槟金（`#C9A96E`）与波尔多酒红。
   - 界面灵感源于经典高端腕表与酒标：外圈流逝时间，内圈标准杯刻度，中央宋体大数字。

---

## 🏝️ 灵动岛与实时活动 (Live Activity & Dynamic Island)

引入 ActivityKit 原生支持，无论是锁屏还是退至桌面，随时斜眼一瞥即可掌握节奏：

```
                    ┌─────────────────────────┐
                    │  🍸 2.0  (紧凑左)       │  实时杯数（超限变红）
                    │  22:30  (紧凑右)       │  下次提醒倒计时
                    └────────────┬────────────┘
                                 │ 长按展开
                                 ▼
         ┌─────────────────────────────────────────────────┐
         │ 停杯 · 小酌                  快到线了            │
         │ 2.0 / 2杯 (含估算)          下次提醒 22:30       │
         │ ─────────────────────────────────────────────── │
         │ 这杯就当最后一杯，给身体一点代谢时间。          │
         │                                                 │
         │ [ 💧 喝了水 ]    [ ＋1杯 ]        [ 我停了 ]     │
         └─────────────────────────────────────────────────┘
```

- **全天候显示（Always-On Display）**：锁屏时常驻沉浸式黑金小表盘，免解锁掌握当前进度。
- **免进 App 快捷动作**：在灵动岛直接轻触 `喝了水`、`+1杯` 或 `我停了`，通过 `tingbei://` 原生 URL Schemes 瞬间响应。

---

## 📈 动态提醒与状态机 (`Pace.swift`)

```mermaid
stateDiagram-v2
    [*] --> Quiet: 开局 / 摄入 < 45%
    Quiet --> Steady: 进度 45%~75%
    Steady --> Hurried: 两杯间隔过短 (按酒精度加权)
    Hurried --> Steady: 冷却等待结束
    Steady --> Near: 触及 75% 软限 / 时间过 75%
    Near --> Due: 触及建议目标软限 / 预定时长到达
    Due --> Over: 超出硬限 / 超时30分钟 (持续强提醒)
    Over --> [*]: 我收杯了 · 完成复盘
```

### 五级动态提醒阶梯

| 档位 | 状态 | 触发条件 | 提醒频率 | 提示烈度与文案 |
| :--- | :--- | :--- | :--- | :--- |
| **0. 轻声** | `quiet` | 开局 / 摄入 < 45% | 基础间隔（约 20~40 分钟） | 温和轻震，问句：“开喝了吗 / 大概第 1 杯了？” |
| **1. 留意** | `steady` | 进度 45%~75% | 间隔缩短 25% | 温和：“约 2 杯了，节奏还行，下一杯慢点，先喝口水” |
| **2. 收尾** | `near` | 触及 75% 软限 | 间隔缩至 10~20 分钟 | 警示震动：“快到线了，这杯当最后一杯” |
| **3. 到线** | `due` | 达到建议目标 | **8 分钟一催**（高优先级） | 突破静音专注模式，时效性通知：“到线了，现在停刚刚好” |
| **4. 强提醒** | `over` | 超过硬限 / 严重超时 | **4 分钟一催 + 持续强震** | 标明催促次数：“停！第 N 次提醒，超过上限，现在停下比再喝好得多” |

---

## 📱 核心功能特性

- **灵动岛与锁屏实时活动（Live Activity & Dynamic Island）**：
  - 支持全状态适配（锁屏小部件、紧凑左/右、展开态与最小化态）。
- **时效性通知（Time-Sensitive Notifications）**：
  - 到线与越线提醒自动升级为 `Time-Sensitive` 并搭载 `.defaultCritical` 强警示蜂鸣与脉冲物理震动，即使在勿扰模式或嘈杂酒桌也不会被遗漏。
- **时间回溯与快速补记**：
  - 点击 `+1` 提供了「刚才 / 10分钟前 / 20分钟前 / 30分钟前」回溯选项，彻底避免事后补记导致的急饮误报。
  - 顶部常驻「同上一杯」大卡片，一键即记。
- **客观度量与多方案预设**：
  - 内置经典方案：**小酌**（2 标准杯 · 90 分钟）、**聚餐**（4 标准杯 · 3 小时）。
  - 支持滑动自定义任意容量（20ml~1000ml）与酒精度（1%~65%）。
- **纯粹黑金腕表仪表盘**：
  - 外圈流逝时间细线，内圈标准杯弧线与软限刻度小点，中央经典宋体大数字。
- **局域网静默无线续签**：
  - 内置 `renew.sh`，支持在局域网内无线将应用（主 App + 小组件扩展）静默更新至真机，永不掉签。

---

## 🛠️ 项目结构

```
TingBei/
├── TingBei/
│   ├── TingBeiApp.swift          # App 入口、通知代理与 URL Scheme 深链路由
│   ├── TingBeiAttributes.swift   # ActivityKit 灵动岛与实时活动共享数据模型
│   ├── Pace.swift                # 核心业务算法：标准杯折算、预排推演、状态机与单元自检
│   ├── SessionStore.swift        # 全局状态管理：@Observable 驱动、时效性通知排期、Live Activity 生命周期
│   ├── Views.swift               # 界面层：黑金腕表双环表盘、三元控制组、回溯补记面板、复盘页面
│   └── Assets.xcassets           # 配色与矢量资源
├── TingBeiWidgets/
│   ├── TingBeiWidgets.swift      # 灵动岛（紧凑态/展开态）与锁屏实时活动 WidgetKit 实现
│   └── Info.plist                # Widget Extension 配置文件
├── TingBei.xcodeproj             # Xcode 工程配置（包含主 App 与 Widget 扩展）
├── Info.plist                    # 主应用配置（开启 NSSupportsLiveActivities 与 URL Schemes）
├── renew.sh                      # 局域网自动化增量编译、签名打包与无线推送脚本
└── README.md                     # 项目说明文档
```

---

## 🚀 编译与运行要求

* **macOS**：macOS 27.0+
* **Xcode**：Xcode 27.0+（包含 iOS 27.0+ SDK）
* **设备支持**：iPhone（iOS 27.0 或更高版本，支持灵动岛的设备体验更佳）

### 命令行编译与自检

```bash
# 运行 Debug 编译（主 App + 灵动岛小组件扩展）
xcodebuild -project TingBei.xcodeproj -scheme TingBei -destination 'generic/platform=iOS' build

# 运行独立状态机单元自测试
swift -DPACE_CHECKS TingBei/Pace.swift
```

---

## 📄 开源许可

本项目遵循 [MIT License](LICENSE) 开源。
