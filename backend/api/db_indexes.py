"""
Run once to create MongoDB indexes for security collections.
Usage: python manage.py shell -c "from api.db_indexes import create_indexes; create_indexes()"
"""

from .db import get_db


def create_indexes():
    db = get_db()

    # Refresh tokens: lookup by token, cleanup by expiry
    db.refresh_tokens.create_index('token', unique=True)
    db.refresh_tokens.create_index('user_id')
    db.refresh_tokens.create_index('expires_at', expireAfterSeconds=0)

    # Audit logs: query by user, time-based retention (auto-delete after 1 year)
    db.audit_logs.create_index('user_id')
    db.audit_logs.create_index([('timestamp', 1)], name='timestamp_ttl', expireAfterSeconds=365 * 24 * 3600)

    # OTP codes: auto-expire
    db.otp_codes.create_index('expires_at', expireAfterSeconds=0)

    print('All indexes created successfully.')
