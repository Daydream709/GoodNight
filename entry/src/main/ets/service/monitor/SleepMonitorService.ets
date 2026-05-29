/**
 * 睡眠监测核心协调器
 * 协调屏幕监听 + 传感器监听，在睡眠窗口结束时执行综合判定
 *
 * 本类实现 ScreenEventCallback 和 SensorEventCallback 接口，
 * 自身作为回调对象传入子监测器，避免 ArkTS 不允许的对象字面量
 */
import { ISleepMonitorService, SleepMonitorStateCallback } from '../../interface/ISleepMonitorService';
import { IScreenMonitorService, ScreenEventCallback } from '../../interface/IScreenMonitorService';
import { ISensorMonitorService, SensorEventCallback } from '../../interface/ISensorMonitorService';
import { IPointsService } from '../../interface/IPointsService';
import { IDataRepository } from '../../interface/IDataRepository';
import { INotificationService } from '../../interface/INotificationService';
import { DailyRecord } from '../../model/DailyRecord';
import { SleepJudgment } from '../../model/SleepJudgment';
import { SCREEN_ON_THRESHOLD, CYCLE_DURATION_DAYS } from '../../common/Constants';
import { isInSleepWindow, getCurrentNightDateKey, getMillisUntilSleepWindowEnd } from '../../common/SleepTimeUtils';
import { logInfo, logError, logWarn } from '../../common/Logger';
import { notificationManager } from '@kit.NotificationKit';

export class SleepMonitorService implements ISleepMonitorService, ScreenEventCallback, SensorEventCallback {
  private screenMonitor: IScreenMonitorService;
  private sensorMonitor: ISensorMonitorService;
  private pointsService: IPointsService;
  private dataRepository: IDataRepository;
  private notificationService: INotificationService;

  private currentNightRecord: DailyRecord | null = null;
  private monitoringActive: boolean = false;
  private stateCallback: SleepMonitorStateCallback | null = null;
  private endTimer: number = -1;

  constructor(
    screenMonitor: IScreenMonitorService,
    sensorMonitor: ISensorMonitorService,
    pointsService: IPointsService,
    dataRepository: IDataRepository,
    notificationService: INotificationService
  ) {
    this.screenMonitor = screenMonitor;
    this.sensorMonitor = sensorMonitor;
    this.pointsService = pointsService;
    this.dataRepository = dataRepository;
    this.notificationService = notificationService;
  }

  // ========== ScreenEventCallback 实现 ==========

  onScreenOn(): void {
    if (this.stateCallback) {
      this.stateCallback.onIntermediateEvent('screenOn', this.screenMonitor.getScreenOnCount());
    }
  }

  onScreenOff(): void {
  }

  // ========== SensorEventCallback 实现 ==========

  onSignificantMovement(magnitude: number): void {
    if (this.stateCallback) {
      this.stateCallback.onIntermediateEvent('movement', this.sensorMonitor.getMovementEventCount());
    }
  }

  // ========== ISleepMonitorService 实现 ==========

  startNightlyMonitoring(callback: SleepMonitorStateCallback): void {
    if (this.monitoringActive) {
      logWarn('Monitoring already active');
      return;
    }

    if (!isInSleepWindow()) {
      logWarn('Not in sleep window, cannot start monitoring');
      return;
    }

    this.stateCallback = callback;

    // 重置子监测器计数
    this.screenMonitor.resetScreenOnCount();
    this.sensorMonitor.resetMovementEventCount();

    // 创建当晚记录
    this.currentNightRecord = new DailyRecord();
    this.currentNightRecord.dateKey = getCurrentNightDateKey();
    this.currentNightRecord.judgment = SleepJudgment.NOT_YET_EVALUATED;
    this.currentNightRecord.monitorStartTime = Date.now();

    // 启动屏幕和传感器监听，传入 this 作为回调
    this.screenMonitor.startMonitoring(this);
    this.sensorMonitor.startMonitoring(this);

    // 设置窗口结束定时器（06:00 自动停止并判定）
    const millisUntilEnd = getMillisUntilSleepWindowEnd();
    this.endTimer = setTimeout(() => {
      this.evaluateAndStop();
    }, millisUntilEnd) as number;

    this.monitoringActive = true;
    logInfo('Nightly monitoring started for %{public}s, will end in %{public}s ms',
      this.currentNightRecord.dateKey, millisUntilEnd.toString());

    if (this.stateCallback) {
      this.stateCallback.onMonitoringStarted();
    }
  }

  stopNightlyMonitoring(): void {
    this.evaluateAndStop();
  }

  isMonitoring(): boolean {
    return this.monitoringActive;
  }

  getCurrentNightData(): DailyRecord | null {
    return this.currentNightRecord;
  }

  /**
   * 综合判定并停止监测
   */
  private async evaluateAndStop(): Promise<void> {
    if (!this.monitoringActive) {
      return;
    }

    // 清除定时器
    if (this.endTimer !== -1) {
      clearTimeout(this.endTimer);
      this.endTimer = -1;
    }

    // 获取监测数据
    const screenOnCount = this.screenMonitor.getScreenOnCount();
    const movementEventCount = this.sensorMonitor.getMovementEventCount();
    const maxAcceleration = this.sensorMonitor.getMaxAcceleration();

    // 综合判定逻辑
    const judgment = this.evaluateCompliance(screenOnCount, movementEventCount);

    // 停止子监测器
    this.screenMonitor.stopMonitoring();
    this.sensorMonitor.stopMonitoring();

    // 完成记录
    if (this.currentNightRecord) {
      this.currentNightRecord.screenOnCount = screenOnCount;
      this.currentNightRecord.movementEventCount = movementEventCount;
      this.currentNightRecord.maxAcceleration = maxAcceleration;
      this.currentNightRecord.judgment = judgment;
      this.currentNightRecord.monitorEndTime = Date.now();

      // 保存记录
      await this.dataRepository.saveDailyRecord(this.currentNightRecord);

      // 更新周期天数
      const cycle = await this.dataRepository.getCurrentCycle();
      if (cycle && cycle.isActive) {
        cycle.currentDayIndex = Math.min(cycle.currentDayIndex + 1, CYCLE_DURATION_DAYS);

        // 如果达标，返还点数
        if (judgment === SleepJudgment.COMPLIANT) {
          await this.pointsService.returnPoint(cycle.cycleId, this.currentNightRecord.dateKey);
        }

        // 检查周期是否结束
        if (cycle.currentDayIndex > CYCLE_DURATION_DAYS) {
          cycle.isActive = false;
          await this.notificationService.notifyCycleSummary(cycle);
        }

        await this.dataRepository.saveCurrentCycle(cycle);
      }

      // 发送结果通知
      await this.notificationService.notifyComplianceResult(
        judgment === SleepJudgment.COMPLIANT,
        this.currentNightRecord.dateKey
      );
    }

    // 取消持续通知
    try {
      await notificationManager.cancel(1001);
    } catch (e) {
      // 忽略取消失败
    }

    this.monitoringActive = false;
    const judgmentStr = judgment === SleepJudgment.COMPLIANT ? 'COMPLIANT' : 'NON_COMPLIANT';
    logInfo('Monitoring ended: %{public}s, screenOn=%{public}s, movement=%{public}s',
      judgmentStr, screenOnCount.toString(), movementEventCount.toString());

    if (this.stateCallback) {
      this.stateCallback.onMonitoringStopped(judgment);
    }
    this.stateCallback = null;
  }

  /**
   * 综合判定算法
   * - 亮屏次数 <= 阈值 且 无显著移动 → 达标
   * - 否则 → 未达标
   */
  private evaluateCompliance(screenOnCount: number, movementEventCount: number): SleepJudgment {
    if (screenOnCount <= SCREEN_ON_THRESHOLD && movementEventCount === 0) {
      return SleepJudgment.COMPLIANT;
    }
    return SleepJudgment.NON_COMPLIANT;
  }
}
