import { BaseConstants, BreakpointConstants, Logger } from '@ohos/base';
import { HomeConstants } from '../../../constants/HomeConstants';
import { ParticipantItem } from '../../../views/Chat/ParticipantItem';
import { ChatDataSource } from '../../../viewmodel/Chat/ChatDataSource';
import { getParticipants, NativeParticipant, ChatType } from 'libhomogrape.so';
import { deviceInfo } from '@kit.BasicServicesKit';
import { curves } from '@kit.ArkUI';

@Component
export struct ParticipantList {
  @StorageProp('currentBreakpoint') currentBreakpoint: string = BreakpointConstants.BREAKPOINT_SM;
  @Consume('pageInfo') pageInfo: NavPathStack;
  @Consume chatDataSource: ChatDataSource;
  @Consume currentChatId: string;
  @State participants: NativeParticipant[] = [];
  @State isLoading: boolean = true;
  @State errorMessage: string = '';
  @State chatName: string = '';
  @State participantCount: number = 0;
  private scroller: Scroller = new Scroller();

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.Top }) {
        if (this.isLoading) {
          Column() {
            LoadingProgress()
              .width(48)
              .height(48)
            Text($r('app.string.loading'))
              .fontSize(BaseConstants.FONT_SIZE_SIXTEEN)
              .fontColor(Color.Grey)
              .margin({ top: 16 })
          }
          .width(BaseConstants.FULL_WIDTH)
          .height(BaseConstants.FULL_HEIGHT)
          .justifyContent(FlexAlign.Center)
        } else if (this.errorMessage.length > 0) {
          Column() {
            SymbolGlyph($r('sys.symbol.exclamationmark_triangle'))
              .fontSize(48)
              .fontColor([$r('sys.color.ohos_id_color_warning')])
            Text(this.errorMessage)
              .fontSize(BaseConstants.FONT_SIZE_SIXTEEN)
              .fontColor($r('sys.color.font_secondary'))
              .margin({ top: 16 })
              .textAlign(TextAlign.Center)
            Button($r('app.string.retry'))
              .margin({ top: 24 })
              .onClick(() => {
                this.loadParticipants();
              })
          }
          .width(BaseConstants.FULL_WIDTH)
          .height(BaseConstants.FULL_HEIGHT)
          .justifyContent(FlexAlign.Center)
          .padding({ left: 24, right: 24 })
        } else {
          List({ scroller: this.scroller }) {
            ListItem() {
              Row()
                .height(HomeConstants.NAV_TITLE_TOP_MARGIN_MINI)
                .width(BaseConstants.FULL_WIDTH)
            }

            ForEach(this.participants, (participant: NativeParticipant, index: number) => {
              ListItem() {
                ParticipantItem({
                  participant: participant
                })
                  .onClick(() => {
                    // TODO: 点击参与者跳转到个人资料页面
                    Logger.debug('ParticipantList: clicked participant ' + participant.userId);
                  })
              }
            }, (participant: NativeParticipant, index: number) => index + '_' + participant.userId.toString())

            ListItem() {
              Row()
                .height((this.currentBreakpoint === BreakpointConstants.BREAKPOINT_LG ||
                  this.currentBreakpoint === BreakpointConstants.BREAKPOINT_XL) ?
                  BaseConstants.FULL_PERCENT :
                  (deviceInfo.deviceType === BaseConstants.DEVICE_TYPES[0] ? $r('app.float.tab_size_lg') :
                  $r('app.float.tab_size')))
                .width(BaseConstants.FULL_WIDTH)
            }
          }
          .height(BaseConstants.FULL_PERCENT)
          .cachedCount(BaseConstants.LAZY_FOR_EACH_CACHED_COUNT)
          .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
          .scrollBar(BarState.Off)
          .animation({ curve: curves.springMotion(0.6, 0.8) })
        }
      }
      .expandSafeArea([SafeAreaType.SYSTEM])
      .height(BaseConstants.FULL_HEIGHT)
      .width(BaseConstants.FULL_WIDTH)
    }
    .title(this.chatName)
    .expandSafeArea([SafeAreaType.SYSTEM])
  }

  aboutToAppear(): void {
    const chat = this.chatDataSource.get(this.currentChatId);
    this.chatName = chat?.name || '';
    this.loadParticipants();
  }

  private async loadParticipants(): Promise<void> {
    this.isLoading = true;
    this.errorMessage = '';
    
    try {
      const chatId = parseInt(this.currentChatId);
      Logger.debug('ParticipantList: loading participants for chat ' + chatId);
      
      const participants = await getParticipants(chatId);
      
      Logger.debug('ParticipantList: loaded ' + participants.length + ' participants');
      this.participants = participants;
      this.participantCount = participants.length;
    } catch (error) {
      Logger.error('ParticipantList: failed to load participants: ' + (error as Error).message);
      this.errorMessage = (error as Error).message;
    } finally {
      this.isLoading = false;
    }
  }
}
