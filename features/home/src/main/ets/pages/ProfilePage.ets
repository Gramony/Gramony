import { NativeSeenChat } from "libhomogrape.so";
import { Profile } from "../views/Profile"
import { ComposeListItem, IconType } from "@kit.ArkUI";

@ComponentV2
export struct ProfilePage {
  @Local pageInfo: NavPathStack = new NavPathStack();

  @Param user: NativeSeenChat | null = null;
  @Param chatId: string = '';
  @Param title: Resource | string = 'Profile';
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
            bio: this.user.bio ?? "\n",
          })

          // 详细信息列表
          List() {
            // 用户名
            if (this.user.username) {
              ListItem() {
                ComposeListItem({
                  contentItem: {
                    iconStyle: IconType.SYSTEM_ICON,
                    icon: $r('sys.symbol.edit_colour'),
                    primaryText: '用户名',
                    secondaryText: `@${this.user.username}`
                  }
                })
              }
            }

            // 电话号码
            if (this.user.phone) {
              ListItem() {
                ComposeListItem({
                  contentItem: {
                    iconStyle: IconType.SYSTEM_ICON,
                    icon: $r('sys.media.ohos_ic_public_phone'),
                    primaryText: '电话',
                    secondaryText: this.user.phone
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
                  primaryText: '名',
                  secondaryText: this.user.firstName
                }
              })
            }

            // 姓氏
            if (this.user.lastName) {
              ListItem() {
                ComposeListItem({
                  contentItem: {
                    iconStyle: IconType.SYSTEM_ICON,
                    icon: $r('sys.media.ohos_ic_public_edit'),
                    primaryText: '姓',
                    secondaryText: this.user.lastName
                  }
                })
              }
            }

            // 生日
            if (this.user.dateOfBirth) {
              ListItem() {
                ComposeListItem({
                  contentItem: {
                    iconStyle: IconType.SYSTEM_ICON,
                    icon: $r('sys.symbol.calendar'),
                    primaryText: '生日',
                    secondaryText: this.formatDate(this.user.dateOfBirth)
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
                  primaryText: '联系人',
                  secondaryText: this.user.isContact ? '是' : '否'
                }
              })
            }

            // 互相联系人
            if (this.user.isContact) {
              ListItem() {
                ComposeListItem({
                  contentItem: {
                    iconStyle: IconType.SYSTEM_ICON,
                    icon: $r('sys.symbol.person_2'),
                    primaryText: '互相联系人',
                    secondaryText: this.user.isMutualContact ? '是' : '否'
                  }
                })
              }
            }

            // 论坛标识
            if (this.user.forum) {
              ListItem() {
                ComposeListItem({
                  contentItem: {
                    primaryText: '论坛',
                    secondaryText: '是'
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
                  secondaryText: this.user.chatId.toString()
                }
              })
            }

            // Chat 类型
            ListItem() {
              ComposeListItem({
                contentItem: {
                  iconStyle: IconType.SYSTEM_ICON,
                  icon: $r('sys.media.ohos_ic_public_more'),
                  primaryText: '类型',
                  secondaryText: this.getChatTypeString(this.user.chatType)
                }
              })
            }
          }
          .width('100%')
          .padding({ top: 16 })

        } else if (!this.chatId) {
          // 缺少参数的回退
          Column() {
            Text('Missing chat_id').fontSize(16)
            Button('Go Back')
              .margin({ top: 12 })
              .onClick(() => this.pageInfo.pop())
          }
        } else {
          // 加载中或用户未找到
          Column() {
            Text(`正在加载 chat_id: ${this.chatId}`)
              .fontSize(18).fontWeight(FontWeight.Medium)
          }
        }
      }
      .width('100%').height('100%').padding(16)
    }
    .title(this.user?.fullName ?? this.title, { barStyle: BarStyle.STACK })
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
      this.pageParam = context.pathInfo.param as string;
    })
  }

  private getAvatarFromBytes(bytes: ArrayBuffer | number[]): string {
    // TODO: 将字节数组转换为 base64 或图片 URI
    // 这取决于你的图片处理方式
    return "";
  }

  private formatDate(timestamp: number): string {
    const date = new Date(timestamp * 1000);
    return `${date.getFullYear()}-${(date.getMonth() + 1).toString().padStart(2, '0')}-${date.getDate().toString().padStart(2, '0')}`;
  }

  private getChatTypeString(chatType: number): string {
    // 根据你的 ChatType 枚举值调整
    switch (chatType) {
      case 0: return "用户";
      case 1: return "群组";
      case 2: return "频道";
      default: return "未知";
    }
  }
}