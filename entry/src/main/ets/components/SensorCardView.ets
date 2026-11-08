import { SensorRow } from '../model/SensorModels';
import { SensorController } from '../services/SensorController';
import { SensorChart } from './SensorChart';

@Component
export struct SensorCardView {
  @Prop row: SensorRow;
  @Prop compact: boolean = false;
  @Prop television: boolean = false;
  @Prop cardWidth: number = 320;
  @Prop showDetails: boolean = false;
  @State selectedAxis: number = 0;
  private controller: SensorController = SensorController.shared();
  private colors: string[] = ['#087F8C', '#B64A34', '#7356AF', '#A57205', '#386AAB', '#A44579'];
  private textSize(): number { return this.television ? 20 : (this.compact ? 12 : 14); }
  private safeAxis(): number { return Math.max(0, Math.min(this.selectedAxis, this.row.labels.length - 1)); }
  private stateLabel(status: string): string {
    switch (status) {
      case 'live': return '实时'; case 'waiting': return '等待样本'; case 'stale': return '数据超时';
      case 'paused': return '已暂停'; case 'background': return '后台已停止'; case 'disabled': return '已关闭';
      case 'permission': return '未授权'; case 'unsupported': return '不支持';
      case 'qualification': return '健康待核验'; case 'error': return '服务异常'; default: return status;
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
  build() {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        Text(this.row.title).fontSize(this.compact ? 18 : (this.television ? 26 : 20)).fontWeight(FontWeight.Bold)
          .fontColor('#102C41').layoutWeight(1)
        Text(this.stateLabel(this.row.status)).fontSize(this.textSize()).fontColor(this.stateColor(this.row.status))
      }.width('100%')
      Text(this.row.unit).fontSize(this.textSize()).fontColor('#526679').width('100%')
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
          Select(this.row.labels.map((label: string): SelectOption => { return { value: label }; }))
            .selected(this.safeAxis()).value(this.row.labels[this.safeAxis()]).font({ size: this.textSize() })
            .onSelect((axis: number) => this.selectedAxis = axis).accessibilityText(this.row.title + '曲线分量')
        }
        SensorChart({ row: this.row, axis: this.safeAxis(), compact: this.compact })
      }
      Text(this.row.message).fontSize(this.textSize()).fontColor(this.stateColor(this.row.status)).width('100%')
      Text(this.row.lastReceivedMs === 0 ? '尚未收到样本' : '最后接收 ' +
        Math.max(0, Math.floor((Date.now() - this.row.lastReceivedMs) / 1000)).toString() + ' 秒前')
        .fontSize(this.compact ? 10 : 12).fontColor('#64748B').width('100%')
      if (this.showDetails) {
        Text('硬件：' + this.row.sensorName + '\n厂商：' + this.row.vendor + '\n类型 / 实例：' + this.row.key +
          '\n请求间隔：' + (this.row.requestedIntervalNs / 1000000).toFixed(1) + ' ms')
          .fontSize(this.textSize()).fontColor('#526679').width('100%')
      }
      if (this.row.status !== 'qualification' && this.row.status !== 'unsupported') {
        Row() {
          Text(this.row.enabled ? '采集已开启' : '采集已关闭').fontSize(this.textSize()).fontColor('#526679').layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: this.row.enabled }).selectedColor('#087F8C')
            .onChange((enabled: boolean) => this.controller.setEnabled(this.row.key, enabled)).accessibilityText(this.row.title + '的采集开关')
        }.width('100%')
      }
    }.padding(this.compact ? 14 : 20).width(this.cardWidth).backgroundColor(Color.White)
      .borderRadius(20).border({ width: 1, color: '#DCE5ED' }).margin({ bottom: 16 }).alignItems(HorizontalAlign.Start)
  }
}
