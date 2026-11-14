import { SensorRow } from '../model/SensorModels';
import { tr } from '../model/Locale';
import { deviceInfo } from '@kit.BasicServicesKit';
import { SymbolGlyphModifier } from '@ohos.arkui.modifier';
import { SensorController } from '../services/SensorController';
import { SensorChart } from './SensorChart';

@Component
export struct SensorCardView {
  @Prop @Watch('syncAxisLabels') row: SensorRow;
  @Prop compact: boolean = false;
  @Prop television: boolean = false;
  @Prop cardWidth: number = 320;
  @Prop showDetails: boolean = false;
  initialAxis: number = 0;
  onAxisChange: (axis: number) => void = (_axis: number): void => {};
  @State selectedAxis: number = 0;
  @State axisLabels: string[] = [];
  @State curveDescription: string = '';
  private controller: SensorController = SensorController.shared();
  private arrowStyle: SymbolGlyphModifier = new SymbolGlyphModifier().fontColor(['#102C41']);
  private colors: string[] = ['#087F8C', '#B64A34', '#7356AF', '#A57205', '#386AAB', '#A44579'];
  private textSize(): number { return this.television ? 20 : (this.compact ? 12 : 14); }
  aboutToAppear(): void {
    this.selectedAxis = this.initialAxis;
    this.syncAxisLabels();
  }
  private syncAxisLabels(): void {
    const description: string = tr(this.row.title + '曲线分量', this.row.title + ' chart component');
    if (this.curveDescription !== description) { this.curveDescription = description; }
    if (this.axisLabels.length !== this.row.labels.length ||
      this.axisLabels.some((label: string, index: number) => label !== this.row.labels[index])) {
      this.axisLabels = this.row.labels.slice();
      this.selectedAxis = Math.max(0, Math.min(this.selectedAxis, this.axisLabels.length - 1));
    }
  }
  private safeAxis(): number { return Math.max(0, Math.min(this.selectedAxis, this.axisLabels.length - 1)); }
  private selectAxis(axis: number): void {
    this.selectedAxis = axis;
    this.onAxisChange(axis);
  }
  private activateKey(event: KeyEvent, action: () => void): boolean {
    if (this.television && event.type === KeyType.Down && [2016, 2054, 2050].includes(event.keyCode)) {
      action(); return true;
    }
    return false;
  }
  private stateLabel(status: string): string {
    switch (status) {
      case 'live': return tr('实时', 'Live');
      case 'waiting': return tr('等待样本', 'Waiting');
      case 'stale': return tr('数据超时', 'Stale');
      case 'paused': return tr('已暂停', 'Paused');
      case 'background': return tr('后台已停止', 'In background');
      case 'disabled': return tr('已关闭', 'Off');
      case 'permission': return tr('未授权', 'Permission needed');
      case 'unsupported': return this.row.labels.length === 0 ? tr('仅硬件信息', 'Details only') : tr('不支持', 'Unavailable');
      case 'qualification': return tr('健康待核验', 'Health restricted');
      case 'error': return tr('服务异常', 'Error');
      default: return status;
    }
  }
  private stateColor(status: string): string {
    if (status === 'live') { return '#087F66'; }
    if (status === 'error' || status === 'stale' || status === 'permission') { return '#A54721'; }
    return '#64748B';
  }
  private valueText(axis: number): string {
    if (this.row.values.length <= axis) { return '—'; }
    return this.row.eventDriven ? this.row.values[axis].toString() : this.row.values[axis].toFixed(3);
  }
  private lastSampleText(): string {
    if (this.row.lastReceivedMs === 0) {
      return tr('尚未收到样本', 'No samples yet');
    }
    const seconds: number = Math.max(0, Math.floor((Date.now() - this.row.lastReceivedMs) / 1000));
    return tr('最后接收 ' + seconds + ' 秒前', 'Last reading ' + seconds + ' s ago');
  }
  private hardwareDetails(): string {
    const description: string = tr('硬件：', 'Hardware: ') + this.row.sensorName +
      tr('\n厂商：', '\nVendor: ') + this.row.vendor + tr('\n类型 / 实例：', '\nType / instance: ') + this.row.key;
    return this.row.status === 'unsupported' || this.row.status === 'qualification' ? description :
      description + tr('\n请求间隔：', '\nRequested interval: ') + (this.row.requestedIntervalNs / 1000000).toFixed(1) + ' ms';
  }
  build() {
    Column({ space: 10 }) {
      if (this.compact) {
        Column({ space: 4 }) {
          Text(this.row.title).fontSize(18).fontWeight(FontWeight.Bold).fontColor('#102C41').width('100%')
          Text(this.stateLabel(this.row.status)).fontSize(this.textSize()).fontColor(this.stateColor(this.row.status))
            .width('100%')
        }.width('100%')
      } else {
        Row({ space: 8 }) {
          Text(this.row.title).fontSize(this.television ? 26 : 20).fontWeight(FontWeight.Bold)
            .fontColor('#102C41').layoutWeight(1)
          Text(this.stateLabel(this.row.status)).fontSize(this.textSize()).fontColor(this.stateColor(this.row.status))
        }.width('100%')
      }
      if (this.row.unit.length > 0) {
        Text(this.row.unit).fontSize(this.textSize()).fontColor('#526679').width('100%')
      }
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.row.labels, (label: string, axis: number) => {
          Column({ space: 3 }) {
            Text(label).fontSize(this.compact ? 11 : 12).fontColor(this.colors[axis % this.colors.length])
            Text(this.valueText(axis)).fontSize(this.compact ? 19 : (this.television ? 30 : 24))
              .fontWeight(FontWeight.Medium).fontColor(this.colors[axis % this.colors.length])
          }.margin({ right: 16, bottom: 6 }).alignItems(HorizontalAlign.Start)
        }, (label: string) => label)
      }.width('100%')
      if (this.row.labels.length > 0 && this.row.status !== 'qualification') {
        if (this.row.labels.length > 1) {
          if (this.compact) {
            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(this.axisLabels, (label: string, axis: number) => {
                Button({ type: ButtonType.Normal }) {
                  Text(label.split(' (')[0]).fontSize(this.textSize()).textAlign(TextAlign.Center)
                    .fontColor(this.safeAxis() === axis ? Color.White : '#102C41')
                }.constraintSize({ minWidth: 40, minHeight: 40 }).padding({ left: 6, right: 6, top: 4, bottom: 4 })
                  .borderRadius(12).margin({ right: 4, bottom: 4 })
                  .backgroundColor(this.safeAxis() === axis ? '#102C41' : '#E5EEF5')
                  .onClick(() => this.selectAxis(axis))
                  .accessibilityText(this.curveDescription + ' · ' + label)
              }, (label: string) => label)
            }.width('100%')
          } else if (this.television) {
            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(this.axisLabels, (label: string, axis: number) => {
                Button(label.split(' (')[0]).fontSize(this.textSize()).height(56).focusable(true)
                  .margin({ right: 8, bottom: 8 })
                  .backgroundColor(this.safeAxis() === axis ? '#102C41' : '#E5EEF5')
                  .fontColor(this.safeAxis() === axis ? Color.White : '#102C41')
                  .onClick(() => this.selectedAxis = axis)
                  .onKeyEvent((event: KeyEvent) => this.activateKey(event, () => this.selectedAxis = axis))
                  .accessibilityText(this.curveDescription + tr('：', ': ') + label)
              }, (label: string) => label)
            }.width('100%')
          } else if (deviceInfo.apiAvailable(20)) {
            Select(this.axisLabels.map((label: string): SelectOption => { return { value: label }; }))
              .selected(this.safeAxis()).value(this.axisLabels[this.safeAxis()]).font({ size: this.textSize() })
              .fontColor('#102C41').backgroundColor('#E5EEF5').arrowModifier(this.arrowStyle)
              .onSelect((axis: number) => this.selectedAxis = axis).accessibilityText(this.curveDescription)
          } else {
            Select(this.axisLabels.map((label: string): SelectOption => { return { value: label }; }))
            .selected(this.safeAxis()).value(this.axisLabels[this.safeAxis()]).font({ size: this.textSize() })
            .fontColor('#102C41').backgroundColor('#E5EEF5')
            .onSelect((axis: number) => this.selectedAxis = axis).accessibilityText(this.curveDescription)
          }
        }
        SensorChart({ row: this.row, axis: this.safeAxis(), compact: this.compact })
      }
      Text(this.row.message).fontSize(this.textSize()).fontColor(this.stateColor(this.row.status)).width('100%')
      if (this.row.status !== 'unsupported' && this.row.status !== 'qualification') {
        Text(this.lastSampleText()).fontSize(this.compact ? 10 : 12).fontColor('#64748B').width('100%')
      }
      if (this.showDetails || (this.row.status === 'unsupported' && this.row.labels.length === 0)) {
        Text(this.hardwareDetails()).fontSize(this.textSize()).fontColor('#526679').width('100%')
      }
      if (this.row.status !== 'qualification' && this.row.status !== 'unsupported') {
        Row() {
          Text(this.row.enabled ? tr('采集已开启', 'Collection on') : tr('采集已关闭', 'Collection off'))
            .fontSize(this.textSize()).fontColor('#526679').layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: this.row.enabled }).selectedColor('#087F8C')
            .onChange((enabled: boolean) => this.controller.setEnabled(this.row.key, enabled))
            .accessibilityText(tr(this.row.title + '的采集开关', this.row.title + ' collection'))
            .onKeyEvent((event: KeyEvent) => this.activateKey(event, () => this.controller.setEnabled(this.row.key, !this.row.enabled)))
        }.width('100%')
      }
    }.padding(this.compact ? 14 : 20).width(this.cardWidth).backgroundColor(Color.White)
      .borderRadius(20).border({ width: 1, color: '#DCE5ED' }).margin({ bottom: 16 }).alignItems(HorizontalAlign.Start)
  }
}
