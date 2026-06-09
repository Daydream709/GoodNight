/**
 * 主页 Tab - 显示监测状态、周期进度、点数、昨晚结果
 * 未开始周期时展示引导性空状态（玩法 + 隐私 + 开始挑战）
 */
import { router } from '@kit.ArkUI';
import { CycleInfo } from '../model/CycleInfo';
import { DailyRecord } from '../model/DailyRecord';
import { SleepJudgment } from '../model/SleepJudgment';
import { IAuthService } from '../interface/IAuthService';
import { ISleepMonitorService } from '../interface/ISleepMonitorService';
import { DatabaseRepository } from '../service/data/DatabaseRepository';
import { VirtualPointsService } from '../service/points/VirtualPointsService';
import { getPreviousNightDateKey, isInSleepWindow } from '../common/SleepTimeUtils';
import { CYCLE_DURATION_DAYS, INITIAL_POINTS_INVESTED } from '../common/Constants';
import { AppSettings } from '../common/AppSettings';
import { showToast } from '../common/Toast';
import { StatsCalculator } from '../common/StatsCalculator';
import { logError } from '../common/Logger';
import { AppColors, ColorPalette } from '../common/AppColors';

@Component
export struct HomeTab {
  @StorageLink('isDarkMode') isDarkMode: boolean = false;
  @State currentCycle: CycleInfo | null = null;
  @State lastNightRecord: DailyRecord | null = null;
  // 监测状态与实时计数：用 @State + 轮询定时器从服务直读（可靠，不依赖 @StorageProp 响应式）
  @State isMonitoring: boolean = false;
  @State liveScreenOn: number = 0;
  @State liveMovement: number = 0;
  @State inSleepWindow: boolean = false;
  @State remainingPoints: number = 0;
  @State returnedPoints: number = 0;
  @State username: string = '';
  @State toggleAngle: number = 0;
  @State monitorPulse: boolean = false;
  @State pageAppeared: boolean = false;
  @State lastCompletedCycle: CycleInfo | null = null;
  @State busy: boolean = false;
  @State streak: number = 0;
  @State celebrate: boolean = false;
  // 监测结算等操作后，由其它页面（MonitorPage）递增以触发刷新
  @StorageLink('dataVersion') @Watch('onDataVersionChanged') dataVersion: number = 0;

  private dataRepo: DatabaseRepository | null = null;
  private pointsService: VirtualPointsService | null = null;
  private authService: IAuthService | null = null;
  private servicesReady: boolean = false;
  private monTimer: number = -1;

  onDataVersionChanged(): void {
    this.refreshData();
  }

  /** 从服务轮询监测状态与实时计数 */
  private pollMonitorState(): void {
    const monitor = this.getSleepMonitor();
    if (monitor) {
      this.isMonitoring = monitor.isMonitoring();
      this.liveScreenOn = monitor.getLiveScreenOnCount();
      this.liveMovement = monitor.getLiveMovementCount();
    } else {
      this.isMonitoring = false;
    }
  }

  /**
   * 懒取监测服务：EntryAbility 通过 eventHub 异步构建，
   * 进入主页时可能尚未就绪，故每次使用时从 AppStorage 实时读取
   */
  private getSleepMonitor(): ISleepMonitorService | null {
    return AppStorage.get<ISleepMonitorService>('sleepMonitorService') ?? null;
  }

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
      this.servicesReady = true;
      // 启动监测状态指示灯的呼吸动效
      this.monitorPulse = true;
      this.pollMonitorState();
      // 主页监测计数靠 1.5s 轮询刷新（含 isMonitoring 状态变化）
      this.monTimer = setInterval(() => { this.pollMonitorState(); }, 1500) as number;
      await this.refreshData();
    } catch (err) {
      logError('HomeTab init failed: %{public}s', (err as Error).message ?? '');
    } finally {
      // 内容入场动效：无论数据加载成败都触发，避免内容停留在 opacity 0
      animateTo({ duration: 450, curve: Curve.EaseOut }, () => {
        this.pageAppeared = true;
      });
    }
  }

  aboutToDisappear(): void {
    if (this.monTimer !== -1) {
      clearInterval(this.monTimer);
      this.monTimer = -1;
    }
  }

  private colors(): ColorPalette {
    return AppColors.current(this.isDarkMode);
  }

  /** 睡眠窗口文案，如 "23:30 - 06:00"（读取可配置设置） */
  private sleepWindowText(): string {
    return AppSettings.sleepWindowText();
  }

  build() {
    Column() {
      this.TopBar();
      Scroll() {
        Column({ space: 16 }) {
          if (this.currentCycle) {
            this.MonitorStatusCard();
            this.CycleCard();
            this.PointsCard();
            this.LastNightCard();
            if (this.isMonitoring) {
              this.StopButton();
            } else {
              this.EndCycleButton();
            }
          } else {
            this.EmptyStateCard();
          }
        }
        .padding({ left: 20, right: 20, bottom: 24 })
        .opacity(this.pageAppeared ? 1 : 0)
        .translate({ y: this.pageAppeared ? 0 : 16 })
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
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .constraintSize({ maxWidth: 220 })
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

  /**
   * 监测状态卡 - 主页核心。监测中显示呼吸灯守护态，空闲显示下次监测时间
   */
  @Builder
  MonitorStatusCard(): void {
    Column() {
      Row() {
        // 状态指示点（监测中呼吸）
        Column()
          .width(10)
          .height(10)
          .borderRadius(5)
          .backgroundColor(this.isMonitoring ? this.colors().success : this.colors().textSecondary)
          .opacity(this.isMonitoring ? (this.monitorPulse ? 1 : 0.35) : 0.5)
          .animation(this.isMonitoring
            ? { duration: 1000, iterations: -1, playMode: PlayMode.Alternate, curve: Curve.EaseInOut }
            : { duration: 0 })
        Text(this.isMonitoring ? '正在守护你的睡眠' : '今晚待命中')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.colors().textPrimary)
          .margin({ left: 10 })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text(this.isMonitoring
        ? '把手机放下，安心睡个好觉 · 到点自动结算'
        : (this.inSleepWindow
          ? '现在正处于睡眠时段，可立即开始监测'
          : `每晚 ${this.sleepWindowText()} 自动开始监测`))
        .fontSize(13)
        .fontColor(this.colors().textSecondary)
        .margin({ top: 10 })
        .width('100%')

      // 监测中：实时计数（点击卡片可重新进入监测页）
      if (this.isMonitoring) {
        // 统计内联读取 @State（@Builder 按值传参不会响应式刷新，故不走 LiveStat）
        Row({ space: 20 }) {
          Row() {
            Text(`${this.liveScreenOn}`)
              .fontSize(20).fontWeight(FontWeight.Bold).fontColor(this.colors().textPrimary)
            Text(' 操作').fontSize(12).fontColor(this.colors().textSecondary)
          }.alignItems(VerticalAlign.Center)
          Row() {
            Text(`${this.liveMovement}`)
              .fontSize(20).fontWeight(FontWeight.Bold).fontColor(this.colors().textPrimary)
            Text(' 移动').fontSize(12).fontColor(this.colors().textSecondary)
          }.alignItems(VerticalAlign.Center)
          Blank()
          Text('进入 ›').fontSize(13).fontColor(this.colors().primary)
        }
        .width('100%')
        .margin({ top: 14 })
      } else {
        // 空闲：进入全屏监测页（随时可进入）
        Button('开始今晚监测')
          .width('100%')
          .height(42)
          .fontSize(15)
          .fontColor(Color.White)
          .backgroundColor(this.colors().primary)
          .borderRadius(10)
          .margin({ top: 14 })
          .onClick(() => {
            this.openMonitorPage();
          })
      }
    }
    .width('100%')
    .padding(20)
    .backgroundColor(this.colors().glassBg)
    .borderRadius(20)
    .border({ width: 1, color: this.colors().glassBorder })
    .backdropBlur(this.colors().glassBlur)
    .alignItems(HorizontalAlign.Start)
    .onClick(() => {
      if (this.isMonitoring) {
        this.openMonitorPage();
      }
    })
  }

  @Builder
  CycleCard(): void {
    Row() {
      // 环形进度 + 中心天数
      Stack() {
        Progress({
          value: this.currentCycle ? this.currentCycle.currentDayIndex : 0,
          total: CYCLE_DURATION_DAYS,
          type: ProgressType.Ring
        })
          .width(96)
          .height(96)
          .color(this.colors().primary)
          .backgroundColor(this.colors().progressTrack)
          .style({ strokeWidth: 8 })
        Column() {
          Text(`${this.currentCycle ? this.currentCycle.currentDayIndex : 0}`)
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.colors().primary)
          Text(`/ ${CYCLE_DURATION_DAYS} 天`)
            .fontSize(11)
            .fontColor(this.colors().textSecondary)
        }
      }
      .width(96)
      .height(96)

      Column() {
        Text('当前周期')
          .fontSize(14)
          .fontColor(this.colors().textSecondary)
        // 连续达标 streak
        Row() {
          Text('🔥')
            .fontSize(15)
          Text(`连续达标 ${this.streak} 天`)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.colors().textPrimary)
            .margin({ left: 4 })
        }
        .margin({ top: 8 })
        if (this.currentCycle) {
          Text(`${this.currentCycle.startDateKey} ~ ${this.currentCycle.endDateKey}`)
            .fontSize(11)
            .fontColor(this.colors().textSecondary)
            .margin({ top: 8 })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 20 })
    }
    .width('100%')
    .padding(20)
    .backgroundColor(this.colors().glassBg)
    .borderRadius(20)
    .border({ width: 1, color: this.colors().glassBorder })
    .backdropBlur(this.colors().glassBlur)
    .alignItems(VerticalAlign.Center)
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
            Text('✓').fontSize(24).fontColor('#FFFFFF').backgroundColor(this.colors().success).borderRadius(20).width(40).height(40).textAlign(TextAlign.Center)
            Text('睡眠达标，点数已返还！').fontSize(16).fontColor(this.colors().textPrimary).margin({ left: 12 })
          }
        } else if (this.lastNightRecord.judgment === SleepJudgment.NON_COMPLIANT) {
          Row() {
            Text('✗').fontSize(24).fontColor('#FFFFFF').backgroundColor(this.colors().danger).borderRadius(20).width(40).height(40).textAlign(TextAlign.Center)
            Text('检测到熬夜，未返还点数').fontSize(16).fontColor(this.colors().textPrimary).margin({ left: 12 })
          }
        } else {
          Text('监测中...').fontSize(16).fontColor(this.colors().textSecondary)
        }
        if (this.lastNightRecord.judgment !== SleepJudgment.NOT_YET_EVALUATED) {
          Row({ space: 24 }) {
            Text(`操作: ${this.lastNightRecord.screenOnCount} 次`).fontSize(12).fontColor(this.colors().textSecondary)
            Text(`移动: ${this.lastNightRecord.movementEventCount} 次`).fontSize(12).fontColor(this.colors().textSecondary)
          }.margin({ top: 8 })
        }
      } else {
        Text('暂无数据，今晚开始你的第一次监测吧').fontSize(14).fontColor(this.colors().textSecondary)
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

  /**
   * 空状态引导卡 - 未开始周期时展示玩法、隐私与开始挑战入口
   */
  @Builder
  EmptyStateCard(): void {
    Column() {
      // 峰终：上一期成绩回顾
      if (this.lastCompletedCycle) {
        Column() {
          Text('🎉 上一期挑战完成')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.colors().textPrimary)
          Text(`30 天里成功返还 ${this.lastCompletedCycle.pointsReturned} / ${this.lastCompletedCycle.pointsInvested} 个点数`)
            .fontSize(12)
            .fontColor(this.colors().textSecondary)
            .margin({ top: 4 })
        }
        .width('100%')
        .padding(16)
        .backgroundColor(this.colors().glassInputBg)
        .borderRadius(14)
        .margin({ bottom: 20 })
        .alignItems(HorizontalAlign.Center)
        .scale({ x: this.celebrate ? 1 : 0.85, y: this.celebrate ? 1 : 0.85 })
        .opacity(this.celebrate ? 1 : 0)
      }

      Text('🌙')
        .fontSize(48)
        .margin({ top: 8, bottom: 12 })
      Text(this.lastCompletedCycle ? '再来一期好梦挑战' : '开启 30 天好梦挑战')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.colors().textPrimary)
      Text(`投入 ${INITIAL_POINTS_INVESTED} 个点数，每晚不熬夜就返还 1 个`)
        .fontSize(14)
        .fontColor(this.colors().textSecondary)
        .margin({ top: 8 })
        .textAlign(TextAlign.Center)

      // 三步玩法
      Column({ space: 14 }) {
        this.HowItWorksRow('🌙', '夜间自动监测', `每晚 ${this.sleepWindowText()} 守护你的睡眠`)
        this.HowItWorksRow('📵', '放下手机', '频繁操作手机或移动会判定为熬夜')
        this.HowItWorksRow('🎁', '坚持得回报', '达标次日自动返还 1 个点数')
      }
      .width('100%')
      .margin({ top: 24, bottom: 20 })

      // 隐私说明
      Row() {
        Text('🔒')
          .fontSize(13)
        Text('所有睡眠数据仅存储在本机，不会上传')
          .fontSize(12)
          .fontColor(this.colors().textSecondary)
          .margin({ left: 6 })
      }
      .margin({ bottom: 20 })

      Button(this.lastCompletedCycle ? '再次开始挑战' : '开始 30 天挑战')
        .width('100%')
        .height(50)
        .fontSize(18)
        .fontColor(Color.White)
        .backgroundColor(this.colors().primary)
        .borderRadius(12)
        .enabled(!this.busy)
        .onClick(() => {
          this.confirmStartCycle();
        })
    }
    .width('100%')
    .padding(24)
    .backgroundColor(this.colors().glassBg)
    .borderRadius(20)
    .border({ width: 1, color: this.colors().glassBorder })
    .backdropBlur(this.colors().glassBlur)
    .alignItems(HorizontalAlign.Center)
    .margin({ top: 8 })
  }

  @Builder
  HowItWorksRow(icon: string, title: string, desc: string): void {
    Row() {
      Text(icon)
        .fontSize(20)
        .width(36)
        .height(36)
        .borderRadius(18)
        .backgroundColor(this.colors().glassInputBg)
        .textAlign(TextAlign.Center)
      Column() {
        Text(title)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.colors().textPrimary)
        Text(desc)
          .fontSize(12)
          .fontColor(this.colors().textSecondary)
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 12 })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  StopButton(): void {
    Button('提前结束今晚监测')
      .width('100%')
      .height(50)
      .fontSize(16)
      .fontColor(this.colors().danger)
      .backgroundColor(this.colors().glassBg)
      .borderRadius(12)
      .border({ width: 1, color: this.colors().glassBorder })
      .onClick(() => {
        const monitor = this.getSleepMonitor();
        if (monitor) {
          monitor.stopNightlyMonitoring();
          this.pollMonitorState();
          this.refreshData();
          showToast('已结束今晚监测并结算');
        }
      })
  }

  @Builder
  EndCycleButton(): void {
    Text('提前结束本期')
      .fontSize(14)
      .fontColor(this.colors().textSecondary)
      .padding({ top: 8, bottom: 8 })
      .onClick(() => {
        this.confirmEndCycle();
      })
  }

  /** 开始新周期前确认（投入点数为高承诺操作） */
  private confirmStartCycle(): void {
    AlertDialog.show({
      title: '开始 30 天挑战',
      message: `将投入 ${INITIAL_POINTS_INVESTED} 个点数。此后每晚不熬夜，次日自动返还 1 个，坚持 30 天拿回全部。`,
      autoCancel: true,
      alignment: DialogAlignment.Center,
      secondaryButton: {
        value: '再想想',
        action: () => {}
      },
      primaryButton: {
        value: '开始',
        fontColor: this.colors().primary,
        action: () => {
          this.startNewCycle();
        }
      }
    });
  }

  /** 提前结束周期确认（退还剩余点数并关闭本期） */
  private confirmEndCycle(): void {
    const remaining = this.currentCycle ? this.currentCycle.getRemainingPoints() : 0;
    AlertDialog.show({
      title: '提前结束本期？',
      message: `结束后将退还剩余 ${remaining} 个点数，本期挑战关闭且无法恢复。`,
      autoCancel: true,
      alignment: DialogAlignment.Center,
      secondaryButton: {
        value: '继续坚持',
        action: () => {}
      },
      primaryButton: {
        value: '结束本期',
        fontColor: this.colors().danger,
        action: () => {
          this.endCurrentCycle();
        }
      }
    });
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
        this.lastCompletedCycle = null;
        this.streak = await this.computeStreak();
      } else {
        this.remainingPoints = 0;
        this.returnedPoints = 0;
        this.lastNightRecord = null;
        // 无进行中周期时，查询上一期已完成周期用于展示成绩
        const recent = await this.dataRepo.getMostRecentCycle();
        this.lastCompletedCycle = (recent && !recent.isActive) ? recent : null;
        // 完成庆祝：成绩横幅弹入
        if (this.lastCompletedCycle) {
          this.celebrate = false;
          animateTo({ duration: 520, curve: Curve.EaseOut, delay: 200 }, () => {
            this.celebrate = true;
          });
        }
      }
      this.inSleepWindow = isInSleepWindow();
    } catch (err) {
      logError('Refresh failed: %{public}s', (err as Error).message ?? '');
    }
  }

  private async startNewCycle(): Promise<void> {
    if (!this.dataRepo || !this.pointsService || this.busy) { return; }
    this.busy = true;
    try {
      const cycle = await this.dataRepo.startNewCycle();
      await this.pointsService.investPoints(cycle.cycleId, INITIAL_POINTS_INVESTED);
      await this.refreshData();
      showToast('挑战开始啦，今晚早点休息 🌙');
    } catch (err) {
      logError('Start cycle failed: %{public}s', (err as Error).message ?? '');
    } finally {
      this.busy = false;
    }
  }

  private async endCurrentCycle(): Promise<void> {
    if (!this.dataRepo || !this.pointsService || !this.currentCycle || this.busy) { return; }
    this.busy = true;
    try {
      await this.pointsService.refundAllRemaining(this.currentCycle.cycleId);
      await this.refreshData();
      showToast('已结束本期，剩余点数已退还');
    } catch (err) {
      logError('End cycle failed: %{public}s', (err as Error).message ?? '');
    } finally {
      this.busy = false;
    }
  }

  // ========== 监测页入口 ==========

  /** 进入全屏"今晚监测"页 */
  private openMonitorPage(): void {
    router.pushUrl({ url: 'pages/MonitorPage' });
  }

  /** 计算当前连续达标天数：从最近的已评估记录往前数连续 COMPLIANT */
  private async computeStreak(): Promise<number> {
    if (!this.dataRepo) { return 0; }
    try {
      const records = await this.dataRepo.getDailyRecordsByDateRange(
        StatsCalculator.getDateKeyDaysAgo(CYCLE_DURATION_DAYS), StatsCalculator.getTodayKey());
      let count = 0;
      // records 按 date_key 升序，从最后往前数
      for (let i = records.length - 1; i >= 0; i--) {
        const j = records[i].judgment;
        if (j === SleepJudgment.NOT_YET_EVALUATED) { continue; }
        if (j === SleepJudgment.COMPLIANT) { count++; } else { break; }
      }
      return count;
    } catch (err) {
      return 0;
    }
  }
}

