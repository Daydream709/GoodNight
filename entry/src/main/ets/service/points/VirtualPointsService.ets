/**
 * 虚拟点数服务实现
 * 纯本地余额管理，不涉及真实支付
 *
 * 扩展说明：
 * 未来接入微信/支付宝支付时，创建 WeChatPayPointsService implements IPointsService，
 * 在 investPoints() 中调用支付 SDK，在 returnPoint() 中调用退款/转账 API。
 * 然后在服务注入点（EntryAbility）将 VirtualPointsService 替换为新实现即可。
 */
import { IPointsService } from '../../interface/IPointsService';
import { IDataRepository } from '../../interface/IDataRepository';
import { INITIAL_POINTS_INVESTED, POINT_RETURN_PER_DAY } from '../../common/Constants';
import { logInfo, logError } from '../../common/Logger';

export class VirtualPointsService implements IPointsService {
  private repository: IDataRepository;

  constructor(repository: IDataRepository) {
    this.repository = repository;
  }

  async investPoints(cycleId: string, amount: number): Promise<boolean> {
    try {
      const cycle = await this.repository.getCurrentCycle();
      if (!cycle || cycle.cycleId !== cycleId) {
        logError('Cycle not found: %{public}s', cycleId);
        return false;
      }
      cycle.pointsInvested = amount;
      await this.repository.saveCurrentCycle(cycle);
      logInfo('Invested %{public}d points for cycle %{public}s', amount.toString(), cycleId);
      return true;
    } catch (err) {
      logError('Failed to invest points: %{public}s', JSON.stringify(err));
      return false;
    }
  }

  async returnPoint(cycleId: string, dateKey: string): Promise<boolean> {
    try {
      const cycle = await this.repository.getCurrentCycle();
      if (!cycle || cycle.cycleId !== cycleId) {
        logError('Cycle not found: %{public}s', cycleId);
        return false;
      }

      // 检查该日期是否已经返还过
      const record = await this.repository.getDailyRecord(dateKey);
      if (record && record.pointReturned) {
        logInfo('Point already returned for %{public}s', dateKey);
        return false;
      }

      // 增加返还点数
      cycle.pointsReturned += POINT_RETURN_PER_DAY;
      await this.repository.saveCurrentCycle(cycle);

      // 标记记录已返还
      if (record) {
        record.pointReturned = true;
        await this.repository.saveDailyRecord(record);
      }

      logInfo('Returned 1 point for cycle %{public}s, date %{public}s', cycleId, dateKey);
      return true;
    } catch (err) {
      logError('Failed to return point: %{public}s', JSON.stringify(err));
      return false;
    }
  }

  async getBalance(cycleId: string): Promise<number> {
    try {
      const cycle = await this.repository.getCurrentCycle();
      if (!cycle || cycle.cycleId !== cycleId) {
        return 0;
      }
      return cycle.getRemainingPoints();
    } catch (err) {
      logError('Failed to get balance: %{public}s', JSON.stringify(err));
      return 0;
    }
  }

  async getTotalReturned(cycleId: string): Promise<number> {
    try {
      const cycle = await this.repository.getCurrentCycle();
      if (!cycle || cycle.cycleId !== cycleId) {
        return 0;
      }
      return cycle.pointsReturned;
    } catch (err) {
      logError('Failed to get total returned: %{public}s', JSON.stringify(err));
      return 0;
    }
  }

  async refundAllRemaining(cycleId: string): Promise<number> {
    try {
      const cycle = await this.repository.getCurrentCycle();
      if (!cycle || cycle.cycleId !== cycleId) {
        return 0;
      }
      const remaining = cycle.getRemainingPoints();
      cycle.pointsReturned = cycle.pointsInvested;
      cycle.isActive = false;
      await this.repository.saveCurrentCycle(cycle);
      logInfo('Refunded %{public}d remaining points', remaining.toString());
      return remaining;
    } catch (err) {
      logError('Failed to refund: %{public}s', JSON.stringify(err));
      return 0;
    }
  }
}
