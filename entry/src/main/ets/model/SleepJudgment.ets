/**
 * 睡眠判定结果枚举
 */
export enum SleepJudgment {
  /** 尚未判定（监测中或未开始） */
  NOT_YET_EVALUATED = 0,
  /** 达标 - 未熬夜，返还点数 */
  COMPLIANT = 1,
  /** 未达标 - 检测到熬夜，不返还点数 */
  NON_COMPLIANT = 2
}
