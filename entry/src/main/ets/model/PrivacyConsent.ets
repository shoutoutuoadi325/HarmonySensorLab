import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

export type PrivacyDecision = 'undecided' | 'declined' | 'accepted';

const STORE_NAME: string = 'privacy_consent';
const DECISION_KEY: string = 'decision_1_0_1';

export async function readPrivacyDecision(context: common.UIAbilityContext): Promise<PrivacyDecision> {
  const store: preferences.Preferences = await preferences.getPreferences(context, STORE_NAME);
  const value: preferences.ValueType = await store.get(DECISION_KEY, 'undecided');
  return value === 'accepted' || value === 'declined' ? value : 'undecided';
}

export async function writePrivacyDecision(context: common.UIAbilityContext,
  decision: PrivacyDecision): Promise<void> {
  try {
    const store: preferences.Preferences = await preferences.getPreferences(context, STORE_NAME);
    await store.put(DECISION_KEY, decision);
    await store.flush();
  } catch (_) {
    // If a write fails, remove the dedicated consent store so it cannot restore obsolete consent.
    await preferences.deletePreferences(context, STORE_NAME);
    if (decision === 'accepted') {
      throw new Error('Could not save privacy consent');
    }
  }
}
