import { i18n } from '@kit.LocalizationKit';

let chinese: boolean | undefined;

export function isChinese(): boolean {
  if (chinese === undefined) {
    const preferredLanguage: string = i18n.System.getAppPreferredLanguage();
    const language: string = preferredLanguage.length === 0 || preferredLanguage === 'default'
      ? i18n.System.getSystemLanguage() : preferredLanguage;
    chinese = /^zh(?:[-_]|$)/i.test(language);
  }
  return chinese;
}

export function tr(zh: string, en: string): string {
  return isChinese() ? zh : en;
}
