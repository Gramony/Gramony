import { BaseConstants, BreakpointConstants, Logger } from '@ohos/base';
import { HomeConstants } from '../../constants/HomeConstants';
import { NativeParticipant, NativeParticipantRole } from 'libhomogrape.so';
import { image } from '@kit.ImageKit';

@Component
export struct ParticipantItem {
  @StorageProp('currentBreakpoint') currentBreakpoint: string = BreakpointConstants.BREAKPOINT_SM;
  @State isPixelMapReady: boolean = false;
  @State profilePhotoPixelMap: PixelMap | undefined = undefined;
  participant?: NativeParticipant;

  build() {
    Flex({ alignItems: ItemAlign.Center }) {
      // 头像
      if (this.isPixelMapReady && this.profilePhotoPixelMap) {
        Image(this.profilePhotoPixelMap)
          .height(HomeConstants.PROFILE_PHOTO_SIZE)
          .width(HomeConstants.PROFILE_PHOTO_SIZE)
          .borderRadius(HomeConstants.PROFILE_PHOTO_SIZE / 2)
          .margin({ left: $r('app.float.icon_margin_one'), right: $r('app.float.icon_margin_one') })
      } else {
        // 默认头像，显示首字母
        Column() {
          Text(this.getInitials())
            .fontSize(BaseConstants.FONT_SIZE_SIXTEEN)
            .fontWeight(BaseConstants.FONT_WEIGHT_FIVE)
            .fontColor($r('sys.color.font_on_primary'))
        }
        .height(HomeConstants.PROFILE_PHOTO_SIZE)
        .width(HomeConstants.PROFILE_PHOTO_SIZE)
        .borderRadius(HomeConstants.PROFILE_PHOTO_SIZE / 2)
        .backgroundColor(this.getAvatarColor())
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .margin({ left: $r('app.float.icon_margin_one'), right: $r('app.float.icon_margin_one') })
      }

      Flex({ direction: FlexDirection.Column, justifyContent: FlexAlign.Start, alignItems: ItemAlign.Start }) {
        Row() {
          Text(this.participant?.fullName || '')
            .maxLines(1)
            .fontSize(BaseConstants.FONT_SIZE_SIXTEEN)
            .fontWeight(BaseConstants.FONT_WEIGHT_FIVE)
            .lineHeight($r('app.float.text_line_height_two'))
            .fontFamily(BaseConstants.FONT_FAMILY_MEDIUM)
          
          // 显示角色标签
          if (this.participant?.role === NativeParticipantRole.Creator) {
            Text($r('app.string.role_creator'))
              .fontSize(BaseConstants.FONT_SIZE_TEN)
              .fontColor($r('sys.color.font_on_primary'))
              .backgroundColor($r('app.color.color_danger'))
              .borderRadius(4)
              .padding({ left: 4, right: 4, top: 2, bottom: 2 })
              .margin({ left: 8 })
          } else if (this.participant?.role === NativeParticipantRole.Admin) {
            Text($r('app.string.role_admin'))
              .fontSize(BaseConstants.FONT_SIZE_TEN)
              .fontColor($r('sys.color.font_on_primary'))
              .backgroundColor($r('app.color.color_success'))
              .borderRadius(4)
              .padding({ left: 4, right: 4, top: 2, bottom: 2 })
              .margin({ left: 8 })
          }
        }

        if (this.participant?.username) {
          Text('@' + this.participant.username)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .fontSize(BaseConstants.FONT_SIZE_FOURTEEN)
            .fontWeight(BaseConstants.FONT_WEIGHT_FOUR)
            .lineHeight($r('app.float.text_line_height_one'))
            .fontFamily(BaseConstants.FONT_FAMILY_NORMAL)
            .fontColor($r('sys.color.font_secondary'))
        }
      }
      .margin({ left: $r('app.float.icon_margin_one') })

      Blank()
    }
    .width(BaseConstants.FULL_WIDTH)
    .padding({
      top: HomeConstants.CHAT_LIST_ITEM_MARGIN,
      bottom: HomeConstants.CHAT_LIST_ITEM_MARGIN,
    })
    .hoverEffect(HoverEffect.Highlight)
  }

  private getInitials(): string {
    const fullName = this.participant?.fullName || '';
    if (fullName.length === 0) {
      return '?';
    }
    const parts = fullName.split(' ');
    if (parts.length >= 2) {
      return (parts[0].charAt(0) + parts[1].charAt(0)).toUpperCase();
    }
    return fullName.charAt(0).toUpperCase();
  }

  private getAvatarColor(): Color {
    // 根据用户 ID 生成一个固定的颜色
    const userId = this.participant?.userId || 0;
    const colors: Color[] = [
      0xFF5722 as Color, // Deep Orange
      0x2196F3 as Color, // Blue
      0x4CAF50 as Color, // Green
      0x9C27B0 as Color, // Purple
      0xE91E63 as Color, // Pink
      0x00BCD4 as Color, // Cyan
      0xFF9800 as Color, // Orange
      0x607D8B as Color, // Blue Grey
    ];
    return colors[Math.abs(Number(userId)) % colors.length];
  }

  async aboutToAppear(): Promise<void> {
    // 尝试从 photoThumb 创建 PixelMap
    if (this.participant?.photoThumb && this.participant.photoThumb.length > 0) {
      try {
        const buffer = new ArrayBuffer(this.participant.photoThumb.length);
        const view = new Uint8Array(buffer);
        for (let i = 0; i < this.participant.photoThumb.length; i++) {
          view[i] = this.participant.photoThumb[i];
        }
        const imageSource = image.createImageSource(buffer);
        this.profilePhotoPixelMap = await imageSource.createPixelMap();
        this.isPixelMapReady = true;
      } catch (error) {
        Logger.error('ParticipantItem: failed to create pixel map: ' + (error as Error).message);
      }
    }
  }
}
