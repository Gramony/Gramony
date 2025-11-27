import { BaseConstants } from '@ohos/base';
import { NativeSeenChat } from 'libhomogrape.so';

@ComponentV2
export struct Contacts {

  @Local contacts: undefined | NativeSeenChat[];

  build(): void {
    List() {
      ForEach(Array(10).fill("联系人"), (item: string) => {
        ListItem() {
          Text(item)
            .fontSize(BaseConstants.FONT_SIZE_SIXTEEN)
        }
      }, (item: string, index) => index + JSON.stringify(item))
    }
  }
}