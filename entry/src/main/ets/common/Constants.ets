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
export const MOVEMENT_THRESHOLD: number = 15.0;     // m/s² 加速度阈值，表示明显移动
export const ACCELEROMETER_INTERVAL: number = 500000000; // 纳秒，500ms 采样间隔

// 数据存储 - SQLite
export const DB_NAME: string = 'goodnight.db';
export const DB_SECURITY_LEVEL: number = 1; // S1

// 数据库表名
export const TABLE_USERS: string = 'users';
export const TABLE_CYCLES: string = 'cycles';
export const TABLE_DAILY_RECORDS: string = 'daily_records';
export const TABLE_APP_CONFIG: string = 'app_config';

// 应用配置键
export const CONFIG_KEY_REMEMBER_PASSWORD: string = 'remember_password';
export const CONFIG_KEY_AUTO_LOGIN: string = 'auto_login';
export const CONFIG_KEY_SAVED_USERNAME: string = 'saved_username';
export const CONFIG_KEY_SAVED_PASSWORD_HASH: string = 'saved_password_hash';
export const CONFIG_KEY_CURRENT_USER_ID: string = 'current_user_id';

// 日志
export const LOG_DOMAIN: number = 0x0000;
export const LOG_TAG: string = 'GoodNight';

// 通知
export const NOTIFICATION_ID_MONITOR: number = 1001;
export const NOTIFICATION_ID_RESULT: number = 1002;
export const NOTIFICATION_ID_CYCLE: number = 1003;
