import { Profile } from "../views/Profile"

@Component
export struct ProfilePage {
  @Consume('pageInfo') pageInfo: NavPathStack;

  @State chatId: string = '';
  @State title: string = 'Profile';
  pathStack: NavPathStack | undefined = undefined;
  pageParam: string = '';

  build() {
    NavDestination() {
      // Layout
      Column() {
        // Title (optional, real title is set via .title() below)
        // Text(this.title).fontSize(20).fontWeight(FontWeight.Bold)

        // Content
        Profile({
          avatar: "",
          name: "Hone Doe",
          bio: "红豆",
        })

        if (!this.chatId) {
          // Missing/invalid param fallback
          Column() {
            Text('Missing chat_id').fontSize(16)
            Button('Go Back')
              .margin({ top: 12 })
              .onClick(() => this.pageInfo.pop())
          }
        } else {
          // TODO: plug in your component
          // Temporary placeholder so page compiles
          Column() {
            Text(`Profile for chat_id: ${this.chatId}`)
              .fontSize(18).fontWeight(FontWeight.Medium)
          }
        }
      }
      .width('100%').height('100%').padding(16)
    }
    .title(this.title, { barStyle: BarStyle.STACK })
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
      this.pageParam = context.pathInfo.param as string;
    })
  }
}
