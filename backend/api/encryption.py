"""
Field-level encryption for sensitive health data stored in MongoDB.

Cipher: Fernet — AES-128-CBC for confidentiality plus an HMAC-SHA256
authentication tag for integrity. The Fernet key is the *Data Encryption Key*
(DEK).

KEY PROTECTION (envelope encryption — production)
-------------------------------------------------
The most secure configuration. The DEK is NEVER stored in plaintext on the
server. Instead:

  * AWS KMS holds the *Key Encryption Key* (KEK) inside an HSM and never
    releases it.
  * The DEK is stored only in KMS-wrapped (ciphertext) form, in the
    ``FIELD_ENCRYPTION_KEY_CIPHERTEXT`` environment variable / secret.
  * At process startup we make ONE call to KMS ``Decrypt`` to unwrap the DEK
    into memory; the plaintext key is cached for the process lifetime and never
    written to disk.
  * A fixed ``EncryptionContext`` (additional authenticated data) binds the
    wrapped key to this app + purpose, so a wrapped blob cannot be reused in a
    different context.

So a database dump alone is useless: decrypting the records requires the DEK,
which can only be recovered by an IAM principal authorised to call KMS Decrypt
on the KEK.

KEY ROTATION
------------
``FIELD_ENCRYPTION_KEY_CIPHERTEXT`` (and the dev ``FIELD_ENCRYPTION_KEY``) may
contain MULTIPLE keys separated by commas, newest first. We build a
``MultiFernet``: new data is encrypted with the first key, while decryption
transparently tries every key. To rotate: prepend a new wrapped DEK, deploy,
then (optionally) re-encrypt old records in the background and drop the old key.

LOCAL / DEV FALLBACK
--------------------
If no KMS ciphertext is configured, we fall back to a plaintext
``FIELD_ENCRYPTION_KEY`` so local development works without AWS. This fallback
is intended for dev only — production must use the KMS path.
"""

import base64
import hashlib
from cryptography.fernet import Fernet, MultiFernet
from django.conf import settings

_fernet = None


def _to_fernet(raw):
    """Build a Fernet from a key string. If it isn't already a valid Fernet
    key, derive one deterministically (kept for backward compatibility with the
    original behaviour)."""
    key_bytes = raw.encode() if isinstance(raw, str) else raw
    try:
        return Fernet(key_bytes)
    except Exception:
        derived = hashlib.sha256(key_bytes).digest()
        return Fernet(base64.urlsafe_b64encode(derived))


def _kms_encryption_context():
    """Additional authenticated data bound to the wrapped DEK. Must match on
    wrap and unwrap. Configurable but with a safe default."""
    return getattr(settings, 'KMS_ENCRYPTION_CONTEXT', None) or {
        'app': 'careme',
        'purpose': 'field-encryption',
    }


def _unwrap_with_kms(ciphertexts):
    """Given a list of base64 KMS-wrapped DEKs, call AWS KMS once per key to
    recover the plaintext DEKs and return the corresponding Fernet objects."""
    import boto3  # imported lazily so dev installs without boto3 still work

    region = getattr(settings, 'AWS_REGION', None) or None
    kms = boto3.client('kms', region_name=region)
    context = _kms_encryption_context()

    fernets = []
    for ct in ciphertexts:
        blob = base64.b64decode(ct)
        resp = kms.decrypt(CiphertextBlob=blob, EncryptionContext=context)
        plaintext_dek = resp['Plaintext']  # the original Fernet key bytes
        fernets.append(_to_fernet(plaintext_dek))
    return fernets


def _split(value):
    """Split a comma-separated key list, newest first, trimming blanks."""
    return [part.strip() for part in (value or '').split(',') if part.strip()]


def _get_fernet():
    """Resolve and cache the (Multi)Fernet used for all field encryption."""
    global _fernet
    if _fernet is not None:
        return _fernet

    # 1) Production: KMS-wrapped DEK(s).
    wrapped = _split(getattr(settings, 'FIELD_ENCRYPTION_KEY_CIPHERTEXT', ''))
    if wrapped:
        fernets = _unwrap_with_kms(wrapped)
        _fernet = fernets[0] if len(fernets) == 1 else MultiFernet(fernets)
        return _fernet

    # 2) Dev fallback: plaintext key(s) from the environment.
    plain = _split(getattr(settings, 'FIELD_ENCRYPTION_KEY', ''))
    if plain:
        fernets = [_to_fernet(k) for k in plain]
        _fernet = fernets[0] if len(fernets) == 1 else MultiFernet(fernets)
        return _fernet

    raise ValueError(
        'No field-encryption key configured. In production set '
        'FIELD_ENCRYPTION_KEY_CIPHERTEXT (a KMS-wrapped key) and KMS_KEY_ID; '
        'for local dev set FIELD_ENCRYPTION_KEY (generate one with: '
        'python -c "from cryptography.fernet import Fernet; '
        'print(Fernet.generate_key().decode())").'
    )


def encrypt_field(value):
    """Encrypt a string value. Returns encrypted string or original if empty."""
    if not value or not isinstance(value, str):
        return value
    return _get_fernet().encrypt(value.encode('utf-8')).decode('utf-8')


def decrypt_field(value):
    """Decrypt an encrypted string value. Returns decrypted string or original if not encrypted."""
    if not value or not isinstance(value, str):
        return value
    try:
        return _get_fernet().decrypt(value.encode('utf-8')).decode('utf-8')
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
