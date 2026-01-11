import { Logger, Vibrator } from '@ohos/base';
import { promptAction } from '@kit.ArkUI';
import { common, Want } from '@kit.AbilityKit';
import { PushService, CHUCKFANG_APP_ID } from '../utils/push';

@Component
export struct PushSettings {
  @State nickname: string = '';
  @State isSaving: boolean = false;
  @State isTesting: boolean = false;
  @State isUnregistering: boolean = false;
  @State statusType: string = ''; // 'enter_nickname', 'registering', 'register_success', 'register_failed', 'register_first', 'testing', 'test_sent', 'test_failed', 'unregistering', 'unregister_success', 'unregister_failed'
  @State statusDetail: string = ''; // 用于存储额外信息如返回值或错误信息
  @Consume('pageInfo') pageInfo: NavPathStack;
  
  private pushService: PushService | null = null;

  aboutToAppear(): void {
    this.initPushService();
  }

  async initPushService() {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      this.pushService = new PushService(context);
      this.nickname = await this.pushService.loadNickname();
    } catch (e) {
      Logger.error('PushSettings initPushService error: ' + JSON.stringify(e));
    }
  }

  showAppStoreDialog() {
    promptAction.showDialog({
      title: $r('app.string.push_download_app'),
      message: $r('app.string.push_meow_disclaimer'),
      buttons: [{
        text: $r('app.string.push_confirm'),
        color: '#096ad2',
      }]
    },
      (err, data) => {
        if (err) {
          console.info('showDialog err: ' + err);
          return;
        }
        // 拉起应用市场
        const want: Want = {
          uri: `store://appgallery.huawei.com/app/detail?id=${CHUCKFANG_APP_ID}`
        }
        const context = getContext(this) as common.UIAbilityContext;
        context.startAbility(want).then(() => {
          Logger.debug('PushSettings opened app store');
        }).catch((e: Error) => {
          Logger.error('PushSettings startAbility error: ' + JSON.stringify(e));
        })
      }
    );
  }

  async handleRegisterPush() {
    if (!this.pushService) {
      this.statusType = 'register_failed';
      this.statusDetail = 'PushService not initialized';
      return;
    }

    if (!this.nickname || this.nickname.trim() === '') {
      this.statusType = 'enter_nickname';
      this.statusDetail = '';
      Vibrator.kata();
      return;
    }

    this.isSaving = true;
    this.statusType = 'registering';
    this.statusDetail = '';

    try {
      const result = await this.pushService.registerPush(this.nickname.trim());
      this.statusType = 'register_success';
      this.statusDetail = result;
      Vibrator.kata();
    } catch (e) {
      this.statusType = 'register_failed';
      this.statusDetail = JSON.stringify(e);
      Vibrator.kata();
    } finally {
      this.isSaving = false;
    }
  }

  async handleTestPush() {
    if (!this.pushService) {
      this.statusType = 'test_failed';
      this.statusDetail = 'PushService not initialized';
      return;
    }

    if (!this.nickname || this.nickname.trim() === '') {
      this.statusType = 'register_first';
      this.statusDetail = '';
      Vibrator.kata();
      return;
    }

    this.isTesting = true;
    this.statusType = 'testing';
    this.statusDetail = '';

    try {
      const response = await this.pushService.testPush(this.nickname.trim());
      this.statusType = 'test_sent';
      this.statusDetail = response ? response : "Fail";
      Vibrator.kata();
    } catch (e) {
      this.statusType = 'test_failed';
      this.statusDetail = JSON.stringify(e);
      Vibrator.kata();
    } finally {
      this.isTesting = false;
    }
  }

  async handleUnregisterPush() {
    if (!this.pushService) {
      this.statusType = 'unregister_failed';
      this.statusDetail = 'PushService not initialized';
      return;
    }

    if (!this.nickname || this.nickname.trim() === '') {
      this.statusType = 'enter_nickname';
      this.statusDetail = '';
      Vibrator.kata();
      return;
    }

    this.isUnregistering = true;
    this.statusType = 'unregistering';
    this.statusDetail = '';

    try {
      const result = await this.pushService.unregisterPush(this.nickname.trim());
      this.nickname = '';
      this.statusType = 'unregister_success';
      this.statusDetail = result;
      Vibrator.kata();
    } catch (e) {
      this.statusType = 'unregister_failed';
      this.statusDetail = JSON.stringify(e);
      Vibrator.kata();
    } finally {
      this.isUnregistering = false;
    }
  }

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 20 }) {
          // 引导信息
          Column({ space: 12 }) {
            Text($r('app.string.push_install_app_first'))
              .fontSize(14)
              .fontColor('#8a8a8a')
              .textAlign(TextAlign.Center)

            Button($r('app.string.push_download_meow'))
              .width('100%')
              .backgroundColor('#007AFF')
              .fontColor('#f5f5f5')
              .onClick(() => {
                this.showAppStoreDialog();
              })
          }
          .width('100%')
            .padding(20)
            .borderRadius(12)

          Divider()

          // Nickname 输入
          Column({ space: 8 }) {
            Text($r('app.string.push_nickname'))
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .alignSelf(ItemAlign.Start)

            Text($r('app.string.push_nickname_instruction'))
              .fontSize(12)
              .fontColor('#8a8a8a')
              .alignSelf(ItemAlign.Start)

            TextInput({
              placeholder: 'a23bc4de',
              text: this.nickname
            })
              .width('100%')
              .onChange((value: string) => {
                this.nickname = value;
              })
              .maxLength(50)

            Text($r('app.string.push_nickname_note'))
              .fontSize(12)
              .alignSelf(ItemAlign.Start)
          }
          .width('100%')

          // 操作按钮
          Column({ space: 12 }) {
            Button(this.isSaving ? $r('app.string.push_registering_loading') : $r('app.string.push_register_button'))
              .width('100%')
              .backgroundColor('#34C759')
              .enabled(!this.isSaving && !this.isTesting && !this.isUnregistering)
              .onClick(() => {
                this.handleRegisterPush();
              })

            Button(this.isTesting ? $r('app.string.push_testing_loading') : $r('app.string.push_test_button'))
              .width('100%')
              .backgroundColor('#FF9500')
              .enabled(!this.isSaving && !this.isTesting && !this.isUnregistering && this.nickname !== '')
              .onClick(() => {
                this.handleTestPush();
              })

            Button(this.isUnregistering ? $r('app.string.push_unregistering_loading') : $r('app.string.push_unregister_button'))
              .width('100%')
              .backgroundColor('#FF3B30')
              .enabled(!this.isSaving && !this.isTesting && !this.isUnregistering && this.nickname !== '')
              .onClick(() => {
                this.handleUnregisterPush();
              })
          }
          .width('100%')

          // 状态消息
          if (this.statusType === 'enter_nickname') {
            Text($r('app.string.push_enter_nickname'))
              .fontSize(14)
              .fontColor('#FF3B30')
              .textAlign(TextAlign.Center)
              .width('100%')
          }

          if (this.statusType === 'registering') {
            Text($r('app.string.push_registering'))
              .fontSize(14)
              .fontColor('#007AFF')
              .textAlign(TextAlign.Center)
              .width('100%')
          }

          if (this.statusType === 'register_success') {
            Column({ space: 4 }) {
              Text($r('app.string.push_register_success'))
                .fontSize(14)
                .fontColor('#34C759')
                .textAlign(TextAlign.Center)
              if (this.statusDetail) {
                Row({ space: 4 }) {
                  Text($r('app.string.push_return_value'))
                    .fontSize(12)
                    .fontColor('#34C759')
                  Text(this.statusDetail)
                    .fontSize(12)
                    .fontColor('#34C759')
                }
                .justifyContent(FlexAlign.Center)
              }
            }
            .width('100%')
          }

          if (this.statusType === 'register_failed') {
            Column({ space: 4 }) {
              Text($r('app.string.push_register_failed'))
                .fontSize(14)
                .fontColor('#FF3B30')
                .textAlign(TextAlign.Center)
              if (this.statusDetail) {
                Text(this.statusDetail)
                  .fontSize(12)
                  .fontColor('#FF3B30')
                  .textAlign(TextAlign.Center)
              }
            }
            .width('100%')
          }

          if (this.statusType === 'register_first') {
            Text($r('app.string.push_register_first'))
              .fontSize(14)
              .fontColor('#FF3B30')
              .textAlign(TextAlign.Center)
              .width('100%')
          }

          if (this.statusType === 'testing') {
            Text($r('app.string.push_testing'))
              .fontSize(14)
              .fontColor('#007AFF')
              .textAlign(TextAlign.Center)
              .width('100%')
          }

          if (this.statusType === 'test_sent') {
            Column({ space: 4 }) {
              Text($r('app.string.push_test_sent'))
                .fontSize(14)
                .fontColor('#34C759')
                .textAlign(TextAlign.Center)
              if (this.statusDetail) {
                Text(this.statusDetail)
                  .fontSize(12)
                  .fontColor('#34C759')
                  .textAlign(TextAlign.Center)
              }
            }
            .width('100%')
          }

          if (this.statusType === 'test_failed') {
            Column({ space: 4 }) {
              Text($r('app.string.push_test_failed'))
                .fontSize(14)
                .fontColor('#FF3B30')
                .textAlign(TextAlign.Center)
              if (this.statusDetail) {
                Text(this.statusDetail)
                  .fontSize(12)
                  .fontColor('#FF3B30')
                  .textAlign(TextAlign.Center)
              }
            }
            .width('100%')
          }

          if (this.statusType === 'unregistering') {
            Text($r('app.string.push_unregistering'))
              .fontSize(14)
              .fontColor('#007AFF')
              .textAlign(TextAlign.Center)
              .width('100%')
          }

          if (this.statusType === 'unregister_success') {
            Column({ space: 4 }) {
              Text($r('app.string.push_unregister_success'))
                .fontSize(14)
                .fontColor('#34C759')
                .textAlign(TextAlign.Center)
              if (this.statusDetail) {
                Row({ space: 4 }) {
                  Text($r('app.string.push_return_value'))
                    .fontSize(12)
                    .fontColor('#34C759')
                  Text(this.statusDetail)
                    .fontSize(12)
                    .fontColor('#34C759')
                }
                .justifyContent(FlexAlign.Center)
              }
            }
            .width('100%')
          }

          if (this.statusType === 'unregister_failed') {
            Column({ space: 4 }) {
              Text($r('app.string.push_unregister_failed'))
                .fontSize(14)
                .fontColor('#FF3B30')
                .textAlign(TextAlign.Center)
              if (this.statusDetail) {
                Text(this.statusDetail)
                  .fontSize(12)
                  .fontColor('#FF3B30')
                  .textAlign(TextAlign.Center)
              }
            }
            .width('100%')
          }

          Blank()

          // 说明信息
          Column({ space: 8 }) {
            Text($r('app.string.push_instructions_title'))
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .alignSelf(ItemAlign.Start)

            Text($r('app.string.push_instruction_1'))
              .fontSize(13)
              .fontColor('#666')
              .alignSelf(ItemAlign.Start)

            Text($r('app.string.push_instruction_2'))
              .fontSize(13)
              .fontColor('#666')
              .alignSelf(ItemAlign.Start)

            Text($r('app.string.push_instruction_3'))
              .fontSize(13)
              .fontColor('#666')
              .alignSelf(ItemAlign.Start)

            Text($r('app.string.push_instruction_4'))
              .fontSize(13)
              .fontColor('#666')
              .alignSelf(ItemAlign.Start)
          }
          .width('100%')
            .padding(16)
            .backgroundColor('#f9f9f9')
            .borderRadius(8)
        }
        .width('100%')
          .padding(20)
      }
      .width('100%')
        .height('100%')
        .scrollBar(BarState.Auto)
    }
    .onReady((context: NavDestinationContext) => {
      this.pageInfo = context.pathStack;
    })
  }
}
