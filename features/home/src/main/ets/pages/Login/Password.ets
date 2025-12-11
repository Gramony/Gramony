import { Logger } from '@ohos/base'
import { LoginState, password, signOut } from 'libhomogrape.so'
import { emitter } from '@kit.BasicServicesKit';
import { promptAction } from '@kit.ArkUI';
import { EventConstants } from '../../constants/EventConstants';
import { Lottie, LottieController } from "@jjr/lottie_component";

@Entry
@Component
export struct Password {
  @State password: string = '';
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
            animationUri: "https://cdn.jsdelivr.net/npm/tgs-collection/duck-password-unlock.json",
            loop: true,
          })
            .width(256)
            .height(256)
          Text($r('app.string.login_password_hint')).margin({ top: 20 })
          TextInput({ placeholder: $r('app.string.login_password_placeholder'), text: this.password })
            .type(InputType.Password)
            .margin({ top: 20 })
            .onChange((value) => {
              this.password = value;
            })
          Button($r('app.string.login_sign_in')).width(150).margin({ top: 20 })
            .enabled(!this.isLoading)
            .onClick(async () => {
            if (this.password.length == 0) {
              this.errorMessage = 'Password is empty';
              Logger.error(this.errorMessage);
              this.isError = true;
              return;
            }
            this.isLoading = true;
            promptAction.showToast({ message: $r('app.string.loading'), duration: 2000 });
            Logger.debug('Login/Password: ' + this.password);
            let result = await password(this.password);
            if (result == LoginState.LoggedIn) {
              // Index -> PhoneNumber -> VerifyCode -> Password
              if (this.pageInfo.size() != 3) {
                this.errorMessage =
                  'Login/Password LoggedIn but pageInfo size is not 3 (is ' + this.pageInfo.size().toString() + ')';
                Logger.error(this.errorMessage);
                this.isError = true;
                this.isLoading = false;
                promptAction.showToast({ message: $r('app.string.login_failed_retry'), duration: 2000 });
                this.isSignOut = await signOut();
                this.errorMessage = 'Sign out: ' + this.isSignOut.toString();
                return; // TODO: should we clear pageInfo here?
              }
              this.pageInfo.clear();
              emitter.emit(EventConstants.onLoginEvent);
            } else {
              this.errorMessage = 'Password failed: ' + result.toString();
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