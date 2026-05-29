/**
 * 数据持久化接口
 * 解耦业务逻辑与存储实现，当前使用 Preferences，未来可替换为数据库或云端
 */
import { CycleInfo } from '../model/CycleInfo';
import { DailyRecord } from '../model/DailyRecord';

export interface IDataRepository {
  /** 初始化数据存储 */
  init(context: Context): Promise<void>;

  /** 获取当前活跃周期 */
  getCurrentCycle(): Promise<CycleInfo | null>;

  /** 保存周期信息 */
  saveCurrentCycle(cycle: CycleInfo): Promise<void>;

  /** 获取指定日期的监测记录 */
  getDailyRecord(dateKey: string): Promise<DailyRecord | null>;

  /** 保存每日监测记录 */
  saveDailyRecord(record: DailyRecord): Promise<void>;

  /** 获取指定周期的所有监测记录 */
  getAllDailyRecordsForCycle(cycleId: string): Promise<DailyRecord[]>;

  /** 开始新周期（自动结束旧周期） */
  startNewCycle(): Promise<CycleInfo>;

  /** 按日期范围查询监测记录 */
  getDailyRecordsByDateRange(startDateKey: string, endDateKey: string): Promise<DailyRecord[]>;
}
