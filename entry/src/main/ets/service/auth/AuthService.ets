/**
 * 认证服务实现
 * 使用 SQLite 存储，通过 DatabaseRepository 共享 RdbStore
 */
import { relationalStore } from '@kit.ArkData';
import { IAuthService } from '../../interface/IAuthService';
import { User } from '../../model/User';
import { DatabaseRepository } from '../data/DatabaseRepository';
import {
  TABLE_USERS, TABLE_APP_CONFIG,
  CONFIG_KEY_REMEMBER_ACCOUNT, CONFIG_KEY_AUTO_LOGIN,
  CONFIG_KEY_SAVED_USERNAME, CONFIG_KEY_CURRENT_USER_ID
} from '../../common/Constants';
import { hashPassword } from '../../common/PasswordHasher';
import { logInfo, logError } from '../../common/Logger';

export class AuthService implements IAuthService {
  private dbRepo: DatabaseRepository;
  private currentUser: User | null = null;

  constructor(dbRepo: DatabaseRepository) {
    this.dbRepo = dbRepo;
  }

  async register(username: string, password: string): Promise<boolean> {
    const store = this.dbRepo.getStore();
    if (!store) {
      logError('Database not initialized');
      return false;
    }

    const name = username.trim();
    if (name.length < 2 || password.length < 4) {
      logError('Username must be >= 2 chars, password >= 4 chars');
      return false;
    }

    try {
      const hash = hashPassword(password);
      const values: Record<string, relationalStore.ValueType> = {
        'username': name,
        'password_hash': hash,
        'created_at': Date.now()
      };
      const rowId = await store.insert(TABLE_USERS, values);
      if (rowId > 0) {
        logInfo('User registered: %{public}s', username);
        return true;
      }
      return false;
    } catch (err) {
      logError('Register failed (username may exist): %{public}s', (err as Error).message ?? '');
      return false;
    }
  }

  async login(username: string, password: string): Promise<boolean> {
    const store = this.dbRepo.getStore();
    if (!store) {
      return false;
    }

    try {
      const hash = hashPassword(password);
      const predicates = new relationalStore.RdbPredicates(TABLE_USERS);
      predicates.equalTo('username', username);
      predicates.equalTo('password_hash', hash);
      const resultSet = await store.query(predicates);

      if (resultSet.goToFirstRow()) {
        const user = new User();
        user.id = resultSet.getLong(resultSet.getColumnIndex('id'));
        user.username = resultSet.getString(resultSet.getColumnIndex('username'));
        user.passwordHash = resultSet.getString(resultSet.getColumnIndex('password_hash'));
        user.createdAt = resultSet.getLong(resultSet.getColumnIndex('created_at'));
        // 读取头像路径（兼容旧表没有该列的情况）
        try {
          user.avatarPath = resultSet.getString(resultSet.getColumnIndex('avatar_path'));
        } catch (e) {
          user.avatarPath = '';
        }
        resultSet.close();

        this.currentUser = user;
        this.dbRepo.setCurrentUserId(user.id);

        // 保存当前登录用户
        await this.saveConfig(CONFIG_KEY_CURRENT_USER_ID, String(user.id));

        logInfo('User logged in: %{public}s', username);
        return true;
      }
      resultSet.close();
      logError('Login failed: invalid credentials');
      return false;
    } catch (err) {
      logError('Login error: %{public}s', (err as Error).message ?? '');
      return false;
    }
  }

  async logout(): Promise<void> {
    this.currentUser = null;
    this.dbRepo.setCurrentUserId(0);
    await this.saveConfig(CONFIG_KEY_CURRENT_USER_ID, '');
    await this.saveConfig(CONFIG_KEY_AUTO_LOGIN, 'false');
    logInfo('User logged out');
  }

  isLoggedIn(): boolean {
    return this.currentUser !== null;
  }

  getCurrentUser(): User | null {
    return this.currentUser;
  }

  isRememberAccount(): boolean {
    return this.getConfig(CONFIG_KEY_REMEMBER_ACCOUNT) === 'true';
  }

  isAutoLogin(): boolean {
    return this.getConfig(CONFIG_KEY_AUTO_LOGIN) === 'true';
  }

  async setRememberAccount(remember: boolean): Promise<void> {
    await this.saveConfig(CONFIG_KEY_REMEMBER_ACCOUNT, remember ? 'true' : 'false');
    if (!remember) {
      await this.saveConfig(CONFIG_KEY_SAVED_USERNAME, '');
      await this.saveConfig(CONFIG_KEY_AUTO_LOGIN, 'false');
    }
  }

  async setAutoLogin(auto: boolean): Promise<void> {
    await this.saveConfig(CONFIG_KEY_AUTO_LOGIN, auto ? 'true' : 'false');
  }

  getSavedUsername(): string {
    return this.getConfig(CONFIG_KEY_SAVED_USERNAME);
  }

  async tryAutoLogin(): Promise<boolean> {
    if (!this.isAutoLogin()) {
      return false;
    }

    const userIdStr = this.getConfig(CONFIG_KEY_CURRENT_USER_ID);
    if (!userIdStr) {
      return false;
    }

    const store = this.dbRepo.getStore();
    if (!store) {
      return false;
    }

    try {
      const userId = Number(userIdStr);
      const predicates = new relationalStore.RdbPredicates(TABLE_USERS);
      predicates.equalTo('id', userId);
      const resultSet = await store.query(predicates);

      if (resultSet.goToFirstRow()) {
        const user = new User();
        user.id = resultSet.getLong(resultSet.getColumnIndex('id'));
        user.username = resultSet.getString(resultSet.getColumnIndex('username'));
        user.passwordHash = resultSet.getString(resultSet.getColumnIndex('password_hash'));
        user.createdAt = resultSet.getLong(resultSet.getColumnIndex('created_at'));
        // 读取头像路径（兼容旧表没有该列的情况）
        try {
          user.avatarPath = resultSet.getString(resultSet.getColumnIndex('avatar_path'));
        } catch (e) {
          user.avatarPath = '';
        }
        resultSet.close();

        this.currentUser = user;
        this.dbRepo.setCurrentUserId(user.id);
        logInfo('Auto-login success: %{public}s', user.username);
        return true;
      }
      resultSet.close();
    } catch (err) {
      logError('Auto-login failed: %{public}s', (err as Error).message ?? '');
    }
    return false;
  }

  /**
   * 保存记住的用户名（记住账号时调用）
   */
  async saveUsername(username: string): Promise<void> {
    await this.saveConfig(CONFIG_KEY_SAVED_USERNAME, username);
  }

  // ========== 用户信息修改 ==========

  async updateUsername(newUsername: string): Promise<boolean> {
    if (!this.currentUser) {
      return false;
    }
    const name = newUsername.trim();
    if (name.length < 2) {
      return false;
    }
    const store = this.dbRepo.getStore();
    if (!store) {
      return false;
    }
    try {
      // 检查用户名是否已被占用
      const predicates = new relationalStore.RdbPredicates(TABLE_USERS);
      predicates.equalTo('username', name);
      predicates.notEqualTo('id', this.currentUser.id);
      const resultSet = await store.query(predicates, ['id']);
      if (resultSet.goToFirstRow()) {
        resultSet.close();
        logError('Username already taken');
        return false;
      }
      resultSet.close();

      const values: Record<string, relationalStore.ValueType> = { 'username': name };
      const updatePred = new relationalStore.RdbPredicates(TABLE_USERS);
      updatePred.equalTo('id', this.currentUser.id);
      await store.update(values, updatePred);
      this.currentUser.username = name;
      logInfo('Username updated to: %{public}s', name);
      return true;
    } catch (err) {
      logError('Update username failed: %{public}s', (err as Error).message ?? '');
      return false;
    }
  }

  async updatePassword(oldPassword: string, newPassword: string): Promise<boolean> {
    if (!this.currentUser) {
      return false;
    }
    const oldHash = hashPassword(oldPassword);
    if (oldHash !== this.currentUser.passwordHash) {
      logError('Old password incorrect');
      return false;
    }
    if (newPassword.length < 4) {
      return false;
    }
    const store = this.dbRepo.getStore();
    if (!store) {
      return false;
    }
    try {
      const newHash = hashPassword(newPassword);
      const values: Record<string, relationalStore.ValueType> = { 'password_hash': newHash };
      const predicates = new relationalStore.RdbPredicates(TABLE_USERS);
      predicates.equalTo('id', this.currentUser.id);
      await store.update(values, predicates);
      this.currentUser.passwordHash = newHash;
      logInfo('Password updated');
      return true;
    } catch (err) {
      logError('Update password failed: %{public}s', (err as Error).message ?? '');
      return false;
    }
  }

  async updateAvatar(avatarPath: string): Promise<boolean> {
    if (!this.currentUser) {
      return false;
    }
    const store = this.dbRepo.getStore();
    if (!store) {
      return false;
    }
    try {
      const values: Record<string, relationalStore.ValueType> = { 'avatar_path': avatarPath };
      const predicates = new relationalStore.RdbPredicates(TABLE_USERS);
      predicates.equalTo('id', this.currentUser.id);
      await store.update(values, predicates);
      this.currentUser.avatarPath = avatarPath;
      logInfo('Avatar updated');
      return true;
    } catch (err) {
      logError('Update avatar failed: %{public}s', (err as Error).message ?? '');
      return false;
    }
  }

  // ========== 内部方法 ==========

  private getConfig(key: string): string {
    // 同步读取 - 使用缓存方式
    // 注意：需要在 init 后使用
    return this.configCache.get(key) ?? '';
  }

  private configCache: Map<string, string> = new Map();
  private configLoaded: boolean = false;

  /**
   * 加载所有配置到缓存
   */
  async loadConfigCache(): Promise<void> {
    const store = this.dbRepo.getStore();
    if (!store) {
      return;
    }
    try {
      const resultSet = await store.querySql('SELECT key, value FROM ' + TABLE_APP_CONFIG);
      this.configCache.clear();
      while (resultSet.goToNextRow()) {
        const key = resultSet.getString(0);
        const value = resultSet.getString(1);
        this.configCache.set(key, value);
      }
      resultSet.close();
      this.configLoaded = true;
    } catch (err) {
      logError('Failed to load config cache: %{public}s', (err as Error).message ?? '');
    }
  }

  private async saveConfig(key: string, value: string): Promise<void> {
    const store = this.dbRepo.getStore();
    if (!store) {
      return;
    }
    try {
      // upsert: 先删后插
      await store.executeSql('DELETE FROM ' + TABLE_APP_CONFIG + ' WHERE key = ?', [key]);
      if (value) {
        const values: Record<string, relationalStore.ValueType> = { 'key': key, 'value': value };
        await store.insert(TABLE_APP_CONFIG, values);
      }
      this.configCache.set(key, value);
    } catch (err) {
      logError('Failed to save config: %{public}s', (err as Error).message ?? '');
    }
  }
}
