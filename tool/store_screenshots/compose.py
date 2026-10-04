"""Lays out the Google Play images from the raw screenshots.

Run from the root of the repository, after
    flutter test tool/store_screenshots --update-goldens
with:
    python tool/store_screenshots/compose.py
Needs Pillow (pip install pillow). Writes store/<language>/screenshots/*.png
(1080 x 1920) and store/<language>/feature-graphic.png (1024 x 500).
"""
import os

from PIL import Image, ImageDraw, ImageFont

SAIRA = 'assets/fonts/SairaSemiCondensed-ExtraBold.ttf'
OUTFIT = 'assets/fonts/Outfit-Medium.ttf'
ICON = 'assets/branding/play-store-icon-512.png'
COBALT = (45, 63, 224)
MARINE = (11, 16, 80)
ORANGE = (255, 138, 61)
WHITE = (255, 255, 255)

# Raw screenshot, theme, caption on two lines.
SCREENS = {
    'fr': [
        ('1-today', 'dark', 'Ton objectif protéines,', 'dans un shaker'),
        ('2-day', 'dark', 'Chaque moment', 'de ta journée'),
        ('3-history', 'dark', 'Ton historique', "d'un coup d'œil"),
        ('4-products', 'dark', 'Tes produits,', 'ajoutés en un geste'),
        ('5-entry', 'dark', 'Le calcul', 'est fait pour toi'),
        ('1-today', 'light', 'Clair ou sombre,', 'comme tu préfères'),
    ],
    'en': [
        ('1-today', 'dark', 'Your protein goal,', 'in a shaker'),
        ('2-day', 'dark', 'Every part', 'of your day'),
        ('3-history', 'dark', 'Your history', 'at a glance'),
        ('4-products', 'dark', 'Your foods,', 'added in one tap'),
        ('5-entry', 'dark', 'The math', 'is done for you'),
        ('1-today', 'light', 'Light or dark,', 'your choice'),
    ],
}
TAGLINES = {
    'fr': 'Suis tes protéines, simplement',
    'en': 'Track your protein, simply',
}


def rounded(image, radius):
    mask = Image.new('L', image.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, *image.size), radius, fill=255)
    out = image.convert('RGBA')
    out.putalpha(mask)
    return out


def screenshot(language, shot, theme, line1, line2, path):
    canvas = Image.new('RGB', (1080, 1920), COBALT)
    draw = ImageDraw.Draw(canvas)
    title = ImageFont.truetype(SAIRA, 92)
    for row, (text, color) in enumerate([(line1, WHITE), (line2, ORANGE)]):
        width = draw.textlength(text, font=title)
        draw.text(((1080 - width) / 2, 90 + row * 110), text, font=title, fill=color)

    raw = Image.open(f'tool/store_screenshots/{language}/{theme}-{shot}.png')
    height = 1560
    width = round(1080 * height / 1920)
    raw = raw.convert('RGB').resize((width, height), Image.LANCZOS)
    frame = rounded(Image.new('RGB', (width + 24, height + 24), MARINE), 64)
    canvas.paste(frame, ((1080 - width - 24) // 2, 370), frame)
    raw = rounded(raw, 52)
    canvas.paste(raw, ((1080 - width) // 2, 382), raw)
    canvas.save(path, optimize=True)


def feature_graphic(language, path):
    graphic = Image.new('RGB', (1024, 500), COBALT)
    draw = ImageDraw.Draw(graphic)
    icon = rounded(
        Image.open(ICON).convert('RGBA').resize((300, 300), Image.LANCZOS), 66
    )
    graphic.paste(icon, (80, 100), icon)
    name = ImageFont.truetype(SAIRA, 74)
    tagline = ImageFont.truetype(OUTFIT, 34)
    draw.text((420, 150), 'Protein', font=name, fill=WHITE)
    draw.text((420, 225), 'Calculator', font=name, fill=WHITE)
    draw.text((424, 325), TAGLINES[language], font=tagline, fill=ORANGE)
    graphic.save(path, optimize=True)


for language, screens in SCREENS.items():
    folder = f'store/{language}/screenshots'
    os.makedirs(folder, exist_ok=True)
    for index, (shot, theme, line1, line2) in enumerate(screens, 1):
        screenshot(language, shot, theme, line1, line2, f'{folder}/{index}.png')
    feature_graphic(language, f'store/{language}/feature-graphic.png')
    print(f'{language}: {len(screens)} screenshots and the feature graphic')
