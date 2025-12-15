import sql from "@liushengyi/smartdb"
import { MediaType, NativeMessage, NativeMessageEntity, MessageEntityType } from 'libhomogrape.so'
import { IComparable } from '@ohos/base'

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

  constructor(chatId: number, messageId: number, outgoing: boolean, pinned: boolean, senderId: number,
    senderName: string, timestamp: number, text: string, mediaType: MediaType, editTimestamp?: number,
    groupedId?: number, replyToMessageId?: number, fmtEntities?: MessageEntity[]) {
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
    // 序列化为 JSON 存储
    if (fmtEntities && fmtEntities.length > 0) {
      this.fmtEntitiesJson = JSON.stringify(fmtEntities);
      console.warn(`[FMTENTITIES] Message constructor: serialized ${fmtEntities.length} entities to JSON: ${this.fmtEntitiesJson}`);
    }
  }

  public static fromNative(nativeMessage: NativeMessage): Message {
    // 转换格式化实体
    let fmtEntities: MessageEntity[] | undefined;
    if (nativeMessage.fmtEntities && nativeMessage.fmtEntities.length > 0) {
      console.warn(`[FMTENTITIES] fromNative: converting ${nativeMessage.fmtEntities.length} entities from NAPI`);
      console.warn(`[FMTENTITIES] fromNative: first entity raw: ${JSON.stringify(nativeMessage.fmtEntities[0])}`);
      fmtEntities = nativeMessage.fmtEntities.map(e => MessageEntity.fromNative(e));
      console.warn(`[FMTENTITIES] fromNative: first entity converted: ${JSON.stringify(fmtEntities[0])}`);
    } else {
      console.warn(`[FMTENTITIES] fromNative: no fmtEntities in nativeMessage`);
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
      fmtEntities
    );

    msg.viewCount = nativeMessage.viewCount ?? 0;
    msg.forwardCount = nativeMessage.forwardCount ?? 0;
    msg.replyCount = nativeMessage.replyCount ?? 0;

    // 确保 fmtEntitiesJson 被正确设置,以便 ORM 能保存它
    // 注意:构造函数已经设置了 fmtEntitiesJson,但为了确保,这里再次显式赋值
    if (fmtEntities && fmtEntities.length > 0) {
      msg.fmtEntitiesJson = JSON.stringify(fmtEntities);
      console.warn(`[FMTENTITIES] fromNative: explicitly set fmtEntitiesJson for ORM: ${msg.fmtEntitiesJson}`);
    }

    return msg;
  }

  /**
   * 从数据库加载后，反序列化 fmtEntities
   */
  public deserializeFmtEntities(): void {
    console.warn(`[FMTENTITIES] deserializeFmtEntities: messageId=${this.messageId}, fmtEntitiesJson=${this.fmtEntitiesJson}`);

    if (this.fmtEntitiesJson && this.fmtEntitiesJson.length > 0) {
      try {
        // JSON 中的字段名已经是 camelCase（因为序列化时就是 MessageEntity 对象）
        // 直接解析为 MessageEntity 数组，不需要 fromNative 转换
        this.fmtEntities = JSON.parse(this.fmtEntitiesJson) as MessageEntity[];
        console.warn(`[FMTENTITIES] deserializeFmtEntities: successfully parsed ${this.fmtEntities.length} entities`);
        if (this.fmtEntities.length > 0) {
          console.warn(`[FMTENTITIES] deserializeFmtEntities: first entity: ${JSON.stringify(this.fmtEntities[0])}`);
        }
      } catch (e) {
        // 解析失败，忽略
        console.warn(`[FMTENTITIES] deserializeFmtEntities: failed to parse JSON: ${e}`);
        this.fmtEntities = undefined;
      }
    } else {
      console.warn(`[FMTENTITIES] deserializeFmtEntities: no fmtEntitiesJson to deserialize`);
    }
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