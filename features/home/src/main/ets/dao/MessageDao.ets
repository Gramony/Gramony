import sql from "@liushengyi/smartdb"
import { Message } from "../entities/Message"
import { DatabaseConstants } from "../constants/DatabaseConstants"
import { escapeString } from "@ohos/base"

class MessageDao {
  constructor() {
  }

  @sql.Sql(`CREATE TABLE IF NOT EXISTS ${DatabaseConstants.MESSAGES_TABLE_NAME} (
    chatId INTEGER NOT NULL,
    messageId INTEGER NOT NULL,
    outgoing BOOLEAN NOT NULL,
    pinned BOOLEAN DEFAULT FALSE,
    senderId INTEGER NOT NULL,
    senderName TEXT NOT NULL,
    timestamp INTEGER NOT NULL,
    text TEXT NOT NULL,
    mediaType INTEGER,
    editTimestamp INTEGER,
    groupedId INTEGER,
    replyToMessageId INTEGER,
    viewCount INTEGER DEFAULT 0,
    forwardCount INTEGER DEFAULT 0,
    replyCount INTEGER DEFAULT 0,
    fmtEntitiesJson TEXT,
    stickerInfoJson TEXT,
    mediaInfoJson TEXT,
  	PRIMARY KEY (chatId, messageId),
    FOREIGN KEY (chatId) REFERENCES chats(chatId) DEFERRABLE INITIALLY DEFERRED
    FOREIGN KEY (senderId) REFERENCES seen_chats(chatId) DEFERRABLE INITIALLY DEFERRED
    FOREIGN KEY (replyToMessageId) REFERENCES messages(messageId) DEFERRABLE INITIALLY DEFERRED
)`)
  createMessagesTable(): Promise<void> {
    return sql.PromiseNull();
  }

  @sql.Sql(`DROP TABLE IF EXISTS ${DatabaseConstants.MESSAGES_TABLE_NAME}`)
  deleteMessagesTable(): Promise<void> {
    return sql.PromiseNull();
  }

  @sql.SqlInsert("REPLACE INTO messages (chatId, messageId, outgoing, pinned, senderId, senderName, timestamp, text, " +
    "mediaType, editTimestamp, groupedId, replyToMessageId, viewCount, forwardCount, replyCount, fmtEntitiesJson, stickerInfoJson, mediaInfoJson) " +
    "VALUES (#{chatId}, #{messageId}, #{outgoing}, #{pinned}, #{senderId}, #{senderName}, #{timestamp}, #{text}, #{mediaType}," +
    " #{editTimestamp}, #{groupedId}, #{replyToMessageId}, #{viewCount}, #{forwardCount}, #{replyCount}, #{fmtEntitiesJson}, #{stickerInfoJson}, #{mediaInfoJson})")
  insert(@sql.Param("chatId") chatId: number, @sql.Param("messageId") messageId: number,
    @sql.Param("outgoing") outgoing: boolean,
    @sql.Param("pinned") pinned: boolean, @sql.Param("senderId") senderId: number,
    @sql.Param("senderName") senderName: string,
    @sql.Param("timestamp") timestamp: number, @sql.Param("text") text: string,
    @sql.Param("mediaType") mediaType: number,
    @sql.Param("editTimestamp") editTimestamp: number,
    @sql.Param("groupedId") groupedId: number,
    @sql.Param("replyToMessageId") replyToMessageId: number,
    @sql.Param("viewCount") viewCount: number,
    @sql.Param("forwardCount") forwardCount: number,
    @sql.Param("replyCount") replyCount: number,
    @sql.Param("fmtEntitiesJson") fmtEntitiesJson: string,
    @sql.Param("stickerInfoJson") stickerInfoJson: string,
    @sql.Param("mediaInfoJson") mediaInfoJson: string): Promise<void> {
    return sql.PromiseNull();
  }

  @sql.SqlInsert("REPLACE INTO messages (chatId, messageId, outgoing, pinned, senderId, senderName, timestamp, text, " +
    "mediaType, editTimestamp, groupedId, replyToMessageId, viewCount, forwardCount, replyCount, fmtEntitiesJson, stickerInfoJson, mediaInfoJson) " +
    "VALUES (#{message.chatId}, #{message.messageId}, #{message.outgoing}, #{message.pinned}, #{message.senderId}," +
    "#{message.senderName}, #{message.timestamp}, #{message.text}, #{message.mediaType}, " +
    "#{message.editTimestamp}, #{message.groupedId}, #{message.replyToMessageId}, " +
    "#{message.viewCount}, #{message.forwardCount}, #{message.replyCount}, #{message.fmtEntitiesJson}, #{message.stickerInfoJson}, #{message.mediaInfoJson})")
  insertMessage(@sql.Param("message") message: Message): Promise<void> {
    return sql.PromiseNull();
  }

  @sql.SqlInsert("REPLACE INTO messages (chatId, messageId, outgoing, pinned, senderId, senderName, timestamp, text, " +
    "mediaType, editTimestamp, groupedId, replyToMessageId, viewCount, forwardCount, replyCount, fmtEntitiesJson, stickerInfoJson, mediaInfoJson) VALUES #{messagesSql}")
  _insertMessages(@sql.Param("messagesSql", true) messagesSql: string): Promise<void> {
    return sql.PromiseNull();
  }

  async insertMessages(messages: Array<Message>): Promise<void> {
    let messagesSql = messages.map((message) => {
      const fmtJson = message.fmtEntitiesJson ? `"${escapeString(message.fmtEntitiesJson)}"` : 'NULL';
      const stickerJson = message.stickerInfoJson ? `"${escapeString(message.stickerInfoJson)}"` : 'NULL';
      const mediaJson = message.mediaInfoJson ? `"${escapeString(message.mediaInfoJson)}"` : 'NULL';

      // 添加插入日志
      if (message.mediaType === 3 || message.stickerInfoJson || message.mediaInfoJson) {
        console.warn(`[DB_INSERT] MessageDao: inserting messageId=${message.messageId}, mediaType=${message.mediaType}`);
        console.warn(`[DB_INSERT] MessageDao: stickerInfoJson=${message.stickerInfoJson}`);
        console.warn(`[DB_INSERT] MessageDao: mediaInfoJson=${message.mediaInfoJson}`);
      }
      
      return `(${message.chatId}, ${message.messageId}, ${message.outgoing}, ${message.pinned}, ${message.senderId},
      "${escapeString(message.senderName)}", ${message.timestamp}, "${escapeString(message.text)}", ${message.mediaType},
      ${message.editTimestamp || 0}, ${message.groupedId || 0}, ${message.replyToMessageId || 0},
      ${message.viewCount || 0}, ${message.forwardCount || 0}, ${message.replyCount || 0}, ${fmtJson}, ${stickerJson}, ${mediaJson})`;
    }).join(", ");
    return this._insertMessages(messagesSql);
  }

  @sql.SqlQuery("SELECT * FROM messages WHERE chatId = #{chatId} AND messageId = #{messageId}")
  @sql.ReturnType(Message)
  async getMessageById(@sql.Param("chatId") chatId: number, @sql.Param("messageId") messageId: number): Promise<Message> {
    const msg: Message = await sql.PromiseNull();
    if (msg) {
      console.warn(`[FMTENTITIES] MessageDao.getMessageById: before deserialize, fmtEntitiesJson=${msg.fmtEntitiesJson}`);
      msg.deserializeFmtEntities();
      console.warn(`[FMTENTITIES] MessageDao.getMessageById: after deserialize, fmtEntities count=${msg.fmtEntities?.length ?? 0}`);
    }
    return msg;
  }

  @sql.SqlQuery("SELECT * FROM messages WHERE chatId = #{chatId}")
  @sql.ReturnType([Message])
  async getMessagesByChatId(@sql.Param("chatId") chatId: number): Promise<Array<Message>> {
    const messages: Array<Message> = await sql.PromiseNull();
    console.warn(`[DB_QUERY] MessageDao.getMessagesByChatId: loaded ${messages.length} messages for chatId=${chatId}`);
    // 反序列化格式化实体
    for (const msg of messages) {
      console.warn(`[DB_QUERY] MessageDao: messageId=${msg.messageId}, mediaType=${msg.mediaType}`);
      console.warn(`[DB_QUERY] MessageDao: fmtEntitiesJson=${msg.fmtEntitiesJson}`);
      console.warn(`[DB_QUERY] MessageDao: stickerInfoJson=${msg.stickerInfoJson}`);
      console.warn(`[DB_QUERY] MessageDao: mediaInfoJson=${msg.mediaInfoJson}`);
      msg.deserializeFmtEntities();
      console.warn(`[DB_QUERY] MessageDao: after deserialize - fmtEntities count=${msg.fmtEntities?.length ?? 0}, stickerInfo=${JSON.stringify(msg.stickerInfo)}, mediaInfo=${JSON.stringify(msg.mediaInfo)}`);
    }
    return messages;
  }
}

export const messageDao = new MessageDao();