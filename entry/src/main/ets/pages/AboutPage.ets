/**
 * 关于 / 帮助页 - 说明监测原理与隐私
 */
import { router } from '@kit.ArkUI';
import { AppColors, ColorPalette } from '../common/AppColors';
import { AppSettings } from '../common/AppSettings';

@Entry
@Component
struct AboutPage {
  @StorageLink('isDarkMode') isDarkMode: boolean = false;

  private colors(): ColorPalette {
    return AppColors.current(this.isDarkMode);
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
        Text('关于好梦')
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
          // 品牌
          Column() {
            Text('🌙').fontSize(48).margin({ bottom: 8 })
            Text('好梦 Good Night')
              .fontSize(20).fontWeight(FontWeight.Bold).fontColor(this.colors().textPrimary)
            Text('v1.0.0')
              .fontSize(12).fontColor(this.colors().textSecondary).margin({ top: 4 })
          }
          .width('100%').padding(24).alignItems(HorizontalAlign.Center)
          .backgroundColor(this.colors().glassBg).borderRadius(20)
          .border({ width: 1, color: this.colors().glassBorder }).backdropBlur(this.colors().glassBlur)

          this.Section('它怎么帮你', [
            `每晚 ${AppSettings.sleepWindowText()}，App 会自动监测你的设备状态。`,
            '若操作手机次数少且基本没移动，判定为"睡眠达标"，次日返还 1 个点数。',
            '坚持 30 天，把投入的点数全部赚回来，养成早睡习惯。'
          ])

          this.Section('如何判定熬夜', [
            '操作检测：统计夜间亮屏、切走应用、下拉通知栏等操作次数。',
            '移动检测：通过加速度传感器判断手机是否被频繁拿起。',
            '操作过多或有明显移动，则判定为熬夜，当晚不返还点数。'
          ])

          this.Section('隐私说明', [
            '🔒 所有睡眠数据仅存储在你的设备本地。',
            '不会上传到任何服务器，也不会被分享。',
            '加速度与屏幕状态仅用于本地达标判定。'
          ])
        }
        .padding({ left: 20, right: 20, bottom: 24 })
      }
      .layoutWeight(1)
    }
    .width('100%').height('100%')
    .backgroundColor(this.colors().background)
  }

  @Builder
  Section(title: string, lines: string[]): void {
    Column() {
      Text(title)
        .fontSize(16).fontWeight(FontWeight.Bold).fontColor(this.colors().textPrimary)
        .width('100%').margin({ bottom: 12 })
      ForEach(lines, (line: string) => {
        Row() {
          Text('·').fontSize(14).fontColor(this.colors().textSecondary)
          Text(line)
            .fontSize(13).fontColor(this.colors().textSecondary)
            .layoutWeight(1).margin({ left: 8 })
        }
        .width('100%').margin({ bottom: 8 }).alignItems(VerticalAlign.Top)
      }, (line: string, idx: number) => idx.toString())
    }
    .width('100%').padding(20)
    .backgroundColor(this.colors().glassBg).borderRadius(20)
    .border({ width: 1, color: this.colors().glassBorder }).backdropBlur(this.colors().glassBlur)
    .alignItems(HorizontalAlign.Start)
  }
}
