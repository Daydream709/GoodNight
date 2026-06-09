# 好梦 (Good Night) - 架构设计文档

## 1. 项目概述

好梦是一款基于 HarmonyOS 6.0.2 的熬夜辅助工具，通过"点数对赌"机制激励用户养成良好作息习惯。

### 核心业务流程
1. 用户开始 30 天周期，投入 30 虚拟点数
2. 每晚 23:30 - 次日 06:00 系统自动监测（或前台「今晚监测」页随时进入）
3. 若未检测到熬夜行为（**操作**次数≤3 且无手机移动），次日返还 1 点
4. 30 天周期结束后统计返还情况

> "操作"= 一次"使用手机"的统称，含真实亮屏广播、离开/切走监测页、失焦（下拉通知栏/控制中心）等；UI 统一用"操作"而非"亮屏"，内部计数字段仍为 `screenOnCount`。

## 2. 分层架构

```
┌─────────────────────────────────────────┐
│              UI 层 (ArkUI)               │
│  pages/  LoginPage / RegisterPage /      │
│          Index(底部 Tabs 容器) /         │
│          SettingsPage / AboutPage        │
│  tabs/   HomeTab / StatisticsTab /       │
│          ProfileTab                      │
├─────────────────────────────────────────┤
│           业务逻辑层 (Service)            │
│  SleepMonitorService (核心协调器)         │
│  VirtualPointsService (点数管理)          │
│  AuthService (账号认证)                   │
│  NotificationService (通知)              │
├──────────┬──────────┬───────────────────┤
│  接口层   │          │                   │
│  IPoints │ ISleep   │ IScreen/ISensor   │
│  Service │ Monitor  │ Monitor / IAuth   │
├──────────┴──────────┴───────────────────┤
│        公共/配置层 (common)              │
│  AppSettings(可配置) / AppColors(主题)   │
│  DateUtils / PasswordHasher / Toast      │
│  StatsCalculator / SleepTimeUtils        │
├─────────────────────────────────────────┤
│           数据/资产层 (Data)              │
│  DatabaseRepository (SQLite/RDB)        │
│  CycleInfo / DailyRecord / User          │
├─────────────────────────────────────────┤
│         设备检测层 (Device)              │
│  ScreenMonitorService (操作/亮屏检测)     │
│  SensorMonitorService (加速度检测)       │
└─────────────────────────────────────────┘
```

## 3. 模块依赖图

```
HomeTab / StatisticsTab / ProfileTab (UI)
  └── 经 AppStorage 获取共享单例：
        dbRepo(DatabaseRepository) / authService / sleepMonitorService

SleepMonitorService
  ├── IScreenMonitorService ← ScreenMonitorService
  ├── ISensorMonitorService ← SensorMonitorService
  ├── IPointsService ← VirtualPointsService
  ├── IDataRepository ← DatabaseRepository
  └── INotificationService ← NotificationService

EntryAbility.ets
  └── 监听 eventHub(EVENT_LOGIN_SUCCESS / EVENT_LOGOUT / EVENT_REQUEST_MONITORING)
        登录成功 → 用共享 dbRepo 构建监测服务链并发布到 AppStorage
        登出 → 停止监测、清后台任务、清空 sleepMonitorService
        EVENT_REQUEST_MONITORING → 睡眠时段内立即启动后台监测（保留入口，
          当前首页改为进入全屏 MonitorPage，暂未发出该事件）
        窗口失焦/隐藏(windowStageEvent) → 监测中记一次"操作"(recordScreenLeave)
```

**服务生命周期**：登录页初始化 `DatabaseRepository` + `AuthService` 存入 AppStorage，并通过 `context.eventHub.emit(EVENT_LOGIN_SUCCESS)` 通知 `EntryAbility` 构建监测服务链（共享同一 dbRepo，避免双实例与竞态）。

**依赖方向始终向下**：UI → Service → Interface → Model，没有反向依赖。

## 4. 核心模块说明

### 4.1 接口层（interface/）

所有服务通过接口解耦，关键接口：

| 接口 | 职责 | 扩展性 |
|------|------|--------|
| IPointsService | 点数投入/返还 | 未来替换为真实支付 |
| IDataRepository | 数据存取 | 可替换为云端/数据库 |
| IScreenMonitorService | 屏幕事件 | 可替换检测实现 |
| ISensorMonitorService | 传感器 | 可替换检测实现 |
| ISleepMonitorService | 监测协调 | 可替换调度策略 |
| INotificationService | 通知 | 可替换为推送服务 |
| IAuthService | 账号注册/登录/资料 | 可替换为云端账号体系 |

### 4.2 点数服务扩展点（IPointsService）

```
当前：VirtualPointsService（纯本地余额）
  ↓ 未来替换
WeChatPayPointsService（微信支付 SDK）
AlipayPointsService（支付宝支付 SDK）
```

只需新建实现类，在 EntryAbility.initServices() 中替换注入即可，UI 和判定逻辑零修改。

### 4.3 睡眠监测协调器（SleepMonitorService）

两个启动入口共用私有内核 `beginSession(callback)`（重置计数 → 建当晚记录 → 启动子监测器 → **装 06:00 自动结算定时器** → 发布状态），保证前台/后台行为一致、不留"永不结算"的僵尸会话：

1. `startNightlyMonitoring()` - 后台夜间监测：校验睡眠窗口 → `beginSession` → 发常驻通知
2. `startDemoMonitoring()` - 前台「今晚监测」页：跳过窗口校验 → `beginSession`（同样有自动结算定时器）
3. 监测期间 - 屏幕事件（亮屏广播 + 离开页面/失焦）与传感器移动实时计数
4. `recordScreenLeave()` - 把"离开监测页/失焦/返回"记为一次**操作**（800ms 去抖；兼容模拟机无真实亮屏广播）
5. `setCountListener(cb)` - 计数变化即时回调，供监测页实时刷新（取代不可靠的 @StorageProp 响应式）
6. `evaluateAndStop()` → `finalizeNight()` - 窗口结束或手动结算时综合判定、落库、返点、推进周期、发通知

**`finalizeNight()` 的关键约束**：
- **幂等**：按 `dateKey` 判断是否已结算，重复结算只覆盖记录、不重复推进天数/返点
- **顺序**：`returnPoint()` 会写库中的 `pointsReturned`，故推进天数前**重新读取最新 cycle**，避免旧副本覆盖刚返还的点数
- 收尾统一 `AppStorage.setOrCreate('dataVersion', …)`，让首页/统计/我的三页（@Watch dataVersion）在任意结算路径后刷新

### 4.4 后台任务策略

使用 `backgroundTaskManager.startBackgroundRunning()` + `taskKeeping` 模式：
- 在 EntryAbility.onBackground() 中，若处于睡眠窗口则启动后台任务
- 后台任务通过 WantAgent 绑定持续通知
- 监测结束后自动调用 stopBackgroundRunning()

> ⚠️ `taskKeeping` 仅在特定真机支持，模拟机会报 `9800005` 启动失败。因此模拟机/演示以**前台全屏「今晚监测」页**为主路径（不依赖后台模式）；真机后台常驻监测需另行验证（见 `docs/device-test-checklist.md`）。

## 5. 数据模型（SQLite / relationalStore）

数据库 `goodnight.db`，四张表：`users` / `cycles` / `daily_records` / `app_config`。
`cycles` 与 `daily_records` 均以 `user_id` 做**多用户隔离**。

### User（用户）
- id, username(唯一), passwordHash, createdAt, avatarPath

### CycleInfo（周期）
- user_id, cycleId, startDateKey, endDateKey
- pointsInvested(30), pointsReturned, currentDayIndex(1-30)
- isActive

### DailyRecord（每日记录）
- user_id, dateKey（YYYY-MM-DD，凌晨归属前一晚）
- 唯一键 `UNIQUE(user_id, date_key)`
- judgment（COMPLIANT / NON_COMPLIANT / NOT_YET_EVALUATED）
- screenOnCount, movementEventCount, maxAcceleration
- monitorStartTime, monitorEndTime, pointReturned

### 判定算法
```
if (screenOnCount <= AppSettings.screenOnThreshold && movementEventCount == 0)
  → COMPLIANT（达标，返还点数）
else
  → NON_COMPLIANT（未达标，不返还）
```
> 阈值与睡眠窗口均来自 `AppSettings`（默认 3 次 / 23:30-06:00），用户可在设置页调整。

## 6. UI 功能特性

### 6.1 HomeTab（主页）
- **监测状态卡**：监测中显示呼吸灯 + 实时操作/移动计数（每 1.5 秒轮询 `getLiveScreenOnCount/Count`）；点击"开始今晚监测"或卡片进入全屏 `MonitorPage`
- **环形周期进度** + **连续达标 streak（🔥）** + 剩余/已返还点数卡
- **空状态引导**：玩法三步 + 隐私说明 + 开始挑战；完成上一期后展示成绩横幅（弹入动画）
- 高风险操作确认弹窗：开始挑战 / 提前结束本期（退还剩余点数）

### 6.2 MonitorPage（全屏「今晚监测」页）
- 进入即开始前台监测会话（`startDemoMonitoring`）；深色全屏沉浸式，呼吸月亮 + 守护计时
- "操作/移动"两项计数**内联读取 @State**（经 `setCountListener` 即时回调 + 1s 定时器兜底刷新）
- 离开页面 / 系统返回 / 失焦 / 下拉通知栏均记为一次"操作"（服务层 800ms 去抖）
- "结束今晚监测并结算"= 提前结算；文案以服务层**真实判定**为准（不在页面重算）

### 6.3 StatisticsTab（「睡眠报告」）
- 近 7/30/90 天分段控制器；**达标率环形**为视觉核心（配色随表现：高=成功/中=主色/低=警示）
- **关键指标条**：平均时长 / 平均入睡 / 熬夜天数
- **睡眠时长趋势图**：带 12/8/4/0h 网格刻度与 8h 目标线，横向滚动、按达标着色
- **作息洞察**：工作日 vs 周末达标率对比条 + 一句生成文案
- **深度洞察**：最长连续好眠、最常熬夜的星期、本期前/后段作息趋势
- **每日达标热力图**（含图例），点击查看当晚详情弹窗

### 6.4 ProfileTab（我的）
- 头像 / 用户名 / 修改密码（改名/改密/换头像有 `busy` 防重复提交；用户名 `trim` + 超长截断）
- **账号汇总**：累计周期数、累计赚回点数
- 入口：设置页、关于页；退出登录（含确认弹窗，emit `EVENT_LOGOUT`）

### 6.5 SettingsPage / AboutPage
- 设置页：睡眠时段（TimePicker）、允许操作次数（步进）、通知开关、深色模式开关；改动经 `AppSettings.saveItem()` 持久化到 `app_config` 并实时生效
- 关于页：监测原理、判定方式、隐私说明、版本号

> 全局一致性：所有可点 `TextInput` 限 `maxLength`、返回按钮扩大点击热区、各 Tab 入场淡入、深色模式经 `@StorageLink('isDarkMode')` + `PersistentStorage` 全局同步。

## 7. 公共工具与可配置设置（common/）

| 模块 | 职责 |
|------|------|
| AppSettings | 运行时可配置项（睡眠窗口/阈值/通知），默认取自 Constants，登录后从 app_config 加载 |
| AppColors | 浅/深色主题 token（液态玻璃风格） |
| DateUtils | 统一的日期键格式化/解析 |
| PasswordHasher | 统一的本地密码哈希（demo 级） |
| Toast | promptAction 轻量反馈封装 |
| SleepTimeUtils | 睡眠窗口判断与时间戳计算（读取 AppSettings） |
| StatsCalculator | 睡眠统计聚合计算 |
| Logger | hilog 日志封装 |

> 注：登录/注册页通过 `ENABLE_DEV_TOOLS` 常量门控"生成测试数据"调试入口，发布版应置为 `false`。
