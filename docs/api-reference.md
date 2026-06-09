# HarmonyOS API 参考 - 好梦应用

## 1. 使用的 HarmonyOS API 清单

### 1.1 数据持久化 - 关系型数据库 (relationalStore)

| 项目 | 说明 |
|------|------|
| **模块** | `@kit.ArkData` |
| **导入** | `import { relationalStore } from '@kit.ArkData'` |
| **API 版本** | API 10+ |
| **权限** | 无需特殊权限 |
| **用途** | 存储 users / cycles / daily_records / app_config 表 |
| **关键方法** | `getRdbStore(context, config)`, `executeSql()`, `insert()`, `update()`, `query(predicates)`, `querySql()` |
| **安全等级** | `SecurityLevel.S1` |
| **多用户** | `cycles`、`daily_records` 以 `user_id` 隔离 |

> 备注：早期设计曾计划用 Preferences（key-value），实现时改用 relationalStore 以支持多用户、范围查询与统计。

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
| **导入** | `import { commonEventManager } from '@kit.BasicServicesKit'` |
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

### 1.7 页面与 Ability 通信 - EventHub

| 项目 | 说明 |
|------|------|
| **模块** | `@kit.AbilityKit`（`UIAbilityContext.eventHub`） |
| **获取** | 页面侧 `getUIContext().getHostContext() as common.UIAbilityContext` |
| **用途** | 页面通知 EntryAbility 管理监测服务生命周期 |
| **关键方法** | `eventHub.on(event, cb)`, `eventHub.off(event, cb)`, `eventHub.emit(event)` |
| **事件** | `EVENT_LOGIN_SUCCESS` / `EVENT_LOGOUT` / `EVENT_REQUEST_MONITORING` |

### 1.8 轻量提示 - promptAction / TimePickerDialog

| 项目 | 说明 |
|------|------|
| **模块** | `@kit.ArkUI` |
| **用途** | Toast 反馈封装（`Toast.ets`）；设置页选择睡眠时段 |
| **关键方法** | `promptAction.showToast({ message, duration })`、`TimePickerDialog.show({ selected, useMilitaryTime, onAccept })` |

### 1.9 常用 ArkUI 组件

| 组件 | 用途 |
|------|------|
| `Progress(type: Ring/Linear)` | 周期环形进度 |
| `Toggle(type: Switch)` | 设置页开关项 |
| `LoadingProgress` | 登录/注册按钮加载态 |
| `TextInput().showPasswordIcon(true)` | 密码显示/隐藏 |
| `AlertDialog.show()` | 高风险操作确认 |
| `Tabs().animationDuration()` | 底部 Tab 切换过渡 |

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
| relationalStore | API 10 | 当前使用 | 取代早期 preferences 方案 |
| sensor | API 9 | 当前使用 | - |
| CommonEventManager | API 9 | 当前使用 | 旧版 `@ohos.commonEvent` 已废弃 |
| backgroundTaskManager | API 9 | 当前使用 | 旧版 `@ohos.backgroundTaskManager` 已废弃 |
| notificationManager | API 9 | 当前使用 | 旧版 `@ohos.notification` 已废弃 |

所有 API 均使用 Kit 导入方式（`@kit.*`），符合 HarmonyOS 6.0.2 最新规范。
