/**
 * 统计 Tab - 展示睡眠数据统计
 */
import { DailyRecord } from '../model/DailyRecord';
import { SleepJudgment } from '../model/SleepJudgment';
import { SleepStats } from '../model/SleepStats';
import { DatabaseRepository } from '../service/data/DatabaseRepository';
import { StatsCalculator } from '../common/StatsCalculator';
import { AppColors } from '../common/AppColors';
import { logInfo, logError } from '../common/Logger';

@Component
export struct StatisticsTab {
  @StorageLink('isDarkMode') isDarkMode: boolean = false;
  @StorageLink('dbRepo') dataRepo: DatabaseRepository | null = null;
  @State periodFilter: number = 0;
  @State stats: SleepStats = new SleepStats();
  @State records: DailyRecord[] = [];
  @State hasData: boolean = false;

  aboutToAppear(): void {
    this.loadData();
  }

  private colors() {
    return AppColors.current(this.isDarkMode);
  }

  build() {
    Column() {
      Text('睡眠统计')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.colors().textPrimary)
        .margin({ top: 16, bottom: 16 })
        .width('100%')
        .padding({ left: 20 })

      // 周期筛选
      Row({ space: 12 }) {
        this.PeriodButton('近7天', 0)
        this.PeriodButton('近30天', 1)
        this.PeriodButton('近90天', 2)
      }
      .width('100%')
      .padding({ left: 20, right: 20 })
      .margin({ bottom: 16 })

      // 统计摘要卡片 2x2 — 直接内联，不通过 @Builder 传参
      Column({ space: 12 }) {
        Row({ space: 12 }) {
          Column() {
            Text('平均睡眠时长').fontSize(12).fontColor(this.colors().textSecondary).margin({ bottom: 8 })
            Text(StatsCalculator.formatDuration(this.stats.avgSleepDurationHours))
              .fontSize(22).fontWeight(FontWeight.Bold).fontColor(this.colors().textPrimary)
          }
          .layoutWeight(1).padding(16)
          .backgroundColor(this.colors().glassBg).borderRadius(20)
          .border({ width: 1, color: this.colors().glassBorder }).backdropBlur(this.colors().glassBlur)
          .alignItems(HorizontalAlign.Center)

          Column() {
            Text('平均入睡时间').fontSize(12).fontColor(this.colors().textSecondary).margin({ bottom: 8 })
            Text(StatsCalculator.formatBedtime(this.stats.avgBedtimeHour, this.stats.avgBedtimeMinute))
              .fontSize(22).fontWeight(FontWeight.Bold).fontColor(this.colors().textPrimary)
          }
          .layoutWeight(1).padding(16)
          .backgroundColor(this.colors().glassBg).borderRadius(20)
          .border({ width: 1, color: this.colors().glassBorder }).backdropBlur(this.colors().glassBlur)
          .alignItems(HorizontalAlign.Center)
        }
        .width('100%')

        Row({ space: 12 }) {
          Column() {
            Text('熬夜天数').fontSize(12).fontColor(this.colors().textSecondary).margin({ bottom: 8 })
            Text(`${this.stats.lateNightCount} 天`)
              .fontSize(22).fontWeight(FontWeight.Bold).fontColor(this.colors().textPrimary)
          }
          .layoutWeight(1).padding(16)
          .backgroundColor(this.colors().glassBg).borderRadius(20)
          .border({ width: 1, color: this.colors().glassBorder }).backdropBlur(this.colors().glassBlur)
          .alignItems(HorizontalAlign.Center)

          Column() {
            Text('达标率').fontSize(12).fontColor(this.colors().textSecondary).margin({ bottom: 8 })
            Text(`${this.stats.complianceRate}%`)
              .fontSize(22).fontWeight(FontWeight.Bold).fontColor(this.colors().textPrimary)
          }
          .layoutWeight(1).padding(16)
          .backgroundColor(this.colors().glassBg).borderRadius(20)
          .border({ width: 1, color: this.colors().glassBorder }).backdropBlur(this.colors().glassBlur)
          .alignItems(HorizontalAlign.Center)
        }
        .width('100%')
      }
      .width('100%')
      .padding({ left: 20, right: 20 })
      .margin({ bottom: 20 })

      // 每日柱状图
      Scroll() {
        Column() {
          Text('每日达标情况')
            .fontSize(14)
            .fontColor(this.colors().textSecondary)
            .margin({ bottom: 12 })

          if (this.hasData) {
            Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
              ForEach(this.records, (record: DailyRecord) => {
                this.DayBlock(record)
              }, (record: DailyRecord) => record.dateKey)
            }
            .width('100%')
          } else {
            Text('暂无统计数据')
              .fontSize(14)
              .fontColor(this.colors().textSecondary)
              .margin({ top: 24 })
          }
        }
        .width('100%')
        .padding(16)
        .backgroundColor(this.colors().glassBg)
        .borderRadius(20)
        .border({ width: 1, color: this.colors().glassBorder })
        .backdropBlur(this.colors().glassBlur)
      }
      .layoutWeight(1)
      .padding({ left: 20, right: 20 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.colors().background)
  }

  @Builder
  PeriodButton(label: string, index: number): void {
    Button(label)
      .height(36)
      .fontSize(14)
      .fontColor(this.periodFilter === index ? Color.White : this.colors().textSecondary)
      .backgroundColor(this.periodFilter === index ? this.colors().primary : this.colors().glassBg)
      .borderRadius(18)
      .border(this.periodFilter === index ? { width: 0 } : { width: 1, color: this.colors().glassBorder })
      .backdropBlur(this.periodFilter === index ? 0 : this.colors().glassBlur)
      .onClick(() => {
        this.periodFilter = index;
        this.loadData();
      })
  }

  @Builder
  DayBlock(record: DailyRecord): void {
    Column() {
      Text(record.dateKey.substring(5))
        .fontSize(10)
        .fontColor(this.colors().textSecondary)
      Row()
        .width(28)
        .height(28)
        .borderRadius(6)
        .backgroundColor(
          record.judgment === SleepJudgment.COMPLIANT ? this.colors().success :
          record.judgment === SleepJudgment.NON_COMPLIANT ? this.colors().danger : this.colors().progressTrack
        )
        .margin({ top: 4 })
    }
    .alignItems(HorizontalAlign.Center)
    .margin({ bottom: 8, right: 8 })
  }

  private async loadData(): Promise<void> {
    try {
      if (!this.dataRepo) { return; }
      const store = this.dataRepo.getStore();
      if (!store) { return; }

      const days = this.periodFilter === 0 ? 7 : (this.periodFilter === 1 ? 30 : 90);
      const startDate = StatsCalculator.getDateKeyDaysAgo(days);
      const endDate = StatsCalculator.getTodayKey();

      this.records = await this.dataRepo.getDailyRecordsByDateRange(startDate, endDate);
      this.stats = StatsCalculator.calculate(this.records);
      this.hasData = this.records.length > 0;

      logInfo('Stats loaded: %{public}s records, duration=%{public}s',
        this.records.length.toString(), this.stats.avgSleepDurationHours.toString());
    } catch (err) {
      logError('Load stats failed: %{public}s', (err as Error).message ?? '');
    }
  }
}
