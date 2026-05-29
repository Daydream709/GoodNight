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

export class ScreenMonitorService implements IScreenMonitorService {
  private screenOnCount: number = 0;
  private subscriber: commonEventManager.CommonEventSubscriber | null = null;
  private callback: ScreenEventCallback | null = null;

  startMonitoring(callback: ScreenEventCallback): void {
    this.callback = callback;
    this.screenOnCount = 0;
    this.setupSubscription();
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
            this.screenOnCount++;
            logInfo('Screen ON detected, count: %{public}s', this.screenOnCount.toString());
            if (this.callback) {
              this.callback.onScreenOn();
            }
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

  getScreenOnCount(): number {
    return this.screenOnCount;
  }

  resetScreenOnCount(): void {
    this.screenOnCount = 0;
  }
}
