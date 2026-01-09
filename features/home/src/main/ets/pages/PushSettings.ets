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
  @State statusMessage: string = '';
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
      title: `前去应用市场`,
      message: 'MeoW为一款专注于鸿蒙推送服务的应用，与本应用无关。请您注意相应的隐私政策与风险。',
      buttons: [{
        text: '确定',
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
      this.statusMessage = '请输入昵称';
      Vibrator.kata();
      return;
    }

    this.isSaving = true;
    this.statusMessage = '正在注册推送…';

    try {
      const pushUrl = `https://gramonotify.dokodemodoor.workers.dev/tg/simplepush/${encodeURIComponent(this.nickname.trim())}`;

      const result = await registerPush(pushUrl);
      await this.saveNickname();
      await this.saveLastRegisterTime();

      this.statusMessage = `推送注册成功！\n返回值: ${result}`;
      Vibrator.kata();

      Logger.debug(`PushSettings registered push with URL: ${pushUrl}, result: ${result}`);
    } catch (e) {
      this.statusMessage = '推送注册失败: ' + JSON.stringify(e);
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
      this.statusMessage = '请先注册推送';
      Vibrator.kata();
      return;
    }

    this.isTesting = true;
    this.statusMessage = '正在测试推送...';

    try {
      const response = await testPush(this.nickname.trim());
      this.statusMessage = `测试推送已发送！\n${response}`;
      Vibrator.kata();
      Logger.debug(`handleTestPush response: ${response}`);
    } catch (e) {
      this.statusMessage = '测试推送失败: ' + JSON.stringify(e);
      Logger.error('PushSettings handleTestPush error: ' + JSON.stringify(e));
      Vibrator.kata();
    } finally {
      this.isTesting = false;
    }
  }

  async handleUnregisterPush() {
    if (!this.nickname || this.nickname.trim() === '') {
      this.statusMessage = '请输入昵称';
      Vibrator.kata();
      return;
    }

    this.isUnregistering = true;
    this.statusMessage = '正在取消注册...';

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
      this.statusMessage = `取消注册成功！\n返回值: ${result}`;
      Vibrator.kata();

      Logger.debug(`PushSettings unregistered push with URL: ${pushUrl}, result: ${result}`);
    } catch (e) {
      this.statusMessage = '取消注册失败: ' + JSON.stringify(e);
      Logger.error('PushSettings handleUnregisterPush error: ' + JSON.stringify(e));
      Vibrator.kata();
    } finally {
      this.isUnregistering = false;
    }
  }

  build() {
    NavDestination() {
      Column({ space: 20 }) {
        // 引导信息
        Column({ space: 12 }) {
          Text('推送通知设置')
            .fontSize(28)
            .fontWeight(FontWeight.Bold)

          Text('要接收推送通知，您需要先安装配套的推送应用')
            .fontSize(14)
            .fontColor('#8a8a8a')
            .textAlign(TextAlign.Center)

          Button('下载推送应用')
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
          Text('昵称')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .alignSelf(ItemAlign.Start)

          Text('在 MeoW → 我的中第三个选项里复制一串字母和数字')
            .fontSize(12)
            .fontColor('#8a8a8a')
            .alignSelf(ItemAlign.Start)

          TextInput({ placeholder: 'a23bc4de', text: this.nickname })
            .width('100%')
            .onChange((value: string) => {
              this.nickname = value;
            })
            .maxLength(50)

          Text('此 Nickname 将用于接收推送通知')
            .fontSize(12)
            .fontColor('#8a8a8a')
            .alignSelf(ItemAlign.Start)
        }
        .width('100%')

        // 操作按钮
        Column({ space: 12 }) {
          Button(this.isSaving ? '注册中...' : '注册推送')
            .width('100%')
            .backgroundColor('#34C759')
            .enabled(!this.isSaving && !this.isTesting && !this.isUnregistering)
            .onClick(() => {
              this.handleRegisterPush();
            })

          Button(this.isTesting ? '测试中...' : '测试推送')
            .width('100%')
            .backgroundColor('#FF9500')
            .enabled(!this.isSaving && !this.isTesting && !this.isUnregistering && this.nickname !== '')
            .onClick(() => {
              this.handleTestPush();
            })
          
          Button(this.isUnregistering ? '取消中...' : '取消推送')
            .width('100%')
            .backgroundColor('#FF3B30')
            .enabled(!this.isSaving && !this.isTesting && !this.isUnregistering && this.nickname !== '')
            .onClick(() => {
              this.handleUnregisterPush();
            })
        }
        .width('100%')

        // 状态消息
        if (this.statusMessage) {
          Text(this.statusMessage)
            .fontSize(14)
            .fontColor(this.statusMessage.includes('成功') ? '#34C759' : '#FF3B30')
            .textAlign(TextAlign.Center)
            .width('100%')
        }

        Blank()

        // 说明信息
        Column({ space: 8 }) {
          Text('使用说明')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .alignSelf(ItemAlign.Start)

          Text('1. 先下载并安装推送应用')
            .fontSize(13)
            .fontColor('#666')
            .alignSelf(ItemAlign.Start)

          Text('2. 在推送应用中注册您的 Nickname')
            .fontSize(13)
            .fontColor('#666')
            .alignSelf(ItemAlign.Start)

          Text('3. 在此输入相同的 Nickname 并注册')
            .fontSize(13)
            .fontColor('#666')
            .alignSelf(ItemAlign.Start)

          Text('4. 点击测试按钮验证推送是否正常')
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
        .height('100%')
        .padding(20)
    }
    .title('推送设置')
      .onReady((context: NavDestinationContext) => {
        this.pageInfo = context.pathStack;
      })
  }
}
