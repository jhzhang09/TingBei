import SwiftUI

// MARK: - 多主题配色表（App 与灵动岛小组件共享的唯一配色来源）

struct ThemePalette: Sendable {
    let bg: Color
    let raised: Color
    let surface: Color
    let cream: Color
    let mute: Color
    let faint: Color
    /// 主题主色：按钮、描边、装饰。只表达「这是什么主题」，不承担状态含义。
    let gold: Color
    let goldBright: Color
    /// 状态色「当止」：到线 / 越线，统一取朱砂、朱漆一类的红
    let wine: Color
    /// 状态色「从容」
    let sage: Color
    let water: Color
    let ink: Color
    /// 状态色「宜缓」：偏快 / 临线。必须与 gold 拉开色相，否则警示会淹没在满屏装饰色里
    let caution: Color
    let isLight: Bool
}

extension ThemePalette {
    /// 按主题 ID（即 AppTheme.rawValue）取配色，未知 ID 回退为玄漆描金。
    /// 以字符串为键是因为小组件进程只拿得到 ContentState.themeID，且不编译 AppTheme 所在的 Pace.swift。
    static func forThemeID(_ themeID: String?) -> ThemePalette {
        switch themeID {
        case "celadonJade":
            // 汝窑天青 · 雨过天青云破处：粉青釉面、香灰胎墨字、梅子青与朱砂
            let inkBase = Color(red: 0.149, green: 0.208, blue: 0.200)  // 香灰胎深黛墨 #263533
            return ThemePalette(
                bg: Color(red: 0.843, green: 0.886, blue: 0.878),       // 雨过天青淡雾釉底 #D7E2E0
                raised: Color(red: 0.918, green: 0.945, blue: 0.939),   // 凝脂月白釉面 #EAF1EF
                surface: Color(red: 0.776, green: 0.835, blue: 0.824),  // 弦纹积釉 #C6D5D2
                cream: inkBase,
                mute: inkBase.opacity(0.55),
                faint: inkBase.opacity(0.11),
                gold: Color(red: 0.259, green: 0.467, blue: 0.455),     // 秘色深天青 #427774
                goldBright: Color(red: 0.337, green: 0.557, blue: 0.541), // 玛瑙青釉高光 #568E8A
                wine: Color(red: 0.698, green: 0.290, blue: 0.255),     // 宋画矿物朱砂 #B24A41
                sage: Color(red: 0.290, green: 0.506, blue: 0.424),     // 龙泉梅子青 #4A816C
                water: Color(red: 0.267, green: 0.486, blue: 0.596),    // 影青湖水蓝 #447C98
                ink: Color(red: 0.945, green: 0.969, blue: 0.965),      // 月白反白字
                caution: Color(red: 0.722, green: 0.525, blue: 0.169),  // 秋香赭黄 #B8862B
                isLight: true
            )

        case "burgundyCellar":
            // 琥珀光 · 兰陵美酒郁金香，玉碗盛来琥珀光：郁金酒色为地，琥珀暖光为饰
            let creamBase = Color(red: 0.961, green: 0.918, blue: 0.890)
            return ThemePalette(
                bg: Color(red: 0.071, green: 0.031, blue: 0.035),       // 郁金深酒色 #120809
                raised: Color(red: 0.129, green: 0.059, blue: 0.067),   // 酒坛陶釉 #210F11
                surface: Color(red: 0.192, green: 0.090, blue: 0.102),  // 杯中酒液 #31171A
                cream: creamBase,                                       // 玉碗暖白 #F5EAE3
                mute: creamBase.opacity(0.55),
                faint: creamBase.opacity(0.12),
                gold: Color(red: 0.851, green: 0.604, blue: 0.333),     // 琥珀 #D99A55
                goldBright: Color(red: 0.945, green: 0.769, blue: 0.506), // 烛下琥珀光 #F1C481
                wine: Color(red: 0.855, green: 0.235, blue: 0.282),     // 胭脂朱红 #DA3C48
                sage: Color(red: 0.518, green: 0.686, blue: 0.541),     // 竹叶青 #84AF8A
                water: Color(red: 0.490, green: 0.698, blue: 0.878),    // 清泉蓝
                ink: Color(red: 0.090, green: 0.030, blue: 0.038),
                caution: Color(red: 0.914, green: 0.824, blue: 0.290),  // 藤黄 #E9D24A
                isLight: false
            )

        case "midnightSapphire":
            // 霁蓝映月 · 明清霁蓝釉：深蓝如夜、釉色匀净，月白银辉为针
            let creamBase = Color(red: 0.925, green: 0.949, blue: 0.976)
            return ThemePalette(
                bg: Color(red: 0.035, green: 0.063, blue: 0.137),       // 霁蓝釉深夜底 #091023
                raised: Color(red: 0.059, green: 0.102, blue: 0.200),   // 霁蓝釉面 #0F1A33
                surface: Color(red: 0.090, green: 0.149, blue: 0.278),  // 积釉深蓝 #172647
                cream: creamBase,                                       // 月下银白 #ECF2F9
                mute: creamBase.opacity(0.55),
                faint: creamBase.opacity(0.12),
                gold: Color(red: 0.580, green: 0.741, blue: 0.890),     // 月白蓝 #94BDE3
                goldBright: Color(red: 0.784, green: 0.871, blue: 0.953), // 月华 #C8DEF3
                wine: Color(red: 0.886, green: 0.325, blue: 0.263),     // 祭红 #E25343
                sage: Color(red: 0.410, green: 0.765, blue: 0.635),     // 松石绿
                water: Color(red: 0.400, green: 0.690, blue: 0.940),    // 青花水蓝
                ink: Color(red: 0.035, green: 0.063, blue: 0.137),
                caution: Color(red: 0.910, green: 0.667, blue: 0.247),  // 杏黄 #E8AA3F
                isLight: false
            )

        case "enamelIvory":
            // 牙白界画 · 宋元界画以尺引线：象牙瓷白为地，乌墨双界为轨，铜金分刻
            let inkBase = Color(red: 0.106, green: 0.094, blue: 0.082)  // 乌墨 #1B1815
            return ThemePalette(
                bg: Color(red: 0.961, green: 0.949, blue: 0.925),       // 象牙瓷白 #F5F2EC
                raised: Color(red: 0.996, green: 0.992, blue: 0.984),   // 素绢 #FEFDFA
                surface: Color(red: 0.914, green: 0.894, blue: 0.855),  // 绢底浅黄 #E9E4DA
                cream: inkBase,
                mute: inkBase.opacity(0.55),
                faint: inkBase.opacity(0.10),
                gold: Color(red: 0.620, green: 0.416, blue: 0.188),     // 铜金 #9E6A30
                goldBright: Color(red: 0.737, green: 0.506, blue: 0.243), // 赤铜 #BC813E
                wine: Color(red: 0.753, green: 0.196, blue: 0.161),     // 朱砂 #C03229
                sage: Color(red: 0.220, green: 0.502, blue: 0.345),     // 石绿 #388058
                water: Color(red: 0.125, green: 0.369, blue: 0.620),    // 石青 #205E9E
                ink: Color(red: 0.996, green: 0.992, blue: 0.984),
                caution: Color(red: 0.780, green: 0.467, blue: 0.000),  // 橘黄 #C77700
                isLight: true
            )

        case "xuanPaperInk":
            // 宣纸水墨 · 兰亭雅集：泾县生宣、徽州松烟墨、书画泥金与西泠朱砂印
            let inkBase = Color(red: 0.122, green: 0.118, blue: 0.110)  // 松烟浓墨 #1F1E1C
            return ThemePalette(
                bg: Color(red: 0.937, green: 0.922, blue: 0.886),       // 生宣米白 #EFEBE2
                raised: Color(red: 0.976, green: 0.969, blue: 0.945),   // 云母净皮宣 #F9F7F1
                surface: Color(red: 0.878, green: 0.859, blue: 0.816),  // 端砚淡墨痕 #E0DBD0
                cream: inkBase,
                mute: inkBase.opacity(0.56),
                faint: inkBase.opacity(0.11),
                gold: Color(red: 0.451, green: 0.365, blue: 0.247),     // 书画泥金 #735D3F
                goldBright: Color(red: 0.565, green: 0.463, blue: 0.322), // 洒金铜 #907652
                wine: Color(red: 0.737, green: 0.204, blue: 0.169),     // 八宝印泥朱砂 #BC342B
                sage: Color(red: 0.282, green: 0.471, blue: 0.384),     // 花青石绿 #487862
                water: Color(red: 0.227, green: 0.416, blue: 0.533),    // 花青水蓝 #3A6A88
                ink: Color(red: 0.976, green: 0.969, blue: 0.945),
                caution: Color(red: 0.710, green: 0.396, blue: 0.114),  // 赭石 #B5651D
                isLight: true
            )

        default:
            // 玄漆描金 · 明清黑漆描金器：乌黑漆地，泥金细线
            let creamBase = Color(red: 0.945, green: 0.918, blue: 0.871)
            return ThemePalette(
                bg: Color(red: 0.039, green: 0.035, blue: 0.031),       // 玄漆 #0A0908
                raised: Color(red: 0.086, green: 0.078, blue: 0.071),   // 漆面 #161412
                surface: Color(red: 0.133, green: 0.122, blue: 0.110),  // 退光漆槽 #221F1C
                cream: creamBase,                                       // 象牙白 #F1EAE0
                mute: creamBase.opacity(0.54),
                faint: creamBase.opacity(0.11),
                gold: Color(red: 0.784, green: 0.643, blue: 0.431),     // 泥金 #C8A46E
                goldBright: Color(red: 0.902, green: 0.776, blue: 0.565), // 描金高光 #E6C690
                wine: Color(red: 0.776, green: 0.231, blue: 0.204),     // 朱漆 #C63B34
                sage: Color(red: 0.545, green: 0.698, blue: 0.529),     // 青绿 #8BB287
                water: Color(red: 0.365, green: 0.576, blue: 0.808),    // 石青 #5D93CE
                ink: Color(red: 0.050, green: 0.040, blue: 0.030),
                caution: Color(red: 0.890, green: 0.537, blue: 0.184),  // 橘黄 #E3892F
                isLight: false
            )
        }
    }
}
