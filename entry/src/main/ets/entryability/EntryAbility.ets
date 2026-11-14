import { UIAbility, Want, AbilityConstant } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { window } from '@kit.ArkUI';
import { SensorController } from '../services/SensorController';
export default class EntryAbility extends UIAbility {
  onCreate(_want: Want, _launchParam: AbilityConstant.LaunchParam): void {
    SensorController.shared().attach(this.context);
    SensorController.shared().setPaused(true);
  }
  onWindowStageCreate(stage: window.WindowStage): void {
    stage.loadContent('pages/Index', (error: BusinessError) => {
      if (error.code) { SensorController.shared().setForeground(false); return; }
    });
  }
  onForeground(): void { SensorController.shared().setForeground(true); }
  onBackground(): void { SensorController.shared().setForeground(false); }
  onWindowStageDestroy(): void { SensorController.shared().setForeground(false); }
  onDestroy(): void { SensorController.shared().dispose(); }
}
