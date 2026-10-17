#!/usr/bin/env python3
"""Updates the main Google Play listing from the store folder.

For each language of the store folder, replaces the title, the short and full
descriptions, the icon, the feature graphic, and the phone and Wear OS
screenshots, in the order of their numbers (`screenshots/1.png`...), with
those of the store folder: the images shown before are removed.

Usage:
  update_store_listing.py --plan       # prints what would be sent, offline
  update_store_listing.py --dry-run    # checks it with Google Play
  update_store_listing.py              # publishes it

The service account key is read from PLAY_SERVICE_ACCOUNT_JSON.
"""
import argparse
import json
import os
import re
import sys
from pathlib import Path

PACKAGE = 'arbitro.android.protein_calculator'

# Folder of each language in the store folder, and its Google Play code.
LANGUAGES = {'fr': 'fr-FR', 'en': 'en-US'}

# Most characters Google Play accepts.
LIMITS = {'title': 30, 'shortDescription': 80, 'fullDescription': 4000}

def numbered(folder):
    """Images of [folder] named by their number, in order."""
    images = [path for path in folder.glob('*.png') if re.fullmatch(r'\d+', path.stem)]
    return sorted(images, key=lambda path: int(path.stem))


def listing(store, folder):
    """Texts and images of the language in [folder] of [store]."""
    def text(name):
        return (folder / name).read_text(encoding='utf-8').strip()

    texts = {
        'title': text('title.txt'),
        'shortDescription': text('short_description.txt'),
        'fullDescription': text('full_description.txt'),
    }
    for field, limit in LIMITS.items():
        if len(texts[field]) > limit:
            sys.exit(f'{folder.name}: {field} has {len(texts[field])} characters, {limit} at most')
    images = {
        'icon': [store / 'icon-512.png'],
        'featureGraphic': [folder / 'feature-graphic.png'],
        'phoneScreenshots': numbered(folder / 'screenshots'),
        'wearScreenshots': numbered(folder / 'wear'),
    }
    for kind, paths in images.items():
        if not paths or not all(path.is_file() for path in paths):
            sys.exit(f'{folder.name}: no image for {kind}')
    return texts, images


def main():
    parser = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    parser.add_argument('--store', default='store', type=Path)
    parser.add_argument('--plan', action='store_true', help='print what would be sent, offline')
    parser.add_argument('--dry-run', action='store_true', help='check it with Google Play, without publishing')
    args = parser.parse_args()

    listings = {code: listing(args.store, args.store / folder) for folder, code in LANGUAGES.items()}
    for code, (texts, images) in listings.items():
        print(f'{code}: {texts["title"]!r}, short description of {len(texts["shortDescription"])} '
              f'characters, full description of {len(texts["fullDescription"])}')
        for kind, paths in images.items():
            print(f'  {kind}: {", ".join(path.name for path in paths)}')
    if args.plan:
        return

    from google.oauth2 import service_account
    from googleapiclient.discovery import build
    from googleapiclient.http import MediaFileUpload

    credentials = service_account.Credentials.from_service_account_info(
        json.loads(os.environ['PLAY_SERVICE_ACCOUNT_JSON']),
        scopes=['https://www.googleapis.com/auth/androidpublisher'],
    )
    edits = build('androidpublisher', 'v3', credentials=credentials, cache_discovery=False).edits()
    edit = edits.insert(packageName=PACKAGE, body={}).execute()['id']
    try:
        for code, (texts, images) in listings.items():
            # Patched, so the fields kept elsewhere, such as a video, stay.
            edits.listings().patch(
                packageName=PACKAGE, editId=edit, language=code, body={'language': code, **texts},
            ).execute()
            for kind, paths in images.items():
                edits.images().deleteall(
                    packageName=PACKAGE, editId=edit, language=code, imageType=kind,
                ).execute()
                for path in paths:
                    edits.images().upload(
                        packageName=PACKAGE, editId=edit, language=code, imageType=kind,
                        media_body=MediaFileUpload(str(path), mimetype='image/png'),
                    ).execute()
        if args.dry_run:
            edits.validate(packageName=PACKAGE, editId=edit).execute()
            print('Google Play accepts this listing; nothing was published.')
        else:
            edits.commit(packageName=PACKAGE, editId=edit).execute()
            print('Listing published.')
            edit = None
    finally:
        # A dry run, or a failure, leaves nothing behind.
        if edit is not None:
            edits.delete(packageName=PACKAGE, editId=edit).execute()


if __name__ == '__main__':
    main()
