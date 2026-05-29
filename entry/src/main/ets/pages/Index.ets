/**
 * 好梦 (Good Night) 主入口
 * 底部导航：主页、统计、我的
 */
import { HomeTab } from '../tabs/HomeTab';
import { StatisticsTab } from '../tabs/StatisticsTab';
import { ProfileTab } from '../tabs/ProfileTab';

@Entry
@Component
struct Index {
  @State currentIndex: number = 0;

  build() {
    Column() {
      Tabs({ barPosition: BarPosition.End, index: this.currentIndex }) {
        TabContent() {
          HomeTab()
        }
        .tabBar(this.TabBuilder('主页', 0))

        TabContent() {
          StatisticsTab()
        }
        .tabBar(this.TabBuilder('统计', 1))

        TabContent() {
          ProfileTab()
        }
        .tabBar(this.TabBuilder('我的', 2))
      }
      .scrollable(false)
      .barBackgroundColor(Color.White)
      .barMode(BarMode.Fixed)
      .width('100%')
      .layoutWeight(1)
      .onChange((index: number) => {
        this.currentIndex = index;
      })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  TabBuilder(title: string, index: number): void {
    Column() {
      Text(title)
        .fontSize(14)
        .fontColor(this.currentIndex === index ? '#6C5CE7' : '#636E72')
        .fontWeight(this.currentIndex === index ? FontWeight.Bold : FontWeight.Normal)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }
}
