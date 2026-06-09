/**
 * 通知服务实现
 * 使用 @kit.NotificationKit 发送本地通知
 */
import { notificationManager } from '@kit.NotificationKit';
import { INotificationService } from '../../interface/INotificationService';
import { CycleInfo } from '../../model/CycleInfo';
import { NOTIFICATION_ID_MONITOR, NOTIFICATION_ID_RESULT, NOTIFICATION_ID_CYCLE } from '../../common/Constants';
import { AppSettings } from '../../common/AppSettings';
import { logInfo, logError } from '../../common/Logger';

export class NotificationService implements INotificationService {
  async notifyMonitoringStarted(): Promise<void> {
    if (!AppSettings.notificationsEnabled) { return; }
    try {
      const request: notificationManager.NotificationRequest = {
        id: NOTIFICATION_ID_MONITOR,
        content: {
          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: {
            title: '好梦 - 睡眠监测',
            text: '今晚的睡眠监测已开始，早点休息哦！'
          }
        },
        isOngoing: true // 持续性通知（后台任务需要）
      };
      await notificationManager.publish(request);
      logInfo('Monitoring started notification sent');
    } catch (err) {
      logError('Failed to send monitoring notification: %{public}s', JSON.stringify(err));
    }
  }

  async notifyComplianceResult(compliant: boolean, dateKey: string): Promise<void> {
    if (!AppSettings.notificationsEnabled) { return; }
    try {
      const title = compliant ? '好梦 - 睡眠达标！' : '好梦 - 检测到熬夜';
      const text = compliant
        ? `恭喜！${dateKey} 晚上睡眠达标，已返还 1 个点数。`
        : `${dateKey} 晚上检测到熬夜行为，本次不返还点数。`;

      const request: notificationManager.NotificationRequest = {
        id: NOTIFICATION_ID_RESULT,
        content: {
          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: {
            title: title,
            text: text
          }
        }
      };
      await notificationManager.publish(request);
      logInfo('Compliance result notification sent: %{public}s', compliant.toString());
    } catch (err) {
      logError('Failed to send result notification: %{public}s', JSON.stringify(err));
    }
  }

  async notifyCycleSummary(cycle: CycleInfo): Promise<void> {
    if (!AppSettings.notificationsEnabled) { return; }
    try {
      const title = '好梦 - 周期结束';
      const text = `30 天周期已结束！共返还 ${cycle.pointsReturned} / ${cycle.pointsInvested} 点数。`;

      const request: notificationManager.NotificationRequest = {
        id: NOTIFICATION_ID_CYCLE,
        content: {
          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: {
            title: title,
            text: text
          }
        }
      };
      await notificationManager.publish(request);
      logInfo('Cycle summary notification sent');
    } catch (err) {
      logError('Failed to send cycle notification: %{public}s', JSON.stringify(err));
    }
  }

  async cancelAll(): Promise<void> {
    try {
      await notificationManager.cancelAll();
      logInfo('All notifications cancelled');
    } catch (err) {
      logError('Failed to cancel notifications: %{public}s', JSON.stringify(err));
    }
  }
}
