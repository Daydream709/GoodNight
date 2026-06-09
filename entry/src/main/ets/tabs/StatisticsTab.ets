/**
 * 统计 Tab - 「睡眠报告」
 * 视觉核心为达标率环形；含作息洞察对比、带目标线的时长趋势、每日达标热力图。
 * 注意：所有随数据变化的值（stats / rates / records）一律在无参（或静态参）@Builder 内
 * 直接读 this.*，绝不按值传进 @Builder——否则 ArkUI 只渲染首帧快照、刷新失效。
 */
import { DailyRecord } from '../model/DailyRecord';
import { SleepJudgment } from '../model/SleepJudgment';
import { SleepStats } from '../model/SleepStats';
import { DatabaseRepository } from '../service/data/DatabaseRepository';
import { StatsCalculator } from '../common/StatsCalculator';
import { AppColors, ColorPalette } from '../common/AppColors';
import { parseDateKey } from '../common/DateUtils';
import { logInfo, logError } from '../common/Logger';

const WEEKDAY_NAMES: string[] = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];

@Component
export struct StatisticsTab {
  @StorageLink('isDarkMode') isDarkMode: boolean = false;
  @StorageLink('dbRepo') dataRepo: DatabaseRepository | null = null;
  @State periodFilter: number = 0;
  @State stats: SleepStats = new SleepStats();
  @State records: DailyRecord[] = [];
  @State hasData: boolean = false;
  @State weekdayRate: number = -1;
  @State weekendRate: number = -1;
  @State rangeStart: string = '';
  @State appeared: boolean = false;
  // 更丰富的洞察
  @State longestGoodStreak: number = 0;   // 本期内最长连续好眠
  @State worstWeekday: string = '';        // 最常熬夜的星期（无则空）
  @State trendText: string = '';           // 本期前/后段作息变化趋势
  @StorageLink('dataVersion') @Watch('onDataVersionChanged') dataVersion: number = 0;

  aboutToAppear(): void {
    this.loadData();
    animateTo({ duration: 420, curve: Curve.EaseOut }, () => { this.appeared = true; });
  }

  onDataVersionChanged(): void {
    this.loadData();
  }

  private colors(): ColorPalette {
    return AppColors.current(this.isDarkMode);
  }

  private periodDays(): number {
    return this.periodFilter === 0 ? 7 : (this.periodFilter === 1 ? 30 : 90);
  }

  /** 达标率配色：高=成功色，中=主色，低=警示色 */
  private rateColor(): string {
    if (this.stats.totalEvaluatedDays === 0) { return this.colors().textSecondary; }
    const r = this.stats.complianceRate;
    return r >= 80 ? this.colors().success : (r >= 50 ? this.colors().primary : this.colors().danger);
  }

  /** 根据工作日/周末达标率生成一句洞察文案 */
  private insightText(): string {
    if (this.weekdayRate < 0 && this.weekendRate < 0) { return '完成更多监测后，这里会给出你的作息洞察'; }
    if (this.weekdayRate < 0 || this.weekendRate < 0) { return '工作日与周末数据都齐全后，可对比作息差异'; }
    if (this.weekendRate + 10 < this.weekdayRate) { return '周末更容易熬夜，试着周末也保持规律作息 🌙'; }
    if (this.weekdayRate + 10 < this.weekendRate) { return '工作日睡眠更难达标，睡前早点放下手机 📵'; }
    return '工作日与周末作息都比较稳定，继续保持 👍';
  }

  build() {
    Column() {
      // 顶栏标题 + 时间范围副标题
      Column() {
        Text('睡眠报告')
          .fontSize(24).fontWeight(FontWeight.Bold).fontColor(this.colors().textPrimary)
          .width('100%')
        Text(this.hasData ? `${this.rangeStart} 至今 · 共 ${this.records.length} 晚记录` : `近 ${this.periodDays()} 天`)
          .fontSize(12).fontColor(this.colors().textSecondary)
          .width('100%').margin({ top: 4 })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 16, bottom: 14 })
      .alignItems(HorizontalAlign.Start)

      // 时间范围分段控制器
      Column() {
        this.Segmented();
      }
      .width('100%')
      .padding({ left: 20, right: 20 })

      Scroll() {
        Column({ space: 16 }) {
          if (this.hasData) {
            this.ComplianceHero();
            this.MetricStrip();
            this.DurationTrend();
            this.RhythmInsight();
            this.InsightsCard();
            this.DailyHeatmap();
          } else {
            this.EmptyState();
          }
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 16, bottom: 24 })
        .opacity(this.appeared ? 1 : 0)
        .translate({ y: this.appeared ? 0 : 14 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.colors().background)
  }

  // ========== 分段控制器 ==========

  @Builder
  Segmented(): void {
    Row() {
      this.Segment('近 7 天', 0)
      this.Segment('近 30 天', 1)
      this.Segment('近 90 天', 2)
    }
    .width('100%')
    .padding(4)
    .backgroundColor(this.colors().glassInputBg)
    .borderRadius(22)
  }

  @Builder
  Segment(label: string, index: number): void {
    Text(label)
      .layoutWeight(1)
      .textAlign(TextAlign.Center)
      .height(36)
      .fontSize(13)
      .fontWeight(this.periodFilter === index ? FontWeight.Bold : FontWeight.Normal)
      .fontColor(this.periodFilter === index ? Color.White : this.colors().textSecondary)
      .backgroundColor(this.periodFilter === index ? this.colors().primary : Color.Transparent)
      .borderRadius(18)
      .onClick(() => {
        this.periodFilter = index;
        this.loadData();
      })
  }

  // ========== 达标率环形（视觉核心） ==========

  @Builder
  ComplianceHero(): void {
    Column() {
      Stack() {
        Progress({ value: this.stats.complianceRate, total: 100, type: ProgressType.Ring })
          .width(168).height(168)
          .color(this.rateColor())
          .backgroundColor(this.colors().progressTrack)
          .style({ strokeWidth: 14 })
        Column() {
          Row() {
            Text(`${this.stats.complianceRate}`)
              .fontSize(50).fontWeight(FontWeight.Bold).fontColor(this.rateColor())
            Text('%')
              .fontSize(20).fontWeight(FontWeight.Bold).fontColor(this.rateColor())
              .margin({ left: 2, bottom: 6 })
          }
          .alignItems(VerticalAlign.Bottom)
          Text('达标率')
            .fontSize(13).fontColor(this.colors().textSecondary).margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Center)
      }
      .width(168).height(168)

      Row({ space: 6 }) {
        Text('🌙').fontSize(13)
        Text(`近 ${this.periodDays()} 天已判定 ${this.stats.totalEvaluatedDays} 晚，达标 ${this.stats.totalCompliantDays} 晚`)
          .fontSize(13).fontColor(this.colors().textSecondary)
      }
      .margin({ top: 16 })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding({ top: 28, bottom: 24 })
    .backgroundColor(this.colors().glassBg)
    .borderRadius(24)
    .border({ width: 1, color: this.colors().glassBorder })
    .backdropBlur(this.colors().glassBlur)
    .alignItems(HorizontalAlign.Center)
  }

  // ========== 关键指标条 ==========

  @Builder
  MetricStrip(): void {
    Row() {
      Column() {
        Text('平均时长').fontSize(12).fontColor(this.colors().textSecondary)
        Text(StatsCalculator.formatDuration(this.stats.avgSleepDurationHours))
          .fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.colors().textPrimary).margin({ top: 6 })
      }
      .layoutWeight(1).alignItems(HorizontalAlign.Center)

      Divider().vertical(true).height(36).color(this.colors().divider)

      Column() {
        Text('平均入睡').fontSize(12).fontColor(this.colors().textSecondary)
        Text(StatsCalculator.formatBedtime(this.stats.avgBedtimeHour, this.stats.avgBedtimeMinute))
          .fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.colors().textPrimary).margin({ top: 6 })
      }
      .layoutWeight(1).alignItems(HorizontalAlign.Center)

      Divider().vertical(true).height(36).color(this.colors().divider)

      Column() {
        Text('熬夜天数').fontSize(12).fontColor(this.colors().textSecondary)
        Text(`${this.stats.lateNightCount} 天`)
          .fontSize(18).fontWeight(FontWeight.Bold)
          .fontColor(this.stats.lateNightCount > 0 ? this.colors().danger : this.colors().textPrimary)
          .margin({ top: 6 })
      }
      .layoutWeight(1).alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .padding({ top: 18, bottom: 18 })
    .backgroundColor(this.colors().glassBg)
    .borderRadius(20)
    .border({ width: 1, color: this.colors().glassBorder })
    .backdropBlur(this.colors().glassBlur)
  }

  // ========== 睡眠时长趋势（带网格 + 目标线） ==========

  @Builder
  DurationTrend(): void {
    Column() {
      Row() {
        Text('睡眠时长趋势').fontSize(14).fontWeight(FontWeight.Medium).fontColor(this.colors().textPrimary)
        Blank()
        Text('目标 8 小时').fontSize(11).fontColor(this.colors().primary)
      }
      .width('100%').margin({ bottom: 16 }).alignItems(VerticalAlign.Center)

      Stack({ alignContent: Alignment.TopStart }) {
        // 背景网格刻度：12 / 8(目标) / 4 / 0 小时，等距
        Column() {
          this.GridLine('12h', false)
          this.GridLine('8h', true)
          this.GridLine('4h', false)
          this.GridLine('0', false)
        }
        .width('100%').height(140)
        .justifyContent(FlexAlign.SpaceBetween)

        // 前景柱状（横向滚动）
        Scroll() {
          Row({ space: 7 }) {
            ForEach(this.records, (record: DailyRecord) => {
              Column() {
                Column()
                  .width(9)
                  .height(`${Math.min(this.durationHours(record) / 12, 1) * 100}%`)
                  .borderRadius(4)
                  .backgroundColor(this.judgmentColor(record))
              }
              .height('100%')
              .justifyContent(FlexAlign.End)
              .onClick(() => { this.showDayDetail(record); })
            }, (record: DailyRecord) => record.dateKey)
          }
          .height(140)
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%').height(140)
      }
      .width('100%').height(140)

      // x 轴起止日期
      Row() {
        Text(this.records.length > 0 ? this.records[0].dateKey.substring(5) : '')
          .fontSize(10).fontColor(this.colors().textSecondary)
        Blank()
        Text(this.records.length > 0 ? this.records[this.records.length - 1].dateKey.substring(5) : '')
          .fontSize(10).fontColor(this.colors().textSecondary)
      }
      .width('100%').margin({ top: 6 })
    }
    .width('100%')
    .padding(18)
    .backgroundColor(this.colors().glassBg)
    .borderRadius(20)
    .border({ width: 1, color: this.colors().glassBorder })
    .backdropBlur(this.colors().glassBlur)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  GridLine(label: string, goal: boolean): void {
    Row() {
      Divider()
        .layoutWeight(1)
        .color(goal ? this.colors().primary : this.colors().divider)
        .opacity(goal ? 0.6 : 0.4)
      Text(label)
        .fontSize(9)
        .fontColor(goal ? this.colors().primary : this.colors().textSecondary)
        .margin({ left: 6 })
        .width(24)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  // ========== 作息洞察（工作日 vs 周末对比条） ==========

  @Builder
  RhythmInsight(): void {
    Column() {
      Text('作息洞察').fontSize(14).fontWeight(FontWeight.Medium).fontColor(this.colors().textPrimary)
        .width('100%').margin({ bottom: 16 })

      // 工作日
      Row() {
        Text('工作日').fontSize(13).fontColor(this.colors().textSecondary).width(52)
        Stack({ alignContent: Alignment.Start }) {
          Row().width('100%').height(10).borderRadius(5).backgroundColor(this.colors().progressTrack)
          Row()
            .width(`${this.weekdayRate < 0 ? 0 : this.weekdayRate}%`)
            .height(10).borderRadius(5).backgroundColor(this.colors().primary)
        }
        .layoutWeight(1).margin({ left: 8, right: 10 })
        Text(this.weekdayRate >= 0 ? `${this.weekdayRate}%` : '--')
          .fontSize(13).fontWeight(FontWeight.Bold).fontColor(this.colors().textPrimary).width(44)
          .textAlign(TextAlign.End)
      }
      .width('100%').alignItems(VerticalAlign.Center)

      // 周末
      Row() {
        Text('周末').fontSize(13).fontColor(this.colors().textSecondary).width(52)
        Stack({ alignContent: Alignment.Start }) {
          Row().width('100%').height(10).borderRadius(5).backgroundColor(this.colors().progressTrack)
          Row()
            .width(`${this.weekendRate < 0 ? 0 : this.weekendRate}%`)
            .height(10).borderRadius(5).backgroundColor(this.colors().success)
        }
        .layoutWeight(1).margin({ left: 8, right: 10 })
        Text(this.weekendRate >= 0 ? `${this.weekendRate}%` : '--')
          .fontSize(13).fontWeight(FontWeight.Bold).fontColor(this.colors().textPrimary).width(44)
          .textAlign(TextAlign.End)
      }
      .width('100%').margin({ top: 14 }).alignItems(VerticalAlign.Center)

      // 生成的一句话洞察
      Row() {
        Text(this.insightText())
          .fontSize(12).fontColor(this.colors().textSecondary).lineHeight(18)
      }
      .width('100%')
      .padding(12)
      .backgroundColor(this.colors().glassInputBg)
      .borderRadius(12)
      .margin({ top: 16 })
    }
    .width('100%')
    .padding(18)
    .backgroundColor(this.colors().glassBg)
    .borderRadius(20)
    .border({ width: 1, color: this.colors().glassBorder })
    .backdropBlur(this.colors().glassBlur)
    .alignItems(HorizontalAlign.Start)
  }

  // ========== 更丰富的洞察 ==========

  /**
   * 深度洞察卡。三行统计值内联读取 @State（不经按值传参的 @Builder，
   * 否则数据刷新后 Builder 仍显示首帧快照）。
   */
  @Builder
  InsightsCard(): void {
    Column() {
      Text('深度洞察').fontSize(14).fontWeight(FontWeight.Medium).fontColor(this.colors().textPrimary)
        .width('100%').margin({ bottom: 14 })

      // 最长连续好眠
      Row() {
        Text('🔥').fontSize(18).width(30)
        Text('最长连续好眠').fontSize(14).fontColor(this.colors().textSecondary).layoutWeight(1)
        Text(this.longestGoodStreak > 0 ? `${this.longestGoodStreak} 晚` : '暂无')
          .fontSize(14).fontWeight(FontWeight.Bold).fontColor(this.colors().textPrimary)
      }
      .width('100%').alignItems(VerticalAlign.Center)

      Divider().color(this.colors().divider).margin({ top: 12, bottom: 12 })

      // 最常熬夜的星期
      Row() {
        Text('😴').fontSize(18).width(30)
        Text('最常熬夜').fontSize(14).fontColor(this.colors().textSecondary).layoutWeight(1)
        Text(this.worstWeekday.length > 0 ? this.worstWeekday : '暂无熬夜，很棒')
          .fontSize(14).fontWeight(FontWeight.Bold)
          .fontColor(this.worstWeekday.length > 0 ? this.colors().textPrimary : this.colors().success)
      }
      .width('100%').alignItems(VerticalAlign.Center)

      Divider().color(this.colors().divider).margin({ top: 12, bottom: 12 })

      // 作息趋势
      Row() {
        Text('📈').fontSize(18).width(30)
        Text('作息趋势').fontSize(14).fontColor(this.colors().textSecondary).layoutWeight(1)
        Text(this.trendText.length > 0 ? this.trendText : '数据较少')
          .fontSize(14).fontWeight(FontWeight.Bold).fontColor(this.colors().textPrimary)
      }
      .width('100%').alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding(18)
    .backgroundColor(this.colors().glassBg)
    .borderRadius(20)
    .border({ width: 1, color: this.colors().glassBorder })
    .backdropBlur(this.colors().glassBlur)
    .alignItems(HorizontalAlign.Start)
  }

  // ========== 每日达标热力图 ==========

  @Builder
  DailyHeatmap(): void {
    Column() {
      Row() {
        Text('每日达标').fontSize(14).fontWeight(FontWeight.Medium).fontColor(this.colors().textPrimary)
        Blank()
        Row({ space: 10 }) {
          this.LegendItem(this.colors().success, '达标')
          this.LegendItem(this.colors().danger, '熬夜')
          this.LegendItem(this.colors().progressTrack, '未评估')
        }
      }
      .width('100%').margin({ bottom: 14 }).alignItems(VerticalAlign.Center)

      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
        ForEach(this.records, (record: DailyRecord) => {
          Column()
            .width(24).height(24).borderRadius(7)
            .backgroundColor(this.judgmentColor(record))
            .margin({ right: 8, bottom: 8 })
            .onClick(() => { this.showDayDetail(record); })
        }, (record: DailyRecord) => record.dateKey)
      }
      .width('100%')

      Text('点击任意方块查看当晚详情')
        .fontSize(11).fontColor(this.colors().textSecondary).margin({ top: 4 })
    }
    .width('100%')
    .padding(18)
    .backgroundColor(this.colors().glassBg)
    .borderRadius(20)
    .border({ width: 1, color: this.colors().glassBorder })
    .backdropBlur(this.colors().glassBlur)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  LegendItem(color: string, label: string): void {
    Row() {
      Row().width(10).height(10).borderRadius(3).backgroundColor(color)
      Text(label).fontSize(11).fontColor(this.colors().textSecondary).margin({ left: 4 })
    }
    .alignItems(VerticalAlign.Center)
  }

  // ========== 空状态 ==========

  @Builder
  EmptyState(): void {
    Column() {
      Text('📊').fontSize(52).margin({ bottom: 16 })
      Text('还没有睡眠报告')
        .fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.colors().textPrimary)
      Text('完成第一晚监测后，这里会生成你的达标率、作息趋势与洞察')
        .fontSize(13).fontColor(this.colors().textSecondary)
        .margin({ top: 10 }).textAlign(TextAlign.Center).lineHeight(20)
    }
    .width('100%')
    .padding({ top: 60, bottom: 60, left: 24, right: 24 })
    .backgroundColor(this.colors().glassBg)
    .borderRadius(24)
    .border({ width: 1, color: this.colors().glassBorder })
    .backdropBlur(this.colors().glassBlur)
    .alignItems(HorizontalAlign.Center)
    .margin({ top: 40 })
  }

  // ========== 工具方法 ==========

  private judgmentColor(record: DailyRecord): string {
    if (record.judgment === SleepJudgment.COMPLIANT) { return this.colors().success; }
    if (record.judgment === SleepJudgment.NON_COMPLIANT) { return this.colors().danger; }
    return this.colors().progressTrack;
  }

  /** 某晚睡眠时长（小时），无数据返回 0 */
  private durationHours(record: DailyRecord): number {
    if (record.monitorStartTime > 0 && record.monitorEndTime > record.monitorStartTime) {
      return (record.monitorEndTime - record.monitorStartTime) / 3600000;
    }
    return 0;
  }

  /** 工作日 / 周末达标率 */
  private computeWeekdayWeekend(): void {
    let wdTotal = 0;
    let wdOk = 0;
    let weTotal = 0;
    let weOk = 0;
    for (let i = 0; i < this.records.length; i++) {
      const r = this.records[i];
      if (r.judgment === SleepJudgment.NOT_YET_EVALUATED) { continue; }
      const dow = parseDateKey(r.dateKey).getDay();
      const isWeekend = dow === 0 || dow === 6;
      const ok = r.judgment === SleepJudgment.COMPLIANT ? 1 : 0;
      if (isWeekend) { weTotal++; weOk += ok; } else { wdTotal++; wdOk += ok; }
    }
    this.weekdayRate = wdTotal > 0 ? Math.round((wdOk / wdTotal) * 100) : -1;
    this.weekendRate = weTotal > 0 ? Math.round((weOk / weTotal) * 100) : -1;
  }

  /**
   * 深度洞察：最长连续好眠、最常熬夜的星期、本期前/后段作息趋势。
   * 仅基于已判定记录；记录按 date_key 升序。
   */
  private computeInsights(): void {
    let longest = 0;
    let cur = 0;
    const lateByDow: number[] = [0, 0, 0, 0, 0, 0, 0];
    const evaluated: DailyRecord[] = [];

    for (let i = 0; i < this.records.length; i++) {
      const r = this.records[i];
      if (r.judgment === SleepJudgment.NOT_YET_EVALUATED) { continue; }
      evaluated.push(r);
      if (r.judgment === SleepJudgment.COMPLIANT) {
        cur++;
        if (cur > longest) { longest = cur; }
      } else {
        cur = 0;
        const dow = parseDateKey(r.dateKey).getDay();
        lateByDow[dow]++;
      }
    }
    this.longestGoodStreak = longest;

    // 最常熬夜的星期
    let maxLate = 0;
    let worstDow = -1;
    for (let d = 0; d < 7; d++) {
      if (lateByDow[d] > maxLate) { maxLate = lateByDow[d]; worstDow = d; }
    }
    this.worstWeekday = (maxLate > 0 && worstDow >= 0) ? WEEKDAY_NAMES[worstDow] : '';

    // 作息趋势：前半段 vs 后半段达标率（需至少 4 个已判定夜才有意义）
    this.trendText = this.computeTrend(evaluated);
  }

  private computeTrend(evaluated: DailyRecord[]): string {
    if (evaluated.length < 4) { return '数据较少，继续记录'; }
    const mid = Math.floor(evaluated.length / 2);
    const rate = (arr: DailyRecord[]): number => {
      let ok = 0;
      for (let i = 0; i < arr.length; i++) {
        if (arr[i].judgment === SleepJudgment.COMPLIANT) { ok++; }
      }
      return arr.length > 0 ? (ok / arr.length) * 100 : 0;
    };
    const firstRate = rate(evaluated.slice(0, mid));
    const secondRate = rate(evaluated.slice(mid));
    const diff = Math.round(secondRate - firstRate);
    if (diff >= 10) { return `近期在改善 +${diff}% ✨`; }
    if (diff <= -10) { return `近期有所退步 ${diff}%`; }
    return '作息保持稳定';
  }

  /** 点击某天查看详情 */
  private showDayDetail(record: DailyRecord): void {
    const judgmentText = record.judgment === SleepJudgment.COMPLIANT ? '✓ 睡眠达标'
      : (record.judgment === SleepJudgment.NON_COMPLIANT ? '✗ 检测到熬夜' : '未评估');
    let durationText = '--';
    if (record.monitorStartTime > 0 && record.monitorEndTime > record.monitorStartTime) {
      const h = (record.monitorEndTime - record.monitorStartTime) / 3600000;
      durationText = h.toFixed(1) + ' 小时';
    }
    AlertDialog.show({
      title: record.dateKey,
      message: `${judgmentText}\n\n睡眠时长：${durationText}\n操作次数：${record.screenOnCount} 次\n移动次数：${record.movementEventCount} 次\n点数返还：${record.pointReturned ? '是' : '否'}`,
      autoCancel: true,
      alignment: DialogAlignment.Center,
      confirm: {
        value: '知道了',
        action: () => {}
      }
    });
  }

  private async loadData(): Promise<void> {
    try {
      if (!this.dataRepo) { return; }
      const store = this.dataRepo.getStore();
      if (!store) { return; }

      const days = this.periodDays();
      const startDate = StatsCalculator.getDateKeyDaysAgo(days);
      const endDate = StatsCalculator.getTodayKey();

      this.records = await this.dataRepo.getDailyRecordsByDateRange(startDate, endDate);
      this.stats = StatsCalculator.calculate(this.records);
      this.hasData = this.records.length > 0;
      this.rangeStart = this.records.length > 0 ? this.records[0].dateKey : startDate;
      this.computeWeekdayWeekend();
      this.computeInsights();

      logInfo('Stats loaded: %{public}s records, duration=%{public}s',
        this.records.length.toString(), this.stats.avgSleepDurationHours.toString());
    } catch (err) {
      logError('Load stats failed: %{public}s', (err as Error).message ?? '');
    }
  }
}
