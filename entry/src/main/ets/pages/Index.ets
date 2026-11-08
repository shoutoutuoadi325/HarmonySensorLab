import { deviceInfo } from '@kit.BasicServicesKit';
import { SensorRow, SensorSnapshot } from '../model/SensorModels';
import { SensorController } from '../services/SensorController';
import { SensorCardView } from '../components/SensorCardView';
import { PRIVACY_TEXT } from '../model/PrivacyText';


@Entry
@Component
struct Index {
  @State snapshot: SensorSnapshot = SensorController.shared().snapshot();
  @State viewportWidth: number = 360;
  @State started: boolean = false;
  @State showDetails: boolean = false;
  private controller: SensorController = SensorController.shared();
  private wearable: boolean = deviceInfo.deviceType === 'wearable';
  private television: boolean = deviceInfo.deviceType === 'tv';
  private colors: string[] = ['#087F8C', '#B64A34', '#7356AF', '#A57205', '#386AAB', '#A44579'];
  aboutToAppear(): void {
    this.controller.onChange = () => { this.snapshot = this.controller.snapshot(); };
    this.snapshot = this.controller.snapshot();
  }
  aboutToDisappear(): void { this.controller.onChange = undefined; }
  private textSize(): number { return this.television ? 20 : (this.wearable ? 12 : 14); }
  private buttonSize(): number { return this.television ? 56 : 44; }
  private cardWidth(): number {
    const available: number = this.viewportWidth - (this.wearable ? 48 : 40);
    const columns: number = this.wearable ? 1 : (available >= 1120 ? 3 : (available >= 680 ? 2 : 1));
    return Math.max(150, (available - (columns - 1) * 16) / columns);
  }
  private currentRow(row: SensorRow): SensorRow {
    const latest: SensorRow | undefined = this.snapshot.rows.find((item: SensorRow) => item.key === row.key);
    return latest === undefined ? row : latest;
  }
  private showPrivacy(): void {
    this.getUIContext().showAlertDialog({ title: '本机数据与隐私', message: PRIVACY_TEXT,
      autoCancel: true, primaryButton: { value: '知道了', action: () => {} } });
  }
  @Builder
  Controls() {
    Flex({ wrap: FlexWrap.Wrap, alignItems: ItemAlign.Center }) {
      Button(this.snapshot.paused ? '继续采集' : '暂停采集').fontSize(this.textSize()).height(this.buttonSize())
        .margin({ right: 10, bottom: 10 }).backgroundColor('#102C41').defaultFocus(true)
        .onClick(() => this.controller.setPaused(!this.snapshot.paused))
      Select([{ value: '1 Hz · 省电' }, { value: '5 Hz · 默认' }, { value: '10 Hz' }, { value: '20 Hz' }])
        .selected([1000, 200, 100, 50].indexOf(this.snapshot.intervalMs))
        .value(['1 Hz · 省电', '5 Hz · 默认', '10 Hz', '20 Hz'][[1000, 200, 100, 50].indexOf(this.snapshot.intervalMs)])
        .font({ size: this.textSize() }).height(this.buttonSize()).margin({ right: 10, bottom: 10 })
        .onSelect((index: number) => this.controller.setIntervalMs([1000, 200, 100, 50][index]))
        .accessibilityText('采集请求频率，硬件实际频率可能不同')
      Button(this.snapshot.refreshing ? '正在刷新' : '刷新设备').fontSize(this.textSize()).height(this.buttonSize())
        .margin({ right: 10, bottom: 10 }).backgroundColor('#E5EEF5').fontColor('#102C41').enabled(!this.snapshot.refreshing)
        .onClick(() => { this.controller.refresh(); })
      Button('清空曲线').fontSize(this.textSize()).height(this.buttonSize()).margin({ right: 10, bottom: 10 })
        .backgroundColor('#E5EEF5').fontColor('#102C41').onClick(() => this.controller.clearHistory())
      if (this.snapshot.rows.some((row: SensorRow) => row.id === 265 || row.id === 266)) {
        Button('授权运动').fontSize(this.textSize()).height(this.buttonSize()).margin({ right: 10, bottom: 10 })
          .backgroundColor('#E5EEF5').fontColor('#102C41').onClick(() => { this.controller.authorizeMotion(); })
      }
    }.width('100%')
    Text('频率为请求值；事件型传感器仅在变化时上报。曲线按接收时间绘制，保留最近 60 秒，最多 240 点。')
      .fontSize(this.textSize()).fontColor('#526679').width('100%')
  }
  build() {
    Scroll() {
      Column({ space: this.wearable ? 16 : 24 }) {
        Column({ space: 8 }) {
          Text('SENSOR / LOCAL').fontSize(this.wearable ? 10 : 12).fontWeight(FontWeight.Bold).fontColor('#087F8C').letterSpacing(2)
          Text('传感器观测').fontSize(this.wearable ? 21 : (this.television ? 40 : 32)).fontWeight(FontWeight.Bold).fontColor('#102C41')
          Text('本机 · 前台采集 · 数据不上传').fontSize(this.textSize()).fontColor('#526679')
        }.width('100%').alignItems(this.wearable ? HorizontalAlign.Center : HorizontalAlign.Start)
        if (!this.started) {
          Column({ space: 14 }) {
            Text('观测这台设备').fontSize(this.wearable ? 18 : 24).fontWeight(FontWeight.Bold).fontColor('#102C41')
            Text('仅展示公开 API 的真实回调。样本只保存在内存，退到后台即停止采集；健康数据暂不采集。')
              .fontSize(this.textSize()).fontColor('#526679')
            Button('开始观测').fontSize(this.textSize()).height(this.buttonSize()).backgroundColor('#102C41').defaultFocus(true)
              .onClick(() => { this.started = true; this.controller.setPaused(false); })
          }.padding(20).width('100%').backgroundColor(Color.White).borderRadius(20)
        } else {
          this.Controls()
          Row() {
            Text('本机硬件 · ' + this.snapshot.rows.length.toString() + ' 项').fontSize(this.wearable ? 16 : 20)
              .fontWeight(FontWeight.Bold).fontColor('#102C41').layoutWeight(1)
            Button(this.showDetails ? '收起详情' : '硬件详情').fontSize(this.textSize()).height(this.buttonSize())
              .backgroundColor('#E5EEF5').fontColor('#102C41').onClick(() => { this.showDetails = !this.showDetails; })
          }.width('100%')
          if (this.snapshot.enumerationError.length > 0) {
            Text('无法枚举传感器：' + this.snapshot.enumerationError + '\n可以点击“刷新设备”重试。')
              .fontSize(this.textSize()).fontColor('#A54721').padding(20).width('100%').backgroundColor('#FFF3E8').borderRadius(16)
          } else if (this.snapshot.rows.length === 0) {
            Column({ space: 10 }) {
              Text('暂无可枚举的本机传感器').fontSize(this.wearable ? 17 : 22).fontWeight(FontWeight.Bold).fontColor('#102C41')
              Text('部分 PC、二合一和智慧屏没有公开传感器；也可能是服务尚未就绪。请刷新或在其他设备验证。')
                .fontSize(this.textSize()).fontColor('#526679')
            }.padding(24).width('100%').backgroundColor(Color.White).borderRadius(20)
          } else {
            Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween, alignItems: ItemAlign.Start }) {
              ForEach(this.snapshot.rows, (row: SensorRow) => {
                SensorCardView({ row: this.currentRow(row), compact: this.wearable, television: this.television,
                  cardWidth: this.cardWidth(), showDetails: this.showDetails })
              }, (row: SensorRow) => row.key)
            }.width('100%')
          }
          if (this.snapshot.excludedCount > 0) {
            Text('已排除 ' + this.snapshot.excludedCount.toString() + ' 个远程、模拟或无法区分的实例。')
              .fontSize(this.textSize()).fontColor('#526679').width('100%')
          }
        }
        Button('本机数据与隐私').fontSize(this.textSize()).height(this.buttonSize()).backgroundColor('#E5EEF5').fontColor('#102C41')
          .onClick(() => this.showPrivacy())
        Text('手机 / 平板 / PC / 智慧屏 / 智能手表\n各设备以实际公开硬件能力为准')
          .fontSize(this.wearable ? 10 : 12).fontColor('#64748B').textAlign(TextAlign.Center)
      }.width('100%').padding({ left: this.wearable ? 24 : 20, right: this.wearable ? 24 : 20,
        top: this.wearable ? 42 : 28, bottom: this.wearable ? 42 : 32 })
    }.width('100%').height('100%').backgroundColor('#F4F7FB').scrollBar(this.wearable ? BarState.Off : BarState.Auto)
      .onAreaChange((_old: Area, area: Area) => { this.viewportWidth = Number(area.width); })
  }
}
