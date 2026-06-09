/**
 * 运行时可配置设置（睡眠窗口 / 检测阈值 / 通知开关）
 * 默认值取自 Constants，登录后从 app_config 表加载覆盖，设置页可修改并持久化。
 * SleepTimeUtils / SleepMonitorService / SensorMonitorService 统一读取此处。
 */
import { relationalStore } from '@kit.ArkData';
import {
  SLEEP_START_HOUR, SLEEP_START_MINUTE, SLEEP_END_HOUR, SLEEP_END_MINUTE,
  SCREEN_ON_THRESHOLD, TABLE_APP_CONFIG,
  CONFIG_KEY_SLEEP_START_HOUR, CONFIG_KEY_SLEEP_START_MINUTE,
  CONFIG_KEY_SLEEP_END_HOUR, CONFIG_KEY_SLEEP_END_MINUTE,
  CONFIG_KEY_SCREEN_ON_THRESHOLD, CONFIG_KEY_NOTIFICATIONS_ENABLED
} from './Constants';
import { logError } from './Logger';

export class AppSettings {
  static sleepStartHour: number = SLEEP_START_HOUR;
  static sleepStartMinute: number = SLEEP_START_MINUTE;
  static sleepEndHour: number = SLEEP_END_HOUR;
  static sleepEndMinute: number = SLEEP_END_MINUTE;
  static screenOnThreshold: number = SCREEN_ON_THRESHOLD;
  static notificationsEnabled: boolean = true;

  /** 从 app_config 加载设置，缺失项保留默认 */
  static async load(store: relationalStore.RdbStore): Promise<void> {
    try {
      const resultSet = await store.querySql('SELECT key, value FROM ' + TABLE_APP_CONFIG);
      while (resultSet.goToNextRow()) {
        const key = resultSet.getString(0);
        const value = resultSet.getString(1);
        AppSettings.apply(key, value);
      }
      resultSet.close();
    } catch (err) {
      logError('AppSettings load failed: %{public}s', (err as Error).message ?? '');
    }
  }

  private static apply(key: string, value: string): void {
    if (key === CONFIG_KEY_SLEEP_START_HOUR) { AppSettings.sleepStartHour = Number(value); }
    else if (key === CONFIG_KEY_SLEEP_START_MINUTE) { AppSettings.sleepStartMinute = Number(value); }
    else if (key === CONFIG_KEY_SLEEP_END_HOUR) { AppSettings.sleepEndHour = Number(value); }
    else if (key === CONFIG_KEY_SLEEP_END_MINUTE) { AppSettings.sleepEndMinute = Number(value); }
    else if (key === CONFIG_KEY_SCREEN_ON_THRESHOLD) { AppSettings.screenOnThreshold = Number(value); }
    else if (key === CONFIG_KEY_NOTIFICATIONS_ENABLED) { AppSettings.notificationsEnabled = value === 'true'; }
  }

  /** 持久化单项设置（upsert） */
  static async saveItem(store: relationalStore.RdbStore, key: string, value: string): Promise<void> {
    try {
      await store.executeSql('DELETE FROM ' + TABLE_APP_CONFIG + ' WHERE key = ?', [key]);
      const values: Record<string, relationalStore.ValueType> = { 'key': key, 'value': value };
      await store.insert(TABLE_APP_CONFIG, values);
      AppSettings.apply(key, value);
    } catch (err) {
      logError('AppSettings save failed: %{public}s', (err as Error).message ?? '');
    }
  }

  /** 睡眠窗口文案，如 "23:30 - 06:00" */
  static sleepWindowText(): string {
    const pad = (n: number): string => String(n).padStart(2, '0');
    return `${pad(AppSettings.sleepStartHour)}:${pad(AppSettings.sleepStartMinute)} - ` +
      `${pad(AppSettings.sleepEndHour)}:${pad(AppSettings.sleepEndMinute)}`;
  }
}
