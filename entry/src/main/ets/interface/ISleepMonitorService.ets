/**
 * 睡眠监测协调器接口
 * 协调屏幕监听和传感器监听，执行综合判定
 */
import { DailyRecord } from '../model/DailyRecord';
import { SleepJudgment } from '../model/SleepJudgment';

/** 实时计数变化监听器（screenOn 亮屏次数，movement 移动次数） */
export type MonitorCountListener = (screenOn: number, movement: number) => void;

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

  /** 实时亮屏次数（监测中供 UI 展示） */
  getLiveScreenOnCount(): number;

  /** 实时显著移动次数（监测中供 UI 展示） */
  getLiveMovementCount(): number;

  /** 启动一次前台监测会话：忽略睡眠时段、手动结算（监测页使用） */
  startDemoMonitoring(): void;

  /** 记一次"离开监测页"为亮屏（监测中才生效） */
  recordScreenLeave(): void;

  /** 注册/注销实时计数监听器（监测页用，计数变化时直接回调刷新 UI） */
  setCountListener(listener: MonitorCountListener | null): void;

  /** 模拟一整晚结算：用给定计数直接走完判定与落库流程（开发版） */
  simulateNight(screenOnCount: number, movementEventCount: number): Promise<SleepJudgment>;
}
