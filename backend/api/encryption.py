"""
Field-level encryption for sensitive health data stored in MongoDB.

Uses Fernet symmetric encryption (AES-128-CBC with HMAC-SHA256).
The encryption key is derived from FIELD_ENCRYPTION_KEY in settings/env.
"""

import base64
import hashlib
from cryptography.fernet import Fernet
from django.conf import settings

_fernet = None


def _get_fernet():
    global _fernet
    if _fernet is None:
        key = getattr(settings, 'FIELD_ENCRYPTION_KEY', '')
        if not key:
            raise ValueError(
                'FIELD_ENCRYPTION_KEY must be set in environment variables. '
                'Generate one with: python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"'
            )
        # If the key isn't already a valid Fernet key, derive one
        try:
            Fernet(key.encode() if isinstance(key, str) else key)
            fernet_key = key.encode() if isinstance(key, str) else key
        except Exception:
            # Derive a valid Fernet key from the provided secret
            derived = hashlib.sha256(key.encode()).digest()
            fernet_key = base64.urlsafe_b64encode(derived)
        _fernet = Fernet(fernet_key)
    return _fernet


def encrypt_field(value):
    """Encrypt a string value. Returns encrypted string or original if empty."""
    if not value or not isinstance(value, str):
        return value
    f = _get_fernet()
    return f.encrypt(value.encode('utf-8')).decode('utf-8')


def decrypt_field(value):
    """Decrypt an encrypted string value. Returns decrypted string or original if not encrypted."""
    if not value or not isinstance(value, str):
        return value
    try:
        f = _get_fernet()
        return f.decrypt(value.encode('utf-8')).decode('utf-8')
    except Exception:
        # Value is not encrypted (legacy data) — return as-is
        return value


# Fields that should be encrypted per collection
ENCRYPTED_FIELDS = {
    'medications': ['name', 'dosage', 'purpose', 'sideEffects'],
    'lab_tests': ['name', 'doctor'],
    'users': ['phone', 'dateOfBirth', 'address'],
}


def encrypt_document(collection_name, doc):
    """Encrypt sensitive fields in a document before storing."""
    fields = ENCRYPTED_FIELDS.get(collection_name, [])
    for field in fields:
        if field in doc and doc[field]:
            doc[field] = encrypt_field(str(doc[field]))
    return doc


def decrypt_document(collection_name, doc):
    """Decrypt sensitive fields in a document after reading."""
    if not doc:
        return doc
    fields = ENCRYPTED_FIELDS.get(collection_name, [])
    for field in fields:
        if field in doc and doc[field]:
            doc[field] = decrypt_field(doc[field])
    return doc
