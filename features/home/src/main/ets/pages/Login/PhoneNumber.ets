import { Logger } from '@ohos/base'
import { LoginState, login, signOut } from 'libhomogrape.so'
import { emitter } from '@kit.BasicServicesKit';
import { promptAction } from '@kit.ArkUI';
import { EventConstants } from '../../constants/EventConstants';

import { Lottie, LottieController } from "@jjr/lottie_component";

@Entry
@Component
export struct PhoneNumber {
  @State phone: string = '';
  @State isError: boolean = false;
  @State isSignOut: boolean = false;
  @State isLoading: boolean = false;
  @State errorMessage: string = '';
  @Consume('pageInfo') pageInfo: NavPathStack;

  private controller = new LottieController()

  build() {
    NavDestination() {
      Column() {
        Column() {
          Lottie({
            autoPlay: true,
            controller: this.controller,
            // animationUri: "https://lottie.host/ab168ead-f877-40cd-90e3-4d09fff05b42/F8ZzJ6R846.json",
            animationUri: "https://cdn.jsdelivr.net/npm/tgs-collection/duck-phone.json",
            loop: true,
          })
            .width(256)
            .height(256)
          Text($r('app.string.login_phone_hint')).margin({ top: 20 })
          TextInput({ placeholder: $r('app.string.login_phone_placeholder'), text: this.phone })
            .type(InputType.PhoneNumber)
            .placeholderFont({
              size: 28,
            })
            .fontFamily("HarmonyOS Sans Digit")
            .fontSize(28)
            .margin({ top: 20 })
            .onChange((value) => {
              this.phone = value;
            })
          Button($r('app.string.login_sign_in')).width(150).margin({ top: 20 })
            .enabled(!this.isLoading)
            .onClick(async () => {
            if (this.phone.length == 0) {
              this.errorMessage = 'Phone number is empty';
              Logger.error(this.errorMessage);
              this.isError = true;
              return;
            }
            this.isLoading = true;
            promptAction.showToast({ message: $r('app.string.loading'), duration: 2000 });
            Logger.debug('Login/Phone number: ' + this.phone);
            let result = await login(this.phone);
            if (result == LoginState.LoggedIn) {
              // Index -> PhoneNumber
              if (this.pageInfo.size() != 1) {
                this.errorMessage =
                  'Login/PhoneNumber LoggedIn but pageInfo size is not 1 (is ' + this.pageInfo.size().toString() + ')';
                Logger.error(this.errorMessage);
                this.isError = true;
                this.isLoading = false;
                promptAction.showToast({ message: $r('app.string.login_failed_retry'), duration: 2000 });
                this.isSignOut = await signOut();
                this.errorMessage = 'Sign out: ' + this.isSignOut.toString();
                return;
              }
              this.pageInfo.clear();
              emitter.emit(EventConstants.onLoginEvent);
            } else if (result == LoginState.CodeRequired) {
              this.isLoading = false;
              this.pageInfo.pushPath({ name: 'Login/VerifyCode' });
            } else {
              this.errorMessage = 'VerifyCode failed: ' + result.toString();
              Logger.error(this.errorMessage);
              this.isError = true;
              this.isLoading = false;
              promptAction.showToast({ message: $r('app.string.login_failed_retry'), duration: 2000 });
            }

            return;
          })
            .bindPopup(this.isError, {
              message: this.errorMessage,
            })
        }
        .padding(20)
        .constraintSize({ maxWidth: 400 })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    }
    .hideTitleBar(true)
  }
}