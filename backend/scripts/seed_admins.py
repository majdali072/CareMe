"""Seed two admin accounts into MongoDB.

Credentials are read from environment variables; missing ones are prompted
interactively via getpass (never shown on screen, never in shell history).

Env vars (optional; missing ones are prompted):
    ADMIN1_NAME, ADMIN1_EMAIL, ADMIN1_PASSWORD
    ADMIN2_NAME, ADMIN2_EMAIL, ADMIN2_PASSWORD

Usage (from backend/ directory):
    python scripts/seed_admins.py            # create, refuse if exists
    python scripts/seed_admins.py --force    # update existing admins' password

Never commit the filled-in credentials. .env is gitignored — prefer that.
"""

import argparse
import getpass
import os
import sys
from datetime import datetime
from pathlib import Path

# Make Django settings importable when running this file directly.
BACKEND_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(BACKEND_DIR))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'careme.settings')

import django  # noqa: E402
django.setup()

from api.auth_utils import hash_password, validate_password_strength  # noqa: E402
from api.views import get_db  # noqa: E402


def _prompt_missing(slot: int, force: bool, show_password: bool = False) -> dict:
    prefix = f'ADMIN{slot}'
    name = os.environ.get(f'{prefix}_NAME') or input(f'Admin #{slot} name: ').strip()
    email = os.environ.get(f'{prefix}_EMAIL') or input(f'Admin #{slot} email: ').strip()
    email = email.lower()
    password = os.environ.get(f'{prefix}_PASSWORD')
    if not password:
        if show_password:
            # Visible input — useful for local seeding when typing blindly is causing typos.
            password = input(f'Admin #{slot} password (VISIBLE): ')
        else:
            password = getpass.getpass(f'Admin #{slot} password: ')
            confirm = getpass.getpass(f'Admin #{slot} password (confirm): ')
            if password != confirm:
                raise SystemExit(f'[admin #{slot}] passwords do not match — aborting.')

    if not name or not email or not password:
        raise SystemExit(f'[admin #{slot}] name, email, and password are all required.')

    valid, err = validate_password_strength(password)
    if not valid:
        raise SystemExit(f'[admin #{slot}] weak password: {err}')

    return {'name': name, 'email': email, 'password': password}


def seed_admin(db, slot: int, data: dict, force: bool) -> None:
    existing = db.users.find_one({'email': data['email']})
    if existing and not force:
        print(f'[admin #{slot}] {data["email"]} already exists — skipping. Use --force to update.')
        return

    doc = {
        'name': data['name'],
        'email': data['email'],
        'password': hash_password(data['password']),
        'is_admin': True,
        'deactivated': False,
    }

    if existing:
        db.users.update_one({'_id': existing['_id']}, {'$set': {
            **doc,
            'updated_at': datetime.utcnow(),
        }})
        print(f'[admin #{slot}] updated {data["email"]}.')
    else:
        doc['created_at'] = datetime.utcnow()
        db.users.insert_one(doc)
        print(f'[admin #{slot}] created {data["email"]}.')


def main() -> None:
    parser = argparse.ArgumentParser(description='Seed two admin accounts.')
    parser.add_argument('--force', action='store_true',
                        help='Overwrite existing accounts with the provided credentials.')
    parser.add_argument('--show-password', action='store_true',
                        help='Show password as you type (easier, less secure — only use on a trusted machine).')
    args = parser.parse_args()

    db = get_db()

    for slot in (1, 2):
        data = _prompt_missing(slot, args.force, show_password=args.show_password)
        seed_admin(db, slot, data, force=args.force)

    print('Done.')


if __name__ == '__main__':
    main()
