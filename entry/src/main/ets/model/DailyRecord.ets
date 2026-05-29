/**
 * 每晚监测记录数据类
 */
import { SleepJudgment } from './SleepJudgment';

/** JSON 序列化接口 */
export interface DailyRecordJson {
  dateKey: string;
  judgment: SleepJudgment;
  screenOnCount: number;
  movementEventCount: number;
  maxAcceleration: number;
  monitorStartTime: number;
  monitorEndTime: number;
  pointReturned: boolean;
}

export class DailyRecord {
  /** 日期键 YYYY-MM-DD，标识此记录对应的夜晚 */
  dateKey: string = '';
  /** 睡眠判定结果 */
  judgment: SleepJudgment = SleepJudgment.NOT_YET_EVALUATED;
  /** 睡眠期间屏幕亮起次数 */
  screenOnCount: number = 0;
  /** 睡眠期间显著移动事件次数 */
  movementEventCount: number = 0;
  /** 记录的最大加速度值 (m/s²) */
  maxAcceleration: number = 0;
  /** 监测开始时间戳 (ms) */
  monitorStartTime: number = 0;
  /** 监测结束时间戳 (ms) */
  monitorEndTime: number = 0;
  /** 此晚点数是否已返还 */
  pointReturned: boolean = false;

  /**
   * 从 JSON 对象反序列化
   */
  static fromJson(json: Record<string, Object>): DailyRecord {
    const record = new DailyRecord();
    record.dateKey = (json['dateKey'] as string) ?? '';
    record.judgment = (json['judgment'] as SleepJudgment) ?? SleepJudgment.NOT_YET_EVALUATED;
    record.screenOnCount = (json['screenOnCount'] as number) ?? 0;
    record.movementEventCount = (json['movementEventCount'] as number) ?? 0;
    record.maxAcceleration = (json['maxAcceleration'] as number) ?? 0;
    record.monitorStartTime = (json['monitorStartTime'] as number) ?? 0;
    record.monitorEndTime = (json['monitorEndTime'] as number) ?? 0;
    record.pointReturned = (json['pointReturned'] as boolean) ?? false;
    return record;
  }

  /**
   * 序列化为 JSON 对象
   */
  toJson(): DailyRecordJson {
    const json: DailyRecordJson = {
      dateKey: this.dateKey,
      judgment: this.judgment,
      screenOnCount: this.screenOnCount,
      movementEventCount: this.movementEventCount,
      maxAcceleration: this.maxAcceleration,
      monitorStartTime: this.monitorStartTime,
      monitorEndTime: this.monitorEndTime,
      pointReturned: this.pointReturned
    };
    return json;
  }
}
