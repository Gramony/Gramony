import { Logger, Vibrator } from '@ohos/base';
import { promptAction } from '@kit.ArkUI';
import { common, Want } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { testPush } from '../utils';
import { registerPush, unregisterPush } from 'libhomogrape.so';

const PUSH_NICKNAME_KEY = 'push_nickname';
const CHUCKFANG_APP_ID = 'com.chuckfang.meow';

@Component
export struct PushSettings {
  @State nickname: string = '';
  @State isSaving: boolean = false;
  @State isTesting: boolean = false;
  @State isUnregistering: boolean = false;
  @State statusType: string = ''; // 'enter_nickname', 'registering', 'register_success', 'register_failed', 'register_first', 'testing', 'test_sent', 'test_failed', 'unregistering', 'unregister_success', 'unregister_failed'
  @State statusDetail: string = ''; // 用于存储额外信息如返回值或错误信息
  @Consume('pageInfo') pageInfo: NavPathStack;

  aboutToAppear(): void {
    this.loadNickname();
  }

  async loadNickname() {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const dataPreferences = await preferences.getPreferences(context, 'push_settings');
      this.nickname = await dataPreferences.get(PUSH_NICKNAME_KEY, '') as string;
    } catch (e) {
      Logger.error('PushSettings loadNickname error: ' + JSON.stringify(e));
    }
  }

  async saveNickname() {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const dataPreferences = await preferences.getPreferences(context, 'push_settings');
      await dataPreferences.put(PUSH_NICKNAME_KEY, this.nickname);
      await dataPreferences.flush();
    } catch (e) {
      Logger.error('PushSettings saveNickname error: ' + JSON.stringify(e));
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
      const pushUrl = `https://gramonotify.dokodemodoor.workers.dev/tg/simplepush/${encodeURIComponent(this.nickname.trim())}`;

      const result = await registerPush(pushUrl);
      await this.saveNickname();
      await this.saveLastRegisterTime();

      this.statusType = 'register_success';
      this.statusDetail = result;
      Vibrator.kata();

      Logger.debug(`PushSettings registered push with URL: ${pushUrl}, result: ${result}`);
    } catch (e) {
      this.statusType = 'register_failed';
      this.statusDetail = JSON.stringify(e);
      Logger.error('PushSettings handleRegisterPush error: ' + JSON.stringify(e));
      Vibrator.kata();
    } finally {
      this.isSaving = false;
    }
  }

  async saveLastRegisterTime() {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const dataPreferences = await preferences.getPreferences(context, 'push_settings');
      await dataPreferences.put('push_last_register_time', Date.now());
      await dataPreferences.flush();
    } catch (e) {
      Logger.error('PushSettings saveLastRegisterTime error: ' + JSON.stringify(e));
    }
  }

  async handleTestPush() {
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
      const response = await testPush(this.nickname.trim());
      this.statusType = 'test_sent';
      this.statusDetail = response;
      Vibrator.kata();
      Logger.debug(`handleTestPush response: ${response}`);
    } catch (e) {
      this.statusType = 'test_failed';
      this.statusDetail = JSON.stringify(e);
      Logger.error('PushSettings handleTestPush error: ' + JSON.stringify(e));
      Vibrator.kata();
    } finally {
      this.isTesting = false;
    }
  }

  async handleUnregisterPush() {
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
      const pushUrl = `https://gramonotify.dokodemodoor.workers.dev/tg/simplepush/${encodeURIComponent(this.nickname.trim())}`;

      const result = await unregisterPush(pushUrl);

      // 清除保存的数据
      const context = getContext(this) as common.UIAbilityContext;
      const dataPreferences = await preferences.getPreferences(context, 'push_settings');
      await dataPreferences.delete(PUSH_NICKNAME_KEY);
      await dataPreferences.delete('push_last_register_time');
      await dataPreferences.flush();

      this.nickname = '';
      this.statusType = 'unregister_success';
      this.statusDetail = result;
      Vibrator.kata();

      Logger.debug(`PushSettings unregistered push with URL: ${pushUrl}, result: ${result}`);
    } catch (e) {
      this.statusType = 'unregister_failed';
      this.statusDetail = JSON.stringify(e);
      Logger.error('PushSettings handleUnregisterPush error: ' + JSON.stringify(e));
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
              .onClick(() => {
                this.showAppStoreDialog();
              })
          }
          .width('100%')
            .padding(20)
            .backgroundColor('#f5f5f5')
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
              .fontColor('#8a8a8a')
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
