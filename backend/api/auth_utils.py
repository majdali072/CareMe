import jwt
import bcrypt
import secrets
import datetime
from functools import wraps
from django.conf import settings
from django.http import JsonResponse
from .db import get_db


def hash_password(password):
    return bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')


def check_password(password, hashed):
    return bcrypt.checkpw(password.encode('utf-8'), hashed.encode('utf-8'))


def validate_password_strength(password):
    """Validate password meets security requirements for a medical app.
    Returns (is_valid, error_message)."""
    if len(password) < 8:
        return False, 'Password must be at least 8 characters'
    if not any(c.isupper() for c in password):
        return False, 'Password must contain an uppercase letter'
    if not any(c.islower() for c in password):
        return False, 'Password must contain a lowercase letter'
    if not any(c.isdigit() for c in password):
        return False, 'Password must contain a number'
    if not any(c in '!@#$%^&*(),.?":{}|<>' for c in password):
        return False, 'Password must contain a special character'
    return True, None


# --- Access Tokens (short-lived JWT) ---

ACCESS_TOKEN_EXPIRY_MINUTES = 30


def create_token(user_id, email):
    """Create a short-lived access token (30 minutes)."""
    payload = {
        'user_id': user_id,
        'email': email,
        'type': 'access',
        'exp': datetime.datetime.utcnow() + datetime.timedelta(minutes=ACCESS_TOKEN_EXPIRY_MINUTES),
        'iat': datetime.datetime.utcnow(),
    }
    return jwt.encode(payload, settings.JWT_SECRET, algorithm='HS256')


def decode_token(token):
    payload = jwt.decode(token, settings.JWT_SECRET, algorithms=['HS256'])
    if payload.get('type') != 'access':
        raise jwt.InvalidTokenError('Not an access token')
    return payload


# --- Refresh Tokens (long-lived, stored in DB) ---

REFRESH_TOKEN_EXPIRY_DAYS = 30


def create_refresh_token(user_id, email):
    """Create a long-lived refresh token stored in MongoDB."""
    db = get_db()
    token = secrets.token_urlsafe(64)
    now = datetime.datetime.utcnow()

    db.refresh_tokens.insert_one({
        'token': token,
        'user_id': user_id,
        'email': email,
        'created_at': now,
        'expires_at': now + datetime.timedelta(days=REFRESH_TOKEN_EXPIRY_DAYS),
        'revoked': False,
    })

    return token


def verify_refresh_token(token):
    """Verify a refresh token and return user info. Returns None if invalid."""
    db = get_db()
    record = db.refresh_tokens.find_one({'token': token, 'revoked': False})

    if not record:
        return None

    if datetime.datetime.utcnow() > record['expires_at']:
        db.refresh_tokens.delete_one({'_id': record['_id']})
        return None

    return {'user_id': record['user_id'], 'email': record['email']}


def revoke_refresh_token(token):
    """Revoke a specific refresh token."""
    db = get_db()
    db.refresh_tokens.update_one({'token': token}, {'$set': {'revoked': True}})


def revoke_all_refresh_tokens(user_id):
    """Revoke all refresh tokens for a user (e.g., on password change)."""
    db = get_db()
    db.refresh_tokens.update_many(
        {'user_id': user_id, 'revoked': False},
        {'$set': {'revoked': True}},
    )


# --- Auth decorator ---

def login_required(view_func):
    @wraps(view_func)
    def wrapper(request, *args, **kwargs):
        auth_header = request.headers.get('Authorization', '')
        if not auth_header.startswith('Bearer '):
            return JsonResponse({'error': 'Authentication required'}, status=401)
        try:
            payload = decode_token(auth_header[7:])
            request.user_id = payload['user_id']
            request.user_email = payload['email']
        except jwt.ExpiredSignatureError:
            return JsonResponse({'error': 'Token expired', 'code': 'token_expired'}, status=401)
        except jwt.InvalidTokenError:
            return JsonResponse({'error': 'Invalid token'}, status=401)
        return view_func(request, *args, **kwargs)
    return wrapper


def admin_required(view_func):
    """Requires a valid token AND the user to have is_admin=True in the DB."""
    from bson import ObjectId

    @wraps(view_func)
    def wrapper(request, *args, **kwargs):
        auth_header = request.headers.get('Authorization', '')
        if not auth_header.startswith('Bearer '):
            return JsonResponse({'error': 'Authentication required'}, status=401)
        try:
            payload = decode_token(auth_header[7:])
        except jwt.ExpiredSignatureError:
            return JsonResponse({'error': 'Token expired', 'code': 'token_expired'}, status=401)
        except jwt.InvalidTokenError:
            return JsonResponse({'error': 'Invalid token'}, status=401)

        db = get_db()
        user = db.users.find_one({'_id': ObjectId(payload['user_id'])})
        if not user or not user.get('is_admin'):
            return JsonResponse({'error': 'Admin access required'}, status=403)

        request.user_id = payload['user_id']
        request.user_email = payload['email']
        return view_func(request, *args, **kwargs)
    return wrapper
