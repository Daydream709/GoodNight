/**
 * 通知服务接口
 */
import { CycleInfo } from '../model/CycleInfo';

export interface INotificationService {
  /** 发送"监测已开始"通知 */
  notifyMonitoringStarted(): Promise<void>;

  /** 发送达标/未达标结果通知 */
  notifyComplianceResult(compliant: boolean, dateKey: string): Promise<void>;

  /** 发送周期汇总通知 */
  notifyCycleSummary(cycle: CycleInfo): Promise<void>;

  /** 取消所有通知 */
  cancelAll(): Promise<void>;
}
