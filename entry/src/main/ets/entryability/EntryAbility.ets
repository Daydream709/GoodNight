/**
 * EntryAbility - 应用主入口
 * 实现 SleepMonitorStateCallback，自身作为监测回调
 */
import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { wantAgent, WantAgent } from '@kit.AbilityKit';
import { DatabaseRepository } from '../service/data/DatabaseRepository';
import { AuthService } from '../service/auth/AuthService';
import { VirtualPointsService } from '../service/points/VirtualPointsService';
import { ScreenMonitorService } from '../service/monitor/ScreenMonitorService';
import { SensorMonitorService } from '../service/monitor/SensorMonitorService';
import { SleepMonitorService } from '../service/monitor/SleepMonitorService';
import { NotificationService } from '../service/notification/NotificationService';
import { SleepMonitorStateCallback } from '../interface/ISleepMonitorService';
import { SleepJudgment } from '../model/SleepJudgment';
import { isInSleepWindow } from '../common/SleepTimeUtils';
import { logInfo, logError } from '../common/Logger';

export default class EntryAbility extends UIAbility implements SleepMonitorStateCallback {
  private sleepMonitorService: SleepMonitorService | null = null;
  private dataRepository: DatabaseRepository | null = null;
  private wantAgentObj: WantAgent | null = null;
  private isBackgroundTaskRunning: boolean = false;
  private authService: AuthService | null = null;

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
    this.initDatabase();
  }

  onDestroy(): void {
    logInfo('Ability onDestroy');
    this.cleanup();
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    logInfo('Ability onWindowStageCreate');
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
  }

  onForeground(): void {
    logInfo('Ability onForeground');
  }

  onBackground(): void {
    logInfo('Ability onBackground');
    if (isInSleepWindow() && this.sleepMonitorService && !this.sleepMonitorService.isMonitoring()) {
      this.startBackgroundMonitoring();
    }
  }

  // ========== 服务管理 ==========

  private async initDatabase(): Promise<void> {
    try {
      this.dataRepository = new DatabaseRepository();
      await this.dataRepository.init(this.context);
      this.authService = new AuthService(this.dataRepository);
      await this.authService.loadConfigCache();
      logInfo('Database and AuthService initialized');
    } catch (err) {
      logError('Failed to init database: %{public}s', (err as Error).message ?? '');
    }
  }

  /**
   * 初始化监测相关服务（登录成功后由页面调用）
   */
  async initMonitorServices(dbRepo: DatabaseRepository): Promise<void> {
    try {
      this.dataRepository = dbRepo;

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

      await this.createWantAgent();

      AppStorage.setOrCreate('sleepMonitorService', this.sleepMonitorService);
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
        wants: [{ bundleName: 'com.example.goodnight', abilityName: 'EntryAbility' }],
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
