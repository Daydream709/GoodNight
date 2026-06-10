/**
 * 好梦 (Good Night) 主入口
 * 底部导航：主页、统计、健康、我的
 */
import { HomeTab } from '../tabs/HomeTab';
import { StatisticsTab } from '../tabs/StatisticsTab';
import { HealthTab } from '../tabs/HealthTab';
import { ProfileTab } from '../tabs/ProfileTab';
import { AppColors } from '../common/AppColors';

@Entry
@Component
struct Index {
  @StorageLink('isDarkMode') isDarkMode: boolean = false;
  @State currentIndex: number = 0;

  aboutToAppear(): void {
    PersistentStorage.persistProp('isDarkMode', false);
  }

  build() {
    Column() {
      Tabs({ barPosition: BarPosition.End, index: this.currentIndex }) {
        TabContent() {
          HomeTab()
        }
        .tabBar(this.TabBuilder($r('app.media.tab_home'), '主页', 0))

        TabContent() {
          StatisticsTab()
        }
        .tabBar(this.TabBuilder($r('app.media.tab_stats'), '统计', 1))

        TabContent() {
          HealthTab()
        }
        .tabBar(this.TabBuilder($r('app.media.tab_health'), '健康', 2))

        TabContent() {
          ProfileTab()
        }
        .tabBar(this.TabBuilder($r('app.media.tab_profile'), '我的', 3))
      }
      .scrollable(false)
      .animationDuration(280)
      .barBackgroundColor(this.colors().tabBarBg)
      .barMode(BarMode.Fixed)
      .width('100%')
      .layoutWeight(1)
      .onChange((index: number) => {
        this.currentIndex = index;
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.colors().background)
  }

  private colors() {
    return AppColors.current(this.isDarkMode);
  }

  @Builder
  TabBuilder(icon: Resource, title: string, index: number): void {
    Column() {
      Image(icon)
        .width(24)
        .height(24)
        .fillColor(this.currentIndex === index ? this.colors().primary : this.colors().textSecondary)
      Text(title)
        .fontSize(12)
        .fontColor(this.currentIndex === index ? this.colors().primary : this.colors().textSecondary)
        .fontWeight(this.currentIndex === index ? FontWeight.Bold : FontWeight.Normal)
        .margin({ top: 2 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }
}
