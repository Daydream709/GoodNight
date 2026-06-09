/**
 * 屏幕状态监听服务
 * 通过 commonEventManager 订阅系统亮屏/息屏广播事件
 */
import { commonEventManager, BusinessError } from '@kit.BasicServicesKit';
import { IScreenMonitorService, ScreenEventCallback } from '../../interface/IScreenMonitorService';
import { logInfo, logError } from '../../common/Logger';

// 屏幕事件常量
const EVENT_SCREEN_ON: string = 'usual.event.SCREEN_ON';
const EVENT_SCREEN_OFF: string = 'usual.event.SCREEN_OFF';

// 同一次"使用手机"可能同时触发真实亮屏广播与离开页面的手动计数；
// 在此窗口内的重复信号合并为一次，避免真机上双计数
const SCREEN_ON_DEDUP_MS: number = 1500;

export class ScreenMonitorService implements IScreenMonitorService {
  private screenOnCount: number = 0;
  private subscriber: commonEventManager.CommonEventSubscriber | null = null;
  private callback: ScreenEventCallback | null = null;
  private lastOnTs: number = 0;

  startMonitoring(callback: ScreenEventCallback): void {
    this.callback = callback;
    this.screenOnCount = 0;
    this.lastOnTs = 0;
    this.setupSubscription();
  }

  /**
   * 统一的"亮屏/使用手机"计数入口：真实亮屏广播与手动 increment() 都经此处，
   * 共用去抖窗口，避免真机上同一次使用被两个信号源各记一次（见 #6）。
   */
  private registerScreenOn(source: string): void {
    const now = Date.now();
    if (now - this.lastOnTs < SCREEN_ON_DEDUP_MS) {
      logInfo('Screen-on ignored (dedup), source: %{public}s', source);
      return;
    }
    this.lastOnTs = now;
    this.screenOnCount++;
    logInfo('Screen-on counted (%{public}s), count: %{public}s', source, this.screenOnCount.toString());
    if (this.callback) {
      this.callback.onScreenOn();
    }
  }

  private async setupSubscription(): Promise<void> {
    try {
      const subscribeInfo: commonEventManager.CommonEventSubscribeInfo = {
        events: [EVENT_SCREEN_ON, EVENT_SCREEN_OFF]
      };

      this.subscriber = await commonEventManager.createSubscriber(subscribeInfo);

      commonEventManager.subscribe(this.subscriber,
        (err: BusinessError, data: commonEventManager.CommonEventData) => {
          if (err) {
            logError('Screen event error: %{public}s', err.message ?? '');
            return;
          }
          const event: string = data.event;
          if (event === EVENT_SCREEN_ON) {
            this.registerScreenOn('broadcast');
          } else if (event === EVENT_SCREEN_OFF) {
            logInfo('Screen OFF detected');
            if (this.callback) {
              this.callback.onScreenOff();
            }
          }
        });

      logInfo('ScreenMonitorService started');
    } catch (err) {
      logError('Failed to start screen monitoring: %{public}s', (err as BusinessError).message ?? '');
    }
  }

  stopMonitoring(): void {
    if (this.subscriber) {
      try {
        commonEventManager.unsubscribe(this.subscriber);
        logInfo('ScreenMonitorService stopped, total screenOn: %{public}s', this.screenOnCount.toString());
      } catch (err) {
        logError('Failed to unsubscribe: %{public}s', (err as BusinessError).message ?? '');
      }
      this.subscriber = null;
    }
    this.callback = null;
  }

  /**
   * 手动记一次"使用手机"（将"离开监测页"计为一次使用，
   * 兼容模拟机无法触发真实锁屏/亮屏广播的场景）。
   * 与真实亮屏广播共用去抖，二者临近时只计一次。
   */
  increment(): void {
    this.registerScreenOn('manual');
  }

  getScreenOnCount(): number {
    return this.screenOnCount;
  }

  resetScreenOnCount(): void {
    this.screenOnCount = 0;
    this.lastOnTs = 0;
  }
}
