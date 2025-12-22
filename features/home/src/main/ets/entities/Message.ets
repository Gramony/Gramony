import sql from "@liushengyi/smartdb"
import { MediaType, NativeMessage, NativeMessageEntity, MessageEntityType } from 'libhomogrape.so'
import { IComparable } from '@ohos/base'

/**
 * Sticker 信息
 */
export class StickerInfo {
  emoji?: string;         // 关联的 emoji
  isAnimated: boolean = false;    // 是否为动画 sticker (TGS)
  isVideo: boolean = false;       // 是否为视频 sticker (WEBM)
  mimeType?: string;      // MIME 类型
  fileSize?: number;      // 文件大小
  width?: number;         // 宽度
  height?: number;        // 高度
}

/**
 * 通用媒体信息（Photo、Document、Video 等）
 */
export class MediaInfo {
  mimeType?: string;      // MIME 类型
  fileName?: string;      // 原始文件名
  fileSize?: number;      // 文件大小（字节）
  width?: number;         // 宽度（图片/视频）
  height?: number;        // 高度（图片/视频）
  duration?: number;      // 时长（视频/音频，秒）
}

/**
 * 消息格式化实体（粗体、斜体、链接等）
 */
export class MessageEntity implements NativeMessageEntity {
  entityType: MessageEntityType;
  offset: number;       // UTF-16 偏移量
  length: number;       // UTF-16 长度
  url?: string;         // TextUrl 的链接
  userId?: number;      // MentionName 的用户 ID
  language?: string;    // Pre 的语言
  customEmojiId?: number; // CustomEmoji 的 ID

  constructor(
    entityType: MessageEntityType,
    offset: number,
    length: number,
    url?: string,
    userId?: number,
    language?: string,
    customEmojiId?: number
  ) {
    this.entityType = entityType;
    this.offset = offset;
    this.length = length;
    this.url = url;
    this.userId = userId;
    this.language = language;
    this.customEmojiId = customEmojiId;
  }

  public static fromNative(native: NativeMessageEntity): MessageEntity {
    return new MessageEntity(
      native.entityType,
      native.offset,
      native.length,
      native.url,
      native.userId,
      native.language,
      native.customEmojiId
    );
  }
}

export class Message implements NativeMessage, IComparable<Message> {
  @sql.SqlColumn(sql.ColumnType.INTEGER)
  chatId: number;
  @sql.SqlColumn(sql.ColumnType.INTEGER)
  messageId: number;
  @sql.SqlColumn(sql.ColumnType.BOOL)
  outgoing: boolean;
  @sql.SqlColumn(sql.ColumnType.BOOL)
  pinned: boolean;
  @sql.SqlColumn(sql.ColumnType.INTEGER)
  senderId: number;
  @sql.SqlColumn(sql.ColumnType.TEXT)
  senderName: string;
  @sql.SqlColumn(sql.ColumnType.INTEGER)
  timestamp: number;
  @sql.SqlColumn(sql.ColumnType.TEXT)
  text: string;
  @sql.SqlColumn(sql.ColumnType.INTEGER)
  mediaType: MediaType
  @sql.SqlColumn(sql.ColumnType.INTEGER)
  editTimestamp?: number
  @sql.SqlColumn(sql.ColumnType.INTEGER)
  groupedId?: number
  @sql.SqlColumn(sql.ColumnType.INTEGER)
  replyToMessageId?: number
  @sql.SqlColumn(sql.ColumnType.INTEGER)
  viewCount: number
  @sql.SqlColumn(sql.ColumnType.INTEGER)
  forwardCount: number
  @sql.SqlColumn(sql.ColumnType.INTEGER)
  replyCount: number
  /// 消息格式化实体（粗体、斜体、链接等）- 存储为 JSON 字符串
  @sql.SqlColumn(sql.ColumnType.TEXT)
  fmtEntitiesJson?: string
  /// 运行时使用的格式化实体数组
  fmtEntities?: MessageEntity[]
  /// Sticker 信息 - 存储为 JSON 字符串
  @sql.SqlColumn(sql.ColumnType.TEXT)
  stickerInfoJson?: string
  /// 运行时使用的 Sticker 信息
  stickerInfo?: StickerInfo
  /// 通用媒体信息 - 存储为 JSON 字符串
  @sql.SqlColumn(sql.ColumnType.TEXT)
  mediaInfoJson?: string
  /// 运行时使用的媒体信息
  mediaInfo?: MediaInfo

  constructor(chatId: number, messageId: number, outgoing: boolean, pinned: boolean, senderId: number,
    senderName: string, timestamp: number, text: string, mediaType: MediaType, editTimestamp?: number,
    groupedId?: number, replyToMessageId?: number, fmtEntities?: MessageEntity[], stickerInfo?: StickerInfo) {
    this.chatId = chatId;
    this.messageId = messageId;
    this.outgoing = outgoing;
    this.pinned = pinned;
    this.senderId = senderId;
    this.senderName = senderName;
    this.timestamp = timestamp;
    this.text = text;
    this.mediaType = mediaType;
    this.editTimestamp = editTimestamp || -1;
    this.groupedId = groupedId || -1;
    this.replyToMessageId = replyToMessageId || -1;
    this.replyCount = 0;
    this.forwardCount = 0;
    this.viewCount = 0;
    this.fmtEntities = fmtEntities;
    this.stickerInfo = stickerInfo;
    // Note: JSON 序列化由 fromNative 统一处理，直接序列化 NAPI 原始对象
    // 构造函数不再序列化，避免类实例序列化问题
  }

  public static fromNative(nativeMessage: NativeMessage): Message {
    // 转换格式化实体
    let fmtEntities: MessageEntity[] | undefined;
    if (nativeMessage.fmtEntities && nativeMessage.fmtEntities.length > 0) {
      console.warn(`[FMTENTITIES] fromNative: converting ${nativeMessage.fmtEntities.length} entities from NAPI, first entity raw: ${JSON.stringify(nativeMessage.fmtEntities[0])}`);
      fmtEntities = nativeMessage.fmtEntities.map(e => MessageEntity.fromNative(e));
      console.warn(`[FMTENTITIES] fromNative: first entity converted: ${JSON.stringify(fmtEntities ? fmtEntities[0] : null)}`);
    }

    const msg = new Message(
      nativeMessage.chatId,
      nativeMessage.messageId,
      nativeMessage.outgoing,
      nativeMessage.pinned,
      nativeMessage.senderId,
      nativeMessage.senderName,
      nativeMessage.timestamp,
      nativeMessage.text,
      nativeMessage.mediaType,
      nativeMessage.editTimestamp,
      nativeMessage.groupedId,
      nativeMessage.replyToMessageId,
      fmtEntities,
      nativeMessage.stickerInfo as StickerInfo | undefined
    );

    msg.viewCount = nativeMessage.viewCount ?? 0;
    msg.forwardCount = nativeMessage.forwardCount ?? 0;
    msg.replyCount = nativeMessage.replyCount ?? 0;

    // 直接序列化原始 NAPI 对象，避免类实例序列化问题
    // 这样可以确保数据在数据库往返过程中不丢失
    if (nativeMessage.fmtEntities && nativeMessage.fmtEntities.length > 0) {
      msg.fmtEntitiesJson = JSON.stringify(nativeMessage.fmtEntities);
      console.warn(`[FMTENTITIES] fromNative: serialized ${nativeMessage.fmtEntities.length} entities from NAPI`);
    }
    if (nativeMessage.stickerInfo) {
      msg.stickerInfoJson = JSON.stringify(nativeMessage.stickerInfo);
      console.warn(`[STICKER] fromNative: serialized stickerInfo for messageId=${msg.messageId}`);
    } else {
      console.warn(`[STICKER] fromNative: no stickerInfo for messageId=${msg.messageId}`);
    }
    if (nativeMessage.mediaInfo) {
      msg.mediaInfoJson = JSON.stringify(nativeMessage.mediaInfo);
      console.warn(`[MEDIA] fromNative: serialized mediaInfo for messageId=${msg.messageId}`);
    }

    return msg;
  }

  /**
   * 从数据库加载后，反序列化 fmtEntities、stickerInfo 和 mediaInfo
   */
  public deserializeFmtEntities(): void {
    console.error(`============ [DESERIALIZE START] messageId=${this.messageId} ============`);
    console.error(`[DESERIALIZE] fmtEntitiesJson: type=${typeof this.fmtEntitiesJson}, length=${this.fmtEntitiesJson?.length ?? 'undefined'}`);
    if (this.fmtEntitiesJson) {
      console.error(`[DESERIALIZE] fmtEntitiesJson value: ${this.fmtEntitiesJson.substring(0, 150)}`);
    }
    console.error(`[DESERIALIZE] stickerInfoJson: type=${typeof this.stickerInfoJson}, length=${this.stickerInfoJson?.length ?? 'undefined'}`);
    console.error(`[DESERIALIZE] mediaInfoJson: type=${typeof this.mediaInfoJson}, length=${this.mediaInfoJson?.length ?? 'undefined'}`);
    if (this.mediaInfoJson) {
      console.error(`[DESERIALIZE] mediaInfoJson value: ${this.mediaInfoJson.substring(0, 150)}`);
    }

    if (this.fmtEntitiesJson && this.fmtEntitiesJson.length > 0) {
      try {
        this.fmtEntities = JSON.parse(this.fmtEntitiesJson) as MessageEntity[];
        console.error(`[DESERIALIZE] ✓ Successfully parsed ${this.fmtEntities.length} fmtEntities`);
      } catch (e) {
        console.error(`[DESERIALIZE] ✗ Failed to parse fmtEntitiesJson: ${e}`);
        this.fmtEntities = undefined;
      }
    } else {
      console.error(`[DESERIALIZE] ✗ No fmtEntitiesJson to deserialize`);
    }

    if (this.stickerInfoJson && this.stickerInfoJson.length > 0) {
      try {
        this.stickerInfo = JSON.parse(this.stickerInfoJson) as StickerInfo;
        console.error(`[DESERIALIZE] ✓ Successfully parsed stickerInfo`);
      } catch (e) {
        console.error(`[DESERIALIZE] ✗ Failed to parse stickerInfoJson: ${e}`);
        this.stickerInfo = undefined;
      }
    }

    if (this.mediaInfoJson && this.mediaInfoJson.length > 0) {
      try {
        this.mediaInfo = JSON.parse(this.mediaInfoJson) as MediaInfo;
        console.error(`[DESERIALIZE] ✓ Successfully parsed mediaInfo`);
      } catch (e) {
        console.error(`[DESERIALIZE] ✗ Failed to parse mediaInfoJson: ${e}`);
        this.mediaInfo = undefined;
      }
    }
    console.error(`============ [DESERIALIZE END] messageId=${this.messageId} ============`);
  }

  /**
   * 检查消息是否包含格式化内容
   */
  public hasFormatting(): boolean {
    return this.fmtEntities !== undefined && this.fmtEntities.length > 0;
  }

  /**
   * 获取指定类型的所有实体
   */
  public getEntitiesByType(type: MessageEntityType): MessageEntity[] {
    if (!this.fmtEntities) return [];
    return this.fmtEntities.filter(e => e.entityType === type);
  }

  compareTo(other: Message): number {
    return other.messageId - this.messageId;
  }
}