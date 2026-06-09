/**
 * 密码哈希工具
 * 注意：这是非加密级别的简单哈希，仅适合本地 demo。
 * 接入真实账号体系时应替换为带盐的安全哈希（如 bcrypt/PBKDF2）。
 * 此前 AuthService 与 TestDataGenerator 各有一份相同实现，现集中于此。
 */
export function hashPassword(password: string): string {
  let hash: number = 0;
  for (let i = 0; i < password.length; i++) {
    const ch = password.charCodeAt(i);
    hash = ((hash << 5) - hash) + ch;
    hash = hash & hash; // 转为 32 位整数
  }
  return 'h_' + Math.abs(hash).toString(36);
}
