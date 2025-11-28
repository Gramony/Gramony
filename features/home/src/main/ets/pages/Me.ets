import { NativeSeenChat } from "libhomogrape.so";
import { getMe } from "libhomogrape.so"
import { ProfilePage } from "./ProfilePage";

@ComponentV2
export struct Me {
  @Local meInfo?: NativeSeenChat = undefined;

  build(): void {
    Column() {
      ProfilePage({
        user: this.meInfo,
        chatId: this.meInfo ? this.meInfo.chatId.toString() : '',
        title: $r('app.string.me'),
      })
    }.onAppear(async () => {
      this.meInfo = await getMe();
    })
  }
}