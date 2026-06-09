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
  DB_NAME, TABLE_CYCLES, TABLE_DAILY_RECORDS, TABLE_USERS, TABLE_APP_CONFIG,
  CYCLE_DURATION_DAYS, INITIAL_POINTS_INVESTED
} from '../../common/Constants';
import { formatDateKey } from '../../common/DateUtils';
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

  /**
   * 获取当前用户最近一个周期（不限是否进行中），用于展示上一期成绩
   */
  async getMostRecentCycle(): Promise<CycleInfo | null> {
    this.ensureReady();
    try {
      const predicates = new relationalStore.RdbPredicates(TABLE_CYCLES);
      predicates.equalTo('user_id', this.currentUserId);
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
      logError('Failed to get most recent cycle: %{public}s', (err as Error).message ?? '');
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
      predicates.equalTo('user_id', this.currentUserId);
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
        'user_id': this.currentUserId,
        'date_key': record.dateKey,
        'judgment': record.judgment as number,
        'screen_on_count': record.screenOnCount,
        'movement_event_count': record.movementEventCount,
        'max_acceleration': record.maxAcceleration,
        'monitor_start_time': record.monitorStartTime,
        'monitor_end_time': record.monitorEndTime,
        'point_returned': record.pointReturned ? 1 : 0
      };

      // 检查是否已存在（按 用户 + 日期）
      const predicates = new relationalStore.RdbPredicates(TABLE_DAILY_RECORDS);
      predicates.equalTo('user_id', this.currentUserId);
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
      const predicates = new relationalStore.RdbPredicates(TABLE_DAILY_RECORDS);
      predicates.equalTo('user_id', this.currentUserId);
      predicates.orderByAsc('date_key');
      const resultSet = await this.store!.query(predicates);
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
      predicates.equalTo('user_id', this.currentUserId);
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

  /** 当前用户累计周期数 */
  async getCycleCount(): Promise<number> {
    this.ensureReady();
    try {
      const resultSet = await this.store!.querySql(
        'SELECT COUNT(*) FROM ' + TABLE_CYCLES + ' WHERE user_id = ?', [this.currentUserId]);
      let count = 0;
      if (resultSet.goToFirstRow()) { count = resultSet.getLong(0); }
      resultSet.close();
      return count;
    } catch (err) {
      logError('Failed to get cycle count: %{public}s', (err as Error).message ?? '');
      return 0;
    }
  }

  /** 当前用户累计返还点数（跨所有周期） */
  async getTotalReturnedPoints(): Promise<number> {
    this.ensureReady();
    try {
      // IFNULL 兜底：无周期时 SUM 返回 NULL 行，getLong(NULL) 会抛异常，故在 SQL 层归零
      const resultSet = await this.store!.querySql(
        'SELECT IFNULL(SUM(points_returned), 0) FROM ' + TABLE_CYCLES + ' WHERE user_id = ?',
        [this.currentUserId]);
      let total = 0;
      if (resultSet.goToFirstRow()) { total = resultSet.getLong(0); }
      resultSet.close();
      return total;
    } catch (err) {
      logError('Failed to get total returned: %{public}s', (err as Error).message ?? '');
      return 0;
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
    const startDateKey = formatDateKey(now);
    const endDate = new Date(now);
    endDate.setDate(endDate.getDate() + CYCLE_DURATION_DAYS - 1);

    const newCycle = new CycleInfo();
    newCycle.cycleId = startDateKey;
    newCycle.startDateKey = startDateKey;
    newCycle.endDateKey = formatDateKey(endDate);
    newCycle.pointsInvested = INITIAL_POINTS_INVESTED;
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
      'CREATE TABLE IF NOT EXISTS ' + TABLE_APP_CONFIG + ' (' +
      'key TEXT PRIMARY KEY, ' +
      'value TEXT NOT NULL)'
    );
    // daily_records 按用户隔离（含旧表迁移）
    await this.migrateDailyRecordsTable();
    // 迁移：为旧 users 表添加 avatar_path 列
    try {
      await this.store!.executeSql('ALTER TABLE ' + TABLE_USERS + ' ADD COLUMN avatar_path TEXT NOT NULL DEFAULT \'\'');
    } catch (err) {
      // 列已存在，忽略
    }
  }

  /** daily_records 新表结构 SQL：以 (user_id, date_key) 作为唯一键，实现多用户隔离 */
  private dailyRecordsSchemaSql(): string {
    return 'CREATE TABLE IF NOT EXISTS ' + TABLE_DAILY_RECORDS + ' (' +
      'id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
      'user_id INTEGER NOT NULL DEFAULT 0, ' +
      'date_key TEXT NOT NULL, ' +
      'judgment INTEGER NOT NULL DEFAULT 0, ' +
      'screen_on_count INTEGER NOT NULL DEFAULT 0, ' +
      'movement_event_count INTEGER NOT NULL DEFAULT 0, ' +
      'max_acceleration REAL NOT NULL DEFAULT 0, ' +
      'monitor_start_time INTEGER NOT NULL DEFAULT 0, ' +
      'monitor_end_time INTEGER NOT NULL DEFAULT 0, ' +
      'point_returned INTEGER NOT NULL DEFAULT 0, ' +
      'UNIQUE(user_id, date_key))';
  }

  /**
   * 迁移 daily_records：旧表唯一键为 date_key（全局共享，多用户串数据）。
   * 若检测到旧结构（无 user_id 列），重建表并将历史记录归到 user_id=0。
   */
  private async migrateDailyRecordsTable(): Promise<void> {
    const store = this.store!;
    // 全新安装：直接建新表
    await store.executeSql(this.dailyRecordsSchemaSql());

    // 旧安装：旧表已存在，上面的 IF NOT EXISTS 不生效，需检测并重建
    const hasUserId = await this.columnExists(TABLE_DAILY_RECORDS, 'user_id');
    if (!hasUserId) {
      logInfo('Migrating daily_records to per-user schema');
      await store.executeSql('ALTER TABLE ' + TABLE_DAILY_RECORDS + ' RENAME TO daily_records_old');
      await store.executeSql(this.dailyRecordsSchemaSql());
      await store.executeSql(
        'INSERT OR IGNORE INTO ' + TABLE_DAILY_RECORDS +
        ' (user_id, date_key, judgment, screen_on_count, movement_event_count, ' +
        'max_acceleration, monitor_start_time, monitor_end_time, point_returned) ' +
        'SELECT 0, date_key, judgment, screen_on_count, movement_event_count, ' +
        'max_acceleration, monitor_start_time, monitor_end_time, point_returned FROM daily_records_old'
      );
      await store.executeSql('DROP TABLE daily_records_old');
    }
  }

  /** 判断某表是否包含指定列 */
  private async columnExists(table: string, column: string): Promise<boolean> {
    try {
      const resultSet = await this.store!.querySql('PRAGMA table_info(' + table + ')');
      let found = false;
      while (resultSet.goToNextRow()) {
        if (resultSet.getString(resultSet.getColumnIndex('name')) === column) {
          found = true;
          break;
        }
      }
      resultSet.close();
      return found;
    } catch (err) {
      return false;
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
}
