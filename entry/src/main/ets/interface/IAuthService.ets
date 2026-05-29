/**
 * 认证服务接口
 */
import { User } from '../model/User';

export interface IAuthService {
  /** 注册新用户，返回是否成功 */
  register(username: string, password: string): Promise<boolean>;

  /** 登录，返回是否成功 */
  login(username: string, password: string): Promise<boolean>;

  /** 登出 */
  logout(): Promise<void>;

  /** 当前是否已登录 */
  isLoggedIn(): boolean;

  /** 获取当前登录用户 */
  getCurrentUser(): User | null;

  /** 是否记住了密码 */
  isRememberPassword(): boolean;

  /** 是否开启了自动登录 */
  isAutoLogin(): boolean;

  /** 设置记住密码 */
  setRememberPassword(remember: boolean): Promise<void>;

  /** 设置自动登录 */
  setAutoLogin(auto: boolean): Promise<void>;

  /** 获取记住的用户名 */
  getSavedUsername(): string;

  /** 获取记住的密码哈希 */
  getSavedPasswordHash(): string;

  /** 检查自动登录并尝试自动登录 */
  tryAutoLogin(): Promise<boolean>;
}
