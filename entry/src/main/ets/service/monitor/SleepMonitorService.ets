/**
 * 睡眠监测核心协调器
 * 协调屏幕监听 + 传感器监听，在睡眠窗口结束时执行综合判定
 *
 * 本类实现 ScreenEventCallback 和 SensorEventCallback 接口，
 * 自身作为回调对象传入子监测器，避免 ArkTS 不允许的对象字面量
 */
import { ISleepMonitorService, SleepMonitorStateCallback, MonitorCountListener } from '../../interface/ISleepMonitorService';
import { IScreenMonitorService, ScreenEventCallback } from '../../interface/IScreenMonitorService';
import { ISensorMonitorService, SensorEventCallback } from '../../interface/ISensorMonitorService';
import { IPointsService } from '../../interface/IPointsService';
import { IDataRepository } from '../../interface/IDataRepository';
import { INotificationService } from '../../interface/INotificationService';
import { DailyRecord } from '../../model/DailyRecord';
import { SleepJudgment } from '../../model/SleepJudgment';
import { CYCLE_DURATION_DAYS, NOTIFICATION_ID_MONITOR } from '../../common/Constants';
import { AppSettings } from '../../common/AppSettings';
import { isInSleepWindow, getCurrentNightDateKey, getMillisUntilSleepWindowEnd } from '../../common/SleepTimeUtils';
import { logInfo, logError, logWarn } from '../../common/Logger';
import { notificationManager } from '@kit.NotificationKit';

// AppStorage 中用于 UI 响应式展示监测状态的键（AppStorage 为 ArkTS 全局对象，无需 import）
export const STORE_MON_ACTIVE: string = 'mon_active';
export const STORE_MON_SCREEN_ON: string = 'mon_screenOn';
export const STORE_MON_MOVEMENT: string = 'mon_movement';

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
  private lastLeaveTs: number = 0;
  private countListener: MonitorCountListener | null = null;

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
    this.publishCounts();
    if (this.stateCallback) {
      this.stateCallback.onIntermediateEvent('screenOn', this.screenMonitor.getScreenOnCount());
    }
  }

  onScreenOff(): void {
  }

  // ========== SensorEventCallback 实现 ==========

  onSignificantMovement(magnitude: number): void {
    this.publishCounts();
    if (this.stateCallback) {
      this.stateCallback.onIntermediateEvent('movement', this.sensorMonitor.getMovementEventCount());
    }
  }

  /** 把实时计数发布到 AppStorage + 直接回调监听器，供主页/监测页刷新 */
  private publishCounts(): void {
    const sc = this.screenMonitor.getScreenOnCount();
    const mv = this.sensorMonitor.getMovementEventCount();
    AppStorage.setOrCreate(STORE_MON_SCREEN_ON, sc);
    AppStorage.setOrCreate(STORE_MON_MOVEMENT, mv);
    if (this.countListener) {
      this.countListener(sc, mv);
    }
  }

  setCountListener(listener: MonitorCountListener | null): void {
    this.countListener = listener;
  }

  private publishActive(active: boolean): void {
    AppStorage.setOrCreate(STORE_MON_ACTIVE, active);
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

    this.beginSession(callback);
    logInfo('Nightly monitoring started');

    // 发布常驻通知（后台 taskKeeping 模式需要关联持续通知）
    this.notificationService.notifyMonitoringStarted();

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
   * 公共会话启动内核：重置计数、建当晚记录、起子监测器、装 06:00 自动结算定时器、发布状态。
   * 前台（startDemoMonitoring）与后台夜间（startNightlyMonitoring）共用，确保两条路径行为一致——
   * 尤其是都装自动结算定时器，避免前台会话遗留为"永不结算"的僵尸会话（见 #4）。
   */
  private beginSession(callback: SleepMonitorStateCallback | null): void {
    this.stateCallback = callback;
    this.screenMonitor.resetScreenOnCount();
    this.sensorMonitor.resetMovementEventCount();

    const record = new DailyRecord();
    record.dateKey = getCurrentNightDateKey();
    record.judgment = SleepJudgment.NOT_YET_EVALUATED;
    record.monitorStartTime = Date.now();
    this.currentNightRecord = record;

    this.screenMonitor.startMonitoring(this);
    this.sensorMonitor.startMonitoring(this);

    // 06:00 自动结算定时器（getMillisUntilSleepWindowEnd 始终返回到下一个 06:00 的正值）
    const millisUntilEnd = getMillisUntilSleepWindowEnd();
    this.endTimer = setTimeout(() => {
      this.evaluateAndStop();
    }, millisUntilEnd) as number;

    this.monitoringActive = true;
    this.lastLeaveTs = 0;
    this.publishActive(true);
    this.publishCounts();
    logInfo('Session started for %{public}s, auto-settle in %{public}s ms',
      record.dateKey, millisUntilEnd.toString());
  }

  // ========== 演示 / 模拟（开发版） ==========

  /**
   * 前台监测会话：忽略睡眠时段限制（"今晚监测"页可随时进入），
   * 启动真实的屏幕/传感器监听，可手动结算；同时装 06:00 自动结算定时器，
   * 即使用户不手动结算也不会成为永不结算的僵尸会话。
   */
  startDemoMonitoring(): void {
    if (this.monitoringActive) {
      return;
    }
    this.beginSession(null);
    logInfo('Foreground session started (sleep-window check bypassed)');
  }

  /**
   * 模拟一整晚的结算：用给定计数直接走完整判定与持久化流程，
   * 无需真实监测，便于演示"达标/熬夜"两种结果对点数/记录/统计的影响。
   */
  async simulateNight(screenOnCount: number, movementEventCount: number): Promise<SleepJudgment> {
    const judgment = this.evaluateCompliance(screenOnCount, movementEventCount);
    const record = new DailyRecord();
    record.dateKey = getCurrentNightDateKey();
    record.screenOnCount = screenOnCount;
    record.movementEventCount = movementEventCount;
    record.maxAcceleration = movementEventCount > 0 ? 18 : 3;
    record.judgment = judgment;
    record.monitorEndTime = Date.now();
    record.monitorStartTime = record.monitorEndTime - 8 * 3600 * 1000; // 模拟 8 小时
    await this.finalizeNight(record);
    logInfo('Simulated night: judgment=%{public}s', judgment.toString());
    return judgment;
  }

  /**
   * 结算落库：保存记录、推进周期、达标返点、周期结束通知、结果通知
   * （evaluateAndStop 与 simulateNight 共用）
   *
   * 关键约束：
   * - 幂等：同一晚（dateKey）只推进一次天数、只返一次点；重复结算只覆盖记录、不重复推进。
   * - 顺序：returnPoint 会改写库中的 pointsReturned，故推进天数前必须重新读取最新 cycle，
   *   否则用旧副本保存会把刚返还的点数覆盖回去。
   * - 收尾统一 bump dataVersion，确保自动结算(06:00)等所有路径都能刷新首页/统计/我的。
   */
  private async finalizeNight(record: DailyRecord): Promise<void> {
    // 该日期此前是否已结算过（已有判定结果的记录）
    const existing = await this.dataRepository.getDailyRecord(record.dateKey);
    const alreadySettled: boolean =
      existing !== null && existing.judgment !== SleepJudgment.NOT_YET_EVALUATED;

    await this.dataRepository.saveDailyRecord(record);

    if (!alreadySettled) {
      const cycle = await this.dataRepository.getCurrentCycle();
      if (cycle && cycle.isActive) {
        // 达标返点（由 pointsService 负责并写库，保留未来接入支付的扩展点）
        if (record.judgment === SleepJudgment.COMPLIANT) {
          await this.pointsService.returnPoint(cycle.cycleId, record.dateKey);
        }
        // 重新读取：拿到 returnPoint 写入后的最新 pointsReturned，避免被旧副本覆盖
        const fresh = await this.dataRepository.getCurrentCycle();
        if (fresh && fresh.isActive) {
          const nextDay = fresh.currentDayIndex + 1;
          if (nextDay > CYCLE_DURATION_DAYS) {
            fresh.currentDayIndex = CYCLE_DURATION_DAYS;
            fresh.isActive = false;
            await this.dataRepository.saveCurrentCycle(fresh);
            await this.notificationService.notifyCycleSummary(fresh);
          } else {
            fresh.currentDayIndex = nextDay;
            await this.dataRepository.saveCurrentCycle(fresh);
          }
        }
      }
    }

    await this.notificationService.notifyComplianceResult(
      record.judgment === SleepJudgment.COMPLIANT, record.dateKey);

    // 统一通知所有页面刷新（首页/统计/我的），覆盖自动结算与手动结算所有路径
    AppStorage.setOrCreate('dataVersion', (AppStorage.get<number>('dataVersion') ?? 0) + 1);
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
      await this.finalizeNight(this.currentNightRecord);
    }

    // 取消持续通知
    try {
      await notificationManager.cancel(NOTIFICATION_ID_MONITOR);
    } catch (e) {
      // 忽略取消失败
    }

    this.monitoringActive = false;
    this.publishActive(false);
    this.publishCounts();
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
    if (screenOnCount <= AppSettings.screenOnThreshold && movementEventCount === 0) {
      return SleepJudgment.COMPLIANT;
    }
    return SleepJudgment.NON_COMPLIANT;
  }

  // ========== 实时监测计数（供 UI 展示） ==========

  getLiveScreenOnCount(): number {
    return this.screenMonitor.getScreenOnCount();
  }

  getLiveMovementCount(): number {
    return this.sensorMonitor.getMovementEventCount();
  }

  /** 记一次"离开监测页/使用手机"为亮屏（监测中才生效，800ms 去抖防多信号重复计数） */
  recordScreenLeave(): void {
    if (!this.monitoringActive) {
      return;
    }
    const now = Date.now();
    if (now - this.lastLeaveTs < 800) {
      return;
    }
    this.lastLeaveTs = now;
    this.screenMonitor.increment();
  }
}
