/**
 * 好梦 (Good Night) 主页
 * 展示：当前周期进度、点数状态、昨晚达标结果
 * 使用 SQLite 数据库，通过 AppStorage 获取共享服务
 */
import { router } from '@kit.ArkUI';
import { CycleInfo } from '../model/CycleInfo';
import { DailyRecord } from '../model/DailyRecord';
import { SleepJudgment } from '../model/SleepJudgment';
import { IDataRepository } from '../interface/IDataRepository';
import { IPointsService } from '../interface/IPointsService';
import { ISleepMonitorService } from '../interface/ISleepMonitorService';
import { IAuthService } from '../interface/IAuthService';
import { DatabaseRepository } from '../service/data/DatabaseRepository';
import { VirtualPointsService } from '../service/points/VirtualPointsService';
import { getPreviousNightDateKey } from '../common/SleepTimeUtils';
import { CYCLE_DURATION_DAYS } from '../common/Constants';
import { logInfo, logError } from '../common/Logger';

@Entry
@Component
struct Index {
  @State currentCycle: CycleInfo | null = null;
  @State lastNightRecord: DailyRecord | null = null;
  @State isMonitoring: boolean = false;
  @State remainingPoints: number = 0;
  @State returnedPoints: number = 0;
  @State username: string = '';

  private dataRepo: DatabaseRepository | null = null;
  private pointsService: VirtualPointsService | null = null;
  private sleepMonitor: ISleepMonitorService | null = null;
  private authService: IAuthService | null = null;
  private servicesReady: boolean = false;

  async aboutToAppear(): Promise<void> {
    try {
      // 从 AppStorage 获取共享的数据库实例和认证服务
      this.dataRepo = AppStorage.get<DatabaseRepository>('dbRepo') ?? null;
      this.authService = AppStorage.get<IAuthService>('authService') ?? null;

      if (!this.dataRepo) {
        logError('Database not available, redirecting to login');
        router.replaceUrl({ url: 'pages/LoginPage' });
        return;
      }

      // 获取当前用户名
      if (this.authService && this.authService.getCurrentUser()) {
        this.username = this.authService.getCurrentUser()!.username;
      }

      // 初始化点数服务
      this.pointsService = new VirtualPointsService(this.dataRepo);

      // 触发 EntryAbility 初始化监测服务
      this.sleepMonitor = AppStorage.get<ISleepMonitorService>('sleepMonitorService') ?? null;

      this.servicesReady = true;
      await this.refreshData();
      logInfo('Index page initialized');
    } catch (err) {
      logError('Failed to initialize Index: %{public}s', (err as Error).message ?? '');
    }
  }

  build() {
    Column() {
      // 顶部栏（用户名 + 登出）
      this.TopBar();

      // 内容区域
      Scroll() {
        Column({ space: 16 }) {
          this.CycleCard();
          this.PointsCard();
          this.LastNightCard();
          this.ActionButton();
        }
        .padding({ left: 20, right: 20, bottom: 24 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F0F2F5')
  }

  // ========== 组件 ==========

  @Builder
  TopBar(): void {
    Row() {
      Column() {
        Text('好梦')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor('#2D3436')
        Text(`${this.username}`)
          .fontSize(12)
          .fontColor('#636E72')
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)

      Blank()

      Button('登出')
        .height(32)
        .fontSize(13)
        .fontColor('#E17055')
        .backgroundColor(Color.Transparent)
        .border({ width: 1, color: '#E17055', radius: 16 })
        .onClick(() => {
          this.handleLogout();
        })
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 16, bottom: 8 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  CycleCard(): void {
    Column() {
      Text('当前周期')
        .fontSize(14)
        .fontColor('#636E72')
        .margin({ bottom: 8 })

      if (this.currentCycle) {
        Row() {
          Text(`第 ${this.currentCycle.currentDayIndex} 天`)
            .fontSize(32)
            .fontWeight(FontWeight.Bold)
            .fontColor('#6C5CE7')
          Text(` / ${CYCLE_DURATION_DAYS}`)
            .fontSize(18)
            .fontColor('#636E72')
        }
        .margin({ bottom: 12 })

        Progress({
          value: this.currentCycle.currentDayIndex,
          total: CYCLE_DURATION_DAYS,
          type: ProgressType.Linear
        })
          .width('100%')
          .color('#6C5CE7')
          .backgroundColor('#DFE6E9')
          .style({ strokeWidth: 8 })

        Text(`${this.currentCycle.startDateKey} - ${this.currentCycle.endDateKey}`)
          .fontSize(12)
          .fontColor('#636E72')
          .margin({ top: 8 })
      } else {
        Text('尚未开始周期')
          .fontSize(16)
          .fontColor('#636E72')
          .margin({ top: 16, bottom: 16 })
      }
    }
    .width('100%')
    .padding(20)
    .backgroundColor(Color.White)
    .borderRadius(12)
  }

  @Builder
  PointsCard(): void {
    Row() {
      Column() {
        Text('剩余点数')
          .fontSize(12)
          .fontColor('#636E72')
        Text(`${this.remainingPoints}`)
          .fontSize(36)
          .fontWeight(FontWeight.Bold)
          .fontColor('#E17055')
          .margin({ top: 4 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)

      Divider()
        .vertical(true)
        .height(50)
        .color('#DFE6E9')

      Column() {
        Text('已返还点数')
          .fontSize(12)
          .fontColor('#636E72')
        Text(`${this.returnedPoints}`)
          .fontSize(36)
          .fontWeight(FontWeight.Bold)
          .fontColor('#00B894')
          .margin({ top: 4 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .padding(20)
    .backgroundColor(Color.White)
    .borderRadius(12)
  }

  @Builder
  LastNightCard(): void {
    Column() {
      Text('昨晚')
        .fontSize(14)
        .fontColor('#636E72')
        .margin({ bottom: 12 })

      if (this.lastNightRecord) {
        if (this.lastNightRecord.judgment === SleepJudgment.COMPLIANT) {
          Row() {
            Text('✓')
              .fontSize(24)
              .fontColor('#FFFFFF')
              .backgroundColor('#00B894')
              .borderRadius(20)
              .width(40)
              .height(40)
              .textAlign(TextAlign.Center)
            Text('睡眠达标，点数已返还！')
              .fontSize(16)
              .fontColor('#2D3436')
              .margin({ left: 12 })
          }
        } else if (this.lastNightRecord.judgment === SleepJudgment.NON_COMPLIANT) {
          Row() {
            Text('✗')
              .fontSize(24)
              .fontColor('#FFFFFF')
              .backgroundColor('#E17055')
              .borderRadius(20)
              .width(40)
              .height(40)
              .textAlign(TextAlign.Center)
            Text('检测到熬夜，未返还点数')
              .fontSize(16)
              .fontColor('#2D3436')
              .margin({ left: 12 })
          }
        } else {
          Text('监测中...')
            .fontSize(16)
            .fontColor('#636E72')
        }

        if (this.lastNightRecord.judgment !== SleepJudgment.NOT_YET_EVALUATED) {
          Row({ space: 24 }) {
            Text(`亮屏: ${this.lastNightRecord.screenOnCount} 次`)
              .fontSize(12)
              .fontColor('#636E72')
            Text(`移动: ${this.lastNightRecord.movementEventCount} 次`)
              .fontSize(12)
              .fontColor('#636E72')
          }
          .margin({ top: 8 })
        }
      } else {
        Text('暂无数据')
          .fontSize(16)
          .fontColor('#636E72')
      }
    }
    .width('100%')
    .padding(20)
    .backgroundColor(Color.White)
    .borderRadius(12)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ActionButton(): void {
    Button(this.isMonitoring ? '停止监测' :
           (this.currentCycle ? '周期进行中' : '开始新周期'))
      .width('100%')
      .height(50)
      .fontSize(18)
      .fontColor(Color.White)
      .backgroundColor(this.isMonitoring ? '#E17055' : '#6C5CE7')
      .borderRadius(12)
      .enabled(!this.currentCycle || this.isMonitoring)
      .onClick(() => {
        if (this.isMonitoring && this.sleepMonitor) {
          this.sleepMonitor.stopNightlyMonitoring();
          this.isMonitoring = false;
          this.refreshData();
        } else if (!this.currentCycle) {
          this.startNewCycle();
        }
      })
  }

  // ========== 业务方法 ==========

  private async refreshData(): Promise<void> {
    if (!this.servicesReady || !this.dataRepo) {
      return;
    }
    try {
      const cycle = await this.dataRepo.getCurrentCycle();
      this.currentCycle = cycle;

      if (cycle) {
        this.remainingPoints = cycle.getRemainingPoints();
        this.returnedPoints = cycle.pointsReturned;
        const lastNightKey = getPreviousNightDateKey();
        this.lastNightRecord = await this.dataRepo.getDailyRecord(lastNightKey);
      } else {
        this.remainingPoints = 0;
        this.returnedPoints = 0;
        this.lastNightRecord = null;
      }

      if (this.sleepMonitor) {
        this.isMonitoring = this.sleepMonitor.isMonitoring();
      }
    } catch (err) {
      logError('Failed to refresh data: %{public}s', (err as Error).message ?? '');
    }
  }

  private async startNewCycle(): Promise<void> {
    if (!this.dataRepo || !this.pointsService) {
      logError('Services not initialized');
      return;
    }
    try {
      const cycle = await this.dataRepo.startNewCycle();
      await this.pointsService.investPoints(cycle.cycleId, 30);
      await this.refreshData();
      logInfo('New cycle started from UI');
    } catch (err) {
      logError('Failed to start new cycle: %{public}s', (err as Error).message ?? '');
    }
  }

  private async handleLogout(): Promise<void> {
    if (this.sleepMonitor && this.sleepMonitor.isMonitoring()) {
      this.sleepMonitor.stopNightlyMonitoring();
    }
    if (this.authService) {
      await this.authService.logout();
    }
    router.replaceUrl({ url: 'pages/LoginPage' });
  }
}
