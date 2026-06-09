/**
 * 睡眠统计计算工具
 */
import { DailyRecord } from '../model/DailyRecord';
import { SleepJudgment } from '../model/SleepJudgment';
import { SleepStats } from '../model/SleepStats';
import { getDateKeyDaysAgo, getTodayKey } from './DateUtils';

export class StatsCalculator {
  static calculate(records: DailyRecord[]): SleepStats {
    const stats = new SleepStats();
    if (records.length === 0) {
      return stats;
    }

    let evaluatedCount = 0;
    let compliantCount = 0;
    let lateCount = 0;
    let totalSleepMs: number = 0;
    let sleepRecordCount = 0;
    let totalBedtimeMinutes: number = 0;
    let bedtimeCount = 0;

    for (let i = 0; i < records.length; i++) {
      const r = records[i];
      if (r.judgment === SleepJudgment.NOT_YET_EVALUATED) {
        continue;
      }
      evaluatedCount++;

      if (r.judgment === SleepJudgment.COMPLIANT) {
        compliantCount++;
      } else {
        lateCount++;
      }

      // 睡眠时长
      if (r.monitorStartTime > 0 && r.monitorEndTime > 0 && r.monitorEndTime > r.monitorStartTime) {
        totalSleepMs += r.monitorEndTime - r.monitorStartTime;
        sleepRecordCount++;
      }

      // 入睡时间
      if (r.monitorStartTime > 0) {
        const startDate = new Date(r.monitorStartTime);
        const hours = startDate.getHours();
        const minutes = startDate.getMinutes();
        // 转换为从23:00起算的分钟数，处理跨午夜
        let minutesSince23: number = 0;
        if (hours >= 18) {
          minutesSince23 = (hours - 23) * 60 + minutes;
        } else if (hours < 12) {
          minutesSince23 = (hours + 1) * 60 + minutes; // 0点=60min since 23:00
        }
        totalBedtimeMinutes += minutesSince23;
        bedtimeCount++;
      }
    }

    stats.totalEvaluatedDays = evaluatedCount;
    stats.totalCompliantDays = compliantCount;
    stats.lateNightCount = lateCount;

    if (evaluatedCount > 0) {
      stats.complianceRate = Math.round((compliantCount / evaluatedCount) * 100);
    }

    if (sleepRecordCount > 0) {
      const avgMs = totalSleepMs / sleepRecordCount;
      stats.avgSleepDurationHours = Math.round((avgMs / (1000 * 3600)) * 10) / 10;
    }

    if (bedtimeCount > 0) {
      const avgMinutes = Math.round(totalBedtimeMinutes / bedtimeCount);
      // 转回小时:分钟（从23:00偏移）
      let totalMinutes = 23 * 60 + avgMinutes;
      if (totalMinutes >= 24 * 60) {
        totalMinutes -= 24 * 60;
      }
      stats.avgBedtimeHour = Math.floor(totalMinutes / 60);
      stats.avgBedtimeMinute = totalMinutes % 60;
    }

    return stats;
  }

  /**
   * 格式化睡眠时长显示
   */
  static formatDuration(hours: number): string {
    if (hours <= 0) {
      return '--';
    }
    return hours.toFixed(1) + ' 小时';
  }

  /**
   * 格式化入睡时间显示
   */
  static formatBedtime(hour: number, minute: number): string {
    if (hour === 0 && minute === 0) {
      return '--';
    }
    const h = String(hour).padStart(2, '0');
    const m = String(minute).padStart(2, '0');
    return h + ':' + m;
  }

  /**
   * 计算指定天数前的日期键（转发至 DateUtils，保留静态入口兼容调用方）
   */
  static getDateKeyDaysAgo(days: number): string {
    return getDateKeyDaysAgo(days);
  }

  static getTodayKey(): string {
    return getTodayKey();
  }
}
