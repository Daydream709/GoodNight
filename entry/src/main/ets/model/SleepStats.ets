/**
 * 睡眠统计数据类
 */
export class SleepStats {
  /** 平均睡眠时长（小时） */
  avgSleepDurationHours: number = 0;
  /** 平均入睡时间 - 小时 */
  avgBedtimeHour: number = 0;
  /** 平均入睡时间 - 分钟 */
  avgBedtimeMinute: number = 0;
  /** 熬夜天数 */
  lateNightCount: number = 0;
  /** 达标率（百分比） */
  complianceRate: number = 0;
  /** 已判定总天数 */
  totalEvaluatedDays: number = 0;
  /** 达标天数 */
  totalCompliantDays: number = 0;
}
