/**
 * GoodNight App 全局常量定义
 * 包含睡眠时间窗口、检测阈值、存储键名等配置
 */

// 睡眠时间窗口
export const SLEEP_START_HOUR: number = 23;
export const SLEEP_START_MINUTE: number = 30;
export const SLEEP_END_HOUR: number = 6;
export const SLEEP_END_MINUTE: number = 0;

// 周期配置
export const CYCLE_DURATION_DAYS: number = 30;
export const INITIAL_POINTS_INVESTED: number = 30;
export const POINT_RETURN_PER_DAY: number = 1;

// 检测阈值
export const SCREEN_ON_THRESHOLD: number = 3;       // 允许的亮屏次数（偶尔查看可容忍）
export const MOVEMENT_THRESHOLD: number = 15.0;     // m/s² 加速度模长阈值（保留：剧烈摇晃）
// 相邻采样差值法：能同时捕捉"摇一摇"与"左右旋转"
export const MOVEMENT_DELTA_HIGH: number = 2.5;     // 触发一次移动的三轴差值之和
export const MOVEMENT_DELTA_LOW: number = 1.0;      // 回落到此值以下才允许记下一次（去抖）
export const ACCELEROMETER_INTERVAL: number = 200000000; // 纳秒，200ms 采样间隔

// 数据存储 - SQLite
export const DB_NAME: string = 'goodnight.db';
export const DB_SECURITY_LEVEL: number = 1; // S1

// 数据库表名
export const TABLE_USERS: string = 'users';
export const TABLE_CYCLES: string = 'cycles';
export const TABLE_DAILY_RECORDS: string = 'daily_records';
export const TABLE_APP_CONFIG: string = 'app_config';

// 应用配置键
export const CONFIG_KEY_REMEMBER_ACCOUNT: string = 'remember_account';
export const CONFIG_KEY_AUTO_LOGIN: string = 'auto_login';
export const CONFIG_KEY_SAVED_USERNAME: string = 'saved_username';
export const CONFIG_KEY_CURRENT_USER_ID: string = 'current_user_id';
// 可配置设置项
export const CONFIG_KEY_SLEEP_START_HOUR: string = 'sleep_start_hour';
export const CONFIG_KEY_SLEEP_START_MINUTE: string = 'sleep_start_minute';
export const CONFIG_KEY_SLEEP_END_HOUR: string = 'sleep_end_hour';
export const CONFIG_KEY_SLEEP_END_MINUTE: string = 'sleep_end_minute';
export const CONFIG_KEY_SCREEN_ON_THRESHOLD: string = 'screen_on_threshold';
export const CONFIG_KEY_NOTIFICATIONS_ENABLED: string = 'notifications_enabled';

// 应用包名（与 AppScope/app.json5 保持一致）
export const BUNDLE_NAME: string = 'com.example.goodnight';

// 开发工具开关：控制登录页"生成测试数据"等调试入口，发布版应改回 false
export const ENABLE_DEV_TOOLS: boolean = true;

// Ability 与页面间通信事件名（eventHub）
export const EVENT_LOGIN_SUCCESS: string = 'goodnight.onLoginSuccess';
export const EVENT_LOGOUT: string = 'goodnight.onLogout';
export const EVENT_REQUEST_MONITORING: string = 'goodnight.onRequestMonitoring';

// 日志
export const LOG_DOMAIN: number = 0x0000;
export const LOG_TAG: string = 'GoodNight';

// 通知
export const NOTIFICATION_ID_MONITOR: number = 1001;
export const NOTIFICATION_ID_RESULT: number = 1002;
export const NOTIFICATION_ID_CYCLE: number = 1003;
