import { BaseConstants, BreakpointConstants, DateHelper, Logger, NormalText } from '@ohos/base'
import {
  MediaType,
  downloadMediaFromMessage,
  getProfilePhotoPathAndCount,
  NativeSeenChat,
  downloadProfilePhoto,
  ChatType,
} from 'libhomogrape.so';
import { HomeConstants } from '../../constants/HomeConstants';
import { Message, MessageEntity } from '../../entities/Message';
import { fileIo as fs } from '@kit.CoreFileKit';
import { HashMap } from '@kit.ArkTS';
import { SeenChat } from '../../entities/SeenChat';
import { getOrDownloadProfilePhoto, getThumbProfilePhotoPixelMap } from '../../utils';
import { ReplyToPreview } from './ReplyToPreview'
import { MessageDataSource } from '../../viewmodel/Message/MessageDataSource';
import { MediaModel, MediaPreview, MediaPreviewOptions, MediaPreviewComponent } from '@lyb/media-preview';
import { BusinessError } from '@kit.BasicServicesKit';
import { filePreview } from '@kit.PreviewKit';
import { applyEntityStyle } from './FmtEntities';
import { LengthMetrics, LengthUnit } from '@ohos.arkui.node';
import { Lottie } from '@jjr/lottie_component';

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
  @State styledString: StyledString | undefined = undefined;
  @Consume currentChatId: string;
  @Consume isScrollingDueToReplyToMessage: boolean;
  @Consume scrollToRepliedMessageIndex: number;
  private incomingBorderRadius: LocalizedBorderRadiuses = {
    topStart: new LengthMetrics(0, LengthUnit.VP),
    topEnd: new LengthMetrics(HomeConstants.PATH_BORDER_RADIUS, LengthUnit.VP),
    bottomStart: new LengthMetrics(HomeConstants.PATH_BORDER_RADIUS, LengthUnit.VP),
    bottomEnd: new LengthMetrics(HomeConstants.PATH_BORDER_RADIUS, LengthUnit.VP),
  };
  private outgoingBorderRadius: LocalizedBorderRadiuses = {
    topEnd: new LengthMetrics(0, LengthUnit.VP),
    topStart: new LengthMetrics(HomeConstants.PATH_BORDER_RADIUS, LengthUnit.VP),
    bottomStart: new LengthMetrics(HomeConstants.PATH_BORDER_RADIUS, LengthUnit.VP),
    bottomEnd: new LengthMetrics(HomeConstants.PATH_BORDER_RADIUS, LengthUnit.VP),
  };
  messageListScroller?: ListScroller;
  chatType: ChatType = ChatType.User;
  private content: string = "";
  private isAppletMsg?: boolean = false;
  private isDocumentMsg?: boolean = false;
  textController: TextController = new TextController();
  message?= new Message(
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
              if ((!this.message?.outgoing) && (this.chatType != ChatType.User) && (this.message?.mediaType !== MediaType.Sticker)) {
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
                            uri: "file://" + uiContext.applicationInfo.name + this.mediaPath,
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

                // Sticker 显示
                if (this.message?.mediaType === MediaType.Sticker) {
                  this.StickerView()
                }

                this.MessageContent()

                Row() {
                  Blank()
                  if (this.message?.viewCount && this.message.viewCount > 0) {
                    Text(`󰄠 ${this.message.viewCount}  `)
                      .fontSize(BaseConstants.FONT_SIZE_TWELVE)
                      .fontColor(HomeConstants.MESSAGE_TIME_COLOR)
                      .fontFamily("HarmonyOS Sans Condensed")
                  }
                  Text(DateHelper.getParsedDateString(this.message?.timestamp))
                    .fontSize(BaseConstants.FONT_SIZE_TWELVE)
                    .fontColor(HomeConstants.MESSAGE_TIME_COLOR)
                    .fontFamily("HarmonyOS Sans Condensed")
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
              .alignSelf(ItemAlign.Start)
            }
            .padding({
              left: 8,
              right: 8,
              top: 8,
              bottom: 8
            })
              .backgroundColor(this.message?.mediaType === MediaType.Sticker ? Color.Transparent :
                (!this.message?.outgoing ? HomeConstants.MESSAGE_BACKGROUND_COLOR :
                  HomeConstants.MESSAGE_BACKGROUND_COLOR_OUTGOING))
              .borderRadius(this.message?.outgoing ? this.outgoingBorderRadius : this.incomingBorderRadius)
          }
          .padding({
            top: 5,
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
    // 构建 StyledString 用于富文本渲染
    console.warn(`[FMTENTITIES] MessageBubble messageId=${this.message?.messageId} || count: ${this.message?.fmtEntities?.length ?? 0} || text: "${this.message?.text?.substring(0, 50)}"`);
    if (this.message?.fmtEntities && this.message.fmtEntities.length > 0) {
      console.warn(`[FMTENTITIES] MessageBubble fmtEntities: ${JSON.stringify(this.message.fmtEntities)}`);
    }
    this.buildStyledString();
  }

  /**
   * 根据 fmtEntities 构建 StyledString 用于富文本显示
   */
  private buildStyledString(): void {
    const text = this.message?.text ?? '';
    if (text.length === 0) {
      this.styledString = undefined;
      console.warn(`[FMTENTITIES] buildStyledString: empty text, skipping`);
      return;
    }

    const entities = this.message?.fmtEntities;
    if (!entities || entities.length === 0) {
      // 没有格式化实体，不使用 StyledString，直接使用普通文本
      this.styledString = undefined;
      console.warn(`[FMTENTITIES] buildStyledString: no entities for message ${this.message?.messageId}`);
      return;
    }

    console.warn(`[FMTENTITIES] buildStyledString: creating StyledString for message ${this.message?.messageId}`);
    console.warn(`[FMTENTITIES] buildStyledString: entities count=${entities.length}, entities: ${JSON.stringify(entities)}`);

    // 创建可变属性字符串
    const mutableStyledString = new MutableStyledString(text);

    // 遍历所有格式化实体并应用样式
    for (let i = 0; i < entities.length; i++) {
      const entity = entities[i];
      try {
        console.warn(`[FMTENTITIES] buildStyledString: applying entity ${i}: ${JSON.stringify(entity)}`);
        applyEntityStyle(this.message?.text ?? "", mutableStyledString, entity);
        console.warn(`[FMTENTITIES] buildStyledString: entity ${i} applied successfully`);
      } catch (e) {
        console.warn(`[FMTENTITIES] buildStyledString: failed to apply entity ${i}: ${JSON.stringify(entity)}, error: ${e}`);
      }
    }

    this.styledString = mutableStyledString;
    console.warn(`[FMTENTITIES] buildStyledString: StyledString created successfully for message ${this.message?.messageId}`);
  }

  @Builder
  StickerOnlyView() {
    Flex({
      justifyContent: !this.message?.outgoing ? FlexAlign.Start : FlexAlign.End,
      direction: FlexDirection.Row
    }) {
      this.StickerView()
    }
    .margin({ left: 5, right: 5, top: 2, bottom: 2 })
  }

  @Builder
  StickerView() {
    Stack() {
      if (this.message?.stickerInfo?.isAnimated) {
        // 动画 Sticker (TGS 格式 - Lottie)
        // TGS 文件需要先读取为字符串
        Lottie({
          autoPlay: true,
          animationUri: "file://" + this.mediaPath,
          loop: true,
        })
          .width(160)
          .height(160)
      } else if (this.message?.stickerInfo?.isVideo) {
        // 视频 Sticker (WEBM)
        Video({
          src: "file://" + this.mediaPath
        })
          .width(150)
          .height(150)
          .autoPlay(true)
          .loop(true)
          .muted(true)
          .controls(false)
          .objectFit(ImageFit.Contain)
      } else {
        // 静态 Sticker (WEBP)
        Image("file://" + this.mediaPath)
          .width(150)
          .height(150)
          .objectFit(ImageFit.Contain)
          .interpolation(ImageInterpolation.High)
          .alt(this.message?.stickerInfo?.emoji ?? "Sticker")
      }

      // 加载状态
      if (!this.mediaLoaded && !this.mediaLoadFailed) {
        Loading()
      }

      // 错误状态
      if (this.mediaLoadFailed) {
        Column() {
          Text("加载失败")
            .fontColor(Color.Red)
            .fontSize(BaseConstants.FONT_SIZE_TWELVE)
          Text("点击重试")
            .fontSize(BaseConstants.FONT_SIZE_TEN)
            .fontColor(Color.Gray)
        }
        .onClick(() => this.loadMedia())
      }
    }
    .width(150)
      .height(150)
      .onAppear(() => {
        this.loadMedia();
      })
  }

  @Builder
  MessageContent() {
    if (this.styledString && this.message?.text && this.message.text.length > 0) {
      // 使用 StyledString 渲染富文本
      // 先显示原始文本，然后通过 controller 应用样式
      Text(this.message.text, { controller: this.textController })
        .fontSize(BaseConstants.FONT_SIZE_SIXTEEN)
        .fontFamily(BaseConstants.FONT_FAMILY_NORMAL)
        .fontWeight(BaseConstants.FONT_WEIGHT_FOUR)
        .lineHeight($r('app.float.chat_default_text_line'))
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
        .copyOption(CopyOptions.LocalDevice)
        .alignSelf(ItemAlign.Start)
        .onAppear(() => {
          // 延迟执行以确保布局完成
          setTimeout(() => {
            if (this.styledString) {
              try {
                this.textController.setStyledString(this.styledString);
              } catch (e) {
                Logger.error(`Failed to set styled string: ${e}`);
              }
            }
          }, 16); // 等待一帧
        })
    } else {
      // 普通文本渲染
      Text(this.message?.text)
        .fontSize(BaseConstants.FONT_SIZE_SIXTEEN)
        .fontFamily(BaseConstants.FONT_FAMILY_NORMAL)
        .fontWeight(BaseConstants.FONT_WEIGHT_FOUR)
        .lineHeight($r('app.float.chat_default_text_line'))
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
        .copyOption(CopyOptions.LocalDevice)
        .alignSelf(ItemAlign.Start)
    }
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

    // 根据媒体类型确定文件扩展名
    let extension = ".jpg";
    if (this.message?.mediaType === MediaType.Sticker) {
      if (this.message?.stickerInfo?.isVideo) {
        extension = ".webm";
      } else if (this.message?.stickerInfo?.isAnimated) {
        extension = ".tgs";
      } else {
        extension = ".webp";
      }
    }

    this.mediaPath =
      BaseConstants.BASE_DIR + this.message?.chatId.toString() + "/" + this.message?.messageId.toString() + extension;
    Logger.debug("Media onAppear: " + this.mediaPath);

    // download the media if not exists
    try {
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
    } catch (error) {
      console.error(error);
    }
  }

  @Builder
  SenderName(senderName: string) {
    Row() {
      Text(senderName)
        .fontSize(BaseConstants.FONT_SIZE_FOURTEEN)
        .fontWeight(FontWeight.Bold)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .textAlign(TextAlign.Start)
      Blank()
    }
    .padding({ bottom: 2 })
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