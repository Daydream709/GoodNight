# 好梦 (Good Night) - 架构设计文档

## 1. 项目概述

好梦是一款基于 HarmonyOS 6.0.2 的熬夜辅助工具，通过"点数对赌"机制激励用户养成良好作息习惯。

### 核心业务流程
1. 用户开始 30 天周期，投入 30 虚拟点数
2. 每晚 23:30 - 次日 06:00 系统自动监测
3. 若未检测到熬夜行为（亮屏≤3次且无手机移动），次日返还 1 点
4. 30 天周期结束后统计返还情况

## 2. 分层架构

```
┌─────────────────────────────────────────┐
│              UI 层 (ArkUI)               │
│          pages/Index.ets                │
├─────────────────────────────────────────┤
│           业务逻辑层 (Service)            │
│  SleepMonitorService (核心协调器)         │
│  VirtualPointsService (点数管理)          │
│  NotificationService (通知)              │
├──────────┬──────────┬───────────────────┤
│  接口层   │          │                   │
│  IPoints │ ISleep   │ IScreen/ISensor   │
│  Service │ Monitor  │ Monitor           │
├──────────┴──────────┴───────────────────┤
│           数据/资产层 (Data)              │
│  PreferencesRepository                  │
│  CycleInfo / DailyRecord                │
├─────────────────────────────────────────┤
│         设备检测层 (Device)              │
│  ScreenMonitorService (亮屏检测)         │
│  SensorMonitorService (加速度检测)       │
└─────────────────────────────────────────┘
```

## 3. 模块依赖图

```
Index.ets (UI)
  └── SleepMonitorService
        ├── IScreenMonitorService ← ScreenMonitorService
        ├── ISensorMonitorService ← SensorMonitorService
        ├── IPointsService ← VirtualPointsService
        ├── IDataRepository ← PreferencesRepository
        └── INotificationService ← NotificationService

EntryAbility.ets
  └── 构建并注入上述所有服务
```

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

### 4.2 点数服务扩展点（IPointsService）

```
当前：VirtualPointsService（纯本地余额）
  ↓ 未来替换
WeChatPayPointsService（微信支付 SDK）
AlipayPointsService（支付宝支付 SDK）
```

只需新建实现类，在 EntryAbility.initServices() 中替换注入即可，UI 和判定逻辑零修改。

### 4.3 睡眠监测协调器（SleepMonitorService）

工作流程：
1. `startNightlyMonitoring()` - 检查时间窗口，启动子监测器，设置 06:00 定时器
2. 监测期间 - 屏幕亮屏和传感器移动事件实时计数
3. `evaluateAndStop()` - 窗口结束时综合判定、保存记录、返还点数、发通知

### 4.4 后台任务策略

使用 `backgroundTaskManager.startBackgroundRunning()` + `taskKeeping` 模式：
- 在 EntryAbility.onBackground() 中，若处于睡眠窗口则启动后台任务
- 后台任务通过 WantAgent 绑定持续通知
- 监测结束后自动调用 stopBackgroundRunning()

## 5. 数据模型

### CycleInfo（周期）
- cycleId, startDateKey, endDateKey
- pointsInvested(30), pointsReturned, currentDayIndex(1-30)
- isActive

### DailyRecord（每日记录）
- dateKey（YYYY-MM-DD，凌晨归属前一晚）
- judgment（COMPLIANT / NON_COMPLIANT）
- screenOnCount, movementEventCount, maxAcceleration
- monitorStartTime, monitorEndTime, pointReturned

### 判定算法
```
if (screenOnCount <= 3 && movementEventCount == 0)
  → COMPLIANT（达标，返还点数）
else
  → NON_COMPLIANT（未达标，不返还）
```
