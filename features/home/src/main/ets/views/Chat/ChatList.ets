/*
 * Copyright (c) 2023 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import { Adaptive, BaseConstants, BreakpointConstants, Logger, mapToRecord, Vibrator } from '@ohos/base';
import { ChatItem } from './ChatItem';
import { HomeTopSearch } from '../common/HomeTopSearch';
import { HomeConstants } from '../../constants/HomeConstants';
import { deviceInfo } from '@kit.BasicServicesKit';
import { loadCachedChats, UpdateChatCallback } from '../../viewmodel/Chat/ChatViewModel';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ChatType, loadChatsWithOffset } from 'libhomogrape.so';
import { Chat } from '../../entities/Chat';
import { HashMap } from '@kit.ArkTS';
import { ChatDataSource } from '../../viewmodel/Chat/ChatDataSource';
import { curves } from '@kit.ArkUI';
import { Home } from '../../../../../Index';

@Component
export struct ChatList {
  @StorageProp('currentBreakpoint') currentBreakpoint: string = BreakpointConstants.BREAKPOINT_SM;
  @Consume chatDataSource: ChatDataSource;
  @Consume currentChatId: string;
  @Link isShowSearchIcon: boolean;
  @Link isFromHideSearchBar: boolean;
  @Consume('pageInfo') pageInfo?: NavPathStack;
  @State searchValue: string = '';
  @State homeTopSearchHeight: Length = 102;
  @Consume isAppFirstLoad: boolean;
  @Consume currentForumId: string;
  @State chatItemTransitionEffect: TransitionEffect | undefined = undefined;
  @Prop isInTopicPage: boolean = false;
  private scroller: Scroller = new Scroller();
  private searchController: SearchController = new SearchController();
  private lastIndexInOneScreen: number = -1;
  private onScrollIndexCounter: number = 0;

  @Styles
  animationStyle() {
    .animation({ curve: curves.springMotion(0.6, 0.8) })
    .transition(TransitionEffect.move(TransitionEdge.TOP)
      .animation({ curve: curves.springMotion(0.6, 0.8) }))
  }

  @Styles
  chatListAnimationStyle() {
    .animation({ curve: curves.springMotion(0.6, 0.8) })
    .transition(this.chatItemTransitionEffect)
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      HomeTopSearch({
        title: $r('app.string.app_name'),
      })
        .expandSafeArea([SafeAreaType.SYSTEM])
        .zIndex(1)
        .onAreaChange((oldValue, newValue) => {
          this.homeTopSearchHeight = newValue.height
          console.debug("homeTopSearchHeight", oldValue.height.toString(), "to", newValue.height)
        })

      List({
        scroller: this.scroller,
      }) {
        // if (this.isShowTopPadding) {
        //   ListItem() {
        //     Row()
        //       .width(BaseConstants.FULL_WIDTH)
        //       .height(BaseConstants.NAV_TITLE_BAR_HEIGHT)
        //       .backgroundColor(Color.Black)
        //   }
        //   .transition(TransitionEffect.move(TransitionEdge.BOTTOM)
        //     .animation({ curve: curves.responsiveSpringMotion() }))
        //   .animation({ curve: curves.responsiveSpringMotion() })
        // }


        // ListItem() {
        //   if (!this.isShowSearchIcon) {
        //     // search bar
        //     Search({
        //       value: this.searchValue,
        //       placeholder: $r('app.string.search_placeholder'),
        //       controller: this.searchController,
        //     })
        //       .width(HomeConstants.CHAT_LIST_SEARCH_BAR_WIDTH)
        //       .height(!this.isShowSearchIcon ? HomeConstants.CHAT_LIST_SEARCH_BAR_HEIGHT :
        //         HomeConstants.CHAT_LIST_SEARCH_BAR_HEIGHT + 20)
        //       .padding({
        //         bottom: HomeConstants.CHAT_LIST_SEARCH_BAR_PADDING
        //       })
        //       .margin({
        //         left: HomeConstants.CHAT_LIST_SEARCH_BAR_MARGIN,
        //         right: HomeConstants.CHAT_LIST_SEARCH_BAR_MARGIN,
        //         // top: HomeConstants.CHAT_LIST_SEARCH_BAR_MARGIN,
        //         // top: 56
        //       })
        //       .textFont({
        //         size: HomeConstants.CHAT_LIST_SEARCH_BAR_FONT_SIZE
        //       })
        //       .animationStyle()
        //   }
        // }
        // .margin({
        //   bottom: this.isShowSearchIcon ? 30 : 0
        // })

        // .animationStyle() // forbidden, will cause a mass

        ListItem() { // Placeholder to prevent HomeTopSearch from overlapping ChatItems
          Row()
            .height(this.homeTopSearchHeight)
            .margin({ bottom: -20 })
            .width(BaseConstants.FULL_WIDTH)
        }

        LazyForEach(this.chatDataSource, (item: Chat, index: number) => {
          ListItem() {
            ChatItem({
              chatData: item,
              isInTopicPage: this.isInTopicPage
            })
              .onClick(() => {
                this.currentChatId = item.chatId.toString();
                let chat = this.chatDataSource.get(this.currentChatId);
                Logger.debug('ChatList ChatItem onClick chatType: ' + chat?.chatType + ' forum: ' + chat?.forum);
                
                // 判断是否为 Split 模式（非 sm 断点）
                const isSplitMode = this.currentBreakpoint !== BreakpointConstants.BREAKPOINT_SM;
                // 判断当前是否已有 ChatDetail 页面
                const hasChatDetail = this.pageInfo && this.pageInfo.size() >= 1 &&
                  this.pageInfo.getParamByName('ChatDetail')?.length > 0;
                
                if (chat?.chatType === ChatType.Group && chat?.forum) {
                  if (this.isInTopicPage) {
                    if (this.currentForumId !== this.currentChatId) {
                      if (isSplitMode && hasChatDetail) {
                        this.pageInfo?.replacePath({ name: 'ChatDetail' });
                      } else {
                        this.pageInfo?.pushPath({ name: 'ChatDetail' });
                      }
                    } else {
                      this.currentForumId = "";
                      this.pageInfo?.pop();
                      return;
                    }
                  } else {
                    if (isSplitMode && hasChatDetail) {
                      this.pageInfo?.replacePath({ name: 'ChatDetail' });
                    } else {
                      this.pageInfo?.pushPath({ name: 'ChatDetail' });
                    }
                  }
                  this.currentForumId = this.currentChatId;
                } else {
                  if (isSplitMode && hasChatDetail) {
                    this.pageInfo?.replacePath({ name: 'ChatDetail' });
                  } else {
                    this.pageInfo?.pushPath({ name: 'ChatDetail' });
                  }
                }
              })
              .animation({ curve: curves.springMotion(0.6, 0.8) })
          }

          // .height(Adaptive.ContactItemHeight(this.currentBreakpoint))
          // .margin({
          //   top: (index === 0 && this.isShowSearchIcon) ? 56 : 0
          // })

          // .animation({ curve: curves.springMotion(0.6, 0.8) })
          // .animationStyle()

          // .animation(this.isShowSearchIcon ? { curve: curves.springMotion(0.6, 0.8) } : {})

          // .chatListAnimationStyle()
        }, (item: Chat, index: number) => index + JSON.stringify(item))

        ListItem() {
          Row()
            .height((this.currentBreakpoint === BreakpointConstants.BREAKPOINT_LG || this.currentBreakpoint === BreakpointConstants.BREAKPOINT_XL) ? BaseConstants.FULL_PERCENT :
              (deviceInfo.deviceType === BaseConstants.DEVICE_TYPES[0] ? $r('app.float.tab_size_lg') :
              $r('app.float.tab_size')))
            .width(BaseConstants.FULL_WIDTH)
        }
      }
      .height(BaseConstants.FULL_PERCENT)
      .cachedCount(BaseConstants.LAZY_FOR_EACH_CACHED_COUNT)
      .padding({
        bottom: deviceInfo.deviceType !== BaseConstants.DEVICE_2IN1 &&
          (this.currentBreakpoint === BreakpointConstants.BREAKPOINT_LG || this.currentBreakpoint === BreakpointConstants.BREAKPOINT_XL) ?
        $r('app.float.tab_content_pb') : $r('app.float.zero')
      })
      .onScrollIndex((start, end, center) => {
        Logger.debug('ChatList onScrollIndex start: ' + start + ' end: ' + end + ' center: ' + center +
          ' lastIndexInOneScreen: ' + this.lastIndexInOneScreen + ' isFromHideSearchBar: ' + this.isFromHideSearchBar);
        if (this.onScrollIndexCounter < 3) {
          this.onScrollIndexCounter++;
          this.lastIndexInOneScreen = end;
          if (this.onScrollIndexCounter === 3) {
            this.chatItemTransitionEffect = undefined;
          }
          return;
        }
        this.chatItemTransitionEffect = undefined;
        if (end === this.lastIndexInOneScreen && !this.isShowSearchIcon && !this.isFromHideSearchBar) {
          this.isShowSearchIcon = true;
          this.isFromHideSearchBar = true;
          Logger.debug('ChatList onScrollIndex isShowSearchIcon: ' + this.isShowSearchIcon);
          // this.scroller.scrollToIndex(0,
          //   true); // wrong, will stop the list from scrolling, should add margin of the first
          // this.homeNavTitleBarStyle = BarStyle.STACK;
          return;
        }
      })
      .onScrollFrameBegin((offset, state) => {
        // Logger.debug('ChatList onScrollFrameBegin offset: ' + offset + ' state: ' + state.toString());
        let result = this.scroller.currentOffset();
        // Logger.debug('ChatList onScrollFrameBegin currentOffset: xOffset: ' + result.xOffset + ' yOffset: ' +
        // result.yOffset);
        if (offset < 0 && result.yOffset < 0 && this.isShowSearchIcon) {
          this.isShowSearchIcon = false;
          this.isFromHideSearchBar = false;
          // Vibrator.kata();
          Logger.debug('ChatList onScrollFrameBegin isShowSearchIcon: ' + this.isShowSearchIcon);
        }
        return { offsetRemain: offset };
      })
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .onReachStart(() => {
        Logger.debug('ChatList onReachStart isFromHideSearchBar: ' + this.isFromHideSearchBar);
        // this.isShowSearchIcon = false;
        // this.homeNavTitleBarStyle = BarStyle.STANDARD;
      })
      .chatListAnimationStyle()
      // .divider({
      //   strokeWidth: $r('app.float.chat_list_divider_stroke_width'),
      //   color: $r('app.float.chat_list_divider_stroke_width'),
      //   startMargin: HomeConstants.CHAT_LIST_DIVIDER_START_MARGIN,
      //   endMargin: HomeConstants.CHAT_LIST_DIVIDER_END_MARGIN
      // })
    }
    .expandSafeArea([SafeAreaType.SYSTEM])
    .onAppear(() => {
      AppStorage.setOrCreate("chatListScroller", this.scroller);
    })

    // .backgroundColor($r('app.color.chat_clicked_bg_color'))
  }

  aboutToAppear(): void {
    if (this.isAppFirstLoad) {
      this.isAppFirstLoad = false;
      this.chatItemTransitionEffect = TransitionEffect.move(TransitionEdge.BOTTOM)
        .animation({ curve: curves.springMotion(0.6, 0.8) });
    } else {
      this.chatItemTransitionEffect = undefined;
    }
  }
}