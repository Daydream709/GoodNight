/**
 * 基于 SQLite 的数据持久化实现
 * 使用 @kit.ArkData 的 relationalStore 模块
 */
import { relationalStore } from '@kit.ArkData';
import { IDataRepository } from '../../interface/IDataRepository';
import { CycleInfo } from '../../model/CycleInfo';
import { DailyRecord } from '../../model/DailyRecord';
import { SleepJudgment } from '../../model/SleepJudgment';
import {
  DB_NAME, TABLE_CYCLES, TABLE_DAILY_RECORDS, TABLE_USERS, TABLE_APP_CONFIG, CYCLE_DURATION_DAYS
} from '../../common/Constants';
import { logInfo, logError } from '../../common/Logger';

export class DatabaseRepository implements IDataRepository {
  private store: relationalStore.RdbStore | null = null;
  private currentUserId: number = 0;

  async init(context: Context): Promise<void> {
    try {
      const config: relationalStore.StoreConfig = {
        name: DB_NAME,
        securityLevel: relationalStore.SecurityLevel.S1
      };
      this.store = await relationalStore.getRdbStore(context, config);
      await this.createTables();
      logInfo('DatabaseRepository initialized');
    } catch (err) {
      logError('Failed to init database: %{public}s', (err as Error).message ?? '');
      throw new Error('Failed to init database');
    }
  }

  /**
   * 获取 RdbStore 实例（供 AuthService 共享）
   */
  getStore(): relationalStore.RdbStore | null {
    return this.store;
  }

  /**
   * 设置当前登录用户 ID（登录后调用）
   */
  setCurrentUserId(userId: number): void {
    this.currentUserId = userId;
  }

  getCurrentUserId(): number {
    return this.currentUserId;
  }

  // ========== IDataRepository 实现 ==========

  async getCurrentCycle(): Promise<CycleInfo | null> {
    this.ensureReady();
    try {
      const predicates = new relationalStore.RdbPredicates(TABLE_CYCLES);
      predicates.equalTo('user_id', this.currentUserId);
      predicates.equalTo('is_active', 1);
      predicates.orderByDesc('id');
      predicates.limitAs(1);
      const resultSet = await this.store!.query(predicates);
      if (resultSet.goToFirstRow()) {
        const cycle = this.readCycleFromCursor(resultSet);
        resultSet.close();
        return cycle;
      }
      resultSet.close();
      return null;
    } catch (err) {
      logError('Failed to get current cycle: %{public}s', (err as Error).message ?? '');
      return null;
    }
  }

  async saveCurrentCycle(cycle: CycleInfo): Promise<void> {
    this.ensureReady();
    try {
      const values: Record<string, relationalStore.ValueType> = {
        'user_id': this.currentUserId,
        'cycle_id': cycle.cycleId,
        'start_date_key': cycle.startDateKey,
        'end_date_key': cycle.endDateKey,
        'points_invested': cycle.pointsInvested,
        'points_returned': cycle.pointsReturned,
        'current_day_index': cycle.currentDayIndex,
        'is_active': cycle.isActive ? 1 : 0
      };

      // 检查是否已存在
      const predicates = new relationalStore.RdbPredicates(TABLE_CYCLES);
      predicates.equalTo('cycle_id', cycle.cycleId);
      const resultSet = await this.store!.query(predicates, ['id']);
      if (resultSet.goToFirstRow()) {
        const rowId = resultSet.getLong(0);
        resultSet.close();
        await this.store!.update(values, new relationalStore.RdbPredicates(TABLE_CYCLES).equalTo('id', rowId));
      } else {
        resultSet.close();
        await this.store!.insert(TABLE_CYCLES, values);
      }
      logInfo('Cycle saved: %{public}s', cycle.cycleId);
    } catch (err) {
      logError('Failed to save cycle: %{public}s', (err as Error).message ?? '');
    }
  }

  async getDailyRecord(dateKey: string): Promise<DailyRecord | null> {
    this.ensureReady();
    try {
      const predicates = new relationalStore.RdbPredicates(TABLE_DAILY_RECORDS);
      predicates.equalTo('date_key', dateKey);
      const resultSet = await this.store!.query(predicates);
      if (resultSet.goToFirstRow()) {
        const record = this.readRecordFromCursor(resultSet);
        resultSet.close();
        return record;
      }
      resultSet.close();
      return null;
    } catch (err) {
      logError('Failed to get daily record: %{public}s', (err as Error).message ?? '');
      return null;
    }
  }

  async saveDailyRecord(record: DailyRecord): Promise<void> {
    this.ensureReady();
    try {
      const values: Record<string, relationalStore.ValueType> = {
        'date_key': record.dateKey,
        'judgment': record.judgment as number,
        'screen_on_count': record.screenOnCount,
        'movement_event_count': record.movementEventCount,
        'max_acceleration': record.maxAcceleration,
        'monitor_start_time': record.monitorStartTime,
        'monitor_end_time': record.monitorEndTime,
        'point_returned': record.pointReturned ? 1 : 0
      };

      // 检查是否已存在
      const predicates = new relationalStore.RdbPredicates(TABLE_DAILY_RECORDS);
      predicates.equalTo('date_key', record.dateKey);
      const resultSet = await this.store!.query(predicates, ['id']);
      if (resultSet.goToFirstRow()) {
        const rowId = resultSet.getLong(0);
        resultSet.close();
        await this.store!.update(values, new relationalStore.RdbPredicates(TABLE_DAILY_RECORDS).equalTo('id', rowId));
      } else {
        resultSet.close();
        await this.store!.insert(TABLE_DAILY_RECORDS, values);
      }
      logInfo('Daily record saved: %{public}s', record.dateKey);
    } catch (err) {
      logError('Failed to save daily record: %{public}s', (err as Error).message ?? '');
    }
  }

  async getAllDailyRecordsForCycle(cycleId: string): Promise<DailyRecord[]> {
    this.ensureReady();
    try {
      const resultSet = await this.store!.querySql('SELECT * FROM ' + TABLE_DAILY_RECORDS + ' ORDER BY date_key ASC');
      return this.readAllRecords(resultSet);
    } catch (err) {
      logError('Failed to get all records: %{public}s', (err as Error).message ?? '');
      return [];
    }
  }

  async getDailyRecordsByDateRange(startDateKey: string, endDateKey: string): Promise<DailyRecord[]> {
    this.ensureReady();
    try {
      const predicates = new relationalStore.RdbPredicates(TABLE_DAILY_RECORDS);
      predicates.greaterThanOrEqualTo('date_key', startDateKey);
      predicates.lessThanOrEqualTo('date_key', endDateKey);
      predicates.orderByAsc('date_key');
      const resultSet = await this.store!.query(predicates);
      return this.readAllRecords(resultSet);
    } catch (err) {
      logError('Failed to query records by range: %{public}s', (err as Error).message ?? '');
      return [];
    }
  }

  async startNewCycle(): Promise<CycleInfo> {
    // 结束旧周期
    try {
      const values: Record<string, relationalStore.ValueType> = { 'is_active': 0 };
      const predicates = new relationalStore.RdbPredicates(TABLE_CYCLES);
      predicates.equalTo('user_id', this.currentUserId);
      predicates.equalTo('is_active', 1);
      await this.store!.update(values, predicates);
    } catch (err) {
      // 忽略，可能没有旧周期
    }

    // 创建新周期
    const now = new Date();
    const startDateKey = this.formatDateKey(now);
    const endDate = new Date(now);
    endDate.setDate(endDate.getDate() + CYCLE_DURATION_DAYS - 1);

    const newCycle = new CycleInfo();
    newCycle.cycleId = startDateKey;
    newCycle.startDateKey = startDateKey;
    newCycle.endDateKey = this.formatDateKey(endDate);
    newCycle.pointsInvested = 30;
    newCycle.pointsReturned = 0;
    newCycle.currentDayIndex = 1;
    newCycle.isActive = true;

    await this.saveCurrentCycle(newCycle);
    logInfo('New cycle started: %{public}s', newCycle.cycleId);
    return newCycle;
  }

  // ========== 辅助方法 ==========

  private async createTables(): Promise<void> {
    await this.store!.executeSql(
      'CREATE TABLE IF NOT EXISTS ' + TABLE_USERS + ' (' +
      'id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
      'username TEXT NOT NULL UNIQUE, ' +
      'password_hash TEXT NOT NULL, ' +
      'created_at INTEGER NOT NULL)'
    );
    await this.store!.executeSql(
      'CREATE TABLE IF NOT EXISTS ' + TABLE_CYCLES + ' (' +
      'id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
      'user_id INTEGER NOT NULL, ' +
      'cycle_id TEXT NOT NULL, ' +
      'start_date_key TEXT NOT NULL, ' +
      'end_date_key TEXT NOT NULL, ' +
      'points_invested INTEGER NOT NULL DEFAULT 30, ' +
      'points_returned INTEGER NOT NULL DEFAULT 0, ' +
      'current_day_index INTEGER NOT NULL DEFAULT 1, ' +
      'is_active INTEGER NOT NULL DEFAULT 1)'
    );
    await this.store!.executeSql(
      'CREATE TABLE IF NOT EXISTS ' + TABLE_DAILY_RECORDS + ' (' +
      'id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
      'date_key TEXT NOT NULL UNIQUE, ' +
      'judgment INTEGER NOT NULL DEFAULT 0, ' +
      'screen_on_count INTEGER NOT NULL DEFAULT 0, ' +
      'movement_event_count INTEGER NOT NULL DEFAULT 0, ' +
      'max_acceleration REAL NOT NULL DEFAULT 0, ' +
      'monitor_start_time INTEGER NOT NULL DEFAULT 0, ' +
      'monitor_end_time INTEGER NOT NULL DEFAULT 0, ' +
      'point_returned INTEGER NOT NULL DEFAULT 0)'
    );
    await this.store!.executeSql(
      'CREATE TABLE IF NOT EXISTS ' + TABLE_APP_CONFIG + ' (' +
      'key TEXT PRIMARY KEY, ' +
      'value TEXT NOT NULL)'
    );
    // 迁移：为旧表添加 avatar_path 列
    try {
      await this.store!.executeSql('ALTER TABLE ' + TABLE_USERS + ' ADD COLUMN avatar_path TEXT NOT NULL DEFAULT \'\'');
    } catch (err) {
      // 列已存在，忽略
    }
  }

  private readCycleFromCursor(resultSet: relationalStore.ResultSet): CycleInfo {
    const cycle = new CycleInfo();
    cycle.cycleId = resultSet.getString(resultSet.getColumnIndex('cycle_id'));
    cycle.startDateKey = resultSet.getString(resultSet.getColumnIndex('start_date_key'));
    cycle.endDateKey = resultSet.getString(resultSet.getColumnIndex('end_date_key'));
    cycle.pointsInvested = resultSet.getLong(resultSet.getColumnIndex('points_invested'));
    cycle.pointsReturned = resultSet.getLong(resultSet.getColumnIndex('points_returned'));
    cycle.currentDayIndex = resultSet.getLong(resultSet.getColumnIndex('current_day_index'));
    cycle.isActive = resultSet.getLong(resultSet.getColumnIndex('is_active')) === 1;
    return cycle;
  }

  private readRecordFromCursor(resultSet: relationalStore.ResultSet): DailyRecord {
    const record = new DailyRecord();
    record.dateKey = resultSet.getString(resultSet.getColumnIndex('date_key'));
    record.judgment = resultSet.getLong(resultSet.getColumnIndex('judgment')) as SleepJudgment;
    record.screenOnCount = resultSet.getLong(resultSet.getColumnIndex('screen_on_count'));
    record.movementEventCount = resultSet.getLong(resultSet.getColumnIndex('movement_event_count'));
    record.maxAcceleration = resultSet.getDouble(resultSet.getColumnIndex('max_acceleration'));
    record.monitorStartTime = resultSet.getLong(resultSet.getColumnIndex('monitor_start_time'));
    record.monitorEndTime = resultSet.getLong(resultSet.getColumnIndex('monitor_end_time'));
    record.pointReturned = resultSet.getLong(resultSet.getColumnIndex('point_returned')) === 1;
    return record;
  }

  private readAllRecords(resultSet: relationalStore.ResultSet): DailyRecord[] {
    const records: DailyRecord[] = [];
    while (resultSet.goToNextRow()) {
      records.push(this.readRecordFromCursor(resultSet));
    }
    resultSet.close();
    return records;
  }

  private ensureReady(): void {
    if (!this.store) {
      throw new Error('DatabaseRepository not initialized. Call init() first.');
    }
  }

  private formatDateKey(date: Date): string {
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
  }
}
