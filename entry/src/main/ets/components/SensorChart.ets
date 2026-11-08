import { SensorRow, SamplePoint } from '../model/SensorModels';

@Component
export struct SensorChart {
  @Prop @Watch('draw') row: SensorRow;
  @Prop @Watch('draw') axis: number = 0;
  @Prop compact: boolean = false;
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private canvasWidth: number = 0;
  private canvasHeight: number = 120;
  private ready: boolean = false;
  private colors: string[] = ['#087F8C', '#B64A34', '#7356AF', '#A57205', '#386AAB', '#A44579'];

  draw(): void {
    if (!this.ready || this.canvasWidth <= 0) { return; }
    const c: CanvasRenderingContext2D = this.context;
    const w: number = this.canvasWidth;
    const h: number = this.canvasHeight;
    c.clearRect(0, 0, w, h);
    c.strokeStyle = '#E5EBF1'; c.lineWidth = 1;
    for (let i: number = 0; i <= 3; i++) {
      const y: number = 10 + i * (h - 28) / 3;
      c.beginPath(); c.moveTo(44, y); c.lineTo(w - 8, y); c.stroke();
    }
    const points: SamplePoint[] = this.row.history;
    if (points.length === 0) {
      c.fillStyle = '#64748B'; c.font = '12vp sans-serif'; c.textAlign = 'center';
      c.fillText('等待真实样本', w / 2, h / 2); return;
    }
    let lo: number = Number.POSITIVE_INFINITY;
    let hi: number = Number.NEGATIVE_INFINITY;
    const selected: number = Math.max(0, Math.min(this.axis, this.row.labels.length - 1));
    points.forEach((point: SamplePoint) => {
      lo = Math.min(lo, point.values[selected]); hi = Math.max(hi, point.values[selected]);
    });
    if (hi === lo) {
      const margin: number = Math.max(0.5, Math.abs(hi) * 0.05); hi += margin; lo -= margin;
    } else {
      const margin: number = (hi - lo) * 0.08; hi += margin; lo -= margin;
    }
    const end: number = points[points.length - 1].timeMs;
    const begin: number = end - 60000;
    const xFor = (time: number): number => 44 + Math.max(0, (time - begin) / 60000) * (w - 52);
    const yFor = (value: number): number => 10 + (hi - value) / (hi - lo) * (h - 28);
    c.fillStyle = '#64748B'; c.font = '10vp sans-serif'; c.textAlign = 'right';
    c.fillText(hi.toFixed(1), 39, 13); c.fillText(lo.toFixed(1), 39, h - 18);
    c.textAlign = 'left'; c.fillText('-60s', 44, h - 2);
    c.textAlign = 'right'; c.fillText('最新样本', w - 8, h - 2);
    for (let axis: number = selected; axis <= selected; axis++) {
      c.strokeStyle = this.colors[axis % this.colors.length]; c.fillStyle = this.colors[axis % this.colors.length];
      c.lineWidth = 1.8; c.beginPath();
      points.forEach((point: SamplePoint, index: number) => {
        const x: number = xFor(point.timeMs); const y: number = yFor(point.values[axis]);
        const gap: boolean = index > 0 && point.timeMs - points[index - 1].timeMs >
          Math.max(5000, this.row.requestedIntervalNs / 1000000 * 5);
        if (index === 0 || gap || this.row.eventDriven) { c.moveTo(x, y); } else { c.lineTo(x, y); }
      });
      c.stroke();
      points.forEach((point: SamplePoint) => {
        c.beginPath(); c.arc(xFor(point.timeMs), yFor(point.values[axis]), this.row.eventDriven ? 2.5 : 1.3, 0, Math.PI * 2); c.fill();
      });
    }
  }

  build() {
    Canvas(this.context).width('100%').height(this.compact ? 92 : 124)
      .onReady(() => { this.ready = true; this.draw(); })
      .onAreaChange((_old: Area, area: Area) => {
        this.canvasWidth = Number(area.width); this.canvasHeight = Number(area.height); this.draw();
      })
      .accessibilityText(this.row.history.length === 0 ? '曲线尚无样本' : '最近一分钟曲线，共 ' + this.row.history.length + ' 个真实样本。数值见上方。')
  }
}
