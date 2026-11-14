import { deviceInfo } from '@kit.BasicServicesKit';
import { common } from '@kit.AbilityKit';
import { SymbolGlyphModifier } from '@ohos.arkui.modifier';
import { SensorRow, SensorSnapshot } from '../model/SensorModels';
import { tr } from '../model/Locale';
import { SensorController } from '../services/SensorController';
import { SensorCardView } from '../components/SensorCardView';
import { WatchSensorList } from '../model/WatchSensorList';
import { privacyPolicyParagraphs } from '../model/PrivacyText';
import { PrivacyDecision, readPrivacyDecision, writePrivacyDecision } from '../model/PrivacyConsent';
import { hasPrivacyPolicyUrl, openPrivacyPolicy, PRIVACY_POLICY_URL } from '../model/PrivacyPolicyLink';


@Entry
@Component
struct Index {
  @State snapshot: SensorSnapshot = SensorController.shared().snapshot();
  @State viewportWidth: number = 360;
  @State started: boolean = false;
  @State privacyDecision: PrivacyDecision = 'undecided';
  @State privacyReady: boolean = false;
  @State privacySaving: boolean = false;
  @State privacyVisible: boolean = false;
  @State privacySaveError: boolean = false;
  @State privacyLinkError: boolean = false;
  @State showDetails: boolean = false;
  @State selectedIntervalMs: number = 200;
  @State showFrequencyChoices: boolean = false;
  @State watchUpdate: number = 0;
  private watchSensors: WatchSensorList = new WatchSensorList();
  private watchAxes: Map<string, number> = new Map<string, number>();
  private controller: SensorController = SensorController.shared();
  private wearable: boolean = deviceInfo.deviceType === 'wearable';
  private television: boolean = deviceInfo.deviceType === 'tv';
  private arrowStyle: SymbolGlyphModifier = new SymbolGlyphModifier().fontColor(['#102C41']);
  private privacyOpening: boolean = false;
  private mounted: boolean = false;
  aboutToAppear(): void {
    this.mounted = true;
    this.controller.onChange = () => this.updateSnapshot();
    this.updateSnapshot();
    this.loadPrivacyDecision();
  }
  aboutToDisappear(): void {
    this.mounted = false;
    this.controller.onChange = undefined;
    this.controller.setPaused(true);
  }
  onPageHide(): void {
    // A router-cached page may hide without disappearing. Returning requires an explicit resume.
    this.controller.setPaused(true);
  }
  onBackPress(): boolean {
    if (this.privacyVisible) {
      this.closePrivacy();
      return true;
    }
    return false;
  }
  private deviceSummary(): string {
    return (this.television ? tr('手机 / 平板 / PC / 智慧屏 / 智能手表', 'Phone / tablet / PC / TV / watch') : tr('手机 / 平板 / PC / 智能手表', 'Phone / tablet / PC / watch')) +
      tr('\n各设备以实际公开硬件能力为准', '\nAvailable sensors vary by device.');
  }
  private textSize(): number { return this.television ? 20 : (this.wearable ? 12 : 14); }
  private buttonSize(): number { return this.television ? 56 : 44; }
  private cardWidth(): number {
    if (this.wearable) { return this.viewportWidth - 56; }
    const available: number = this.viewportWidth - 40;
    const columns: number = available >= 1120 ? 3 : (available >= 640 ? 2 : 1);
    return Math.max(150, (available - (columns - 1) * 16) / columns);
  }
  @Builder
  InventoryDetailsButton() {
    Button(this.showDetails ? tr('收起详情', 'Hide details') : tr('硬件详情', 'Hardware details'))
      .fontSize(this.textSize()).height(this.buttonSize()).backgroundColor('#E5EEF5').fontColor('#102C41')
      .onClick(() => { this.showDetails = !this.showDetails; })
      .onKeyEvent((event: KeyEvent) => this.activateKey(event, () => { this.showDetails = !this.showDetails; }))
  }

  @Builder
  SensorInventoryHeader() {
    if (this.wearable) {
      Column({ space: 6 }) {
        Text(tr('本机硬件 · ' + this.snapshot.rows.length + ' 项', 'Local sensors · ' + this.snapshot.rows.length))
          .fontSize(16).fontWeight(FontWeight.Bold).fontColor('#102C41')
        this.InventoryDetailsButton()
      }.width('100%')
    } else {
      Row() {
        Text(tr('本机硬件 · ' + this.snapshot.rows.length + ' 项', 'Local sensors · ' + this.snapshot.rows.length))
          .fontSize(20).fontWeight(FontWeight.Bold).fontColor('#102C41').layoutWeight(1)
        this.InventoryDetailsButton()
      }.width('100%')
    }
  }

  @Builder
  SensorInventoryStatus() {
    if (this.snapshot.refreshing) {
      Text(tr('正在读取本机传感器…', 'Looking for local sensors…'))
        .fontSize(this.textSize()).fontColor('#526679').width('100%').textAlign(TextAlign.Center)
    } else if (this.snapshot.enumerationError.length > 0) {
      Text(tr('无法枚举传感器：', 'Could not list sensors: ') + this.snapshot.enumerationError +
        tr('\n可以点击“刷新设备”重试。', '\nSelect “Refresh” to retry.'))
        .fontSize(this.textSize()).fontColor('#A54721').padding(16).width('100%').backgroundColor('#FFF3E8')
        .borderRadius(16)
    } else if (this.snapshot.rows.length === 0) {
      Column({ space: 10 }) {
        Text(tr('暂无可枚举的本机传感器', 'No local sensors found')).fontSize(this.wearable ? 17 : 22)
          .fontWeight(FontWeight.Bold).fontColor('#102C41')
        Text(tr('此设备可能没有公开传感器，或传感器服务尚未就绪。可以刷新重试。',
          'This device may have no public sensors or its sensor service may still be starting. Refresh to retry.'))
          .fontSize(this.textSize()).fontColor('#526679')
      }.padding(16).width('100%').backgroundColor(Color.White).borderRadius(20)
    }
  }

  @Builder
  SensorInventoryExclusions() {
    if (this.snapshot.excludedCount > 0) {
      Text(tr('已排除 ' + this.snapshot.excludedCount + ' 个远程、模拟或无法区分的实例。',
        'Remote, simulated or indistinguishable sensors excluded: ' + this.snapshot.excludedCount))
        .fontSize(this.textSize()).fontColor('#526679').width('100%')
    }
  }

  @Builder
  ObservationFooter() {
    Button(tr('本机数据与隐私', 'On-device privacy')).fontSize(this.textSize()).height(this.buttonSize())
      .backgroundColor('#E5EEF5').fontColor('#102C41').id('privacy-entry').focusable(true)
      .onClick(() => this.showPrivacy())
      .onKeyEvent((event: KeyEvent) => this.activateKey(event, () => this.showPrivacy()))
    Text(this.deviceSummary())
      .fontSize(this.wearable ? 10 : 12).fontColor('#64748B').textAlign(TextAlign.Center)
  }
  private currentRow(row: SensorRow): SensorRow {
    const latest: SensorRow | undefined = this.snapshot.rows.find((item: SensorRow) => item.key === row.key);
    return latest === undefined ? row : latest;
  }
  private updateSnapshot(): void {
    this.snapshot = this.controller.snapshot(!this.wearable);
    if (this.selectedIntervalMs !== this.snapshot.intervalMs) {
      this.selectedIntervalMs = this.snapshot.intervalMs;
    }
    if (this.wearable) {
      this.watchSensors.update(this.snapshot.rows);
      this.watchUpdate++;
    }
  }
  private watchRow(row: SensorRow, _update: number): SensorRow {
    return this.controller.snapshotRow(row.key) ?? row;
  }
  private activateKey(event: KeyEvent, action: () => void): boolean {
    if (this.television && event.type === KeyType.Down && [2016, 2054, 2050].includes(event.keyCode)) {
      action(); return true;
    }
    return false;
  }
  private startObservation(): void {
    if (this.privacyDecision !== 'accepted') { return; }
    this.started = true;
    this.controller.setPaused(false);
    this.controller.refresh();
    this.focusForTv('collection-pause');
  }
  private focusForTv(id: string): void {
    if (this.television) {
      // Transfer focus after a temporary control leaves the tree.
      setTimeout(() => {
        try {
          this.getUIContext().getFocusController().requestFocus(id);
          if (deviceInfo.apiAvailable(14)) { this.getUIContext().getFocusController().activate(true); }
        } catch (_) {
          // A closed window must not cause an application error or restart collection.
        }
      }, 80);
    }
  }
  private toggleFrequencyChoices(): void {
    this.showFrequencyChoices = !this.showFrequencyChoices;
    this.focusForTv(this.showFrequencyChoices ? 'frequency-choice-' +
      [1000, 200, 100, 50].indexOf(this.selectedIntervalMs).toString() : 'frequency-control');
  }
  private selectFrequency(index: number): void {
    this.controller.setIntervalMs([1000, 200, 100, 50][index]);
    this.showFrequencyChoices = false;
    this.focusForTv('frequency-control');
  }
  private async loadPrivacyDecision(): Promise<void> {
    let decision: PrivacyDecision = 'undecided';
    try {
      decision = await readPrivacyDecision(this.getUIContext().getHostContext() as common.UIAbilityContext);
    } catch (_) {
      // Consent cannot be restored if the local record is unavailable.
    }
    if (this.mounted) {
      this.privacyDecision = decision;
      this.controller.setPrivacyConsent(decision === 'accepted');
      this.privacyReady = true;
    }
  }
  private async savePrivacyDecision(decision: PrivacyDecision): Promise<void> {
    if (!this.privacyReady || this.privacySaving) { return; }
    this.privacySaving = true;
    this.privacySaveError = false;
    if (decision === 'declined') {
      this.controller.setPrivacyConsent(false);
      this.started = false;
      this.showDetails = false;
      this.privacyDecision = 'declined';
    }
    try {
      await writePrivacyDecision(this.getUIContext().getHostContext() as common.UIAbilityContext, decision);
      if (this.mounted) {
        this.privacyDecision = decision;
        this.controller.setPrivacyConsent(decision === 'accepted');
      }
    } catch (_) {
      this.privacySaveError = true;
    } finally {
      this.privacySaving = false;
    }
  }
  private showPrivacy(): void {
    if (this.started) { this.controller.setPaused(true); }
    this.privacyLinkError = false;
    this.privacyVisible = true;
    this.focusForTv('privacy-back');
  }
  private closePrivacy(): void {
    this.privacyVisible = false;
    this.focusForTv(this.privacyDecision === 'accepted' ? 'privacy-entry' : 'privacy-read');
  }
  private async openOnlinePrivacy(): Promise<void> {
    if (this.privacyOpening) { return; }
    this.privacyOpening = true;
    try {
      const context: common.UIAbilityContext | undefined =
        this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
      if (!await openPrivacyPolicy(context) && this.mounted) { this.privacyLinkError = true; }
    } catch (_) {
      this.privacyLinkError = true;
    } finally {
      this.privacyOpening = false;
    }
  }
  @Builder
  Controls() {
    Flex({ wrap: FlexWrap.Wrap, alignItems: ItemAlign.Center,
      justifyContent: this.wearable ? FlexAlign.Center : FlexAlign.Start }) {
      Button(this.snapshot.paused ? tr('继续采集', 'Resume') : tr('暂停采集', 'Pause')).fontSize(this.textSize()).height(this.buttonSize())
        .id('collection-pause').focusable(true)
        .margin({ right: 10, bottom: 10 }).backgroundColor('#102C41').fontColor(Color.White).defaultFocus(true)
        .onClick(() => this.controller.setPaused(!this.snapshot.paused))
        .onKeyEvent((event: KeyEvent) => this.activateKey(event, () => this.controller.setPaused(!this.snapshot.paused)))
      if (this.television || this.wearable) {
        Button(tr('频率：', 'Rate: ') + ['1 Hz', '5 Hz', '10 Hz', '20 Hz'][[1000, 200, 100, 50].indexOf(this.selectedIntervalMs)] + ' ▼')
          .id('frequency-control').focusable(true).fontSize(this.textSize()).height(this.buttonSize())
          .fontColor('#102C41').backgroundColor('#E5EEF5').margin({ right: 10, bottom: 10 })
          .onClick(() => this.toggleFrequencyChoices())
          .onKeyEvent((event: KeyEvent) => this.activateKey(event, () => this.toggleFrequencyChoices()))
      } else if (deviceInfo.apiAvailable(20)) {
        Select([{ value: tr('1 Hz · 省电', '1 Hz · Low power') }, { value: tr('5 Hz · 默认', '5 Hz · Default') }, { value: '10 Hz' }, { value: '20 Hz' }])
          .selected([1000, 200, 100, 50].indexOf(this.selectedIntervalMs))
          .value([tr('1 Hz · 省电', '1 Hz · Low power'), tr('5 Hz · 默认', '5 Hz · Default'), '10 Hz', '20 Hz'][[1000, 200, 100, 50].indexOf(this.selectedIntervalMs)])
          .font({ size: this.textSize() }).fontColor('#102C41').backgroundColor('#E5EEF5')
          .arrowModifier(this.arrowStyle).height(this.buttonSize()).margin({ right: 10, bottom: 10 })
          .onSelect((index: number) => this.controller.setIntervalMs([1000, 200, 100, 50][index]))
          .accessibilityText(tr('采集请求频率，硬件实际频率可能不同', 'Requested sampling rate. Actual rate depends on the hardware.'))
      } else {
        Select([{ value: tr('1 Hz · 省电', '1 Hz · Low power') }, { value: tr('5 Hz · 默认', '5 Hz · Default') }, { value: '10 Hz' }, { value: '20 Hz' }])
        .selected([1000, 200, 100, 50].indexOf(this.selectedIntervalMs))
        .value([tr('1 Hz · 省电', '1 Hz · Low power'), tr('5 Hz · 默认', '5 Hz · Default'), '10 Hz', '20 Hz'][[1000, 200, 100, 50].indexOf(this.selectedIntervalMs)])
        .font({ size: this.textSize() }).fontColor('#102C41').backgroundColor('#E5EEF5')
        .height(this.buttonSize()).margin({ right: 10, bottom: 10 })
        .onSelect((index: number) => this.controller.setIntervalMs([1000, 200, 100, 50][index]))
        .accessibilityText(tr('采集请求频率，硬件实际频率可能不同', 'Requested sampling rate. Actual rate depends on the hardware.'))
      }
      if (this.wearable && this.showFrequencyChoices) {
        this.WatchFrequencyChoices()
      }
      Button(this.snapshot.refreshing ? tr('正在刷新', 'Refreshing') : tr('刷新设备', 'Refresh')).fontSize(this.textSize()).height(this.buttonSize())
        .margin({ right: 10, bottom: 10 }).backgroundColor('#E5EEF5').fontColor('#102C41').enabled(!this.snapshot.refreshing)
        .onClick(() => { this.controller.refresh(); })
        .onKeyEvent((event: KeyEvent) => this.activateKey(event, () => { this.controller.refresh(); }))
      Button(tr('清空曲线', 'Clear charts')).fontSize(this.textSize()).height(this.buttonSize()).margin({ right: 10, bottom: 10 })
        .backgroundColor('#E5EEF5').fontColor('#102C41').onClick(() => this.controller.clearHistory())
        .onKeyEvent((event: KeyEvent) => this.activateKey(event, () => this.controller.clearHistory()))
      if (this.snapshot.rows.some((row: SensorRow) => row.id === 265 || row.id === 266)) {
        Button(tr('授权运动', 'Allow motion')).fontSize(this.textSize()).height(this.buttonSize()).margin({ right: 10, bottom: 10 })
          .backgroundColor('#E5EEF5').fontColor('#102C41').onClick(() => { this.controller.authorizeMotion(); })
          .onKeyEvent((event: KeyEvent) => this.activateKey(event, () => { this.controller.authorizeMotion(); }))
      }
    }.width('100%')
    if (this.television && this.showFrequencyChoices) {
      Column({ space: 10 }) {
        Text(tr('选择采集频率', 'Sampling rate')).fontSize(this.textSize()).fontColor('#102C41').width('100%')
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach([tr('1 Hz · 省电', '1 Hz · Low power'), tr('5 Hz · 默认', '5 Hz · Default'), '10 Hz', '20 Hz'], (label: string, index: number) => {
            Button(label).id('frequency-choice-' + index.toString()).focusable(true)
              .fontSize(this.textSize()).height(this.buttonSize()).margin({ right: 10, bottom: 10 })
              .backgroundColor(this.selectedIntervalMs === [1000, 200, 100, 50][index] ? '#102C41' : '#E5EEF5')
              .fontColor(this.selectedIntervalMs === [1000, 200, 100, 50][index] ? Color.White : '#102C41')
              .onClick(() => this.selectFrequency(index))
              .onKeyEvent((event: KeyEvent) => this.activateKey(event, () => this.selectFrequency(index)))
          }, (label: string) => label)
        }.width('100%')
      }.padding(16).width('100%').backgroundColor(Color.White).borderRadius(16)
    }
    Text(tr('频率为请求值；事件型传感器仅在变化时上报。曲线按接收时间绘制，最多240点，时间跨度不超过60秒；暂停时保留曲线。', 'Actual rates depend on hardware. Event sensors report changes. Charts keep up to 240 readings from the last 60 seconds and remain visible when paused.'))
      .fontSize(this.textSize()).fontColor('#526679').width('100%')
  }

  @Builder
  WatchFrequencyChoices() {
    Column({ space: 6 }) {
      Text(tr('选择采集频率', 'Sampling rate')).fontSize(this.textSize()).fontColor('#102C41')
        .width('100%').textAlign(TextAlign.Center)
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
        ForEach(['1 Hz', '5 Hz', '10 Hz', '20 Hz'], (label: string, index: number) => {
          Button({ type: ButtonType.Normal }) {
            Text(label).fontSize(this.textSize()).textAlign(TextAlign.Center)
              .fontColor(this.selectedIntervalMs === [1000, 200, 100, 50][index] ? Color.White : '#102C41')
          }.constraintSize({ minWidth: 58, minHeight: 42 }).padding({ left: 6, right: 6, top: 4, bottom: 4 })
            .id('frequency-choice-' + index.toString()).borderRadius(12)
            .margin({ left: 3, right: 3, bottom: 6 })
            .backgroundColor(this.selectedIntervalMs === [1000, 200, 100, 50][index] ? '#102C41' : '#E5EEF5')
            .onClick(() => this.selectFrequency(index))
        }, (label: string) => label)
      }.width('100%')
    }.padding(8).width('100%').backgroundColor(Color.White).borderRadius(16).margin({ bottom: 10 })
  }

  @Builder
  WatchDashboard() {
    List({ space: 10 }) {
      ListItem() {
        Column({ space: 12 }) {
          this.Controls()
          this.SensorInventoryHeader()
          this.SensorInventoryStatus()
        }.width('100%')
      }.padding({ left: 28, right: 28 })
      LazyForEach(this.watchSensors, (row: SensorRow) => {
        ListItem() {
          SensorCardView({ row: this.watchRow(row, this.watchUpdate), compact: true,
            cardWidth: this.cardWidth(), showDetails: this.showDetails,
            initialAxis: this.watchAxes.get(row.key) ?? 0,
            onAxisChange: (axis: number) => { this.watchAxes.set(row.key, axis); } })
        }.padding({ left: 28, right: 28 })
      }, (row: SensorRow) => row.key)
      ListItem() {
        Column({ space: 12 }) {
          this.SensorInventoryExclusions()
          this.ObservationFooter()
        }.width('100%')
      }.padding({ left: 28, right: 28 })
    }.width('100%').height('100%').contentStartOffset(42).contentEndOffset(42)
      .backgroundColor('#F4F7FB').scrollBar(BarState.Off).cachedCount(1)
      .onAreaChange((_old: Area, area: Area) => { this.viewportWidth = Number(area.width); })
  }
  @Builder
  PrivacyButton(label: string, id: string, primary: boolean, action: () => void) {
    Button(label, { type: ButtonType.Normal })
      .id(id).focusable(true).borderRadius(18).width('100%').height(this.wearable ? 38 : this.buttonSize())
      .fontSize(this.textSize()).labelStyle({ maxLines: 2 })
      .backgroundColor(primary ? '#102C41' : '#E5EEF5').fontColor(primary ? Color.White : '#102C41')
      .enabled(!this.privacySaving).onClick(action)
      .onKeyEvent((event: KeyEvent) => this.activateKey(event, action))
  }

  @Builder
  WatchPrivacyChoices() {
    Row({ space: 6 }) {
      Button(tr('不同意', 'Decline')).id('privacy-decline').layoutWeight(1).height(40)
        .fontSize(this.textSize()).fontColor('#102C41').backgroundColor('#E5EEF5')
        .enabled(!this.privacySaving).onClick(() => { this.savePrivacyDecision('declined'); })
      Button(tr('同意', 'Agree')).id('privacy-agree').layoutWeight(1).height(40)
        .fontSize(this.textSize()).fontColor(Color.White).backgroundColor('#102C41')
        .enabled(!this.privacySaving).onClick(() => { this.savePrivacyDecision('accepted'); })
    }.width('100%')
  }

  @Builder
  PrivacySaveError() {
    if (this.privacySaveError) {
      Text(tr('无法保存隐私选择。观测已停用，请重试。', 'Could not save your privacy choice. Observation is off. Please try again.'))
        .fontSize(this.textSize()).fontColor('#A54721').width('100%')
    }
  }

  @Builder
  PrivacyGate() {
    Scroll() {
      Column({ space: 10 }) {
        Text(tr('隐私政策', 'Privacy policy')).fontSize(this.wearable ? 20 : 26)
          .fontWeight(FontWeight.Bold).fontColor('#102C41').width('100%')
        if (!this.privacyReady) {
          Text(tr('正在读取隐私选择…', 'Loading your privacy choice…'))
            .fontSize(this.textSize()).fontColor('#526679').width('100%')
        } else {
          Text(this.wearable
            ? tr('加速度、陀螺仪和重力读数仅在本机显示。计步另行授权。',
              'Motion and gravity readings stay on this watch. Steps need separate permission.')
            : tr('观测会通过系统接口读取本机加速度、陀螺仪、重力等传感器，在本机展示数值和曲线。读数仅存于内存。计步和步行检测需要另行授权运动权限。',
              'Observation reads accelerometer, gyroscope, gravity and other local sensors through system APIs to display values and charts. Readings stay in memory. Step count and step detection require separate motion permission.'))
            .fontSize(this.textSize()).fontColor('#526679').width('100%')
          this.PrivacyButton(tr('查看完整隐私政策', 'Read full policy'), 'privacy-read', false, () => this.showPrivacy())
          if (this.wearable && this.privacyDecision === 'undecided') {
            this.WatchPrivacyChoices()
          } else {
            this.PrivacyButton(tr('同意隐私政策', 'Agree to policy'), 'privacy-agree', true,
              () => { this.savePrivacyDecision('accepted'); })
            if (this.privacyDecision === 'undecided' || this.privacySaveError) {
              this.PrivacyButton(tr('不同意', 'Decline'), 'privacy-decline', false,
                () => { this.savePrivacyDecision('declined'); })
            }
          }
          if (this.privacyDecision === 'declined') {
            Text(tr('您未同意隐私政策，传感器观测已停用。', 'Observation is off because you declined the privacy policy.'))
              .fontSize(this.textSize()).fontColor('#526679').width('100%')
          }
          this.PrivacySaveError()
        }
      }.width('100%').constraintSize({ maxWidth: 620 })
        .padding({ left: this.wearable ? 28 : 24, right: this.wearable ? 28 : 24,
          top: this.wearable ? 30 : 28, bottom: this.wearable ? 36 : 28 })
    }.width('100%').height('100%').backgroundColor('#F4F7FB').scrollBar(BarState.Auto)
  }

  @Builder
  PrivacyPolicy() {
    Scroll() {
      Column({ space: 12 }) {
        this.PrivacyButton(tr('返回', 'Back'), 'privacy-back', false, () => this.closePrivacy())
        if (hasPrivacyPolicyUrl()) {
          this.PrivacyButton(tr('在线隐私政策', 'Online privacy policy'), 'privacy-online', false,
            () => { this.openOnlinePrivacy(); })
        }
        if (this.privacyLinkError) {
          Text(tr('无法打开浏览器。请在此阅读完整政策，或在其他设备访问以下网址。',
            'Could not open a browser. Read the full policy here or visit this address on another device.'))
            .fontSize(this.textSize()).fontColor('#A54721').width('100%')
          Text(PRIVACY_POLICY_URL).fontSize(this.textSize()).fontColor('#102C41').width('100%')
        }
        if (this.privacyDecision === 'accepted') {
          this.PrivacyButton(tr('撤回同意', 'Withdraw consent'), 'privacy-withdraw', false,
            () => { this.savePrivacyDecision('declined'); })
        }
        this.PrivacySaveError()
        ForEach(privacyPolicyParagraphs(), (paragraph: string, index: number) => {
          Text(paragraph).fontSize(index === 0 ? (this.wearable ? 17 : 24) : this.textSize())
            .fontWeight(index === 0 ? FontWeight.Bold : FontWeight.Normal)
            .lineHeight(this.wearable ? 18 : (this.television ? 29 : 22)).fontColor('#102C41').width('100%')
        }, (_paragraph: string, index: number) => index.toString())
      }.width('100%').constraintSize({ maxWidth: 760 })
        .padding({ left: this.wearable ? 28 : 24, right: this.wearable ? 28 : 24,
          top: this.wearable ? 42 : 28, bottom: this.wearable ? 46 : 28 })
    }.width('100%').height('100%').backgroundColor('#F4F7FB').scrollBar(BarState.Auto)
  }

  @Builder
  ObservationPage() {
    Scroll() {
      Column({ space: this.wearable ? 16 : 24 }) {
        Column({ space: 8 }) {
          Text('SENSOR / LOCAL').fontSize(this.wearable ? 10 : 12).fontWeight(FontWeight.Bold).fontColor('#087F8C').letterSpacing(2)
          Text(tr('传感器观测', 'Harmony Sensor Lab')).fontSize(this.wearable ? 21 : (this.television ? 40 : 32)).fontWeight(FontWeight.Bold).fontColor('#102C41')
          Text(tr('本机 · 前台采集 · 数据不上传', 'On-device readings. No uploads.')).fontSize(this.textSize()).fontColor('#526679')
        }.width('100%').alignItems(this.wearable ? HorizontalAlign.Center : HorizontalAlign.Start)
        if (!this.started) {
          Column({ space: 14 }) {
            Text(tr('观测这台设备', 'Observe this device')).fontSize(this.wearable ? 18 : 24).fontWeight(FontWeight.Bold).fontColor('#102C41')
            Text(tr('仅展示公开 API 的真实回调。样本只保存在内存，退到后台即停止采集；健康数据暂不采集。', 'View readings from public device APIs. Readings stay in memory and collection stops in the background. Health data is not collected.'))
              .fontSize(this.textSize()).fontColor('#526679')
            Button(tr('开始观测', 'Start observation')).fontSize(this.textSize()).height(this.buttonSize()).backgroundColor('#102C41').fontColor(Color.White).defaultFocus(true)
              .onClick(() => this.startObservation())
              .onKeyEvent((event: KeyEvent) => this.activateKey(event, () => this.startObservation()))
          }.padding(20).width('100%').backgroundColor(Color.White).borderRadius(20)
        } else {
          this.Controls()
          this.SensorInventoryHeader()
          this.SensorInventoryStatus()
          if (this.snapshot.rows.length > 0) {
            Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween, alignItems: ItemAlign.Start }) {
              ForEach(this.snapshot.rows, (row: SensorRow) => {
                SensorCardView({ row: this.currentRow(row), compact: this.wearable, television: this.television,
                  cardWidth: this.cardWidth(), showDetails: this.showDetails })
              }, (row: SensorRow) => row.key)
            }.width('100%')
          }
          this.SensorInventoryExclusions()
        }
        this.ObservationFooter()
      }.width('100%').padding({ left: this.wearable ? 24 : 20, right: this.wearable ? 24 : 20,
        top: this.wearable ? 42 : 28, bottom: this.wearable ? 42 : 32 })
    }.width('100%').height('100%').backgroundColor('#F4F7FB').scrollBar(this.wearable ? BarState.Off : BarState.Auto)
      .onAreaChange((_old: Area, area: Area) => { this.viewportWidth = Number(area.width); })
  }
  build() {
    if (this.privacyVisible) {
      this.PrivacyPolicy()
    } else if (this.privacyDecision !== 'accepted') {
      this.PrivacyGate()
    } else if (this.wearable && this.started) {
      this.WatchDashboard()
    } else {
      this.ObservationPage()
    }
  }
}
