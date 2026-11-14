import { common, Want } from '@kit.AbilityKit';

// Keep the published policy aligned with the in-app policy in PrivacyText.ets.
// An empty value is intentional for local previews and must fail release preflight.
export const PRIVACY_POLICY_URL: string = 'https://harmonysensorlab-privacy.netlify.app/';

export function hasPrivacyPolicyUrl(): boolean {
  return /^https:\/\/[^\s/?#@:]+(?:[/?#][^\s]*)?$/.test(PRIVACY_POLICY_URL);
}

// The system browser handles this public URL. No samples or identifiers are attached.
export async function openPrivacyPolicy(context: common.UIAbilityContext | undefined): Promise<boolean> {
  if (context === undefined || !hasPrivacyPolicyUrl()) {
    return false;
  }
  const want: Want = {
    action: 'ohos.want.action.viewData',
    entities: ['entity.system.browsable'],
    uri: PRIVACY_POLICY_URL
  };
  try {
    await context.startAbility(want);
    return true;
  } catch (_) {
    // Devices without an eligible browser keep access to the full local policy.
    return false;
  }
}
