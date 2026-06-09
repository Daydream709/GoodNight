/**
 * 注册页面
 * 接入 AppColors 主题体系，支持深浅色模式，与登录页/主功能区视觉统一
 */
import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { DatabaseRepository } from '../service/data/DatabaseRepository';
import { AuthService } from '../service/auth/AuthService';
import { AppColors, ColorPalette } from '../common/AppColors';
import { EVENT_LOGIN_SUCCESS } from '../common/Constants';
import { logError } from '../common/Logger';

@Entry
@Component
struct RegisterPage {
  @StorageLink('isDarkMode') isDarkMode: boolean = false;
  @State username: string = '';
  @State password: string = '';
  @State confirmPassword: string = '';
  @State isLoading: boolean = false;
  @State errorMsg: string = '';

  private dbRepo: DatabaseRepository = new DatabaseRepository();
  private authService: AuthService | null = null;

  async aboutToAppear(): Promise<void> {
    // 复用已初始化的 dbRepo（从 AppStorage 获取），或新建
    const existingRepo = AppStorage.get<DatabaseRepository>('dbRepo');
    if (existingRepo) {
      this.dbRepo = existingRepo;
    } else {
      const context = this.getUIContext().getHostContext() as Context;
      await this.dbRepo.init(context);
    }
    this.authService = new AuthService(this.dbRepo);
    await this.authService.loadConfigCache();
  }

  private colors(): ColorPalette {
    return AppColors.current(this.isDarkMode);
  }

  build() {
    Column() {
      // 返回按钮
      Row() {
        Text('‹ 返回登录')
          .fontSize(14)
          .fontColor(this.colors().primary)
          .padding({ top: 6, bottom: 6, right: 12 })
          .onClick(() => {
            router.back();
          })
      }
      .width('86%')
      .margin({ top: 16 })
      .justifyContent(FlexAlign.Start)

      // 标题
      Text('注册账号')
        .fontSize(30)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.colors().textPrimary)
        .margin({ top: 48, bottom: 40 })

      // 表单卡片 - 液态玻璃
      Column({ space: 16 }) {
        TextInput({ placeholder: '用户名（至少 2 个字符）', text: this.username })
          .height(48)
          .fontSize(16)
          .fontColor(this.colors().textPrimary)
          .borderRadius(12)
          .backgroundColor(this.colors().glassInputBg)
          .maxLength(20)
          .onChange((value: string) => {
            this.username = value;
            this.errorMsg = '';
          })

        TextInput({ placeholder: '密码（至少 4 个字符）', text: this.password })
          .height(48)
          .fontSize(16)
          .fontColor(this.colors().textPrimary)
          .borderRadius(12)
          .backgroundColor(this.colors().glassInputBg)
          .type(InputType.Password)
          .showPasswordIcon(true)
          .maxLength(32)
          .onChange((value: string) => {
            this.password = value;
            this.errorMsg = '';
          })

        TextInput({ placeholder: '确认密码', text: this.confirmPassword })
          .height(48)
          .fontSize(16)
          .fontColor(this.colors().textPrimary)
          .borderRadius(12)
          .backgroundColor(this.colors().glassInputBg)
          .type(InputType.Password)
          .showPasswordIcon(true)
          .maxLength(32)
          .onChange((value: string) => {
            this.confirmPassword = value;
            this.errorMsg = '';
          })

        // 实时校验提示
        if (this.confirmPassword.length > 0 && this.password !== this.confirmPassword) {
          Text('两次密码不一致')
            .fontSize(12)
            .fontColor(this.colors().danger)
            .width('100%')
        } else if (this.errorMsg) {
          Text(this.errorMsg)
            .fontSize(13)
            .fontColor(this.colors().danger)
        }

        Button() {
          if (this.isLoading) {
            Row({ space: 8 }) {
              LoadingProgress().width(22).height(22).color(Color.White)
              Text('注册中…').fontSize(18).fontColor(Color.White)
            }
          } else {
            Text('注册').fontSize(18).fontColor(Color.White)
          }
        }
        .width('100%')
        .height(48)
        .backgroundColor(this.colors().primary)
        .borderRadius(12)
        .enabled(!this.isLoading && this.username.trim().length >= 2 &&
          this.password.length >= 4 && this.confirmPassword.length > 0)
        .onClick(() => {
          this.handleRegister();
        })
      }
      .width('86%')
      .padding(24)
      .backgroundColor(this.colors().glassBg)
      .borderRadius(20)
      .border({ width: 1, color: this.colors().glassBorder })
      .backdropBlur(this.colors().glassBlur)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.colors().background)
    .alignItems(HorizontalAlign.Center)
  }

  private async handleRegister(): Promise<void> {
    if (!this.authService) {
      this.errorMsg = '服务未就绪';
      return;
    }

    if (this.password !== this.confirmPassword) {
      this.errorMsg = '两次密码输入不一致';
      return;
    }

    // 与 AuthService 的 trim 校验保持一致，确保随后自动登录用同一份用户名匹配
    const name = this.username.trim();
    if (name.length < 2) {
      this.errorMsg = '用户名至少 2 个字符';
      return;
    }

    this.isLoading = true;
    this.errorMsg = '';

    try {
      const success = await this.authService.register(name, this.password);
      if (success) {
        // 注册成功，自动登录
        await this.authService.login(name, this.password);

        // 存入 AppStorage 并跳转主页
        AppStorage.setOrCreate('dbRepo', this.dbRepo);
        AppStorage.setOrCreate('authService', this.authService);

        // 通知 EntryAbility 构建监测服务链
        const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
        ctx.eventHub.emit(EVENT_LOGIN_SUCCESS);

        router.replaceUrl({ url: 'pages/Index' });
      } else {
        this.errorMsg = '注册失败，用户名可能已存在';
      }
    } catch (err) {
      this.errorMsg = '注册失败，请重试';
      logError('Register failed: %{public}s', (err as Error).message ?? '');
    }
    this.isLoading = false;
  }
}
