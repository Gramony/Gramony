import { NativeSeenChat } from "libhomogrape.so";
import { getMe } from "libhomogrape.so"
import { ProfilePage } from "./ProfilePage";
import { deviceInfo } from '@kit.BasicServicesKit';

@ComponentV2
export struct Me {
  @Local meInfo?: NativeSeenChat = undefined;
  displayVersionInfo: string = deviceInfo.displayVersion; // product version
  osFullNameInfo: string = deviceInfo.osFullName; // system version
  versionIdInfo: string = deviceInfo.versionId; // version ID

  build(): void {
    Column() {
      ProfilePage({
        user: this.meInfo,
        chatId: this.meInfo ? this.meInfo.chatId.toString() : '',
        title: $r('app.string.me'),
        device: deviceInfo.versionId ?? "HarmonyOS NEXT",
      })
    }.onAppear(async () => {
      this.meInfo = await getMe();
    })
  }
}