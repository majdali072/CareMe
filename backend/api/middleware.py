"""
Security middleware for CareMe:
- Audit logging (HIPAA/GDPR compliance)
- HTTPS enforcement
- Rate limiting
- Security headers
"""

import datetime
import json
from django.conf import settings
from django.http import JsonResponse
from .db import get_db


# ---------- Audit Logging Middleware ----------

class AuditLogMiddleware:
    """Log all API access for compliance (HIPAA/GDPR).
    Records: who accessed what endpoint, when, from where, and the response status."""

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        response = self.get_response(request)

        # Only audit API endpoints
        if not request.path.startswith('/api/'):
            return response

        try:
            user_id = getattr(request, 'user_id', None)
            user_email = getattr(request, 'user_email', None)

            log_entry = {
                'timestamp': datetime.datetime.utcnow(),
                'user_id': user_id,
                'user_email': user_email,
                'method': request.method,
                'path': request.path,
                'status_code': response.status_code,
                'ip_address': self._get_client_ip(request),
                'user_agent': request.headers.get('User-Agent', '')[:256],
            }

            db = get_db()
            db.audit_logs.insert_one(log_entry)
        except Exception:
            # Never let audit logging break the request
            pass

        return response

    def _get_client_ip(self, request):
        x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
        if x_forwarded_for:
            return x_forwarded_for.split(',')[0].strip()
        return request.META.get('REMOTE_ADDR', '')


# ---------- HTTPS Enforcement Middleware ----------

class HttpsEnforcementMiddleware:
    """Redirect HTTP to HTTPS and set HSTS headers in production."""

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        # Only enforce in production (when DEBUG is False)
        if not settings.DEBUG:
            if not request.is_secure() and not request.META.get('HTTP_X_FORWARDED_PROTO') == 'https':
                url = request.build_absolute_uri(request.get_full_path())
                secure_url = url.replace('http://', 'https://', 1)
                return JsonResponse(
                    {'error': 'HTTPS required', 'redirect': secure_url},
                    status=301,
                )

        response = self.get_response(request)

        # Security headers
        if not settings.DEBUG:
            response['Strict-Transport-Security'] = 'max-age=31536000; includeSubDomains'
        response['X-Content-Type-Options'] = 'nosniff'
        response['X-Frame-Options'] = 'DENY'
        response['X-XSS-Protection'] = '1; mode=block'
        response['Referrer-Policy'] = 'strict-origin-when-cross-origin'

        return response


# ---------- Rate Limiting Middleware ----------

class RateLimitMiddleware:
    """Simple in-memory rate limiting for auth endpoints.
    For production, use Redis-backed rate limiting or a reverse proxy."""

    # endpoint -> (max_requests, window_seconds)
    RATE_LIMITS = {
        '/api/auth/login/': (5, 60),         # 5 attempts per minute
        '/api/auth/register/': (3, 60),      # 3 registrations per minute
        '/api/auth/send-otp/': (3, 60),      # 3 OTP requests per minute
        '/api/auth/verify-otp/': (5, 60),    # 5 OTP verifications per minute
    }

    def __init__(self, get_response):
        self.get_response = get_response
        self._cache = {}  # {(ip, path): [(timestamp, ...),]}

    def __call__(self, request):
        if request.method != 'POST':
            return self.get_response(request)

        path = request.path
        if path not in self.RATE_LIMITS:
            return self.get_response(request)

        max_requests, window = self.RATE_LIMITS[path]
        ip = self._get_client_ip(request)
        cache_key = (ip, path)
        now = datetime.datetime.utcnow()
        cutoff = now - datetime.timedelta(seconds=window)

        # Clean old entries and check count
        entries = self._cache.get(cache_key, [])
        entries = [t for t in entries if t > cutoff]

        if len(entries) >= max_requests:
            retry_after = int((entries[0] - cutoff).total_seconds()) + 1
            return JsonResponse(
                {'error': 'Too many requests. Please try again later.'},
                status=429,
                headers={'Retry-After': str(retry_after)},
            )

        entries.append(now)
        self._cache[cache_key] = entries

        # Periodic cleanup to prevent memory leak (every 1000th request)
        if sum(len(v) for v in self._cache.values()) > 10000:
            self._cleanup(cutoff)

        return self.get_response(request)

    def _get_client_ip(self, request):
        x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
        if x_forwarded_for:
            return x_forwarded_for.split(',')[0].strip()
        return request.META.get('REMOTE_ADDR', '')

    def _cleanup(self, cutoff):
        keys_to_delete = []
        for key, entries in self._cache.items():
            self._cache[key] = [t for t in entries if t > cutoff]
            if not self._cache[key]:
                keys_to_delete.append(key)
        for key in keys_to_delete:
            del self._cache[key]
