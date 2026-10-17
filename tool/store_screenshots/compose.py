"""Lays out the Google Play images from the raw screenshots.

Run from the root of the repository, after
    flutter test tool/store_screenshots --update-goldens
and, from android/, for the watch app:
    ./gradlew :wear:testDebugUnitTest -PstoreScreenshots --tests '*StoreScreenshotsTest'
with:
    python tool/store_screenshots/compose.py
Needs Pillow (pip install pillow). Writes store/<language>/screenshots/<n>.png
(1080 x 1920), store/<language>/feature-graphic.png (1024 x 500) and
store/<language>/wear/<n>.png (384 x 384), in place of the images of the
previous version, which the screenshot folders lose first.
"""
import os
import re

from PIL import Image, ImageDraw, ImageFont

SAIRA = 'assets/fonts/SairaSemiCondensed-ExtraBold.ttf'
OUTFIT = 'assets/fonts/Outfit-Medium.ttf'
ICON = 'assets/branding/play-store-icon-512.png'
COBALT = (45, 63, 224)
MARINE = (16, 20, 46)
ORANGE = (255, 138, 61)
WHITE = (255, 255, 255)

# Raw screenshot, theme, caption on two lines.
SCREENS = {
    'fr': [
        ('1-today', 'light', 'Ton objectif et', 'ta progression du jour'),
        ('2-day', 'light', 'Suis du matin', 'au soir'),
        ('3-calendar', 'light', 'Ton mois', "en un coup d'œil"),
        ('4-products', 'light', 'Tes aliments,', 'toujours sous la main'),
        ('5-scan', 'light', 'Scanne un produit,', 'tout est rempli'),
        ('6-entry', 'light', 'Les protéines', 'calculées pour toi'),
    ],
    'en': [
        ('1-today', 'light', 'Your goal and', "today's progress"),
        ('2-day', 'light', 'Track from morning', 'to night'),
        ('3-calendar', 'light', 'Your month', 'at a glance'),
        ('4-products', 'light', 'Your foods,', 'always at hand'),
        ('5-scan', 'light', 'Scan a product,', "it's all filled in"),
        ('6-entry', 'light', 'Protein,', 'worked out for you'),
    ],
}
# Raw screenshots of the watch app, rendered by android/wear
# (StoreScreenshotsTest): shown as they are, as Google Play wants the
# interface of the app alone, without frame nor text.
WATCH_SCREENS = ['1-day', '2-entries', '3-products', '4-tile']

TAGLINES = {
    'fr': 'Suis tes protéines, simplement',
    'en': 'Track your protein, simply',
}


def stamp(image, version):
    """Shifts one corner pixel by an invisible amount, depending on the
    version: each version gets files of its own, which Google Play does not
    deduplicate with images uploaded for earlier versions."""
    red, green, blue = image.getpixel((0, 0))[:3]
    shift = 1 + sum(map(ord, version)) % 3
    image.putpixel((0, 0), (red, green, (blue + shift) % 256))
    return image


def rounded(image, radius):
    mask = Image.new('L', image.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, *image.size), radius, fill=255)
    out = image.convert('RGBA')
    out.putalpha(mask)
    return out


# EAN-13 digit patterns: left half (odd, even parity), right half.
EAN_L = ['0001101', '0011001', '0010011', '0111101', '0100011',
         '0110001', '0101111', '0111011', '0110111', '0001011']
EAN_G = ['0100111', '0110011', '0011011', '0100001', '0011101',
         '0111001', '0000101', '0010001', '0001001', '0010111']
EAN_R = ['1110010', '1100110', '1101100', '1000010', '1011100',
         '1001110', '1010000', '1000100', '1001000', '1110100']
EAN_PARITY = ['LLLLLL', 'LLGLGG', 'LLGGLG', 'LLGGGL', 'LGLLGG',
              'LGGLLG', 'LGGGLL', 'LGLGLG', 'LGLGGL', 'LGGLGL']

# A made-up product code, valid but of no real product.
BARCODE = '3761234567895'


def ean13(code):
    """Modules of the EAN-13 [code], 1 for a bar."""
    parity = EAN_PARITY[int(code[0])]
    left = ''.join(
        (EAN_L if p == 'L' else EAN_G)[int(d)] for p, d in zip(parity, code[1:7])
    )
    right = ''.join(EAN_R[int(d)] for d in code[7:])
    return '101' + left + '01010' + right + '101'


def barcode_in_frame(raw):
    """[raw], the scan screen without camera, with the label of a product
    held in its frame, as the camera would show it."""
    draw = ImageDraw.Draw(raw)
    draw.rounded_rectangle((210, 700, 870, 1220), 36, fill=(245, 242, 235))
    modules = ean13(BARCODE)
    unit = 5
    left = (1080 - len(modules) * unit) // 2
    for index, module in enumerate(modules):
        if module == '1':
            x = left + index * unit
            draw.rectangle((x, 790, x + unit - 1, 1090), fill=(20, 20, 20))
    digits = ImageFont.truetype(OUTFIT, 44)
    text = f'{BARCODE[0]} {BARCODE[1:7]} {BARCODE[7:]}'
    width = draw.textlength(text, font=digits)
    draw.text(((1080 - width) / 2, 1110), text, font=digits, fill=(20, 20, 20))
    return raw


def screenshot(language, shot, theme, line1, line2, path):
    canvas = Image.new('RGB', (1080, 1920), COBALT)
    draw = ImageDraw.Draw(canvas)
    title = ImageFont.truetype(SAIRA, 92)
    for row, (text, color) in enumerate([(line1, WHITE), (line2, ORANGE)]):
        width = draw.textlength(text, font=title)
        draw.text(((1080 - width) / 2, 90 + row * 110), text, font=title, fill=color)

    raw = Image.open(f'tool/store_screenshots/{language}/{theme}-{shot}.png')
    if shot == '5-scan':
        raw = barcode_in_frame(raw.convert('RGB'))
    height = 1560
    width = round(1080 * height / 1920)
    raw = raw.convert('RGB').resize((width, height), Image.LANCZOS)
    frame = rounded(Image.new('RGB', (width + 24, height + 24), MARINE), 64)
    canvas.paste(frame, ((1080 - width - 24) // 2, 370), frame)
    raw = rounded(raw, 52)
    canvas.paste(raw, ((1080 - width) // 2, 382), raw)
    stamp(canvas, VERSION).save(path, optimize=True)


def watch_screenshot(language, shot, path):
    raw = Image.open(f'tool/store_screenshots/{language}/wear-{shot}.png')
    # Without transparency, which Google Play refuses.
    stamp(raw.convert('RGB'), VERSION).save(path, optimize=True)


def feature_graphic(language, path):
    graphic = Image.new('RGB', (1024, 500), COBALT)
    draw = ImageDraw.Draw(graphic)
    # The background of the icon is the cobalt of the graphic: only the
    # shaker shows, as large as the height allows.
    icon = rounded(
        Image.open(ICON).convert('RGBA').resize((440, 440), Image.LANCZOS), 97
    )
    graphic.paste(icon, (0, 30), icon)
    name = ImageFont.truetype(SAIRA, 112)
    tagline = ImageFont.truetype(OUTFIT, 42)
    draw.text((390, 88), 'Protein', font=name, fill=WHITE)
    draw.text((390, 188), 'Calculator', font=name, fill=WHITE)
    draw.text((394, 342), TAGLINES[language], font=tagline, fill=ORANGE)
    stamp(graphic, VERSION).save(path, optimize=True)


with open('pubspec.yaml', encoding='utf-8') as pubspec:
    VERSION = re.search(r'^version: *([^+\s]+)', pubspec.read(), re.M).group(1)

def empty(folder):
    """Creates [folder], or removes its images: a screenshot dropped since
    the previous version does not stay behind."""
    os.makedirs(folder, exist_ok=True)
    for name in os.listdir(folder):
        if name.endswith('.png'):
            os.remove(os.path.join(folder, name))


for language, screens in SCREENS.items():
    folder = f'store/{language}/screenshots'
    empty(folder)
    for index, (shot, theme, line1, line2) in enumerate(screens, 1):
        screenshot(language, shot, theme, line1, line2, f'{folder}/{index}.png')
    feature_graphic(language, f'store/{language}/feature-graphic.png')
    wear = f'store/{language}/wear'
    empty(wear)
    for index, shot in enumerate(WATCH_SCREENS, 1):
        watch_screenshot(language, shot, f'{wear}/{index}.png')
    print(
        f'{language} {VERSION}: {len(screens)} screenshots, the feature graphic '
        f'and {len(WATCH_SCREENS)} screenshots of the watch app'
    )
