/**
 * EntryAbility - 应用主入口
 * 实现 SleepMonitorStateCallback，自身作为监测回调
 */
import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { wantAgent, WantAgent } from '@kit.AbilityKit';
import { DatabaseRepository } from '../service/data/DatabaseRepository';
import { VirtualPointsService } from '../service/points/VirtualPointsService';
import { ScreenMonitorService } from '../service/monitor/ScreenMonitorService';
import { SensorMonitorService } from '../service/monitor/SensorMonitorService';
import { SleepMonitorService } from '../service/monitor/SleepMonitorService';
import { NotificationService } from '../service/notification/NotificationService';
import { SleepMonitorStateCallback } from '../interface/ISleepMonitorService';
import { SleepJudgment } from '../model/SleepJudgment';
import { isInSleepWindow } from '../common/SleepTimeUtils';
import { EVENT_LOGIN_SUCCESS, EVENT_LOGOUT, EVENT_REQUEST_MONITORING, BUNDLE_NAME } from '../common/Constants';
import { logInfo, logError } from '../common/Logger';

export default class EntryAbility extends UIAbility implements SleepMonitorStateCallback {
  private sleepMonitorService: SleepMonitorService | null = null;
  private wantAgentObj: WantAgent | null = null;
  private isBackgroundTaskRunning: boolean = false;
  /** 登录成功事件回调，保存引用以便注销 */
  private onLoginSuccessHandler: () => void = (): void => { this.onUserLoggedIn(); };
  private onLogoutHandler: () => void = (): void => { this.onUserLoggedOut(); };
  private onRequestMonitoringHandler: () => void = (): void => { this.startBackgroundMonitoring(); };
  private windowStageRef: window.WindowStage | null = null;
  private windowStageEventHandler: (e: window.WindowStageEventType) => void =
    (e: window.WindowStageEventType): void => {
      // 窗口失焦（下拉通知栏/控制中心）或隐藏（回桌面/切应用）时，监测中记一次操作手机；
      // 计数刷新由页面侧 setCountListener 回调 + 定时器轮询完成，无需再广播。
      if (e === window.WindowStageEventType.INACTIVE || e === window.WindowStageEventType.HIDDEN) {
        if (this.sleepMonitorService && this.sleepMonitorService.isMonitoring()) {
          this.sleepMonitorService.recordScreenLeave();
        }
      }
    };

  // ========== SleepMonitorStateCallback 实现 ==========
  onMonitoringStarted(): void {
    logInfo('Monitoring callback: started');
  }

  onMonitoringStopped(judgment: SleepJudgment): void {
    logInfo('Monitoring callback: stopped, judgment=%{public}s', judgment.toString());
    this.stopBackgroundTask();
  }

  onIntermediateEvent(eventType: string, count: number): void {
    logInfo('Monitoring event: %{public}s = %{public}s', eventType, count.toString());
  }

  // ========== UIAbility 生命周期 ==========

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      logError('Failed to set colorMode: %{public}s', (err as Error).message ?? '');
    }
    logInfo('Ability onCreate');
    // 监听页面侧发出的登录/登出事件，统一在 Ability 中管理监测服务生命周期
    this.context.eventHub.on(EVENT_LOGIN_SUCCESS, this.onLoginSuccessHandler);
    this.context.eventHub.on(EVENT_LOGOUT, this.onLogoutHandler);
    this.context.eventHub.on(EVENT_REQUEST_MONITORING, this.onRequestMonitoringHandler);
  }

  onDestroy(): void {
    logInfo('Ability onDestroy');
    this.context.eventHub.off(EVENT_LOGIN_SUCCESS, this.onLoginSuccessHandler);
    this.context.eventHub.off(EVENT_LOGOUT, this.onLogoutHandler);
    this.context.eventHub.off(EVENT_REQUEST_MONITORING, this.onRequestMonitoringHandler);
    this.cleanup();
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    logInfo('Ability onWindowStageCreate');
    this.windowStageRef = windowStage;
    // 监听窗口焦点/可见性变化（下拉通知栏、控制中心、回桌面、切应用）
    try {
      windowStage.on('windowStageEvent', this.windowStageEventHandler);
    } catch (err) {
      logError('Failed to subscribe windowStageEvent: %{public}s', (err as Error).message ?? '');
    }
    // 始终加载 LoginPage 作为入口（它内部处理自动登录逻辑）
    windowStage.loadContent('pages/LoginPage', (err) => {
      if (err.code) {
        logError('Failed to load content: %{public}s', err.message ?? '');
        return;
      }
      logInfo('LoginPage loaded');
    });
  }

  onWindowStageDestroy(): void {
    logInfo('Ability onWindowStageDestroy');
    if (this.windowStageRef) {
      try {
        this.windowStageRef.off('windowStageEvent', this.windowStageEventHandler);
      } catch (err) {
        // 忽略
      }
      this.windowStageRef = null;
    }
  }

  onForeground(): void {
    logInfo('Ability onForeground');
  }

  onBackground(): void {
    logInfo('Ability onBackground');
    // 监测会话进行中却切到后台（回桌面/切应用）记为一次使用手机
    if (this.sleepMonitorService && this.sleepMonitorService.isMonitoring()) {
      this.sleepMonitorService.recordScreenLeave();
    }
    if (isInSleepWindow() && this.sleepMonitorService && !this.sleepMonitorService.isMonitoring()) {
      this.startBackgroundMonitoring();
    }
  }

  // ========== 服务管理 ==========

  /**
   * 登录成功事件处理：使用页面已初始化的共享 dbRepo 构建监测服务链
   * 通过 eventHub 触发，确保 dbRepo（含 currentUserId）已就绪，避免双实例
   */
  private async onUserLoggedIn(): Promise<void> {
    const dbRepo = AppStorage.get<DatabaseRepository>('dbRepo');
    if (!dbRepo) {
      logError('onUserLoggedIn: dbRepo not found in AppStorage');
      return;
    }
    await this.initMonitorServices(dbRepo);
  }

  /**
   * 登出事件处理：停止监测并清理后台任务
   */
  private onUserLoggedOut(): void {
    this.cleanup();
    this.sleepMonitorService = null;
    AppStorage.setOrCreate('sleepMonitorService', null);
  }

  /**
   * 初始化监测相关服务（登录成功后触发）
   */
  private async initMonitorServices(dbRepo: DatabaseRepository): Promise<void> {
    try {
      const pointsService = new VirtualPointsService(dbRepo);
      const notificationService = new NotificationService();
      const screenMonitor = new ScreenMonitorService();
      const sensorMonitor = new SensorMonitorService();

      this.sleepMonitorService = new SleepMonitorService(
        screenMonitor,
        sensorMonitor,
        pointsService,
        dbRepo,
        notificationService
      );

      // 先发布到 AppStorage 供 UI 立即获取（构造为同步，避免 await 期间出现竞态）
      AppStorage.setOrCreate('sleepMonitorService', this.sleepMonitorService);

      await this.createWantAgent();
      logInfo('Monitor services initialized');

      if (isInSleepWindow()) {
        this.startBackgroundMonitoring();
      }
    } catch (err) {
      logError('Failed to init monitor services: %{public}s', (err as Error).message ?? '');
    }
  }

  private async createWantAgent(): Promise<void> {
    try {
      const wantAgentInfo: wantAgent.WantAgentInfo = {
        wants: [{ bundleName: BUNDLE_NAME, abilityName: 'EntryAbility' }],
        operationType: wantAgent.OperationType.START_ABILITY,
        requestCode: 0,
        wantAgentFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
      };
      this.wantAgentObj = await wantAgent.getWantAgent(wantAgentInfo);
    } catch (err) {
      logError('Failed to create WantAgent: %{public}s', (err as Error).message ?? '');
    }
  }

  private async startBackgroundMonitoring(): Promise<void> {
    if (this.isBackgroundTaskRunning || !this.sleepMonitorService || !this.wantAgentObj) {
      return;
    }
    try {
      await backgroundTaskManager.startBackgroundRunning(
        this.context,
        ['taskKeeping'],
        this.wantAgentObj
      );
      this.isBackgroundTaskRunning = true;
      logInfo('Background task started');
      this.sleepMonitorService.startNightlyMonitoring(this);
    } catch (err) {
      logError('Failed to start background monitoring: %{public}s', (err as Error).message ?? '');
    }
  }

  private stopBackgroundTask(): void {
    if (this.isBackgroundTaskRunning) {
      try {
        backgroundTaskManager.stopBackgroundRunning(this.context);
        this.isBackgroundTaskRunning = false;
        logInfo('Background task stopped');
      } catch (err) {
        logError('Failed to stop background task: %{public}s', (err as Error).message ?? '');
      }
    }
  }

  private cleanup(): void {
    if (this.sleepMonitorService && this.sleepMonitorService.isMonitoring()) {
      this.sleepMonitorService.stopNightlyMonitoring();
    }
    this.stopBackgroundTask();
  }
}
