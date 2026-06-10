/**
 * 硅基流动 AI 聊天服务实现
 * 使用 OpenAI 兼容 API 格式
 */
import { http } from '@kit.NetworkKit';
import { ChatMessage, IAiChatService } from '../../interface/IAiChatService';
import { logInfo, logError } from '../../common/Logger';

const API_URL: string = 'https://api.siliconflow.cn/v1/chat/completions';
const API_KEY: string = 'sk-ibzatiftywifwbsoxjoyzendavsepqgrnlvxaxfgwjmlexpg';
const MODEL: string = 'deepseek-ai/DeepSeek-V4-Flash';

const SYSTEM_PROMPT: string =
  '你是"好梦"App的AI健康助手，专注于睡眠健康和熬夜相关话题。' +
  '请用简洁、温暖的语气回答，每次回复控制在200字以内。' +
  '给出实用的建议，但提醒用户严重问题应咨询医生。' +
  '回复中不要使用 Markdown 格式，用纯文本即可。';

export class SiliconFlowService implements IAiChatService {

  async fetchHealthTip(): Promise<string> {
    const messages: ChatMessage[] = [
      { role: 'system', content: SYSTEM_PROMPT },
      { role: 'user', content: '请给我一条关于熬夜的健康小贴士，要实用有趣，一两句话即可。' }
    ];
    return this.chat(messages);
  }

  async chat(messages: ChatMessage[]): Promise<string> {
    try {
      const httpRequest = http.createHttp();

      const body: Record<string, Object> = {
        'model': MODEL,
        'messages': this.messagesToRecords(messages),
        'temperature': 0.3,
        'max_tokens': 1024,
        'stream': false
      };

      const response = await httpRequest.request(API_URL, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ' + API_KEY
        },
        extraData: JSON.stringify(body)
      });

      httpRequest.destroy();

      if (response.responseCode === 200) {
        const result = JSON.parse(response.result as string) as Record<string, Object>;
        const choices = result['choices'] as Array<Record<string, Object>>;
        if (choices && choices.length > 0) {
          const message = choices[0]['message'] as Record<string, Object>;
          return (message['content'] as string) ?? '抱歉，我暂时无法回答。';
        }
      }

      logError('SiliconFlow API error: %{public}s', response.responseCode.toString());
      return '网络请求失败，请稍后重试。';
    } catch (err) {
      logError('SiliconFlow request failed: %{public}s', (err as Error).message ?? '');
      return '网络连接异常，请检查网络设置。';
    }
  }

  async chatStream(messages: ChatMessage[], onTick: (partial: string) => void): Promise<string> {
    // 先获取完整回复
    const fullText = await this.chat(messages);

    // 逐字输出，模拟打字效果
    for (let i = 1; i <= fullText.length; i++) {
      const partial = fullText.substring(0, i);
      onTick(partial);
      // 每个字符间隔 25ms，约每秒 40 字
      await this.delay(25);
    }

    return fullText;
  }

  private delay(ms: number): Promise<void> {
    return new Promise<void>((resolve: Function) => {
      setTimeout(() => { resolve(); }, ms);
    });
  }

  private messagesToRecords(messages: ChatMessage[]): Array<Record<string, string>> {
    const result: Array<Record<string, string>> = [];
    for (let i = 0; i < messages.length; i++) {
      const record: Record<string, string> = {
        'role': messages[i].role,
        'content': messages[i].content
      };
      result.push(record);
    }
    return result;
  }
}
