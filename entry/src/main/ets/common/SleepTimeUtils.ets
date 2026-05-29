/**
 * 睡眠时间窗口工具
 * 处理 23:30-06:00 跨午夜的时间计算
 */
import {
  SLEEP_START_HOUR, SLEEP_START_MINUTE,
  SLEEP_END_HOUR, SLEEP_END_MINUTE
} from './Constants';

/**
 * 判断当前时间是否在睡眠窗口内（23:30 - 06:00）
 */
export function isInSleepWindow(): boolean {
  const now = new Date();
  const hours = now.getHours();
  const minutes = now.getMinutes();
  const totalMinutes = hours * 60 + minutes;

  const sleepStartTotal = SLEEP_START_HOUR * 60 + SLEEP_START_MINUTE; // 23*60+30 = 1410
  const sleepEndTotal = SLEEP_END_HOUR * 60 + SLEEP_END_MINUTE;       // 6*60+0 = 360

  // 睡眠窗口跨午夜：23:30~24:00 和 00:00~06:00
  return totalMinutes >= sleepStartTotal || totalMinutes < sleepEndTotal;
}

/**
 * 获取当前夜晚的日期键（YYYY-MM-DD）
 * 凌晨 0-6 点归属前一晚
 */
export function getCurrentNightDateKey(): string {
  const now = new Date();
  const hours = now.getHours();

  if (hours < SLEEP_END_HOUR) {
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
  start.setHours(SLEEP_START_HOUR, SLEEP_START_MINUTE, 0, 0);

  // 如果当前时间已过 06:00 但还没到 23:30，则 start 是今晚
  // 如果当前时间在 00:00-06:00 之间，start 实际上是昨晚的（已经过去）
  return start.getTime();
}

/**
 * 获取明早睡眠窗口结束时间的时间戳（06:00）
 */
export function getSleepWindowEndTimestamp(): number {
  const now = new Date();
  const end = new Date(now);
  end.setHours(SLEEP_END_HOUR, SLEEP_END_MINUTE, 0, 0);

  if (now.getHours() >= SLEEP_END_HOUR) {
    // 已经过了今天的 06:00，结束时间是明天 06:00
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

/**
 * 格式化日期为 YYYY-MM-DD
 */
function formatDateKey(date: Date): string {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

/**
 * 解析 YYYY-MM-DD 为 Date 对象
 */
function parseDateKey(dateKey: string): Date {
  const parts = dateKey.split('-');
  return new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]));
}
