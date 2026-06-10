/**
 * AI 聊天服务接口
 */

export interface ChatMessage {
  role: string;    // 'system' | 'user' | 'assistant'
  content: string;
}

export interface IAiChatService {
  /** 获取一条关于熬夜的健康小贴士 */
  fetchHealthTip(): Promise<string>;

  /** 发送对话消息，返回 AI 回复完整文本 */
  chat(messages: ChatMessage[]): Promise<string>;

  /** 流式打印：获取完整回复后逐字输出，onTick 每次回调当前完整文本 */
  chatStream(messages: ChatMessage[], onTick: (partial: string) => void): Promise<string>;
}
