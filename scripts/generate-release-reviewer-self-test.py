#!/usr/bin/env python3
"""Build a concise reviewer DOCX from confirmed, unchanged Release evidence."""
from __future__ import annotations

import hashlib
import json
import re
import zipfile
from datetime import datetime, timezone
from pathlib import Path
from xml.etree import ElementTree as ET

from docx import Document
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_CELL_VERTICAL_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Cm, Inches, Pt, RGBColor
from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / 'reports/emulator-runtime/release-final-2026-11-10'
OUT = ROOT / 'dist/store-submission-release-2026-11-10/reviewer-self-test-release-2026-11-10.docx'
AUDIT = ROOT / 'reports/store-submission/reviewer-self-test-audit-2026-11-10.json'
PACKAGES = {
    'default': ('手机 / 平板', 'sensor-default-release-signed.hap', '5b51c3e763d9dabb52f7defa5564061e6a5916b6f18c764d07b523319f07a2ee'),
    'pc': ('PC', 'sensor-pc-release-signed.hap', '27711ea7c708579278f5f83d815ec7b8ab101e9e4b675327074d271aa91ff562'),
    'wearable': ('智能手表', 'sensor-wearable-release-signed.hap', '522b75ca70d6946c7b8ea39e244e96a5d1a066320d92dc3fd62e84d68448bf4f'),
}
DEVICE_PRODUCT = {'phone': 'default', 'tablet': 'default', 'pc': 'pc', 'watch': 'wearable'}
CAPTURED = {}
INPUTS = {}


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def record(path: Path) -> dict:
    data = path.read_bytes()
    info = {'path': str(path.relative_to(ROOT)), 'sha256': sha(data), 'bytes': len(data)}
    INPUTS[info['path']] = info
    return info


def load(path: Path) -> dict:
    record(path)
    return json.loads(path.read_text())


def evidence(device: str, name: str, required=()) -> dict:
    key = f'{device}/{name}'
    if key in CAPTURED:
        result = CAPTURED[key]
    else:
        meta_path = BASE / device / f'{name}-evidence.json'
        result = load(meta_path)
        screenshot = ROOT / result['screenshot']
        if BASE not in screenshot.parents:
            raise ValueError('Screenshot must be an original current Release runtime capture')
        screenshot_info = record(screenshot)
        assert screenshot_info['sha256'] == result['screenshotSha256'], key
        assert result['installedPackageSha256'] == PACKAGES[DEVICE_PRODUCT[device]][2], key
        assert result['pixelTransformation'] == 'None; original official emulator screenshot', key
        assert result['identity']['testEmulator'] is True, key
        assert result['identity']['properties']['const.ohos.apiversion'] == '26', key
        with Image.open(screenshot) as im:
            assert im.format == 'PNG'
            result['imageSize'] = list(im.size)
        result['metaPath'] = str(meta_path.relative_to(ROOT))
        CAPTURED[key] = result
    visible = chr(10).join(t['text'] for t in result['visibleText'])
    for text in required:
        assert text in visible, (key, text)
    assert not re.search(r'(?<!\d)1[3-9]\d{9}(?!\d)', visible), 'Contact phone found in evidence'
    return result


def style_document(doc: Document) -> None:
    section = doc.sections[0]
    section.page_width, section.page_height = Cm(21), Cm(29.7)
    section.top_margin = section.bottom_margin = Cm(1.5)
    section.left_margin = section.right_margin = Cm(1.5)
    for name in ('Normal', 'Title', 'Heading 1', 'Heading 2'):
        style = doc.styles[name]
        style.font.name = 'Arial'
        style.element.get_or_add_rPr().rFonts.set(qn('w:eastAsia'), 'Microsoft YaHei')
    normal = doc.styles['Normal']
    normal.font.size = Pt(10)
    normal.paragraph_format.space_after = Pt(5)
    normal.paragraph_format.line_spacing = 1.12
    doc.styles['Title'].font.size = Pt(21)
    doc.styles['Heading 1'].font.size = Pt(15)
    doc.styles['Heading 2'].font.size = Pt(11)
    for name in ('Heading 1', 'Heading 2'):
        doc.styles[name].font.color.rgb = RGBColor.from_string('204555')
    props = doc.core_properties
    props.title = '传感器观测 1.0.0 — 当前 Release 审核自测记录'
    props.subject = 'Official HarmonyOS emulator evidence and exact Release HAP associations'
    props.author = 'HarmonySensorLab'
    props.last_modified_by = 'HarmonySensorLab'
    props.keywords = 'Release; reviewer; original emulator evidence'
    footer = section.footer.paragraphs[0]
    footer.alignment = WD_ALIGN_PARAGRAPH.CENTER
    footer.add_run('传感器观测 1.0.0 · 2026-11-10 · ')
    field = OxmlElement('w:fldSimple')
    field.set(qn('w:instr'), 'PAGE')
    footer._p.append(field)


def table(doc: Document, headers: list[str], rows: list[list[str]], widths=None):
    result = doc.add_table(rows=1, cols=len(headers))
    result.style = 'Table Grid'
    result.alignment = WD_TABLE_ALIGNMENT.CENTER
    for i, h in enumerate(headers):
        result.rows[0].cells[i].text = h
        for run in result.rows[0].cells[i].paragraphs[0].runs:
            run.bold = True
    for items in rows:
        row = result.add_row()
        for i, text in enumerate(items):
            row.cells[i].text = text
            row.cells[i].vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.TOP
        trpr = row._tr.get_or_add_trPr()
        trpr.append(OxmlElement('w:cantSplit'))
    for row in result.rows:
        for i, cell in enumerate(row.cells):
            if widths:
                cell.width = Cm(widths[i])
            for p in cell.paragraphs:
                p.paragraph_format.space_after = Pt(3)
                for run in p.runs:
                    run.font.size = Pt(9)
    return result


def photos(doc: Document, device: str, names: list[tuple[str, str]], width: float) -> None:
    grid = doc.add_table(rows=1, cols=len(names))
    grid.alignment = WD_TABLE_ALIGNMENT.CENTER
    for cell, (name, caption) in zip(grid.rows[0].cells, names):
        meta = evidence(device, name)
        p = cell.paragraphs[0]
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        p.add_run().add_picture(str(ROOT / meta['screenshot']), width=Inches(width))
        p = cell.add_paragraph(caption + chr(10) + f'{device}/{name}.png')
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        for run in p.runs:
            run.font.size = Pt(8)


def verify_install(device: str) -> dict:
    install = load(BASE / device / 'install.json')
    identity = load(BASE / device / 'identity.json')
    assert install['successful'] is True, device
    assert install['packageSha256'] == PACKAGES[DEVICE_PRODUCT[device]][2], device
    assert identity['properties']['const.product.model'] == 'emulator'
    assert identity['properties']['const.ohos.apiversion'] == '26'
    return identity


def verify_watch_deny() -> dict:
    """Match the actual successful click to the visible Deny button bounds."""
    prompt = evidence('watch', 'motion-request-bottom', ('Deny', 'Allow'))
    denied = evidence('watch', 'motion-denied', ('授权运动', '本机硬件 · 9 项'))
    button = next(t for t in prompt['visibleText'] if t['text'] == 'Deny')
    left, top, right, bottom = map(int, re.findall(r'\d+', button['bounds']))
    path = BASE / 'watch/commands.jsonl'
    for line in path.read_text().splitlines():
        item = json.loads(line)
        command = item['command']
        if command[-4:-2] != ['uiInput', 'click']:
            continue
        if not prompt['atUtc'] < item['atUtc'] < denied['atUtc']:
            continue
        x, y = map(int, command[-2:])
        if left <= x <= right and top <= y <= bottom:
            assert item['exitCode'] == 0 and 'No Error' in item['stdout']
            return {'sourceLog': str(path.relative_to(ROOT)), 'sourceRecordSha256': sha(line.encode()), 'record': item, 'matchedButtonEvidence': prompt['metaPath'], 'buttonText': 'Deny', 'buttonBounds': button['bounds']}
    raise AssertionError('No successful logged click inside the verified Deny bounds')


def main() -> None:
    verification = load(ROOT / 'reports/store-submission/release-current-local-verification-2026-11-10.json')
    verified = {p['file']: p for p in verification['packages']}
    for _, filename, digest in PACKAGES.values():
        path = ROOT / 'dist/packages' / filename
        assert record(path)['sha256'] == digest
        assert verified[str(path.relative_to(ROOT))]['sha256'] == digest
        assert verified[str(path.relative_to(ROOT))]['profileType'] == 'release'
    phone = verify_install('phone')
    pc = verify_install('pc')
    tablet = verify_install('tablet')
    watch = verify_install('watch')
    evidence('phone', 'initial', ('开始观测',))
    evidence('phone', 'live', ('本机硬件 · 9 项', '实时', '9.800'))
    evidence('phone', 'paused', ('继续采集', '已暂停'))
    evidence('phone', 'resume', ('暂停采集', '实时'))
    evidence('phone', 'home-verified', ('Contacts',))
    evidence('phone', 'return-from-background', ('继续采集', '已暂停'))
    evidence('phone', 'privacy', ('传感器观测隐私政策', 'com.personal.harmonysensorlab', '在线隐私政策'))
    evidence('pc', 'home-prompt-dismissed', ('开始观测',))
    evidence('pc', 'live', ('本机硬件 · 7 项', '实时'))
    evidence('pc', 'paused', ('继续采集', '已暂停'))
    evidence('pc', 'hardware-details', ('收起详情',))
    evidence('pc', 'privacy', ('传感器观测隐私政策', 'com.personal.harmonysensorlab'))
    evidence('pc', 'online-policy-settled', ('harmonysensorlab-privacy.netlify.app', '传感器观测隐私政策'))
    evidence('tablet', 'initial', ('开始观测',))
    evidence('tablet', 'live', ('本机硬件 · 9 项', '实时', '9.800'))
    evidence('tablet', 'paused', ('继续采集', '已暂停'))
    evidence('tablet', 'privacy', ('传感器观测隐私政策', 'com.personal.harmonysensorlab', '在线隐私政策'))
    evidence('tablet', 'online-policy-settled', ('harmonysensorlab-privacy.netlify.app', '传感器观测隐私政策'))
    evidence('watch', 'initial', ('传感器观测',))
    evidence('watch', 'start-scroll', ('开始观测',))
    evidence('watch', 'live', ('本机硬件 · 9 项', '实时', '9.800'))
    evidence('watch', 'pause-controls', ('暂停采集',))
    evidence('watch', 'paused-controls', ('继续采集',))
    watch_deny = verify_watch_deny()

    doc = Document()
    style_document(doc)
    doc.add_heading('传感器观测 · 审核自测记录', 0)
    doc.add_paragraph('版本 1.0.0（1000000）｜包名 com.personal.harmonysensorlab｜记录日期 2026-11-10')
    doc.add_paragraph('本记录使用本次正式 Release HAP，在官方 HarmonyOS 模拟器 API 26 上安装运行。截图中的数值来自官方模拟器公开传感器回调；它们用于验证界面与状态行为，不能作为实体手机、PC 或手表的传感器测量证据。')
    doc.add_heading('审核人员复现入口', 1)
    table(doc, ['操作', '入口及观察内容'], [
        ['启动', '启动“传感器观测”，在欢迎页点击“开始观测”。本次手机、PC、平板和手表均实际进入观测页；手表圆屏可滚动到操作入口。'],
        ['采集 / 暂停', '观测页显示设备公开传感器列表。点击“暂停采集”后显示“继续采集”和“已暂停”，保留暂停前读数；手机点击继续后回到实时状态。'],
        ['前后台', '手机在采集时返回 Home，再回到应用，界面保持“已暂停”，需用户点击继续。此项只记录界面状态，未以截图证明底层订阅数量。'],
        ['隐私政策', '欢迎页或观测页底部“本机数据与隐私”可打开完整本地政策。PC 和平板点击“在线隐私政策”后系统浏览器成功显示政策网站。'],
    ], [3, 15])
    doc.add_heading('当前 Release 包身份', 1)
    doc.add_paragraph('本地官方签名、有效 Release Profile、包名、设备 / SDK / 权限边界均已校验；APP 容器签名及其可执行载荷与对应 HAP 一致。以下哈希属于实际当前文件，签名校验与运行测试分别记录。')
    for label, filename, digest in PACKAGES.values():
        p = doc.add_paragraph(f'{label}：{filename}')
        p.paragraph_format.space_after = Pt(1)
        p = doc.add_paragraph(digest)
        p.paragraph_format.space_after = Pt(5)
        for run in p.runs:
            run.font.name = 'Courier New'
            run.font.size = Pt(8)
    doc.add_heading('证据范围', 1)
    doc.add_paragraph('下页记录已执行的手机、PC、平板和手表测试，未将历史 Debug 测试作为当前 Release 证据。手表实际运动权限提示及 Deny 后界面结果单独记录；权限撤销、实体硬件、最低 API 机型、频率切换和清空曲线未在本记录中宣称通过。本记录不代表应用市场审核结论。')
    doc.add_paragraph('政策地址：https://harmonysensorlab-privacy.netlify.app/。文档内所有图片均直接嵌入原始 PNG，只按比例设置显示尺寸；未裁剪、重绘或修改像素。')

    doc.add_page_break()
    doc.add_heading('手机 · 实际 Release 运行结果', 1)
    doc.add_paragraph(phone['properties']['const.product.software.version'] + '｜API 26｜当前 default HAP 安装成功')
    table(doc, ['已执行步骤', '观察结果', '原始证据'], [
        ['开始观测', '9 项模拟器公开虚拟传感器；加速度卡片“实时”，Y=9.800 m/s²。', 'phone/live'],
        ['暂停 → 继续', '暂停保留既有读数；继续后恢复“实时”。', 'phone/paused、resume'],
        ['Home → 返回', '实际 Home 页面后返回应用，显示“继续采集 / 已暂停”。', 'phone/home-verified、return-from-background'],
        ['打开本机政策', '本地弹窗含政策版本、包名、数据用途与权限说明。', 'phone/privacy'],
    ], [3, 9, 6])
    doc.add_paragraph('截图记录：采集 05:20 UTC；暂停 05:21 UTC；本机政策 05:33 UTC。各截图原始 PNG 与对应证据 JSON 哈希已核对。')
    photos(doc, 'phone', [('live', '采集时的实时状态'), ('paused', '暂停并保留先前读数'), ('privacy', '应用内政策弹窗')], 2.10)

    doc.add_page_break()
    doc.add_heading('PC · 实际 Release 运行结果', 1)
    doc.add_paragraph(pc['properties']['const.product.software.version'] + '｜API 26｜当前 pc HAP 安装成功')
    table(doc, ['已执行步骤', '观察结果', '原始证据'], [
        ['开始观测 / 暂停', '7 项模拟器公开虚拟传感器；双列实时卡片，暂停后保留既有读数。', 'pc/live、paused'],
        ['硬件详情', '点击后按钮变为“收起详情”；展开状态已记录。', 'pc/hardware-details'],
        ['本地 / 在线政策', '本地完整政策弹窗可打开；在线入口由系统浏览器显示公开政策 URL 与正文。', 'pc/privacy、online-policy-settled'],
    ], [3, 9, 6])
    photos(doc, 'pc', [('live', 'PC 采集界面'), ('paused', 'PC 暂停界面')], 3.15)
    photos(doc, 'pc', [('online-policy-settled', '系统浏览器打开公开政策 · 05:33 UTC')], 5.5)

    doc.add_page_break()
    doc.add_heading('平板 · 实际 Release 运行结果', 1)
    doc.add_paragraph(tablet['properties']['const.product.software.version'] + '｜API 26｜当前 default HAP 安装成功')
    table(doc, ['已执行步骤', '观察结果', '原始证据'], [
        ['启动 / 开始观测', '欢迎页可进入观测页；9 项模拟器公开虚拟传感器，横向双列卡片显示实时状态。', 'tablet/initial、live'],
        ['暂停', '显示“继续采集 / 已暂停”，保留先前读数。加速度 X=9.800 m/s²。', 'tablet/paused'],
        ['本地 / 在线政策', '本地完整政策弹窗可打开；系统浏览器显示公开政策 URL 和正文。', 'tablet/privacy、online-policy-settled'],
    ], [3, 9, 6])
    doc.add_paragraph('截图记录：欢迎页 05:37 UTC；采集及暂停 05:38 UTC。本页仅记录上述已执行步骤。')
    photos(doc, 'tablet', [('initial', '平板欢迎页'), ('live', '平板采集界面'), ('paused', '平板暂停界面')], 2.10)

    doc.add_page_break()
    doc.add_heading('智能手表 · 实际 Release 运行结果', 1)
    doc.add_paragraph(watch['properties']['const.product.software.version'] + '｜API 26｜当前 wearable HAP 安装成功')
    table(doc, ['已执行步骤', '观察结果', '原始证据'], [
        ['启动 / 开始观测', '圆屏欢迎页可滚动至“开始观测”；9 项模拟器公开虚拟传感器，加速度卡片显示“实时”，Y=9.800 m/s²。', 'watch/initial、start-scroll、live'],
        ['暂停', '滚动至采集控制，点击“暂停采集”后按钮变为“继续采集”。本项仅记录可观察的控制状态。', 'watch/pause-controls、paused-controls'],
        ['运动权限提示 / Deny', '主动点击“授权运动”后系统弹窗显示用途说明及 Allow / Deny；执行 Deny 返回观测页，随后普通加速度卡片仍显示实时。', 'watch/motion-request-bottom、motion-denied、live'],
    ], [3, 9, 6])
    doc.add_paragraph('运动拒绝操作已与实际系统提示中的 Deny 边界和成功输入记录核对。这里没有宣称运动权限已授予、计步测量已通过或实体旋钮操作已测试。')
    photos(doc, 'watch', [('live', '手表加速度实时界面'), ('paused-controls', '暂停后的继续采集按钮'), ('motion-request-bottom', '系统运动权限提示')], 2.10)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    doc.save(OUT)
    assert OUT.stat().st_size < 15 * 1024 * 1024
    reopened = Document(OUT)
    document_text = chr(10).join(p.text for p in reopened.paragraphs)
    assert all(digest in document_text for _, _, digest in PACKAGES.values())
    embedded = []
    with zipfile.ZipFile(OUT) as zf:
        assert zf.testzip() is None
        for name in zf.namelist():
            if name.endswith('.xml'):
                ET.fromstring(zf.read(name))
            if name.startswith('word/media/'):
                digest = sha(zf.read(name))
                matches = [key for key, meta in CAPTURED.items() if meta['screenshotSha256'] == digest]
                assert matches, ('Embedded image changed or lacks original provenance', name)
                embedded.append({'part': name, 'sha256': digest, 'sourceEvidence': matches})
        assert len(embedded) == 12
        xml = zf.read('word/document.xml').decode()
        assert '<a:srcRect' not in xml
        assert '.signing' not in xml
        assert not re.search(r'(?<!\d)1[3-9]\d{9}(?!\d)', xml), 'Unexpected phone-like number'
    audit = {
        'generatedAtUtc': datetime.now(timezone.utc).isoformat(),
        'document': {'path': str(OUT.relative_to(ROOT)), 'sha256': sha(OUT.read_bytes()), 'bytes': OUT.stat().st_size},
        'runtime': 'bundled Python / python-docx',
        'inputFiles': list(INPUTS.values()),
        'evidence': [{k: m[k] for k in ('metaPath', 'atUtc', 'installedPackageSha256', 'screenshot', 'screenshotSha256', 'pixelTransformation', 'provenance', 'imageSize')} for m in CAPTURED.values()],
        'embeddedMedia': embedded,
        'watchDenyAction': watch_deny,
        'checks': {'reopenedWithPythonDocx': True, 'zipCRC': True, 'allXmlParses': True, 'exactOriginalImageBytes': True, 'noCropping': True, 'below15MB': True, 'hapHashesPresent': True, 'noSigningFiles': True, 'noContactPhone': True},
        'includedRuntimeScope': ['phone current Release install/live/pause/resume/Home-return UI/local policy', 'PC current Release install/live/pause/details/local policy/online policy', 'tablet current Release install/welcome/live/pause/local policy/online policy', 'watch current Release install/welcome scroll/live/pause control/actual motion permission prompt/Deny and later ordinary live sensor UI'],
        'excludedClaims': ['physical hardware measurements/crown operation', 'minimum API runtime', 'motion permission grant/revoke/step measurement', 'frequency change/clear charts', 'sensor service subscription count', 'store backend upload/review/approval'],
        'externalActions': 'None; local document preparation only',
    }
    AUDIT.write_text(json.dumps(audit, ensure_ascii=False, indent=2) + chr(10))
    print(json.dumps(audit['document'], ensure_ascii=False))


if __name__ == '__main__':
    main()
