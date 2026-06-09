/**
 * 测试数据生成器
 * 注册 test01 用户并生成一年的睡眠监测模拟数据
 */
import { relationalStore } from '@kit.ArkData';
import { SleepJudgment } from '../model/SleepJudgment';
import { formatDateKey } from './DateUtils';
import { hashPassword } from './PasswordHasher';
import { logInfo, logError } from './Logger';

export class TestDataGenerator {

  static async generate(store: relationalStore.RdbStore): Promise<boolean> {
    try {
      // 1. 检查是否已有完整数据（有用户且有记录）
      let resultSet = await store.querySql('SELECT id FROM users WHERE username = ?', ['test01']);
      let userExists = false;
      let userId: number = 0;
      if (resultSet.goToFirstRow()) {
        userExists = true;
        userId = resultSet.getLong(0);
      }
      resultSet.close();

      if (userExists) {
        // 检查该用户是否已有日常记录
        resultSet = await store.querySql('SELECT COUNT(*) as cnt FROM daily_records WHERE user_id = ?', [userId]);
        let recordCount = 0;
        if (resultSet.goToFirstRow()) {
          recordCount = resultSet.getLong(0);
        }
        resultSet.close();

        if (recordCount >= 300) {
          logInfo('Test data already exists with %{public}s records, skipping', recordCount.toString());
          return true;
        }

        // 数据不完整，清理该用户旧数据后重新生成
        logInfo('Incomplete test data (%{public}s records), regenerating...', recordCount.toString());
        await store.executeSql('DELETE FROM cycles WHERE user_id = ?', [userId]);
        await store.executeSql('DELETE FROM daily_records WHERE user_id = ?', [userId]);
        await store.executeSql('DELETE FROM users WHERE id = ?', [userId]);
      }

      // 2. 插入 test01 用户
      const passwordHash = hashPassword('test01');
      const userValues: Record<string, relationalStore.ValueType> = {
        'username': 'test01',
        'password_hash': passwordHash,
        'created_at': Date.now(),
        'avatar_path': ''
      };
      await store.insert('users', userValues);

      resultSet = await store.querySql('SELECT id FROM users WHERE username = ?', ['test01']);
      if (resultSet.goToFirstRow()) {
        userId = resultSet.getLong(0);
      }
      resultSet.close();
      logInfo('Test user created: id=%{public}s', userId.toString());

      // 3. 生成一年的每日记录
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      const startDate = new Date(today);
      startDate.setFullYear(startDate.getFullYear() - 1);

      // 用种子生成伪随机，使结果可复现
      let seed: number = 42;
      const rand = (): number => {
        seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF;
        return seed / 0x7FFFFFFF;
      };

      const totalDays = 366;
      let compliantDaysInCycle: number = 0;
      let cycleStart = new Date(startDate);
      let cycleDayIndex: number = 0;

      for (let i = 0; i < totalDays; i++) {
        const currentDate = new Date(startDate);
        currentDate.setDate(currentDate.getDate() + i);

        if (currentDate > today) {
          break;
        }

        const dateKey = formatDateKey(currentDate);
        const dayOfWeek = currentDate.getDay();

        // 周末更容易熬夜
        const isWeekend = dayOfWeek === 5 || dayOfWeek === 6;
        const lateChance = isWeekend ? 0.4 : 0.2;
        const isLate = rand() < lateChance;

        const judgment: number = isLate ? SleepJudgment.NON_COMPLIANT : SleepJudgment.COMPLIANT;

        // 亮屏次数
        const screenOnCount: number = isLate
          ? Math.floor(rand() * 8) + 3    // 3-10
          : Math.floor(rand() * 3);       // 0-2

        // 移动事件次数
        const movementEventCount: number = isLate
          ? Math.floor(rand() * 15) + 5   // 5-19
          : Math.floor(rand() * 4);       // 0-3

        // 最大加速度
        const maxAcceleration: number = isLate
          ? rand() * 10 + 15              // 15-25
          : rand() * 5 + 1;              // 1-6

        // 监测开始时间
        const monitorStartDate = new Date(currentDate.getTime());
        if (isLate) {
          // 熬夜：次日凌晨 00:00 ~ 01:59
          monitorStartDate.setDate(monitorStartDate.getDate() + 1);
          monitorStartDate.setHours(Math.floor(rand() * 2), Math.floor(rand() * 60), 0, 0);
        } else {
          // 正常：当晚 22:30 ~ 23:30
          const hour = rand() > 0.5 ? 23 : 22;
          const baseMinute = hour === 22 ? 30 : 0;
          monitorStartDate.setHours(hour, baseMinute + Math.floor(rand() * 30), 0, 0);
        }
        const monitorStartTime: number = monitorStartDate.getTime();

        // 监测结束时间：次日 6:00 ~ 7:59
        const monitorEndDate = new Date(currentDate.getTime());
        monitorEndDate.setDate(monitorEndDate.getDate() + 1);
        monitorEndDate.setHours(6 + Math.floor(rand() * 2), Math.floor(rand() * 60), 0, 0);
        const monitorEndTime: number = monitorEndDate.getTime();

        const pointReturned: number = isLate ? 0 : 1;

        if (!isLate) {
          compliantDaysInCycle++;
        }

        // 使用 store.insert() 而非 executeSql，确保可靠写入
        const recordValues: Record<string, relationalStore.ValueType> = {
          'user_id': userId,
          'date_key': dateKey,
          'judgment': judgment,
          'screen_on_count': screenOnCount,
          'movement_event_count': movementEventCount,
          'max_acceleration': maxAcceleration,
          'monitor_start_time': monitorStartTime,
          'monitor_end_time': monitorEndTime,
          'point_returned': pointReturned
        };
        try {
          await store.insert('daily_records', recordValues);
        } catch (insertErr) {
          // date_key 已存在则忽略（INSERT OR IGNORE 效果）
          logInfo('Skip existing record: %{public}s', dateKey);
        }

        // 每满 30 天生成一个周期
        cycleDayIndex++;
        if (cycleDayIndex === 30 || i === totalDays - 1) {
          const cycleStartKey = formatDateKey(cycleStart);
          const cycleEndDate = new Date(cycleStart.getTime());
          cycleEndDate.setDate(cycleEndDate.getDate() + 29);
          const cycleEndKey = formatDateKey(cycleEndDate);

          const isActive: number = cycleEndDate >= today ? 1 : 0;
          const daysSinceStart = Math.floor((today.getTime() - cycleStart.getTime()) / 86400000) + 1;
          const currentDayIdx: number = isActive ? Math.min(daysSinceStart, 30) : 30;

          const cycleValues: Record<string, relationalStore.ValueType> = {
            'user_id': userId,
            'cycle_id': cycleStartKey,
            'start_date_key': cycleStartKey,
            'end_date_key': cycleEndKey,
            'points_invested': 30,
            'points_returned': compliantDaysInCycle,
            'current_day_index': currentDayIdx,
            'is_active': isActive
          };
          await store.insert('cycles', cycleValues);

          // 重置周期追踪
          cycleStart = new Date(currentDate.getTime());
          cycleStart.setDate(cycleStart.getDate() + 1);
          cycleDayIndex = 0;
          compliantDaysInCycle = 0;
        }
      }

      logInfo('Test data generated successfully for test01');
      return true;
    } catch (err) {
      logError('Test data generation failed: %{public}s', (err as Error).message ?? '');
      return false;
    }
  }
}
