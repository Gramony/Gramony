import { promptAction } from "@kit.ArkUI"
import { BaseConstants } from '@ohos/base';

@ComponentV2
export struct Profile {
  @Param name: string = ""
  @Param avatar: string = ""
  @Param bio: string = ""

  build() {
    Column() {
      Image("file://" + this.avatar)
        .width(40)
        .height(40)
        // .borderRadius(50)

      Text(this.name)
        .fontSize(24)
        .fontWeight(FontWeight.Bold)

      Row({ space: 8 }) {
        Button('Call')
          .width(100)
          .height(40)
          .backgroundColor($r('app.color.background_color_grey'))
          .onClick(() => {
            try {
              promptAction.showToast({
                message: $r('app.string.unsupported_functionality'),
                duration: 2000
              });
            } catch (e) { }
          })
        Button('Chat')
          .width(100)
          .height(40)
          .backgroundColor($r('sys.color.ohos_id_color_emphasize'))
          .fontColor($r('sys.color.font_on_primary'))
          .onClick(() => {
            try {
              promptAction.showToast({
                message: $r('app.string.unsupported_functionality'),
                duration: 2000
              });
            } catch (e) { }
          })
      }

      Text(this.bio)
        .fontSize(BaseConstants.FONT_SIZE_SIXTEEN)
        .margin({ top: 8, left: 20, right: 20 })
        .textAlign(TextAlign.Center)

      // Button('Edit Profile')
      //   .width(200)
      //   .height(50)
      //   .backgroundColor('#9E9E9E')
      //   .fontColor(Color.White)
      //   .margin({ top: 20 })
    }
  }
}
