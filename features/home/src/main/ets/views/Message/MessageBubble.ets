import { BaseConstants, BreakpointConstants, DateHelper, IntroduceText, Logger, NormalText } from '@ohos/base'
import {
  MediaType,
  downloadMediaFromMessage,
  getProfilePhotoPathAndCount,
  NativeSeenChat,
  downloadProfilePhoto,
  ChatType
} from 'libhomogrape.so';
import { HomeConstants } from '../../constants/HomeConstants';
import { Message } from '../../entities/Message';
import { fileIo as fs } from '@kit.CoreFileKit';
import { HashMap } from '@kit.ArkTS';
import { SeenChat } from '../../entities/SeenChat';
import { getOrDownloadProfilePhoto, getThumbProfilePhotoPixelMap } from '../../utils';
import { ReplyToPreview } from './ReplyToPreview'
import { MessageDataSource } from '../../viewmodel/Message/MessageDataSource';
import { MediaModel, MediaPreview, MediaPreviewOptions, MediaPreviewComponent } from '@lyb/media-preview';
import { BusinessError } from '@kit.BasicServicesKit';
import { filePreview } from '@kit.PreviewKit';
import { promptAction } from '@kit.ArkUI';

enum DefaultMediaType {
  IMAGE,
  VIDEO
}

class DefaultMediaModel extends MediaModel {
  /**
   * 类型
   */
  type: DefaultMediaType = DefaultMediaType.IMAGE
  /**
   * 资源图片
   */
  sourceSrc?: ResourceStr
  /**
   * 缩略图
   */
  thumbSrc?: ResourceStr

  constructor(sourceSrc?: ResourceStr, thumbSrc?: ResourceStr, type: DefaultMediaType = DefaultMediaType.IMAGE) {
    super();
    this.sourceSrc = sourceSrc
    this.thumbSrc = thumbSrc
    this.type = type
  }
}

@Component
export struct MessageBubble {
  @StorageProp('currentBreakpoint') currentBreakpoint: string = BreakpointConstants.BREAKPOINT_SM;
  avatar1: Resource = $r('app.media.avatar1');
  avatar2: Resource = $r('app.media.avatar7');
  @Consume me: NativeSeenChat | undefined;
  @Consume seenChatsMap: HashMap<string, SeenChat>;
  @Consume messagesOfChatMap: HashMap<string, MessageDataSource>;
  @Consume('pageInfo') pageInfo: NavPathStack;
  @State mediaPath: string = "";
  @State mediaLoaded: boolean = false;
  @State mediaLoadFailed: boolean = false;
  @State profilePhotoPath: string | undefined = undefined;
  @State profilePhotoLoaded: boolean = false;
  @State profilePhotoLoadFailed: boolean = false;
  @State profilePhotoPixelMap: PixelMap | undefined = undefined;
  @State mediaPreviewIndex: number = -1;
  @State mediaResources: DefaultMediaModel[] = [];
  @Consume currentChatId: string;
  @Consume isScrollingDueToReplyToMessage: boolean;
  @Consume scrollToRepliedMessageIndex: number;
  private messageListScroller?: ListScroller;
  private chatType: ChatType = ChatType.User;
  private content: string = "";
  private isAppletMsg?: boolean = false;
  private isDocumentMsg?: boolean = false;
  private message? = new Message(
    1,
    1,
    false,
    false,
    1,
    "John Doe",
    Date.now(),
    "Hello, World!",
    MediaType.None,
    0,
    0,
    0,
  );
  private mediaPreviewOptions: MediaPreviewOptions = new MediaPreviewOptions()
    .setBackgroundColor(Color.Black)
    .setPageChangedListener((_item, index) => {
      this.mediaPreviewIndex = index;
    })
    .setBackListener(() => {
      this.mediaPreviewIndex = -1;
    })
    .setLongPressListener((_item, index) => {
      console.log(`MessageBubble Media 长按了第${index + 1}个资源`);
    })//TODO: 可以自定义id
    .setIdBuilder((_item, index) => {
      return `media_${index}`
    })//TODO: 设置thumb可以优化一镜到底效果，可以注释对比效果
    .setThumbBuilder((item, index) => {
      this.Media(item as DefaultMediaModel, index)
    });

  build() {
    Column() {
      Flex({
        justifyContent: !this.message?.outgoing ? FlexAlign.Start : FlexAlign.End,
        direction: FlexDirection.Row
      }) {
        if ((!this.message?.outgoing) && (this.chatType != ChatType.User)) {
          Image("file://" + this.profilePhotoPath)
            .alt("用户头像 / User avatar [i18n]")
            .width(HomeConstants.PROFILE_PHOTO_SIZE_SMALL)
            .height(HomeConstants.PROFILE_PHOTO_SIZE_SMALL)
            .flexShrink(BaseConstants.FLEX_SHRINK_ZERO)
            .clipShape(new Circle({
              width: HomeConstants.PROFILE_PHOTO_SIZE_SMALL,
              height: HomeConstants.PROFILE_PHOTO_SIZE_SMALL
            }))
            .onAppear(() => {
              getOrDownloadProfilePhoto(this.message?.senderId || 0)
                .then((path) => {
                  this.profilePhotoPath = path;
                  this.profilePhotoLoaded = true;
                });
            })
            .onClick(() => {
              const id = this.message?.senderId;
              if (!id) return;

              this.getUIContext().showActionSheet({
                title: this.message?.senderName ?? '用户',
                message: '',
                autoCancel: true,
                alignment: DialogAlignment.Bottom,
                sheets: [
                  {
                    title: '发送消息',
                    action: () => {
                      // 跳转到与该用户的聊天页面
                      this.currentChatId = id.toString();
                      this.pageInfo.pushPath({ name: 'ChatDetail' });
                    }
                  },
                  {
                    title: '查看资料',
                    action: () => {
                      this.pageInfo.pushPath({ name: "ProfilePage", param: id });
                    }
                  }
                ],
              });
            })
        }
        Column() {
          Stack({ alignContent: !this.message?.outgoing ? Alignment.TopStart : Alignment.TopEnd }) {
            Column() {
              if ((!this.message?.outgoing) && (this.chatType != ChatType.User)) {
                this.SenderName(this.message?.senderName ?? "")
              }

              Column() {
                // reply to message
                if (this.message?.replyToMessageId && this.message?.replyToMessageId != -1) {
                  ReplyToPreview({
                    replyToMessageId: this.message?.replyToMessageId
                  })
                    .alignSelf(!this.message?.outgoing ? ItemAlign.Start : ItemAlign.End)
                    .margin({
                      top: HomeConstants.MESSAGE_REPLY_TO_PREVIEW_TOP_MARGIN,
                    })
                    .onClick(() => {
                      Logger.debug("ReplyToPreview onClick: " + this.message?.replyToMessageId + " currentChatId: " +
                        this.currentChatId);
                      let target_index =
                        this.messagesOfChatMap.get(this.currentChatId)?.indexOf(this.message?.replyToMessageId || -1);
                      Logger.debug("ReplyToPreview onClick: target_index: " + target_index);
                      let current_index =
                        this.messagesOfChatMap.get(this.currentChatId)?.indexOf(this.message?.messageId || -1);
                      Logger.debug("ReplyToPreview onClick: current_index: " + current_index);

                      if (target_index === undefined || target_index < 0 || target_index === null) {
                        Logger.error("ReplyToPreview onClick: error, index is " + target_index);
                        return;
                      }
                      if (current_index - target_index > BaseConstants.LAZY_FOR_EACH_SCROLL_INDEX_LIMIT) {
                        Logger.debug("ReplyToPreview onClick: gap is too large, scroll to target in two steps");
                        this.isScrollingDueToReplyToMessage = true;
                        this.scrollToRepliedMessageIndex = target_index;
                        this.messageListScroller?.scrollToIndex(current_index -
                          BaseConstants.LAZY_FOR_EACH_SCROLL_INDEX_LIMIT +
                          BaseConstants.LAZY_FOR_EACH_SCROLL_SMOOTH_BUFFER,
                          true,
                          ScrollAlign.CENTER);
                        Logger.debug("ReplyToPreview onClick: scrollToIndex first step: " +
                          (current_index -
                            BaseConstants.LAZY_FOR_EACH_SCROLL_INDEX_LIMIT +
                            BaseConstants.LAZY_FOR_EACH_SCROLL_SMOOTH_BUFFER));
                      } else {
                        Logger.debug("ReplyToPreview onClick: scroll to target in one step");
                        this.messageListScroller?.scrollToIndex(target_index, true, ScrollAlign.CENTER);
                      }
                    })
                    .alignSelf(ItemAlign.Start)
                }
                if (this.message?.mediaType === MediaType.Photo) {
                  List({ space: 10 }) {
                    ForEach(this.mediaResources, (item: DefaultMediaModel, index: number) => {
                      ListItem() {
                        this.Media(item, index)
                      }
                      //TODO: 设置id，不然不会显示一镜到底效果
                      .id(this.mediaPreviewOptions.idBuilder(item, index))
                        //TODO: 如果列表数据模型和mediaPreview的数据模型不一致，可以自己设置，不过要和上面的`setIdBuilder`中id一致
                        .id(`media_${index}`)
                        // .aspectRatio(1)
                        .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.8 })
                        //TODO: 仿微信那种资源在预览时原始资源隐藏显示
                        .visibility(index == this.mediaPreviewIndex ? Visibility.Hidden : Visibility.Visible)
                        .onClick(() => {
                          Logger.debug("MessageBubble Media onClick: " + index);
                          // this.mediaPreviewOptions
                          //   .setInitIndex(index)
                          //   .setMedias(this.mediaResources);
                          // MediaPreview.open(this.getUIContext(), this.mediaPreviewOptions);
                          let uiContext = getContext(this);
                          let displayInfo: filePreview.DisplayInfo = {
                            x: 100,
                            y: 100,
                            width: 800,
                            height: 800
                          };
                          let fileInfo: filePreview.PreviewInfo = {
                            uri: "file://" + getContext().applicationInfo.name + this.mediaPath,
                            mimeType: 'image/jpeg'
                          };
                          filePreview.openPreview(uiContext, fileInfo, displayInfo).then(() => {
                            console.info('Succeeded in opening preview');
                          }).catch((err: BusinessError) => {
                            console.error(`Failed to open preview, err.code = ${err.code}, err.message = ${err.message}`);
                          });
                        })
                    }, (item: DefaultMediaModel, index: number) => JSON.stringify(item) + index)
                  }
                }
                this.MessageContent()
                // if (this.message?.mediaType === MediaType.Sticker) {
                // }
                Row() {
                  Blank()
                  if (this.message?.view_count && this.message.view_count > 0) {
                    Text(`查看 ${this.message.view_count} 次 `)
                  }
                  Text(DateHelper.getParsedDateString(this.message?.timestamp))
                    .fontSize(BaseConstants.FONT_SIZE_TWELVE)
                    .fontColor(HomeConstants.MESSAGE_TIME_COLOR)
                  if (this.message?.outgoing) {
                    Text(' ')
                    Text() {
                      SymbolSpan($r('sys.symbol.checkmark_circle'))
                    }
                    // .fontColor(HomeConstants.MESSAGE_TIME_COLOR)
                    .fontSize(BaseConstants.FONT_SIZE_TWELVE)
                  }
                }
                .alignSelf(ItemAlign.End)
              }
              // .justifyContent(FlexAlign.Start)
              // .alignItems(HorizontalAlign.Start)
              .alignSelf(ItemAlign.Start)
            }
            .padding({
              left: 8,
              right: 8,
              top: 8,
              bottom: 8
            })
              .backgroundColor(!this.message?.outgoing ? HomeConstants.MESSAGE_BACKGROUND_COLOR :
                HomeConstants.MESSAGE_BACKGROUND_COLOR_OUTGOING)
              .borderRadius(HomeConstants.PATH_BORDER_RADIUS)
          }
          .padding({
            top: 5,
            // left: $r('app.float.path_left'),
            // right: $r('app.float.path_right'),
            bottom: 5
          })
            .width(BaseConstants.NINETY_WIDTH_PERCENT)
        }
        .width(BaseConstants.NINETY_WIDTH_PERCENT)

        // if (this.message?.outgoing) {
        // Image("file://" + this.profilePhotoPath)
        //   .width(HomeConstants.PROFILE_PHOTO_SIZE_SMALL)
        //   .height(HomeConstants.PROFILE_PHOTO_SIZE_SMALL)
        //   .flexShrink(BaseConstants.FLEX_SHRINK_ZERO)
        //   .clipShape(new Circle({
        //     width: HomeConstants.PROFILE_PHOTO_SIZE_SMALL,
        //     height: HomeConstants.PROFILE_PHOTO_SIZE_SMALL
        //   }))
        //   .onAppear(() => {
        //     // getThumbProfilePhotoPixelMap(this.me?.chatId.toString(), this.seenChatsMap)
        //     //   .then((pixelMap) => {
        //     //     this.profilePhotoPixelMap = pixelMap;
        //     //   })
        //     //   .catch((e: Error) => {
        //     //     Logger.error("ChatDetailItem: failed to create pixel map: " + e);
        //     //   });
        //     getOrDownloadProfilePhoto(this.me?.chatId || 0)
        //       .then((path) => {
        //         this.profilePhotoPath = path;
        //         this.profilePhotoLoaded = true;
        //       })
        //       .catch((error: Error) => {
        //         Logger.error("ChatDetailItem: failed to get or download profile photo: " + error);
        //         this.profilePhotoLoadFailed = true;
        //       });
        //   })
        // }
      }
      .flexShrink(BaseConstants.FLEX_SHRINK_ONE)
    }
    .margin({ left: 5, right: 5 })
  }

  aboutToAppear(): void {
    if (this.mediaResources.length == 0) {
      this.loadMedia();
      this.mediaResources = [
        new DefaultMediaModel(this.mediaPath, this.mediaPath)
      ];
    }
  }

  @Builder
  MessageContent() {
    Text(this.message?.text)
      .fontSize(BaseConstants.FONT_SIZE_SIXTEEN)
      .fontFamily(BaseConstants.FONT_FAMILY_NORMAL)
      .fontWeight(BaseConstants.FONT_WEIGHT_FOUR)
      .lineHeight($r('app.float.chat_default_text_line'))
      .fontColor($r('sys.color.ohos_id_color_text_primary'))
      .copyOption(CopyOptions.LocalDevice)
      .alignSelf(ItemAlign.Start)
  }

  @Builder
  Media(item: DefaultMediaModel, index: number) {
    Stack() {
      Image("file://" + item.thumbSrc)
        .objectFit(ImageFit.Auto)
        .margin({ bottom: $r('app.float.applet_image_bottom') })
        .borderRadius(5)
        .clip(true)
        .alt("媒体缩略图 / Media thumbnail [i18n]")
        .onError((e) => {
          this.mediaLoaded = false;
          this.mediaLoadFailed = true;
        })
        .draggable(true)
        .allowDrop(null)
      Image($r('app.media.play'))
        .width('30vp')
        .height('30vp')
        .fillColor(Color.White)
        .visibility(item.type == DefaultMediaType.VIDEO ? Visibility.Visible : Visibility.None)
      if (!this.mediaLoaded) {
        if (this.mediaLoadFailed) {
          Text("Retry")
            .fontColor(Color.Red)
            .fontSize(BaseConstants.FONT_SIZE_FOURTEEN)
            .fontWeight(FontWeight.Bold)
            .lineHeight(`21fp`)
            .textAlign(TextAlign.Center)
            .layoutWeight(1)
            .onClick(() => {
              this.loadMedia()
            })
        } else {
          Loading()
        }
      }
    }
    .alignSelf(ItemAlign.Start)
      .onAppear(() => {
        this.loadMedia();
      })
  }

  loadMedia() {
    this.mediaLoaded = false;
    this.mediaLoadFailed = false;
    this.mediaPath =
      BaseConstants.BASE_DIR + this.message?.chatId.toString() + "/" + this.message?.messageId.toString() + ".jpg";
    Logger.debug("Media onAppear: " + this.mediaPath);
    // download the image if not exists
    if (!fs.accessSync(this.mediaPath)) {
      Logger.debug("Media onAppear: media " + this.mediaPath + " not exists, downloading media");
      downloadMediaFromMessage(this.message?.chatId, this.message?.messageId)
        .then((path) => {
          Logger.debug("Media onAppear: media downloaded: " + path);
          this.mediaPath = path;
          this.mediaLoaded = true;
        })
        .catch((error: Error) => {
          Logger.debug("Media onAppear Failed to download media: " + error.message);
          this.mediaLoadFailed = true;
        });
    } else {
      Logger.debug("Media onAppear: media exists");
      this.mediaLoaded = true;
    }
  }

  @Builder
  SenderName(senderName: string) {
    Row() {
      Text(senderName)
        .fontSize(BaseConstants.FONT_SIZE_FOURTEEN)
        .fontWeight(FontWeight.Bold)
        .textAlign(TextAlign.Start)
      Blank()
    }
    .alignSelf(ItemAlign.Start)
  }
}

@Builder
  function Loading() {
  LoadingProgress()
    .color(Color.Blue)
    .layoutWeight(1)
    .size({
      width: "10%",
      height: "10%"
    })
}