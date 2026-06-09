/**
 * 设置页 - 睡眠窗口 / 检测阈值 / 通知 / 深色模式
 */
import { router } from '@kit.ArkUI';
import { DatabaseRepository } from '../service/data/DatabaseRepository';
import { AppColors, ColorPalette } from '../common/AppColors';
import { AppSettings } from '../common/AppSettings';
import { showToast } from '../common/Toast';
import {
  CONFIG_KEY_SLEEP_START_HOUR, CONFIG_KEY_SLEEP_START_MINUTE,
  CONFIG_KEY_SLEEP_END_HOUR, CONFIG_KEY_SLEEP_END_MINUTE,
  CONFIG_KEY_SCREEN_ON_THRESHOLD, CONFIG_KEY_NOTIFICATIONS_ENABLED
} from '../common/Constants';

@Entry
@Component
struct SettingsPage {
  @StorageLink('isDarkMode') isDarkMode: boolean = false;
  @State startHour: number = AppSettings.sleepStartHour;
  @State startMinute: number = AppSettings.sleepStartMinute;
  @State endHour: number = AppSettings.sleepEndHour;
  @State endMinute: number = AppSettings.sleepEndMinute;
  @State threshold: number = AppSettings.screenOnThreshold;
  @State notificationsEnabled: boolean = AppSettings.notificationsEnabled;

  private dbRepo: DatabaseRepository | null = null;

  aboutToAppear(): void {
    this.dbRepo = AppStorage.get<DatabaseRepository>('dbRepo') ?? null;
  }

  private colors(): ColorPalette {
    return AppColors.current(this.isDarkMode);
  }

  private pad(n: number): string {
    return String(n).padStart(2, '0');
  }

  private store() {
    return this.dbRepo ? this.dbRepo.getStore() : null;
  }

  build() {
    Column() {
      // 顶栏
      Row() {
        Text('‹ 返回')
          .fontSize(16)
          .fontColor(this.colors().primary)
          .padding({ top: 6, bottom: 6, right: 12 })
          .onClick(() => { router.back(); })
        Blank()
        Text('设置')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.colors().textPrimary)
        Blank()
        Text('  ').fontSize(16)
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 16, bottom: 16 })
      .alignItems(VerticalAlign.Center)

      Scroll() {
        Column({ space: 16 }) {
          // 睡眠窗口
          Column() {
            Text('睡眠监测时段')
              .fontSize(14).fontColor(this.colors().textSecondary)
              .width('100%').margin({ bottom: 12 })
            this.TimeRow('开始时间', this.pad(this.startHour) + ':' + this.pad(this.startMinute), () => {
              this.pickStartTime();
            })
            Divider().color(this.colors().divider).margin({ top: 12, bottom: 12 })
            this.TimeRow('结束时间', this.pad(this.endHour) + ':' + this.pad(this.endMinute), () => {
              this.pickEndTime();
            })
          }
          .width('100%').padding(20)
          .backgroundColor(this.colors().glassBg).borderRadius(20)
          .border({ width: 1, color: this.colors().glassBorder }).backdropBlur(this.colors().glassBlur)
          .alignItems(HorizontalAlign.Start)

          // 操作次数阈值
          Column() {
            Text('允许操作次数')
              .fontSize(14).fontColor(this.colors().textSecondary)
              .width('100%').margin({ bottom: 4 })
            Text('一晚操作（亮屏/切走/通知栏等）不超过此次数仍判定为达标')
              .fontSize(11).fontColor(this.colors().textSecondary)
              .width('100%').margin({ bottom: 12 })
            Row() {
              Button('–')
                .width(40).height(40).fontSize(22)
                .fontColor(this.colors().primary).backgroundColor(this.colors().glassInputBg)
                .borderRadius(10)
                .onClick(() => { this.changeThreshold(-1); })
              Text(`${this.threshold}`)
                .fontSize(22).fontWeight(FontWeight.Bold).fontColor(this.colors().textPrimary)
                .layoutWeight(1).textAlign(TextAlign.Center)
              Button('+')
                .width(40).height(40).fontSize(22)
                .fontColor(this.colors().primary).backgroundColor(this.colors().glassInputBg)
                .borderRadius(10)
                .onClick(() => { this.changeThreshold(1); })
            }
            .width('100%')
          }
          .width('100%').padding(20)
          .backgroundColor(this.colors().glassBg).borderRadius(20)
          .border({ width: 1, color: this.colors().glassBorder }).backdropBlur(this.colors().glassBlur)
          .alignItems(HorizontalAlign.Start)

          // 开关项（直接内联读取 @State/@StorageLink，确保 Toggle 与状态双向绑定，
          // 不经过按值传参的 @Builder，否则 isOn 只是首帧快照、切换无效）
          Column() {
            Row() {
              Text('通知提醒').fontSize(16).fontColor(this.colors().textPrimary)
              Blank()
              Toggle({ type: ToggleType.Switch, isOn: this.notificationsEnabled })
                .selectedColor(this.colors().primary)
                .onChange((v: boolean) => {
                  this.notificationsEnabled = v;
                  this.saveItem(CONFIG_KEY_NOTIFICATIONS_ENABLED, v ? 'true' : 'false');
                })
            }
            .width('100%').alignItems(VerticalAlign.Center)

            Divider().color(this.colors().divider).margin({ top: 12, bottom: 12 })

            Row() {
              Text('深色模式').fontSize(16).fontColor(this.colors().textPrimary)
              Blank()
              Toggle({ type: ToggleType.Switch, isOn: this.isDarkMode })
                .selectedColor(this.colors().primary)
                .onChange((v: boolean) => {
                  this.isDarkMode = v;
                })
            }
            .width('100%').alignItems(VerticalAlign.Center)
          }
          .width('100%').padding(20)
          .backgroundColor(this.colors().glassBg).borderRadius(20)
          .border({ width: 1, color: this.colors().glassBorder }).backdropBlur(this.colors().glassBlur)
          .alignItems(HorizontalAlign.Start)
        }
        .padding({ left: 20, right: 20, bottom: 24 })
      }
      .layoutWeight(1)
    }
    .width('100%').height('100%')
    .backgroundColor(this.colors().background)
  }

  @Builder
  TimeRow(label: string, value: string, onTap: () => void): void {
    Row() {
      Text(label).fontSize(16).fontColor(this.colors().textPrimary)
      Blank()
      Text(value).fontSize(16).fontColor(this.colors().primary)
    }
    .width('100%').alignItems(VerticalAlign.Center)
    .onClick(onTap)
  }

  private pickStartTime(): void {
    TimePickerDialog.show({
      selected: this.makeDate(this.startHour, this.startMinute),
      useMilitaryTime: true,
      onAccept: (value: TimePickerResult) => {
        this.startHour = value.hour;
        this.startMinute = value.minute;
        this.saveItem(CONFIG_KEY_SLEEP_START_HOUR, `${value.hour}`);
        this.saveItem(CONFIG_KEY_SLEEP_START_MINUTE, `${value.minute}`);
      }
    });
  }

  private pickEndTime(): void {
    TimePickerDialog.show({
      selected: this.makeDate(this.endHour, this.endMinute),
      useMilitaryTime: true,
      onAccept: (value: TimePickerResult) => {
        this.endHour = value.hour;
        this.endMinute = value.minute;
        this.saveItem(CONFIG_KEY_SLEEP_END_HOUR, `${value.hour}`);
        this.saveItem(CONFIG_KEY_SLEEP_END_MINUTE, `${value.minute}`);
      }
    });
  }

  private makeDate(hour: number, minute: number): Date {
    const d = new Date();
    d.setHours(hour, minute, 0, 0);
    return d;
  }

  private changeThreshold(delta: number): void {
    const next = this.threshold + delta;
    if (next < 0 || next > 20) { return; }
    this.threshold = next;
    this.saveItem(CONFIG_KEY_SCREEN_ON_THRESHOLD, `${next}`);
  }

  private async saveItem(key: string, value: string): Promise<void> {
    const store = this.store();
    if (!store) { return; }
    await AppSettings.saveItem(store, key, value);
    showToast('已保存');
  }
}
