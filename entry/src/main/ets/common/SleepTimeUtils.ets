/**
 * 睡眠时间窗口工具
 * 处理 23:30-06:00 跨午夜的时间计算
 */
import { formatDateKey, parseDateKey } from './DateUtils';
import { AppSettings } from './AppSettings';

/**
 * 判断当前时间是否在睡眠窗口内（默认 23:30 - 06:00，可在设置中调整）
 */
export function isInSleepWindow(): boolean {
  const now = new Date();
  const totalMinutes = now.getHours() * 60 + now.getMinutes();

  const sleepStartTotal = AppSettings.sleepStartHour * 60 + AppSettings.sleepStartMinute;
  const sleepEndTotal = AppSettings.sleepEndHour * 60 + AppSettings.sleepEndMinute;

  // 睡眠窗口跨午夜：23:30~24:00 和 00:00~06:00
  return totalMinutes >= sleepStartTotal || totalMinutes < sleepEndTotal;
}

/**
 * 获取当前夜晚的日期键（YYYY-MM-DD）
 * 凌晨时段（早于睡眠结束）归属前一晚
 */
export function getCurrentNightDateKey(): string {
  const now = new Date();
  const hours = now.getHours();

  if (hours < AppSettings.sleepEndHour) {
    // 凌晨时段，归属前一天
    const yesterday = new Date(now);
    yesterday.setDate(yesterday.getDate() - 1);
    return formatDateKey(yesterday);
  }
  return formatDateKey(now);
}

/**
 * 获取昨晚的日期键
 */
export function getPreviousNightDateKey(): string {
  const todayNightKey = getCurrentNightDateKey();
  const date = parseDateKey(todayNightKey);
  date.setDate(date.getDate() - 1);
  return formatDateKey(date);
}

/**
 * 获取今晚睡眠窗口开始时间的时间戳（23:30）
 */
export function getSleepWindowStartTimestamp(): number {
  const now = new Date();
  const start = new Date(now);
  start.setHours(AppSettings.sleepStartHour, AppSettings.sleepStartMinute, 0, 0);
  return start.getTime();
}

/**
 * 获取明早睡眠窗口结束时间的时间戳（06:00）
 */
export function getSleepWindowEndTimestamp(): number {
  const now = new Date();
  const end = new Date(now);
  end.setHours(AppSettings.sleepEndHour, AppSettings.sleepEndMinute, 0, 0);

  if (now.getHours() >= AppSettings.sleepEndHour) {
    // 已经过了今天的结束时间，结束时间是明天
    end.setDate(end.getDate() + 1);
  }
  return end.getTime();
}

/**
 * 计算从现在到睡眠窗口结束（06:00）的毫秒数
 */
export function getMillisUntilSleepWindowEnd(): number {
  return getSleepWindowEndTimestamp() - Date.now();
}

/**
 * 计算从现在到下一个睡眠窗口开始（23:30）的毫秒数
 */
export function getMillisUntilNextSleepWindow(): number {
  const startTs = getSleepWindowStartTimestamp();
  let diff = startTs - Date.now();
  if (diff < 0) {
    // 已经过了今晚的 23:30，下一次是明晚
    diff += 24 * 60 * 60 * 1000;
  }
  return diff;
}
