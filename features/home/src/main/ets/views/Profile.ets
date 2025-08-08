@ComponentV2
export struct Profile {
  @Param name: string = ""
  @Param avatar: string = ""
  @Param bio: string = ""

  build() {
    Column() {
      Image("file://" + this.avatar)
        .width(100)
        .height(100)
        .borderRadius(50)

      Text(this.name)
        .fontSize(24)
        .fontWeight(FontWeight.Bold)

      Row({ space: 10 }) {
        Button('Call')
          .width(100)
          .height(40)
          .backgroundColor('#2196F3')
          .fontColor(Color.White)
        Button('Chat')
          .width(100)
          .height(40)
          .backgroundColor('#4CAF50')
          .fontColor(Color.White)
      }

      Text('Joined: January 2023')
        .fontSize(14)
        .fontColor(Color.Gray)
        .margin({ top: 20 })

      Text(this.bio)
        .fontSize(16)
        .margin({ top: 10, left: 20, right: 20 })
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
