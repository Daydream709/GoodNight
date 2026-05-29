/**
 * 点数服务接口（**关键扩展点**）
 *
 * 当前由 VirtualPointsService 实现，使用虚拟点数。
 * 未来替换为真实支付时，只需创建 WeChatPayPointsService / AlipayPointsService
 * 实现此接口，然后在注入点替换实现类即可。
 * UI 层和熬夜判定逻辑无需任何修改。
 */
export interface IPointsService {
  /**
   * 用户投入点数（周期开始时调用）
   * @param cycleId 周期 ID
   * @param amount 投入数量
   * @returns 是否成功
   */
  investPoints(cycleId: string, amount: number): Promise<boolean>;

  /**
   * 返还一个点数（每日达标后调用）
   * @param cycleId 周期 ID
   * @param dateKey 达标的日期键
   * @returns 是否成功
   */
  returnPoint(cycleId: string, dateKey: string): Promise<boolean>;

  /**
   * 查询当前余额（剩余未返还的点数）
   * @param cycleId 周期 ID
   */
  getBalance(cycleId: string): Promise<number>;

  /**
   * 查询累计已返还的点数
   * @param cycleId 周期 ID
   */
  getTotalReturned(cycleId: string): Promise<number>;

  /**
   * 退还所有剩余点数（周期取消或结束时）
   * @param cycleId 周期 ID
   * @returns 实际退还的数量
   */
  refundAllRemaining(cycleId: string): Promise<number>;
}
