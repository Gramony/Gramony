import { BaseConstants } from '@ohos/base';
import { NativeSeenChat } from 'libhomogrape.so';

@ComponentV2
export struct Contacts {

  @Local contacts: undefined | NativeSeenChat[];

  build(): void {
    List() {
      // ForEach(Array(1).fill("本功能仍在鸿蒙化\n适配中，敬请期待！"), (item: string) => {
        ListItem() {
          Text($r('app.string.unsupported_functionality'))
            .fontSize(BaseConstants.FONT_SIZE_SIXTEEN)
        }.padding({ left: 20 })
      // }, (item: string, index) => index + JSON.stringify(item))
    }
  }
}
