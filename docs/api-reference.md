# HarmonyOS API 参考 - 好梦应用

## 1. 使用的 HarmonyOS API 清单

### 1.1 数据持久化 - Preferences

| 项目 | 说明 |
|------|------|
| **模块** | `@kit.ArkData` |
| **导入** | `import { preferences } from '@kit.ArkData'` |
| **API 版本** | API 9+ |
| **权限** | 无需特殊权限 |
| **用途** | 存储 CycleInfo 和 DailyRecord 数据 |
| **关键方法** | `getPreferences(context, name)`, `put(key, value)`, `get(key, default)`, `flush()` |
| **限制** | 单条数据不超过 8KB，建议存储 key-value 格式 |

### 1.2 传感器 - Accelerometer

| 项目 | 说明 |
|------|------|
| **模块** | `@kit.SensorServiceKit` |
| **导入** | `import { sensor } from '@kit.SensorServiceKit'` |
| **API 版本** | API 9+ |
| **权限** | `ohos.permission.ACCELEROMETER` |
| **用途** | 检测睡眠期间手机移动 |
| **关键方法** | `sensor.on(SensorId.ACCELEROMETER, callback)`, `sensor.off(SensorId.ACCELEROMETER)` |
| **回调数据** | `AccelerometerResponse { x, y, z }` (m/s²) |

### 1.3 公共事件 - CommonEventManager

| 项目 | 说明 |
|------|------|
| **模块** | `@kit.BasicServicesKit` |
| **导入** | `import { CommonEventManager } from '@kit.BasicServicesKit'` |
| **API 版本** | API 9+ |
| **权限** | 无需特殊权限 |
| **用途** | 订阅屏幕亮屏/息屏系统广播 |
| **关键事件** | `COMMON_EVENT_SCREEN_ON`, `COMMON_EVENT_SCREEN_OFF` |
| **关键方法** | `createSubscriber(subscribeInfo)`, `subscribe(subscriber, callback)`, `unsubscribe(subscriber)` |

### 1.4 后台任务管理

| 项目 | 说明 |
|------|------|
| **模块** | `@kit.BackgroundTasksKit` |
| **导入** | `import { backgroundTaskManager } from '@kit.BackgroundTasksKit'` |
| **API 版本** | API 9+ |
| **权限** | `ohos.permission.KEEP_BACKGROUND_RUNNING` |
| **用途** | 睡眠监测期间保持应用后台运行 |
| **关键方法** | `startBackgroundRunning(context, label, wantAgent)`, `stopBackgroundRunning(context)` |
| **后台模式** | `taskKeeping`（在 module.json5 的 backgroundModes 中声明） |

### 1.5 通知管理

| 项目 | 说明 |
|------|------|
| **模块** | `@kit.NotificationKit` |
| **导入** | `import { notificationManager } from '@kit.NotificationKit'` |
| **API 版本** | API 9+ |
| **权限** | 需要用户授权通知 |
| **用途** | 发送监测状态和结果通知 |
| **关键方法** | `publish(request)`, `cancel(id)`, `cancelAll()` |

### 1.6 WantAgent

| 项目 | 说明 |
|------|------|
| **模块** | `@kit.AbilityKit` |
| **导入** | `import { wantAgent } from '@kit.AbilityKit'` |
| **API 版本** | API 9+ |
| **权限** | 无 |
| **用途** | 后台任务需要绑定 WantAgent 以显示持续通知 |
| **关键方法** | `getWantAgent(wantAgentInfo)` |

## 2. 权限声明

在 `entry/src/main/module.json5` 中声明：

```json5
"requestPermissions": [
  {
    "name": "ohos.permission.ACCELEROMETER",
    "reason": "$string:perm_accelerometer_reason",
    "usedScene": { "abilities": ["EntryAbility"], "when": "inuse" }
  },
  {
    "name": "ohos.permission.KEEP_BACKGROUND_RUNNING",
    "reason": "$string:perm_background_reason",
    "usedScene": { "abilities": ["EntryAbility"], "when": "always" }
  }
]
```

## 3. 后台模式声明

在 EntryAbility 配置中添加：
```json5
"backgroundModes": ["taskKeeping"]
```

## 4. API 兼容性说明

| API | 最低版本 | 推荐版本 | 废弃说明 |
|-----|---------|---------|---------|
| preferences | API 9 | 当前使用 | - |
| sensor | API 9 | 当前使用 | - |
| CommonEventManager | API 9 | 当前使用 | 旧版 `@ohos.commonEvent` 已废弃 |
| backgroundTaskManager | API 9 | 当前使用 | 旧版 `@ohos.backgroundTaskManager` 已废弃 |
| notificationManager | API 9 | 当前使用 | 旧版 `@ohos.notification` 已废弃 |

所有 API 均使用 Kit 导入方式（`@kit.*`），符合 HarmonyOS 6.0.2 最新规范。
