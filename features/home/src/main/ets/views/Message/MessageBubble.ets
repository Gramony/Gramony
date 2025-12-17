import { BaseConstants, BreakpointConstants, DateHelper, Logger, NormalText } from '@ohos/base'
import {
  MediaType,
  downloadMediaFromMessage,
  // getProfilePhotoPathAndCount,
  NativeSeenChat,
  // downloadProfilePhoto,
  ChatType,
} from 'libhomogrape.so';
import { webview } from '@kit.ArkWeb';
import { util } from '@kit.ArkTS';
import { HomeConstants } from '../../constants/HomeConstants';
import { Message, MessageEntity } from '../../entities/Message';
import { fileIo as fs } from '@kit.CoreFileKit';
import { HashMap } from '@kit.ArkTS';
import { SeenChat } from '../../entities/SeenChat';
import { getOrDownloadProfilePhoto, getThumbProfilePhotoPixelMap } from '../../utils';
import { ReplyToPreview } from './ReplyToPreview'
import { MessageDataSource } from '../../viewmodel/Message/MessageDataSource';
import { MediaModel, MediaPreviewOptions } from '@lyb/media-preview';
import { BusinessError, zlib } from '@kit.BasicServicesKit';
import { filePreview } from '@kit.PreviewKit';
import { applyEntityStyle } from './FmtEntities';
import { LengthMetrics, LengthUnit } from '@ohos.arkui.node';
import { Lottie, LottieController } from '@jjr/lottie_component';

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
  @State decompressedMediaPath: string = ""; // 解压后的文件路径（TGS -> JSON）
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
  @State lottieJson: string = "{}";
  @State videoBase64: string = ""; // Base64 编码的视频数据
  @Prop showUserName: boolean = true;
  private lottieController: LottieController = new LottieController();
  private stickerWebviewController: webview.WebviewController = new webview.WebviewController();
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
  message? = new Message(
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
              if (!id) {
                return;
              }

              this.getUIContext().showActionSheet({
                title: this.message?.senderName ?? '用户',
                message: '',
                autoCancel: true,
                alignment: DialogAlignment.Bottom,
                sheets: [
                  {
                    title: $r('app.string.send_message'),
                    action: () => {
                      // 跳转到与该用户的聊天页面
                      this.currentChatId = id.toString();
                      // 确保该聊天的消息数据源存在
                      if (!this.messagesOfChatMap.hasKey(id.toString())) {
                        this.messagesOfChatMap.set(id.toString(), new MessageDataSource());
                      }
                      // 确保 seenChatsMap 中有用户信息（用于显示标题）
                      if (!this.seenChatsMap.hasKey(id.toString())) {
                        // 创建一个临时的 SeenChat 对象
                        const tempSeenChat = new SeenChat(
                          id,
                          ChatType.User,
                          "", // packedChat
                          false, // isContact
                          false, // isMutualContact
                          this.message?.senderName || "User", // fullName
                          this.message?.senderName || "User", // firstName
                          false// forum
                        );
                        this.seenChatsMap.set(id.toString(), tempSeenChat);
                      }
                      this.pageInfo.pushPath({ name: 'ChatDetail' });
                    }
                  },
                  {
                    title: $r('app.string.view_profile'),
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
              if (this.showUserName && (!this.message?.outgoing) && (this.chatType != ChatType.User) &&
                (this.message?.mediaType !== MediaType.Sticker)) {
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

                // Video 显示（Document 类型且 MIME 类型为 video/*）
                if (this.message?.mediaType === MediaType.Document &&
                this.message?.mediaInfo?.mimeType?.startsWith('video/')) {
                  this.VideoView()
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
            .backgroundColor(this.shouldHideBubble() ? Color.Transparent :
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
    console.warn(`[FMTENTITIES] MessageBubble messageId=${this.message?.messageId} || count: ${this.message?.fmtEntities?.length ??
      0} || text: "${this.message?.text?.substring(0, 50)}"`);
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
    .margin({
      left: 5,
      right: 5,
      top: 2,
      bottom: 2
    })
  }

  @Builder
  VideoView() {
    Stack() {
      Video({
        src: "file://" + this.mediaPath
      })
        .width(300)
        .height(200)
        .autoPlay(false)
        .controls(true)
        .objectFit(ImageFit.Contain)
        .onError(() => {
          Logger.error(`Video load error: ${this.mediaPath}`);
          this.mediaLoadFailed = true;
        })
        .onStart(() => {
          Logger.debug(`Video started playing: ${this.mediaPath}`);
        })

      // 加载状态
      if (!this.mediaLoaded && !this.mediaLoadFailed) {
        Loading()
      }

      // 错误状态
      if (this.mediaLoadFailed) {
        Column() {
          Text($r('app.string.load_failed'))
            .fontColor(Color.Red)
            .fontSize(BaseConstants.FONT_SIZE_TWELVE)
          Text($r('app.string.retry'))
            .fontSize(BaseConstants.FONT_SIZE_TEN)
            .fontColor(Color.Gray)
        }
        .onClick(() => this.loadMedia())
      }
    }
    .width(300)
    .height(200)
    .onAppear(() => {
      this.loadMedia();
    })
  }

  @Builder
  StickerView() {
    Stack() {
      if (this.message?.stickerInfo?.isAnimated && this.lottieJson.length > 7) {
        // 动画 Sticker (TGS 格式 - Lottie)
        // TGS 文件已解压为 JSON
        Lottie({
          autoPlay: true,
          controller: this.lottieController,
          animationData: JSON.parse(this.lottieJson) as Object,
          loop: true,
        })
          .width(160)
          .height(160)
      } else if (this.message?.stickerInfo?.isVideo) {
        // 视频 Sticker (WEBM) - 使用 Web 组件显示
        if (this.videoBase64) {
          Web({
            src: 'about:blank',
            controller: this.stickerWebviewController,
            renderMode: RenderMode.SYNC_RENDER
          })
            .width(160)
            .height(160)
            .backgroundColor(Color.Transparent)
            .domStorageAccess(false)
            .mixedMode(MixedMode.All)
            .cacheMode(CacheMode.None)
            .mediaPlayGestureAccess(true)
            .onAppear(() => {
              try {

                this.stickerWebviewController.loadData(
                  "<html><body><style>body{font-size:5em}</style>Unsupported message</body></html>", 'text/html',
                  'UTF-8'
                );
                // 加载包含 Base64 视频的 HTML
                if (this.videoBase64) {
                  // const html = this.generateStickerVideoHtml();
                  this.stickerWebviewController.loadData(
                    this.videoBase64, 'audio/webm', 'base64'
                  );
                }
              } catch (e) {
                Logger.error(`[ARKWEB] Failed to load sticker video HTML: ${e}`);
              }
            })
        }
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
          Text($r('app.string.load_failed'))
            .fontColor(Color.Red)
            .fontSize(BaseConstants.FONT_SIZE_TWELVE)
          Text($r('app.string.retry'))
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

    Logger.warn(`[MEDIA] loadMedia called for messageId=${this.message?.messageId}, mediaType=${this.message?.mediaType}`);

    // 根据 mediaInfo 或 stickerInfo 确定文件扩展名
    let extension = ".jpg"; // 默认扩展名

    // Sticker 类型优先使用 stickerInfo 判断
    if (this.message?.mediaType === MediaType.Sticker) {
      if (this.message?.stickerInfo?.isVideo) {
        extension = ".webm";
        Logger.warn(`[MEDIA] Sticker is video, using .webm`);
      } else if (this.message?.stickerInfo?.isAnimated) {
        extension = ".tgs";
        Logger.warn(`[MEDIA] Sticker is animated (TGS), using .tgs`);
      } else {
        extension = ".webp";
        Logger.warn(`[MEDIA] Sticker is static, using .webp`);
      }
    } else if (this.message?.mediaInfo?.mimeType) {
      // 使用 mediaInfo 中的 MIME 类型
      extension = this.getExtensionFromMimeType(this.message.mediaInfo.mimeType);
      Logger.warn(`[MEDIA] Using extension from mimeType: ${this.message.mediaInfo.mimeType} -> ${extension}`);
    } else if (this.message?.mediaInfo?.fileName) {
      // 使用文件名中的扩展名
      extension = this.getExtensionFromFileName(this.message.mediaInfo.fileName);
      Logger.warn(`[MEDIA] Using extension from fileName: ${this.message.mediaInfo.fileName} -> ${extension}`);
    }

    this.mediaPath =
      BaseConstants.BASE_DIR + this.message?.chatId.toString() + "/" + this.message?.messageId.toString() + extension;
    Logger.warn(`[MEDIA] Computed mediaPath: ${this.mediaPath}`);

    // download the media if not exists
    try {
      if (!fs.accessSync(this.mediaPath)) {
        Logger.warn(`[MEDIA] File not exists, downloading: ${this.mediaPath}`);
        downloadMediaFromMessage(this.message?.chatId, this.message?.messageId)
          .then((path) => {
            Logger.warn(`[MEDIA] Download succeeded: ${path}`);
            this.mediaPath = path;
            // 验证文件是否存在
            if (fs.accessSync(path)) {
              const stat = fs.statSync(path);
              Logger.warn(`[MEDIA] File exists, size: ${stat.size} bytes`);
            } else {
              Logger.error(`[MEDIA] Downloaded file not found: ${path}`);
            }
            // 如果是 TGS 文件，需要解压为 JSON
            if (extension === ".tgs") {
              this.decompressTgsFile(path);
            } else if (extension === ".webm" && this.message?.mediaType === MediaType.Sticker) {
              // WebM sticker - 转换为 Base64
              Logger.warn(`[MEDIA] Converting downloaded WebM to Base64: ${path}`);
              this.loadVideoAsBase64(path)
                .then((base64) => {
                  this.videoBase64 = base64;
                  this.mediaLoaded = true;
                  Logger.warn(`[MEDIA] Downloaded WebM Base64 conversion successful, length: ${base64.length}`);
                })
                .catch((error: Error) => {
                  Logger.error(`[MEDIA] Failed to convert downloaded WebM to Base64: ${error.message}`);
                  this.mediaLoadFailed = true;
                });
            } else {
              this.mediaLoaded = true;
            }
          })
          .catch((error: Error) => {
            Logger.error(`[MEDIA] Download failed: ${error.message}`);
            // this.mediaLoadFailed = true;
            this.mediaLoaded = true; // TODO: 临时忽略下载成功仍然返回失败的问题
          });
      } else {
        const stat = fs.statSync(this.mediaPath);
        Logger.warn(`[MEDIA] File already exists: ${this.mediaPath}, size: ${stat.size} bytes`);
        // 如果是 TGS 文件，检查是否已解压
        if (extension === ".tgs") {
          const jsonPath = this.mediaPath.replace(".tgs", ".json");
          if (fs.accessSync(jsonPath)) {
            Logger.debug("TGS already decompressed: " + jsonPath);
            this.decompressedMediaPath = jsonPath;

            // 读取 JSON 文件内容
            try {
              const file = fs.openSync(jsonPath, fs.OpenMode.READ_ONLY);
              const stat = fs.statSync(jsonPath);
              const buffer = new ArrayBuffer(stat.size);
              fs.readSync(file.fd, buffer);
              fs.closeSync(file);

              // 转换为字符串
              const bytes = new Uint8Array(buffer);
              let jsonContent = '';
              for (let i = 0; i < bytes.length; i++) {
                jsonContent += String.fromCharCode(bytes[i]);
              }

              Logger.warn(`[TGSJSON] Loaded existing JSON (${jsonContent.length} bytes)`);
              this.lottieJson = jsonContent;
              this.mediaLoaded = true;
            } catch (readErr) {
              Logger.error(`[TGSJSON] Failed to read existing JSON: ${readErr}`);
              // 读取失败，尝试重新解压
              this.decompressTgsFile(this.mediaPath);
            }
          } else {
            this.decompressTgsFile(this.mediaPath);
          }
        } else if (extension === ".webm" && this.message?.mediaType === MediaType.Sticker) {
          // WebM sticker - 转换为 Base64
          Logger.warn(`[MEDIA] Converting WebM to Base64: ${this.mediaPath}`);
          this.loadVideoAsBase64(this.mediaPath)
            .then((base64) => {
              this.videoBase64 = base64;
              this.mediaLoaded = true;
              Logger.warn(`[MEDIA] WebM Base64 conversion successful, length: ${base64.length}`);
            })
            .catch((error: Error) => {
              Logger.error(`[MEDIA] Failed to convert WebM to Base64: ${error.message}`);
              this.mediaLoadFailed = true;
            });
        } else {
          this.mediaLoaded = true;
        }
      }
    } catch (error) {
      console.error(error);
    }
  }

  /**
   * 解压 TGS 文件为 JSON
   * TGS 文件是 gzip 压缩的 Lottie JSON 动画
   */
  private async decompressTgsFile(tgsPath: string): Promise<void> {
    const jsonPath = tgsPath.replace(".tgs", ".json");

    Logger.warn(`[TGSJSON] Decompressing TGS (gzip): ${tgsPath} -> ${jsonPath}`);

    try {
      // 创建 Checksum 实例用于 gzip 操作
      const checksum = await zlib.createGZip();

      // 打开 gzip 文件进行读取 (mode: "rb" = read binary)
      await checksum.gzopen(tgsPath, "rb");
      Logger.warn(`[TGSJSON] Gzip file opened successfully`);

      // 预分配一个足够大的缓冲区（TGS 文件通常小于 1MB）
      const bufferSize = 1024 * 1024; // 1MB
      const buffer = new ArrayBuffer(bufferSize);

      // 读取并解压数据
      const bytesRead = await checksum.gzread(buffer);
      Logger.warn(`[TGSJSON] Gzip read ${bytesRead} bytes`);

      // 关闭 gzip 文件
      await checksum.gzcloser();
      Logger.warn(`[TGSJSON] Gzip file closed`);

      if (bytesRead > 0) {
        // 将解压后的数据转换为字符串
        const bytes = new Uint8Array(buffer, 0, bytesRead);
        let jsonContent = '';
        for (let i = 0; i < bytes.length; i++) {
          jsonContent += String.fromCharCode(bytes[i]);
        }

        const contentPreview = jsonContent.length > 200 ? jsonContent.substring(0, 200) + '...' : jsonContent;
        Logger.warn(`[TGSJSON] JSON content (${jsonContent.length} bytes): ${contentPreview}`);

        // 将 JSON 内容写入文件
        const file = await fs.open(jsonPath, fs.OpenMode.CREATE | fs.OpenMode.TRUNC | fs.OpenMode.WRITE_ONLY);
        await fs.write(file.fd, jsonContent);
        await fs.close(file);

        Logger.warn(`[TGSJSON] JSON written to file: ${jsonPath}`);
        Logger.warn(`[TGSJSON] TGS decompression completed!! ${jsonContent.slice(0, 150)}`);

        this.lottieJson = jsonContent;
        this.decompressedMediaPath = jsonPath;
        this.mediaLoaded = true;
      } else {
        Logger.error(`[TGSJSON] No data read from gzip file`);
        this.mediaLoadFailed = true;
      }
    } catch (err) {
      const error = err as BusinessError;
      Logger.error(`[TGSJSON] Exception during gzip decompression: code=${error.code}, msg=${error.message}`);
      this.mediaLoadFailed = true;
    }
  }

  /**
   * 判断是否应该隐藏气泡背景
   * Sticker 和无文本的视频不显示气泡
   */
  private shouldHideBubble(): boolean {
    // Sticker 总是无气泡
    if (this.message?.mediaType === MediaType.Sticker) {
      return true;
    }

    // 视频：如果没有文本，则不显示气泡
    if (this.message?.mediaType === MediaType.Document &&
    this.message?.mediaInfo?.mimeType?.startsWith('video/')) {
      const hasText = this.message?.text && this.message.text.trim().length > 0;
      return !hasText;
    }

    return false;
  }

  /**
   * 从 MIME 类型推断文件扩展名
   */
  private getExtensionFromMimeType(mimeType: string): string {
    const mimeMap: Record<string, string> = {
      'image/jpeg': '.jpg',
      'image/jpg': '.jpg',
      'image/png': '.png',
      'image/gif': '.gif',
      'image/webp': '.webp',
      'video/mp4': '.mp4',
      'video/webm': '.webm',
      'video/quicktime': '.mov',
      'video/x-matroska': '.mkv',
      'audio/mpeg': '.mp3',
      'audio/mp3': '.mp3',
      'audio/ogg': '.ogg',
      'audio/wav': '.wav',
      'audio/aac': '.aac',
      'application/pdf': '.pdf',
      'application/x-tgsticker': '.tgs',
      'application/zip': '.zip',
      'application/x-rar-compressed': '.rar',
    };

    // 直接匹配
    if (mimeMap[mimeType]) {
      return mimeMap[mimeType];
    }

    // 按前缀匹配
    if (mimeType.startsWith('video/')) {
      return '.mp4';
    }
    if (mimeType.startsWith('audio/')) {
      return '.mp3';
    }
    if (mimeType.startsWith('image/')) {
      return '.jpg';
    }

    return '.bin'; // 未知类型
  }

  /**
   * 从文件名中提取扩展名
   */
  private getExtensionFromFileName(fileName: string): string {
    const parts = fileName.split('.');
    if (parts.length > 1) {
      const ext = parts[parts.length - 1];
      // 验证扩展名长度合理
      if (ext.length > 0 && ext.length < 10) {
        return '.' + ext;
      }
    }
    return '.bin';
  }

  /**
   * 生成用于显示视频 sticker 的 HTML 内容
   * 针对 512x512 的 WebM sticker 优化
   * 使用 Base64 编码的 data URI
   */
  private generateStickerVideoHtml(): string {
    const html = `
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        html, body {
            zoom: 0.8;
            width: 100%;
            height: 100%;
            overflow: hidden;
            background: red;
        }
        video {
            width: 100%;
            height: 100%;
            object-fit: contain;
            display: block;
        }
    </style>
</head>
<body>
test
test
test
test
test
test

</body>
</html>
`;
    return html;
  }

  /**
   * 读取视频文件并转换为 Base64 编码
   */
  private async loadVideoAsBase64(filePath: string): Promise<string> {
    try {
      Logger.warn(`[BASE64] Reading video file: ${filePath}`);

      // 打开文件
      const file = await fs.open(filePath, fs.OpenMode.READ_ONLY);
      const stat = await fs.stat(filePath);
      const fileSize = stat.size;

      Logger.warn(`[BASE64] File size: ${fileSize} bytes`);

      // 读取文件内容到 ArrayBuffer
      const buffer = new ArrayBuffer(fileSize);
      const readLen = await fs.read(file.fd, buffer);
      await fs.close(file);

      Logger.warn(`[BASE64] Read ${readLen} bytes from file`);

      // 转换为 Uint8Array
      const uint8Array = new Uint8Array(buffer);

      // 使用 Base64Helper 编码
      const base64Helper = new util.Base64Helper();
      const base64String = base64Helper.encodeToStringSync(uint8Array, util.Type.BASIC);

      Logger.warn(`[BASE64] Base64 encoded length: ${base64String.length} characters`);

      return base64String;
    } catch (error) {
      Logger.error(`[BASE64] Failed to encode video: ${error}`);
      return "";
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
      width: "18vp",
      height: "18vp"
    })
}