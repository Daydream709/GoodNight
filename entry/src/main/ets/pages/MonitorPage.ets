/**
 * 今晚监测页 - 全屏夜间监测
 * 进入即开始监测会话；移动由加速度静默检测（摇晃 + 左右旋转）实时更新；
 * 任何"离开/失焦"（返回、系统返回键、回桌面、切应用、下拉通知栏/控制中心）
 * 都记为一次"操作手机"。计数由服务写入 AppStorage，并通过监听器回调实时刷新本页。
 * "结束今晚监测"= 提前结束本晚监测并立即结算。
 */
import { router } from '@kit.ArkUI';
import { ISleepMonitorService } from '../interface/ISleepMonitorService';
import { SleepJudgment } from '../model/SleepJudgment';
import { AppSettings } from '../common/AppSettings';
import { showToast } from '../common/Toast';

@Entry
@Component
struct MonitorPage {
  // 计数由服务通过监听器直接回调写入 @State（赋值必触发重绘，最可靠）
  @State screenOn: number = 0;
  @State movement: number = 0;
  @State timeText: string = '--:--';
  @State elapsedText: string = '00:00';
  @State pulse: boolean = false;

  private monitor: ISleepMonitorService | null = null;
  private uiTimer: number = -1;
  private startTs: number = 0;
  private settling: boolean = false;

  aboutToAppear(): void {
    this.monitor = AppStorage.get<ISleepMonitorService>('sleepMonitorService') ?? null;
    if (this.monitor && !this.monitor.isMonitoring()) {
      this.monitor.startDemoMonitoring();
    }
    // 注册计数监听：服务每次计数变化直接回调，写入 @State 触发刷新
    if (this.monitor) {
      this.monitor.setCountListener((s: number, m: number): void => {
        this.screenOn = s;
        this.movement = m;
      });
      this.screenOn = this.monitor.getLiveScreenOnCount();
      this.movement = this.monitor.getLiveMovementCount();
    }
    this.startTs = Date.now();
    this.refreshClock();
    // 计数刷新靠 setCountListener（即时）+ 本定时器（每秒兜底，并驱动时钟/计时）
    this.uiTimer = setInterval(() => { this.refreshClock(); }, 1000) as number;
    this.pulse = true;
  }

  aboutToDisappear(): void {
    if (this.uiTimer !== -1) {
      clearInterval(this.uiTimer);
      this.uiTimer = -1;
    }
    if (this.monitor) {
      this.monitor.setCountListener(null);
    }
  }

  onPageHide(): void {
    // 被路由切走 / 应用切后台（去抖在服务层）
    if (!this.settling && this.monitor) {
      this.monitor.recordScreenLeave();
    }
  }

  onBackPress(): boolean {
    // 系统返回键：记一次使用，然后放行返回
    if (this.monitor) {
      this.monitor.recordScreenLeave();
    }
    return false;
  }

  private pad(n: number): string {
    return String(n).padStart(2, '0');
  }

  private refreshClock(): void {
    const now = new Date();
    this.timeText = this.pad(now.getHours()) + ':' + this.pad(now.getMinutes());
    const secs = Math.floor((Date.now() - this.startTs) / 1000);
    this.elapsedText = this.pad(Math.floor(secs / 60)) + ':' + this.pad(secs % 60);
    // 备份路径：定时器在前台时也同步一次计数
    if (this.monitor) {
      this.screenOn = this.monitor.getLiveScreenOnCount();
      this.movement = this.monitor.getLiveMovementCount();
    }
  }

  build() {
    Stack() {
      Column().width('100%').height('100%').backgroundColor('#0B1026')

      Column() {
        Row() {
          Text('‹ 返回')
            .fontSize(16).fontColor('#9FA8DA')
            .padding({ top: 6, bottom: 6, right: 12 })
            .onClick(() => { this.leaveByButton(); })
          Blank()
          Text('今晚监测').fontSize(16).fontColor('#E8EAF6')
          Blank()
          Text('  ').fontSize(16)
        }
        .width('100%').padding({ left: 20, right: 20, top: 28 })

        Blank()

        Column() {
          Text('🌙')
            .fontSize(64)
            .opacity(this.pulse ? 1 : 0.55)
            .animation({ duration: 1600, iterations: -1, playMode: PlayMode.Alternate, curve: Curve.EaseInOut })
          Text(this.timeText)
            .fontSize(44).fontWeight(FontWeight.Bold).fontColor('#FFFFFF').margin({ top: 16 })
          Text('正在守护你的睡眠 · 已守护 ' + this.elapsedText)
            .fontSize(13).fontColor('#9FA8DA').margin({ top: 8 })
        }

        // 统计数字内联读取 @State（不经过按值传参的 @Builder，确保实时响应式刷新）
        Row({ space: 48 }) {
          Column() {
            Text(`${this.screenOn}`)
              .fontSize(32).fontWeight(FontWeight.Bold)
              .fontColor(this.screenOn > AppSettings.screenOnThreshold ? '#F87171' : '#FFFFFF')
            Text('操作').fontSize(12).fontColor('#9FA8DA').margin({ top: 4 })
          }
          Column() {
            Text(`${this.movement}`)
              .fontSize(32).fontWeight(FontWeight.Bold)
              .fontColor(this.movement > 0 ? '#F87171' : '#FFFFFF')
            Text('移动').fontSize(12).fontColor('#9FA8DA').margin({ top: 4 })
          }
        }
        .margin({ top: 40 })

        Text('切走页面、返回、回桌面、切应用或下拉通知栏都会记为一次操作（+1）\n把手机放下、保持安静即可达标')
          .fontSize(12).fontColor('#6B739E').textAlign(TextAlign.Center).margin({ top: 28 }).lineHeight(20)

        Blank()

        Button('结束今晚监测并结算')
          .width('80%').height(48).fontSize(16).fontColor(Color.White)
          .backgroundColor('#A78BFA').borderRadius(12).margin({ bottom: 40 })
          .onClick(() => { this.settle(); })
      }
      .width('100%').height('100%')
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%').height('100%')
  }

  /** 点"返回"：记一次使用并返回（onPageHide 会因去抖跳过，不重复计） */
  private leaveByButton(): void {
    if (this.monitor) {
      this.monitor.recordScreenLeave();
    }
    showToast('已记一次操作（+1）');
    router.back();
  }

  /** 提前结束本晚监测并立即结算 */
  private settle(): void {
    this.settling = true;
    let compliant = false;
    if (this.monitor) {
      // 结算落库与点数推进在服务层异步完成，并由 finalizeNight 统一 bump dataVersion 刷新各页。
      this.monitor.stopNightlyMonitoring();
      // 文案以服务层落库的真实判定为准（判定公式只在 evaluateCompliance 一处），
      // 不再用页面 @State 重算，避免 Toast 与持久化结果不一致。
      const data = this.monitor.getCurrentNightData();
      compliant = data !== null && data.judgment === SleepJudgment.COMPLIANT;
    }
    showToast(compliant ? '本晚达标，已返还 1 点 🎉' : '检测到熬夜，未返还点数');
    router.back();
  }
}
