/**
 * 30 天周期数据类
 */
import { CYCLE_DURATION_DAYS } from '../common/Constants';

/** JSON 序列化接口 */
export interface CycleInfoJson {
  cycleId: string;
  startDateKey: string;
  endDateKey: string;
  pointsInvested: number;
  pointsReturned: number;
  currentDayIndex: number;
  isActive: boolean;
}

export class CycleInfo {
  /** 周期唯一标识（开始日期） */
  cycleId: string = '';
  /** 周期开始日期 YYYY-MM-DD */
  startDateKey: string = '';
  /** 周期结束日期 YYYY-MM-DD */
  endDateKey: string = '';
  /** 投入的点数（初始 30） */
  pointsInvested: number = 30;
  /** 已返还的点数 */
  pointsReturned: number = 0;
  /** 当前天数索引（1-30） */
  currentDayIndex: number = 1;
  /** 周期是否进行中 */
  isActive: boolean = true;

  /**
   * 计算剩余点数（尚未返还的）
   */
  getRemainingPoints(): number {
    return this.pointsInvested - this.pointsReturned;
  }

  /**
   * 计算周期进度百分比
   */
  getProgressPercent(): number {
    return Math.min((this.currentDayIndex / CYCLE_DURATION_DAYS) * 100, 100);
  }

  /**
   * 从 JSON 对象反序列化
   */
  static fromJson(json: Record<string, Object>): CycleInfo {
    const cycle = new CycleInfo();
    cycle.cycleId = (json['cycleId'] as string) ?? '';
    cycle.startDateKey = (json['startDateKey'] as string) ?? '';
    cycle.endDateKey = (json['endDateKey'] as string) ?? '';
    cycle.pointsInvested = (json['pointsInvested'] as number) ?? 30;
    cycle.pointsReturned = (json['pointsReturned'] as number) ?? 0;
    cycle.currentDayIndex = (json['currentDayIndex'] as number) ?? 1;
    cycle.isActive = (json['isActive'] as boolean) ?? true;
    return cycle;
  }

  /**
   * 序列化为 JSON 对象
   */
  toJson(): CycleInfoJson {
    const json: CycleInfoJson = {
      cycleId: this.cycleId,
      startDateKey: this.startDateKey,
      endDateKey: this.endDateKey,
      pointsInvested: this.pointsInvested,
      pointsReturned: this.pointsReturned,
      currentDayIndex: this.currentDayIndex,
      isActive: this.isActive
    };
    return json;
  }
}
