/**
 * 睡眠监测协调器接口
 * 协调屏幕监听和传感器监听，执行综合判定
 */
import { DailyRecord } from '../model/DailyRecord';
import { SleepJudgment } from '../model/SleepJudgment';

export interface SleepMonitorStateCallback {
  /** 监测已开始 */
  onMonitoringStarted(): void;
  /** 监测已结束（含判定结果） */
  onMonitoringStopped(judgment: SleepJudgment): void;
  /** 中间事件（屏幕亮起、移动等） */
  onIntermediateEvent(eventType: string, count: number): void;
}

export interface ISleepMonitorService {
  /** 开始夜间监测 */
  startNightlyMonitoring(callback: SleepMonitorStateCallback): void;

  /** 手动停止夜间监测 */
  stopNightlyMonitoring(): void;

  /** 是否正在监测中 */
  isMonitoring(): boolean;

  /** 获取当前夜晚的监测数据 */
  getCurrentNightData(): DailyRecord | null;
}
