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

  /** 是否记住了账号 */
  isRememberAccount(): boolean;

  /** 是否开启了自动登录 */
  isAutoLogin(): boolean;

  /** 设置记住账号 */
  setRememberAccount(remember: boolean): Promise<void>;

  /** 设置自动登录 */
  setAutoLogin(auto: boolean): Promise<void>;

  /** 获取记住的用户名 */
  getSavedUsername(): string;

  /** 保存记住的用户名 */
  saveUsername(username: string): Promise<void>;

  /** 检查自动登录并尝试自动登录 */
  tryAutoLogin(): Promise<boolean>;

  /** 修改用户名 */
  updateUsername(newUsername: string): Promise<boolean>;

  /** 修改密码 */
  updatePassword(oldPassword: string, newPassword: string): Promise<boolean>;

  /** 修改头像路径 */
  updateAvatar(avatarPath: string): Promise<boolean>;
}
