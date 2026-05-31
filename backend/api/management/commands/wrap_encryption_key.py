"""
Wrap the field-encryption data key (DEK) with AWS KMS for envelope encryption.

The output is a base64 KMS-ciphertext to put in FIELD_ENCRYPTION_KEY_CIPHERTEXT.
Once set (with KMS_KEY_ID), the app unwraps the DEK via KMS at startup and the
plaintext key never has to live on the server.

Default: wrap the EXISTING plaintext FIELD_ENCRYPTION_KEY so all current data
keeps decrypting (no re-encryption needed) — this is the migration path.

  python manage.py wrap_encryption_key

Generate a brand-new key instead (WARNING: existing encrypted data will no
longer decrypt unless you keep the old key for rotation):

  python manage.py wrap_encryption_key --generate
"""
import base64

from django.conf import settings
from django.core.management.base import BaseCommand, CommandError

from api.encryption import _kms_encryption_context


class Command(BaseCommand):
    help = 'Wrap the field-encryption data key with AWS KMS (envelope encryption).'

    def add_arguments(self, parser):
        parser.add_argument(
            '--generate', action='store_true',
            help='Generate a fresh data key instead of wrapping the existing one.',
        )

    def handle(self, *args, **options):
        key_id = getattr(settings, 'KMS_KEY_ID', '')
        if not key_id:
            raise CommandError('KMS_KEY_ID is not set. Set it to your KMS key id, ARN, or alias/<name>.')

        try:
            import boto3
        except ImportError:
            raise CommandError('boto3 is not installed. Add it (pip install boto3) to use AWS KMS.')

        if options['generate']:
            from cryptography.fernet import Fernet
            dek = Fernet.generate_key()  # 44-byte url-safe base64 Fernet key
            self.stdout.write(self.style.WARNING(
                'Generated a NEW data key. Existing encrypted records will not '
                'decrypt with it alone — keep the old wrapped key in the '
                'comma-separated list for rotation.'))
        else:
            existing = (getattr(settings, 'FIELD_ENCRYPTION_KEY', '') or '').strip()
            if not existing:
                raise CommandError(
                    'FIELD_ENCRYPTION_KEY is empty. Set the current plaintext key '
                    'to wrap it, or pass --generate to create a new one.')
            dek = existing.encode('utf-8')

        region = getattr(settings, 'AWS_REGION', None) or None
        kms = boto3.client('kms', region_name=region)
        resp = kms.encrypt(
            KeyId=key_id,
            Plaintext=dek,
            EncryptionContext=_kms_encryption_context(),
        )
        wrapped = base64.b64encode(resp['CiphertextBlob']).decode('ascii')

        self.stdout.write('')
        self.stdout.write(self.style.SUCCESS('KMS-wrapped data key (set as FIELD_ENCRYPTION_KEY_CIPHERTEXT):'))
        self.stdout.write('')
        self.stdout.write(wrapped)
        self.stdout.write('')
        self.stdout.write(
            'Then, in production, you can REMOVE the plaintext FIELD_ENCRYPTION_KEY '
            'from the environment — the app will unwrap the key via KMS.')
