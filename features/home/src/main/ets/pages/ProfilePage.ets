import { NativeSeenChat } from "libhomogrape.so";
import { Profile } from "../views/Profile"
import { ComposeListItem, IconType } from "@kit.ArkUI";
import { PushSettings } from './PushSettings';

@ComponentV2
export struct ProfilePage {
  @Local pageInfo: NavPathStack = new NavPathStack();
  @Param user: NativeSeenChat | null = null;
  @Param chatId: string = '';
  @Param title: Resource | string = 'Profile';
  @Param device: string | false = false;
  @Local showPushSettings: boolean = false;
  pathStack: NavPathStack | undefined = undefined;
  pageParam: string = '';

  build() {
    NavDestination() {
      Column() {
        if (this.user) {
          // 显示用户资料
          Profile({
            avatar: this.user.photoThumb ? this.getAvatarFromBytes(this.user.photoThumb) : "",
            name: this.user.fullName,
            bio: this.user.bio ?? "",
          })

          // 详细信息列表
          this.showList(this.user)
          Row().height(48)
        } else if (!this.chatId) {
          // 缺少参数的回退
          Column() {
            Text('Missing chat_id').fontSize(16)
            Button('Go Back')
              .margin({ top: 48 })
              .onClick(() => this.pageInfo.pop())
          }
        } else {
          // 加载中或用户未找到
          Column() {
            Text($r('app.string.profile_loading_chat') + this.chatId)
              .fontSize(18).fontWeight(FontWeight.Medium)
          }
        }
      }
      .width('100%')
      .padding(16)
    }
    .bindSheet($$this.showPushSettings, this.pushSettingsSheet(), {
      height: '90%',
      showClose: true,
      title: { title: $r('app.string.push_settings') },
      onDisappear: () => {
        this.showPushSettings = false;
      }
    })
    .title(this.user?.fullName ?? this.title, { barStyle: BarStyle.STACK })
    .onAppear(() => {
      if (!this.user) {

      }
    })
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
      this.pageParam = context.pathInfo.param as string;
    })
  }

  @Builder
  showList(user: NativeSeenChat) {
    List() {
      // 用户名
      if (user.username) {
        ListItem() {
          ComposeListItem({
            contentItem: {
              iconStyle: IconType.SYSTEM_ICON,
              icon: $r('sys.symbol.edit_colour'),
              primaryText: $r('app.string.profile_username'),
              secondaryText: `@${user.username}`
            }
          })
        }
      }

      // 电话号码
      if (user.phone) {
        ListItem() {
          ComposeListItem({
            contentItem: {
              iconStyle: IconType.SYSTEM_ICON,
              icon: $r('sys.media.ohos_ic_public_phone'),
              primaryText: $r('app.string.profile_phone'),
              secondaryText: user.phone
            }
          })
        }
      }

      // 名字
      ListItem() {
        ComposeListItem({
          contentItem: {
            iconStyle: IconType.SYSTEM_ICON,
            icon: $r('sys.media.ohos_ic_public_edit'),
            primaryText: $r('app.string.profile_first_name'),
            secondaryText: user.firstName
          }
        })
      }

      // 姓氏
      if (user.lastName) {
        ListItem() {
          ComposeListItem({
            contentItem: {
              iconStyle: IconType.SYSTEM_ICON,
              icon: $r('sys.media.ohos_ic_public_edit'),
              primaryText: $r('app.string.profile_last_name'),
              secondaryText: user.lastName
            }
          })
        }
      }

      // 生日
      if (user.dateOfBirth) {
        ListItem() {
          ComposeListItem({
            contentItem: {
              iconStyle: IconType.SYSTEM_ICON,
              icon: $r('sys.symbol.calendar'),
              primaryText: $r('app.string.profile_birthday'),
              secondaryText: this.formatDate(user.dateOfBirth)
            }
          })
        }
      }

      // 联系人状态
      ListItem() {
        ComposeListItem({
          contentItem: {
            iconStyle: IconType.SYSTEM_ICON,
            icon: $r('sys.symbol.person'),
            primaryText: $r('app.string.profile_contact'),
            secondaryText: user.isContact ? $r('app.string.profile_yes') : $r('app.string.profile_no')
          }
        })
      }

      // 互相联系人
      if (user.isContact) {
        ListItem() {
          ComposeListItem({
            contentItem: {
              iconStyle: IconType.SYSTEM_ICON,
              icon: $r('sys.symbol.person_2'),
              primaryText: $r('app.string.profile_mutual_contact'),
              secondaryText: user.isMutualContact ? $r('app.string.profile_yes') : $r('app.string.profile_no')
            }
          })
        }
      }

      // 论坛标识
      if (user.forum) {
        ListItem() {
          ComposeListItem({
            contentItem: {
              primaryText: $r('app.string.profile_forum'),
              secondaryText: $r('app.string.profile_yes')
            }
          })
        }
      }

      // Chat ID (调试用)
      ListItem() {
        ComposeListItem({
          contentItem: {
            iconStyle: IconType.SYSTEM_ICON,
            icon: $r('sys.symbol.eye'),
            primaryText: 'Chat ID',
            secondaryText: user.chatId.toString()
          }
        })
      }

      // Chat 类型
      ListItem() {
        ComposeListItem({
          contentItem: {
            iconStyle: IconType.SYSTEM_ICON,
            icon: $r('sys.media.ohos_ic_public_more'),
            primaryText: $r('app.string.profile_type'),
            secondaryText: this.getChatTypeString(user.chatType)
          }
        })
      }

      if (this.device) {
        ListItem() {
          ComposeListItem({
            contentItem: {
              iconStyle: IconType.SYSTEM_ICON,
              icon: $r('sys.symbol.paperplane'),
              primaryText: $r('app.string.profile_device'),
              secondaryText: this.device,
            }
          })
        }

        // 推送设置入口
        ListItem() {
          Button({ type: ButtonType.Normal }) {
            Row() {
              SymbolGlyph($r('sys.symbol.bell'))
                .fontSize(24)
                .fontColor([Color.Blue])
              Column({ space: 4 }) {
                Text($r('app.string.push_settings'))
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .alignSelf(ItemAlign.Start)
                Text($r('app.string.push_settings_desc'))
                  .fontSize(14)
                  .fontColor('#8a8a8a')
                  .alignSelf(ItemAlign.Start)
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              .margin({ left: 12 })
            }
            .width('100%')
            .padding(12)
          }
          .width('100%')
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            console.log('Push Settings button clicked');
            this.showPushSettings = true;
          })
        }
      }
    }
    .width('100%')
    .padding({ top: 4 })
  }

  @Builder
  pushSettingsSheet() {
    Column() {
      PushSettings()
    }
    .width('100%')
    .height('100%')
  }

  private getAvatarFromBytes(bytes: ArrayBuffer | number[]): string {
    // TODO: 将字节数组转换为 base64 或图片 URI
    // 这取决于你的图片处理方式
    return "";
  }

  private formatDate(timestamp: number): string {
    const date = new Date(timestamp * 1000);
    return `${date.getFullYear()}-${(date.getMonth() + 1).toString().padStart(2, '0')}-${date.getDate()
      .toString()
      .padStart(2, '0')}`;
  }

  private getChatTypeString(chatType: number): ResourceStr {
    // 根据 ChatType 枚举值调整
    switch (chatType) {
      case 0:
        return $r('app.string.profile_chat_type_user');
      case 1:
        return $r('app.string.profile_chat_type_group');
      case 2:
        return $r('app.string.profile_chat_type_channel');
      default:
        return $r('app.string.profile_chat_type_unknown');
    }
  }
}