import { HashMap } from '@kit.ArkTS';
import { BaseConstants, Logger } from '@ohos/base';
import { downloadMediaFromMessage, MediaType, loadHistoryMessages, NativeMessage } from 'libhomogrape.so';
import { MessageDataSource } from '../../viewmodel/Message/MessageDataSource';
import { fileIo as fs, ReadOptions } from '@kit.CoreFileKit';
import { HomeConstants } from '../../constants/HomeConstants';
import { Message } from '../../entities/Message';

@Component
export struct ReplyToPreview {
  @Prop replyToMessageId: number;
  @Consume currentChatId: string;
  @Consume messagesOfChatMap: HashMap<string, MessageDataSource>;
  @State mediaPath: string = "";
  @State isLoadingMessage: boolean = false;
  @State loadFailed: boolean = false;
  @State message: Message | undefined = this.messagesOfChatMap.get(this.currentChatId)?.getMessageById(this.replyToMessageId);

  build() {
    Row() {
      Blank()
        .color(HomeConstants.MESSAGE_REPLY_TO_PREVIEW_DIVIDER_COLOR)
        .width(HomeConstants.MESSAGE_REPLY_TO_PREVIEW_DIVIDER_WIDTH)
        .margin({ left: -2, right: 4, })
      if (this.isLoadingMessage) {
        LoadingProgress()
          .width(20)
          .height(20)
          .margin({ right: 4 })
      } else if (this.loadFailed) {
        Text($r('app.string.load_failed'))
          .fontSize(BaseConstants.FONT_SIZE_FOURTEEN)
          .fontColor($r('sys.color.ohos_id_color_warning'))
          .margin({ right: 4 })
      } else if (this.message?.mediaType === MediaType.Photo) {
        Image("file://" + this.mediaPath)
          .width(30)
          .height(30)
          .objectFit(ImageFit.Auto)
          .borderRadius(4)
          .margin({ right: 4, })
          .onAppear(() => {
            this.mediaPath =
              BaseConstants.BASE_DIR + this.message?.chatId.toString() + "/" + this.message?.messageId.toString() +
                ".jpg";
            if (!fs.accessSync(this.mediaPath)) {
              Logger.debug("ReplyToPreview ImagePreview onAppear: media not exists, downloading media");
              downloadMediaFromMessage(this.message?.chatId, this.message?.messageId)
                .then((path) => {
                  Logger.debug("ReplyToPreview ImagePreview onAppear: media downloaded: " + path);
                  this.mediaPath = path;
                })
                .catch((error: Error) => {
                  Logger.debug("ReplyToPreview ImagePreview onAppear Failed to download media: " + error.message);
                });
            } else {
              Logger.debug("ReplyToPreview ImagePreview onAppear: media exists");
            }
          })
      }
      Column() {
        if (this.message) {
          Text(this.message.senderName)
            .fontSize(BaseConstants.FONT_SIZE_FOURTEEN)
            .fontWeight(FontWeight.Bold)
            .fontColor(HomeConstants.MESSAGE_REPLY_TO_PREVIEW_DIVIDER_COLOR)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.message.text === "" ? $r('app.string.photo') : this.message.text)
            .fontSize(BaseConstants.FONT_SIZE_SIXTEEN)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        } else if (this.isLoadingMessage) {
        } else if (this.loadFailed) {
          Text($r('app.string.reply_message_load_failed'))
            .fontSize(BaseConstants.FONT_SIZE_FOURTEEN)
            .fontColor($r('sys.color.ohos_id_color_warning'))
        } else {
          Text($r('app.string.message_not_found'))
            .fontSize(BaseConstants.FONT_SIZE_FOURTEEN)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        }
      }
      .alignItems(HorizontalAlign.Start)
    }
    .alignItems(VerticalAlign.Center)
    .padding(8)
    .backgroundColor(HomeConstants.MESSAGE_REPLY_TO_PREVIEW_BACKGROUND_COLOR)
    .borderRadius(8)
    .width("90%")
    .onAppear(() => {
      this.checkAndLoadMessage();
    })
  }

  /**
   * 检查消息是否存在，如果不存在则加载历史消息
   */
  private async checkAndLoadMessage(): Promise<void> {
    // 重新获取消息，因为可能在组件创建后数据已更新
    this.message = this.messagesOfChatMap.get(this.currentChatId)?.getMessageById(this.replyToMessageId);
    
    if (this.message) {
      Logger.debug(`ReplyToPreview: message ${this.replyToMessageId} already exists`);
      return;
    }

    if (this.isLoadingMessage) {
      Logger.debug(`ReplyToPreview: already loading message ${this.replyToMessageId}`);
      return;
    }

    Logger.warn(`ReplyToPreview: message ${this.replyToMessageId} not found, loading history messages`);
    this.isLoadingMessage = true;
    this.loadFailed = false;

    try {
      const chatId = parseInt(this.currentChatId);
      
      // 加载包含被回复消息的历史记录
      // 从 replyToMessageId 往前加载 50 条消息
      const historyMessages: NativeMessage[] = await loadHistoryMessages(
        chatId,
        this.replyToMessageId + 50, // 从被回复消息之后的位置开始加载
        50
      );

      if (historyMessages.length > 0) {
        Logger.debug(`ReplyToPreview: loaded ${historyMessages.length} history messages`);
        
        // 将消息添加到数据源
        const messageDataSource = this.messagesOfChatMap.get(this.currentChatId);
        if (messageDataSource) {
          const messages = historyMessages.map(nativeMsg => Message.fromNative(nativeMsg));
          messageDataSource.append(messages);
          
          // 重新获取被回复的消息
          this.message = messageDataSource.getMessageById(this.replyToMessageId);
          
          if (this.message) {
            Logger.debug(`ReplyToPreview: successfully loaded reply-to message ${this.replyToMessageId}`);
          } else {
            Logger.warn(`ReplyToPreview: reply-to message ${this.replyToMessageId} still not found after loading history`);
            this.loadFailed = true;
          }
        }
      } else {
        Logger.warn(`ReplyToPreview: no history messages loaded for replyToMessageId ${this.replyToMessageId}`);
        this.loadFailed = true;
      }
    } catch (error) {
      Logger.error(`ReplyToPreview: failed to load history messages: ${(error as Error).message}`);
      this.loadFailed = true;
    } finally {
      this.isLoadingMessage = false;
    }
  }
}
