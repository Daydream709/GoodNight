# 点数模块扩展指南 - 接入真实支付

## 1. 背景

当前好梦应用使用 `VirtualPointsService` 实现虚拟点数管理。本模块已通过 `IPointsService` 接口完全解耦，为未来接入微信/支付宝真实支付预留了无缝替换的能力。

## 2. IPointsService 接口定义

```typescript
export interface IPointsService {
  investPoints(cycleId: string, amount: number): Promise<boolean>;
  returnPoint(cycleId: string, dateKey: string): Promise<boolean>;
  getBalance(cycleId: string): Promise<number>;
  getTotalReturned(cycleId: string): Promise<number>;
  refundAllRemaining(cycleId: string): Promise<number>;
}
```

## 3. 替换步骤

### Step 1: 创建新实现类

在 `entry/src/main/ets/service/points/` 下创建新文件，例如 `WeChatPayPointsService.ets`：

```typescript
import { IPointsService } from '../../interface/IPointsService';
import { IDataRepository } from '../../interface/IDataRepository';

export class WeChatPayPointsService implements IPointsService {
  private repository: IDataRepository;

  constructor(repository: IDataRepository) {
    this.repository = repository;
  }

  async investPoints(cycleId: string, amount: number): Promise<boolean> {
    // 1. 调用微信支付 SDK 发起扣款
    // 2. 等待支付回调确认
    // 3. 支付成功后更新本地记录
    // 4. 返回支付结果
    throw new Error('Not implemented - 集成微信支付 SDK 后实现');
  }

  async returnPoint(cycleId: string, dateKey: string): Promise<boolean> {
    // 1. 查询该日期是否达标
    // 2. 调用微信转账 API 将 1 元返还到用户微信
    // 3. 更新本地返还记录
    throw new Error('Not implemented - 集成微信转账 API 后实现');
  }

  async getBalance(cycleId: string): Promise<number> {
    // 从本地记录计算剩余金额
    const cycle = await this.repository.getCurrentCycle();
    return cycle ? cycle.getRemainingPoints() : 0;
  }

  async getTotalReturned(cycleId: string): Promise<number> {
    const cycle = await this.repository.getCurrentCycle();
    return cycle ? cycle.pointsReturned : 0;
  }

  async refundAllRemaining(cycleId: string): Promise<number> {
    // 调用微信退款 API 退还剩余金额
    throw new Error('Not implemented - 集成退款 API 后实现');
  }
}
```

### Step 2: 修改服务注入点

只需修改 `EntryAbility.ets` 中的 `initServices()` 方法：

```typescript
// 替换前
const pointsService = new VirtualPointsService(this.dataRepository);

// 替换后
import { WeChatPayPointsService } from '../service/points/WeChatPayPointsService';
const pointsService = new WeChatPayPointsService(this.dataRepository);
```

同时修改 `Index.ets` 中的类型引用（如有需要）。

### Step 3: 添加支付相关配置

在 `module.json5` 中添加支付所需权限和配置。

## 4. 无需修改的部分

通过接口解耦，以下模块在替换支付实现时**无需任何修改**：

- **UI 层** (`pages/Index.ets`) - 仅调用 getBalance/getTotalReturned
- **睡眠监测** (`SleepMonitorService`) - 仅调用 returnPoint
- **数据层** (`PreferencesRepository`) - 存储 CycleInfo/DailyRecord
- **设备检测** (`ScreenMonitorService`, `SensorMonitorService`) - 无关
- **通知服务** (`NotificationService`) - 无关
- **所有接口定义** - 不变

## 5. 设计原则

1. **业务语义抽象**：接口方法使用 `investPoints`、`returnPoint` 等业务术语，而非 `pay`、`transfer` 等支付术语
2. **依赖倒置**：上层依赖接口，不依赖具体实现
3. **单一职责**：支付逻辑完全封装在 IPointsService 实现类中
4. **开闭原则**：对扩展开放（新增实现类），对修改关闭（不改已有代码）

## 6. 测试建议

在替换实现前：
1. 确保新实现类通过了所有 IPointsService 接口方法的单元测试
2. 使用模拟支付环境进行集成测试
3. 验证 investPoints 失败时的回滚逻辑
4. 验证 returnPoint 的幂等性（同一日期不重复返还）
