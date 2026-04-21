"""
Django management command that checks all medications and sends FCM
push notifications for any that are due right now.

Run every minute via:
    python manage.py send_reminders --loop

Or via cron/Task Scheduler:
    * * * * * cd /path/to/backend && python manage.py send_reminders
"""
import time
from datetime import datetime
from bson import ObjectId
from django.core.management.base import BaseCommand

try:
    from firebase_admin import messaging as fcm
except ImportError:
    fcm = None

from api.db import get_db
from api.encryption import decrypt_document


class Command(BaseCommand):
    help = 'Send FCM medication reminders for the current minute'

    def add_arguments(self, parser):
        parser.add_argument(
            '--loop',
            action='store_true',
            help='Run continuously, checking every 60 seconds',
        )

    def handle(self, *args, **options):
        if not fcm:
            self.stderr.write('firebase-admin not installed')
            return

        if options['loop']:
            self.stdout.write('Starting reminder loop (Ctrl+C to stop)...')
            while True:
                self._check_and_send()
                # Sleep until the next minute boundary
                now = datetime.now()
                sleep_seconds = 60 - now.second
                time.sleep(sleep_seconds)
        else:
            self._check_and_send()

    def _check_and_send(self):
        now = datetime.now()
        current_day = now.strftime('%A')  # Monday, Tuesday, etc.
        current_time = now.strftime('%H:%M')

        db = get_db()

        # Find all users with FCM tokens
        users = list(db.users.find({'fcm_token': {'$exists': True, '$ne': ''}}))

        total_sent = 0

        for user in users:
            user_id = str(user['_id'])
            fcm_token = user.get('fcm_token')
            if not fcm_token:
                continue

            meds = list(db.medications.find({'user_id': user_id}))
            meds = [decrypt_document('medications', m) for m in meds]

            for med in meds:
                schedule = med.get('schedule')
                if not schedule:
                    continue

                # Skip medications that have been marked as history —
                # past meds should never trigger reminders.
                if med.get('isHistory'):
                    continue

                # Skip PRN ("taken when needed") meds — no reminders.
                if med.get('isPrn'):
                    continue

                # Check date range
                start_str = med.get('startDate')
                end_str = med.get('endDate')
                is_lifetime = med.get('isLifetime', False)

                if start_str:
                    try:
                        start_date = datetime.fromisoformat(
                            start_str.replace('Z', '+00:00')
                        ).replace(tzinfo=None)
                        if now < start_date:
                            continue
                    except Exception:
                        pass

                if not is_lifetime and end_str:
                    try:
                        end_date = datetime.fromisoformat(
                            end_str.replace('Z', '+00:00')
                        ).replace(tzinfo=None)
                        if now > end_date:
                            continue
                    except Exception:
                        pass

                for entry in schedule:
                    day = entry.get('day', '')
                    times = entry.get('times', [])
                    if day.lower() != current_day.lower():
                        continue

                    for t in times:
                        if t.strip() == current_time:
                            try:
                                message = fcm.Message(
                                    notification=fcm.Notification(
                                        title=f"Time for {med.get('name', 'medication')}",
                                        body=f"Take {med.get('dosage', '')}",
                                    ),
                                    android=fcm.AndroidConfig(
                                        priority='high',
                                        notification=fcm.AndroidNotification(
                                            channel_id='meds_channel',
                                            priority='max',
                                            default_sound=True,
                                            default_vibrate_timings=True,
                                        ),
                                    ),
                                    token=fcm_token,
                                )
                                fcm.send(message)
                                total_sent += 1
                                self.stdout.write(
                                    f"  Sent: {med.get('name')} -> "
                                    f"{user.get('name', user_id)}"
                                )
                            except Exception as e:
                                self.stderr.write(f"  FCM error: {e}")

        if total_sent > 0:
            self.stdout.write(f'[{current_time}] Sent {total_sent} reminder(s)')
