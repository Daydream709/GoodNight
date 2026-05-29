/**
 * 主页 Tab - 显示周期进度、点数、昨晚结果
 */
import { router } from '@kit.ArkUI';
import { CycleInfo } from '../model/CycleInfo';
import { DailyRecord } from '../model/DailyRecord';
import { SleepJudgment } from '../model/SleepJudgment';
import { IAuthService } from '../interface/IAuthService';
import { ISleepMonitorService } from '../interface/ISleepMonitorService';
import { DatabaseRepository } from '../service/data/DatabaseRepository';
import { VirtualPointsService } from '../service/points/VirtualPointsService';
import { getPreviousNightDateKey } from '../common/SleepTimeUtils';
import { CYCLE_DURATION_DAYS } from '../common/Constants';
import { logInfo, logError } from '../common/Logger';
import { AppColors } from '../common/AppColors';

@Component
export struct HomeTab {
  @StorageLink('isDarkMode') isDarkMode: boolean = false;
  @State currentCycle: CycleInfo | null = null;
  @State lastNightRecord: DailyRecord | null = null;
  @State isMonitoring: boolean = false;
  @State remainingPoints: number = 0;
  @State returnedPoints: number = 0;
  @State username: string = '';
  @State toggleAngle: number = 0;

  private dataRepo: DatabaseRepository | null = null;
  private pointsService: VirtualPointsService | null = null;
  private sleepMonitor: ISleepMonitorService | null = null;
  private authService: IAuthService | null = null;
  private servicesReady: boolean = false;

  async aboutToAppear(): Promise<void> {
    try {
      this.dataRepo = AppStorage.get<DatabaseRepository>('dbRepo') ?? null;
      this.authService = AppStorage.get<IAuthService>('authService') ?? null;

      if (!this.dataRepo) {
        router.replaceUrl({ url: 'pages/LoginPage' });
        return;
      }

      if (this.authService && this.authService.getCurrentUser()) {
        this.username = this.authService.getCurrentUser()!.username;
      }

      this.pointsService = new VirtualPointsService(this.dataRepo);
      this.sleepMonitor = AppStorage.get<ISleepMonitorService>('sleepMonitorService') ?? null;
      this.servicesReady = true;
      await this.refreshData();
    } catch (err) {
      logError('HomeTab init failed: %{public}s', (err as Error).message ?? '');
    }
  }

  private colors() {
    return AppColors.current(this.isDarkMode);
  }

  build() {
    Column() {
      this.TopBar();
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
    .backgroundColor(this.colors().background)
  }

  @Builder
  TopBar(): void {
    Row() {
      Column() {
        Text('好梦')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.colors().textPrimary)
        Text(this.username)
          .fontSize(12)
          .fontColor(this.colors().textSecondary)
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      Blank()
      // 深色/浅色模式切换图标
      Column() {
        Image(this.isDarkMode ? $r('app.media.icon_sun') : $r('app.media.icon_moon'))
          .width(22)
          .height(22)
          .fillColor(this.colors().textPrimary)
      }
      .width(40)
      .height(40)
      .borderRadius(20)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .rotate({ angle: this.toggleAngle })
      .animation({ duration: 400, curve: Curve.EaseInOut })
      .onClick(() => {
        this.toggleAngle = this.toggleAngle + 180;
        animateTo({ duration: 400, curve: Curve.EaseInOut }, () => {
          this.isDarkMode = !this.isDarkMode;
        });
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
        .fontColor(this.colors().textSecondary)
        .margin({ bottom: 8 })
      if (this.currentCycle) {
        Row() {
          Text(`第 ${this.currentCycle.currentDayIndex} 天`)
            .fontSize(32)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.colors().primary)
          Text(` / ${CYCLE_DURATION_DAYS}`)
            .fontSize(18)
            .fontColor(this.colors().textSecondary)
        }
        .margin({ bottom: 12 })
        Progress({ value: this.currentCycle.currentDayIndex, total: CYCLE_DURATION_DAYS, type: ProgressType.Linear })
          .width('100%')
          .color(this.colors().primary)
          .backgroundColor(this.colors().progressTrack)
          .style({ strokeWidth: 8 })
        Text(`${this.currentCycle.startDateKey} - ${this.currentCycle.endDateKey}`)
          .fontSize(12)
          .fontColor(this.colors().textSecondary)
          .margin({ top: 8 })
      } else {
        Text('尚未开始周期')
          .fontSize(16)
          .fontColor(this.colors().textSecondary)
          .margin({ top: 16, bottom: 16 })
      }
    }
    .width('100%')
    .padding(20)
    .backgroundColor(this.colors().glassBg)
    .borderRadius(20)
    .border({ width: 1, color: this.colors().glassBorder })
    .backdropBlur(this.colors().glassBlur)
  }

  @Builder
  PointsCard(): void {
    Row() {
      Column() {
        Text('剩余点数').fontSize(12).fontColor(this.colors().textSecondary)
        Text(`${this.remainingPoints}`).fontSize(36).fontWeight(FontWeight.Bold).fontColor(this.colors().danger).margin({ top: 4 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)
      Divider().vertical(true).height(50).color(this.colors().divider)
      Column() {
        Text('已返还点数').fontSize(12).fontColor(this.colors().textSecondary)
        Text(`${this.returnedPoints}`).fontSize(36).fontWeight(FontWeight.Bold).fontColor(this.colors().success).margin({ top: 4 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .padding(20)
    .backgroundColor(this.colors().glassBg)
    .borderRadius(20)
    .border({ width: 1, color: this.colors().glassBorder })
    .backdropBlur(this.colors().glassBlur)
  }

  @Builder
  LastNightCard(): void {
    Column() {
      Text('昨晚').fontSize(14).fontColor(this.colors().textSecondary).margin({ bottom: 12 })
      if (this.lastNightRecord) {
        if (this.lastNightRecord.judgment === SleepJudgment.COMPLIANT) {
          Row() {
            Text('\u2713').fontSize(24).fontColor('#FFFFFF').backgroundColor(this.colors().success).borderRadius(20).width(40).height(40).textAlign(TextAlign.Center)
            Text('睡眠达标，点数已返还！').fontSize(16).fontColor(this.colors().textPrimary).margin({ left: 12 })
          }
        } else if (this.lastNightRecord.judgment === SleepJudgment.NON_COMPLIANT) {
          Row() {
            Text('\u2717').fontSize(24).fontColor('#FFFFFF').backgroundColor(this.colors().danger).borderRadius(20).width(40).height(40).textAlign(TextAlign.Center)
            Text('检测到熬夜，未返还点数').fontSize(16).fontColor(this.colors().textPrimary).margin({ left: 12 })
          }
        } else {
          Text('监测中...').fontSize(16).fontColor(this.colors().textSecondary)
        }
        if (this.lastNightRecord.judgment !== SleepJudgment.NOT_YET_EVALUATED) {
          Row({ space: 24 }) {
            Text(`亮屏: ${this.lastNightRecord.screenOnCount} 次`).fontSize(12).fontColor(this.colors().textSecondary)
            Text(`移动: ${this.lastNightRecord.movementEventCount} 次`).fontSize(12).fontColor(this.colors().textSecondary)
          }.margin({ top: 8 })
        }
      } else {
        Text('暂无数据').fontSize(16).fontColor(this.colors().textSecondary)
      }
    }
    .width('100%')
    .padding(20)
    .backgroundColor(this.colors().glassBg)
    .borderRadius(20)
    .border({ width: 1, color: this.colors().glassBorder })
    .backdropBlur(this.colors().glassBlur)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ActionButton(): void {
    Button(this.isMonitoring ? '停止监测' : (this.currentCycle ? '周期进行中' : '开始新周期'))
      .width('100%')
      .height(50)
      .fontSize(18)
      .fontColor(Color.White)
      .backgroundColor(this.isMonitoring ? this.colors().danger : this.colors().primary)
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

  private async refreshData(): Promise<void> {
    if (!this.servicesReady || !this.dataRepo) { return; }
    try {
      const cycle = await this.dataRepo.getCurrentCycle();
      this.currentCycle = cycle;
      if (cycle) {
        this.remainingPoints = cycle.getRemainingPoints();
        this.returnedPoints = cycle.pointsReturned;
        this.lastNightRecord = await this.dataRepo.getDailyRecord(getPreviousNightDateKey());
      } else {
        this.remainingPoints = 0;
        this.returnedPoints = 0;
        this.lastNightRecord = null;
      }
      if (this.sleepMonitor) { this.isMonitoring = this.sleepMonitor.isMonitoring(); }
    } catch (err) {
      logError('Refresh failed: %{public}s', (err as Error).message ?? '');
    }
  }

  private async startNewCycle(): Promise<void> {
    if (!this.dataRepo || !this.pointsService) { return; }
    try {
      const cycle = await this.dataRepo.startNewCycle();
      await this.pointsService.investPoints(cycle.cycleId, 30);
      await this.refreshData();
    } catch (err) {
      logError('Start cycle failed: %{public}s', (err as Error).message ?? '');
    }
  }
}
