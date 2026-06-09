/**
 * 日期工具 - 统一的日期键（YYYY-MM-DD）格式化与解析
 * 此前 formatDateKey 在 SleepTimeUtils / DatabaseRepository / StatsCalculator /
 * TestDataGenerator 中各有一份实现，现集中于此，避免重复与不一致。
 */

/** 格式化日期为 YYYY-MM-DD */
export function formatDateKey(date: Date): string {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

/** 解析 YYYY-MM-DD 为 Date 对象（本地时区零点） */
export function parseDateKey(dateKey: string): Date {
  const parts = dateKey.split('-');
  return new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]));
}

/** 今天的日期键 */
export function getTodayKey(): string {
  return formatDateKey(new Date());
}

/** N 天前的日期键 */
export function getDateKeyDaysAgo(days: number): string {
  const date = new Date();
  date.setDate(date.getDate() - days);
  return formatDateKey(date);
}
