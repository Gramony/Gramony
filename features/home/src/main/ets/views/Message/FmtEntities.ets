import {
  MessageEntityType
} from 'libhomogrape.so';
import { BusinessError, pasteboard } from '@kit.BasicServicesKit';
import { promptAction, LengthMetrics } from '@kit.ArkUI';
import { Logger } from '@ohos/base';
import { MessageEntity } from '../../entities/Message';

/**
 * 根据实体类型应用对应的样式
 * @param text 原始文本内容
  * @param styledString |inout| 可变样式字符串
 * @throws BusinessError
 */
export function applyEntityStyle(text: string, styledString: MutableStyledString, entity: MessageEntity): void {
  const start = entity.offset;
  const length = entity.length;

  // 确保范围有效
  if (start < 0 || start >= text.length || length <= 0) {
    return;
  }

  const actualLength = Math.min(length, text.length - start);

  switch (entity.entityType) {
    case MessageEntityType.Bold:
      styledString.setStyle({
        start: start,
        length: actualLength,
        styledKey: StyledStringKey.FONT,
        styledValue: new TextStyle({ fontWeight: FontWeight.Bold })
      });
      break;

    case MessageEntityType.Italic:
      styledString.setStyle({
        start: start,
        length: actualLength,
        styledKey: StyledStringKey.FONT,
        styledValue: new TextStyle({ fontStyle: FontStyle.Italic })
      });
      break;

    case MessageEntityType.Underline:
      styledString.setStyle({
        start: start,
        length: actualLength,
        styledKey: StyledStringKey.DECORATION,
        styledValue: new DecorationStyle({ type: TextDecorationType.Underline, color: $r('app.color.message_decoration_color') })
      });
      break;

    case MessageEntityType.Strike:
      styledString.setStyle({
        start: start,
        length: actualLength,
        styledKey: StyledStringKey.DECORATION,
        styledValue: new DecorationStyle({ type: TextDecorationType.LineThrough, color: $r('app.color.message_decoration_color') })
      });
      break;

    case MessageEntityType.Code:
      styledString.setStyle({
        start: start,
        length: actualLength,
        styledKey: StyledStringKey.FONT,
        styledValue: new TextStyle({ fontFamily: 'monospace' })
      });
      styledString.setStyle({
        start: start,
        length: actualLength,
        styledKey: StyledStringKey.BACKGROUND_COLOR,
        styledValue: new BackgroundColorStyle({ color: $r('app.color.message_code_background_color'), radius: 4 })
      });
      styledString.setStyle({
        start: start,
        length: actualLength,
        styledKey: StyledStringKey.GESTURE,
        styledValue: new GestureStyle({
          onLongPress: () => {
            // 复制代码片段到剪贴板
            const codeText = text.substring(start, start + actualLength);
            const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, codeText);
            const systemPasteboard = pasteboard.getSystemPasteboard();
            systemPasteboard.setData(pasteData).then(() => {
              promptAction.showToast({
                message: $r('app.string.message_code_copied'),
                duration: 2000
              });
            }).catch((err: BusinessError) => {
              Logger.error(`Failed to copy code to clipboard: ${err.message}`);
            });
          }
        })
      });
      break;

    case MessageEntityType.Pre:
      styledString.setStyle({
        start: start,
        length: actualLength,
        styledKey: StyledStringKey.FONT,
        styledValue: new TextStyle({ fontFamily: 'monospace' })
      });
      styledString.setStyle({
        start: start,
        length: actualLength,
        styledKey: StyledStringKey.BACKGROUND_COLOR,
        styledValue: new BackgroundColorStyle({ color: $r('app.color.message_pre_background_color'), radius: 4 })
      });
      break;

    case MessageEntityType.TextUrl:
      // 超链接样式：蓝色 + 下划线
      // 优先使用 entity.url，否则尝试从文本片段识别 URL
      const textUrlRawText = text.substring(start, start + actualLength);
      const textUrlLink = entity.url ?? (isLikelyUrl(textUrlRawText.trim()) ? normalizeUrl(textUrlRawText.trim()) : undefined);

      styledString.setStyle({
        start: start,
        length: actualLength,
        styledKey: StyledStringKey.FONT,
        styledValue: new TextStyle({ fontColor: $r('app.color.message_link_color') })
      });
      styledString.setStyle({
        start: start,
        length: actualLength,
        styledKey: StyledStringKey.DECORATION,
        styledValue: new DecorationStyle({ type: TextDecorationType.Underline, color: $r('app.color.message_link_color') })
      });
      if (textUrlLink) {
        styledString.setStyle({
          start: start,
          length: actualLength,
          styledKey: StyledStringKey.URL,
          styledValue: new UrlStyle(textUrlLink)
        });
      }
      break;

    case MessageEntityType.Url:
    case MessageEntityType.Email:
      // URL 和邮箱样式：蓝色
      styledString.setStyle({
        start: start,
        length: actualLength,
        styledKey: StyledStringKey.FONT,
        styledValue: new TextStyle({ fontColor: $r('app.color.message_link_color') })
      });
      break;

    case MessageEntityType.Mention:
    case MessageEntityType.MentionName:
      // @ 提及样式：蓝色
      styledString.setStyle({
        start: start,
        length: actualLength,
        styledKey: StyledStringKey.FONT,
        styledValue: new TextStyle({ fontColor: $r('app.color.message_link_color'), fontWeight: FontWeight.Medium })
      });
      break;

    case MessageEntityType.Hashtag:
    case MessageEntityType.Cashtag:
      // 标签样式：蓝色
      styledString.setStyle({
        start: start,
        length: actualLength,
        styledKey: StyledStringKey.FONT,
        styledValue: new TextStyle({ fontColor: $r('app.color.message_link_color') })
      });
      break;

    case MessageEntityType.BotCommand:
      // Bot 命令样式：蓝色
      styledString.setStyle({
        start: start,
        length: actualLength,
        styledKey: StyledStringKey.FONT,
        styledValue: new TextStyle({ fontColor: $r('app.color.message_link_color') })
      });
      break;

    case MessageEntityType.Spoiler:
      // 剧透样式：灰色背景（模糊效果需要特殊处理）
      styledString.setStyle({
        start: start,
        length: actualLength,
        styledKey: StyledStringKey.BACKGROUND_COLOR,
        styledValue: new BackgroundColorStyle({ color: $r('app.color.message_spoiler_color'), radius: 4 })
      });
      styledString.setStyle({
        start: start,
        length: actualLength,
        styledKey: StyledStringKey.FONT,
        styledValue: new TextStyle({ fontColor: $r('app.color.message_spoiler_color') })
      });
      break;

    case MessageEntityType.Blockquote:
      // 引用块样式：灰色背景 + 左边距
      styledString.setStyle({
        start: start,
        length: actualLength,
        styledKey: StyledStringKey.BACKGROUND_COLOR,
        styledValue: new BackgroundColorStyle({ color: $r('app.color.message_blockquote_background_color'), radius: 4 })
      });
      styledString.setStyle({
        start: start,
        length: actualLength,
        styledKey: StyledStringKey.FONT,
        styledValue: new TextStyle({ fontColor: $r('app.color.message_blockquote_text_color') })
      });
      break;

    case MessageEntityType.Phone:
      // 电话号码样式
      styledString.setStyle({
        start: start,
        length: actualLength,
        styledKey: StyledStringKey.FONT,
        styledValue: new TextStyle({ fontColor: $r('app.color.message_link_color') })
      });
      break;

    case MessageEntityType.CustomEmoji:
      // 自定义表情：暂不处理，需要加载表情图片
      break;

    default:
      // 未知类型，不处理
      break;
  }
}

/**
 * 粗略判断文本是否可能为 URL
 */
function isLikelyUrl(text: string): boolean {
  if (!text) return false;
  // 常见前缀或域名结构的简单判断
  const lower = text.toLowerCase();
  if (lower.startsWith('http://') || lower.startsWith('https://')) return true;
  if (lower.startsWith('www.')) return true;
  // 简单的域名匹配，如 example.com 或 sub.domain.io/path
  const domainLike = /^(?:[a-z0-9-]+\.)+[a-z]{2,}(?:[/:?#].*)?$/i;
  return domainLike.test(text);
}

/**
 * 规范化 URL：补全协议等
 */
function normalizeUrl(url: string): string {
  const trimmed = (url || '').trim();
  if (trimmed.length === 0) return url;
  const lower = trimmed.toLowerCase();
  if (lower.startsWith('http://') || lower.startsWith('https://')) {
    return trimmed;
  }
  // 为像 `www.example.com` 或裸域名补全默认协议
  return `https://${trimmed}`;
}
