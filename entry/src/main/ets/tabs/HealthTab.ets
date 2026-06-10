/**
 * 健康 Tab - AI 健康小助手对话页
 * 健康贴士在登录时预加载，对话先直调后逐步加流式
 */
import { ChatMessage } from '../interface/IAiChatService';
import { SiliconFlowService } from '../service/ai/SiliconFlowService';
import { AppColors, ColorPalette } from '../common/AppColors';
import { logError } from '../common/Logger';

@Component
export struct HealthTab {
  @StorageLink('isDarkMode') isDarkMode: boolean = false;
  @StorageLink('healthTip') healthTip: string = '';
  @State messages: ChatMessage[] = [];
  @State inputText: string = '';
  @State isLoading: boolean = false;
  @State replyText: string = '';

  private aiService: SiliconFlowService = new SiliconFlowService();
  private scroller: Scroller = new Scroller();
  private msgCounter: number = 0;

  aboutToAppear(): void {
    if (!this.healthTip) {
      this.loadHealthTip();
    }
  }

  private colors(): ColorPalette {
    return AppColors.current(this.isDarkMode);
  }

  build() {
    Column() {
      // 标题栏
      Column() {
        Text('健康助手')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.colors().textPrimary)
          .width('100%')
        Text('AI 睡眠健康顾问')
          .fontSize(12)
          .fontColor(this.colors().textSecondary)
          .margin({ top: 4 })
          .width('100%')
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 16, bottom: 12 })
      .alignItems(HorizontalAlign.Start)

      // 消息列表
      Scroll(this.scroller) {
        Column({ space: 12 }) {
          // 健康小贴士卡片
          if (this.healthTip) {
            Row() {
              Text('\uD83C\uDF19')
                .fontSize(20)
                .margin({ right: 10 })
              Text(this.healthTip)
                .fontSize(14)
                .fontColor(this.colors().textPrimary)
                .layoutWeight(1)
                .lineHeight(22)
            }
            .width('100%')
            .padding(16)
            .backgroundColor(this.colors().glassBg)
            .borderRadius(20)
            .border({ width: 1, color: this.colors().glassBorder })
            .backdropBlur(this.colors().glassBlur)
            .alignItems(VerticalAlign.Top)
          } else {
            Row() {
              Text('\uD83C\uDF19')
                .fontSize(20)
                .margin({ right: 10 })
              Text('正在获取今日健康贴士...')
                .fontSize(14)
                .fontColor(this.colors().textSecondary)
            }
            .width('100%')
            .padding(16)
            .backgroundColor(this.colors().glassBg)
            .borderRadius(20)
            .border({ width: 1, color: this.colors().glassBorder })
            .backdropBlur(this.colors().glassBlur)
          }

          // 已完成的历史消息（内联渲染，不经过 @Builder 传参）
          ForEach(this.messages, (msg: ChatMessage) => {
            if (msg.role === 'user') {
              Row() {
                Blank()
                Text(msg.content)
                  .fontSize(15)
                  .fontColor('#FFFFFF')
                  .padding(12)
                  .backgroundColor(this.colors().primary)
                  .borderRadius({ topLeft: 16, topRight: 4, bottomLeft: 16, bottomRight: 16 })
                  .constraintSize({ maxWidth: '78%' })
              }
              .width('100%')
            } else {
              Row() {
                Text(msg.content)
                  .fontSize(15)
                  .fontColor(this.colors().textPrimary)
                  .padding(12)
                  .backgroundColor(this.colors().glassBg)
                  .borderRadius({ topLeft: 4, topRight: 16, bottomLeft: 16, bottomRight: 16 })
                  .border({ width: 1, color: this.colors().glassBorder })
                  .constraintSize({ maxWidth: '78%' })
                  .lineHeight(22)
                Blank()
              }
              .width('100%')
            }
          }, (msg: ChatMessage, index: number) => `msg_${this.msgCounter}_${index}`)

          // 正在回复的实时文本（放在历史消息之后，紧随用户消息下方）
          if (this.replyText.length > 0) {
            Row() {
              Text(this.replyText)
                .fontSize(15)
                .fontColor(this.colors().textPrimary)
                .padding(12)
                .backgroundColor(this.colors().glassBg)
                .borderRadius({ topLeft: 4, topRight: 16, bottomLeft: 16, bottomRight: 16 })
                .border({ width: 1, color: this.colors().glassBorder })
                .constraintSize({ maxWidth: '78%' })
                .lineHeight(22)
              Blank()
            }
            .width('100%')
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 12 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
      .edgeEffect(EdgeEffect.Spring)

      // 输入区域
      Row({ space: 10 }) {
        TextInput({ placeholder: '问问我关于睡眠健康的问题...', text: this.inputText })
          .layoutWeight(1)
          .height(40)
          .fontSize(15)
          .borderRadius(20)
          .backgroundColor(this.colors().inputBg)
          .onChange((value: string) => { this.inputText = value; })
          .enabled(!this.isLoading)
          .onSubmit(() => { this.sendMessage(); })

        Button() {
          Text('\u27A4')
            .fontSize(18)
            .fontColor(Color.White)
        }
        .width(40)
        .height(40)
        .borderRadius(20)
        .backgroundColor(this.isLoading ? this.colors().textSecondary : this.colors().primary)
        .enabled(!this.isLoading && this.inputText.trim().length > 0)
        .onClick(() => { this.sendMessage(); })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      .backgroundColor(this.colors().cardBg)
      .border({ width: { top: 1 }, color: this.colors().glassBorder })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.colors().background)
  }

  private async loadHealthTip(): Promise<void> {
    try {
      const tip = await this.aiService.fetchHealthTip();
      this.healthTip = tip;
    } catch (err) {
      logError('Load health tip failed: %{public}s', (err as Error).message ?? '');
      this.healthTip = '早睡早起，精神百倍。保持规律的作息是健康睡眠的第一步。';
    }
  }

  private sendMessage(): void {
    const text = this.inputText.trim();
    if (text.length === 0 || this.isLoading) {
      return;
    }

    // 用户消息直接加入历史
    this.msgCounter++;
    const userMsg: ChatMessage = { role: 'user', content: text };
    this.messages = [...this.messages, userMsg];
    this.inputText = '';
    this.replyText = '…';
    this.isLoading = true;
    this.scrollToBottom();

    this.requestReply(text);
  }

  private async requestReply(userText: string): Promise<void> {
    try {
      const chatMessages: ChatMessage[] = [
        {
          role: 'system',
          content: '你是"好梦"App的AI健康助手，专注于睡眠健康和熬夜相关话题。' +
            '请用简洁、温暖的语气回答，每次回复控制在200字以内。' +
            '给出实用的建议，但提醒用户严重问题应咨询医生。' +
            '回复中不要使用 Markdown 格式，用纯文本即可。'
        }
      ];
      // 携带历史对话
      for (let i = 0; i < this.messages.length; i++) {
        chatMessages.push(this.messages[i]);
      }

      // 流式逐字打印：通过 @State replyText 直接驱动渲染
      await this.aiService.chatStream(chatMessages, (partial: string) => {
        this.replyText = partial;
        this.scrollToBottom();
      });

      // 流式结束后，将完整回复存入历史
      this.msgCounter++;
      const aiMsg: ChatMessage = { role: 'assistant', content: this.replyText };
      this.messages = [...this.messages, aiMsg];
      this.replyText = '';
    } catch (err) {
      logError('AI reply failed: %{public}s', (err as Error).message ?? '');
      this.msgCounter++;
      const aiMsg: ChatMessage = { role: 'assistant', content: '抱歉，回复失败了，请稍后重试。' };
      this.messages = [...this.messages, aiMsg];
      this.replyText = '';
    }
    this.isLoading = false;
    this.scrollToBottom();
  }

  private scrollToBottom(): void {
    setTimeout(() => {
      this.scroller.scrollEdge(Edge.Bottom);
    }, 50);
  }
}
