import io
import json
import math
import re
import random
import base64
import requests
from datetime import datetime, timedelta
from bson import ObjectId
from django.conf import settings
from django.http import JsonResponse, HttpResponse, StreamingHttpResponse
from django.views.decorators.http import require_http_methods
from django.views.decorators.csrf import csrf_exempt
from gridfs import GridFS
from reportlab.lib.pagesizes import letter
from reportlab.lib import colors
from reportlab.lib.units import inch
from reportlab.platypus import SimpleDocTemplate, Table, TableStyle, Paragraph, Spacer
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from django.core.mail import send_mail
from .db import get_db
from .auth_utils import (
    hash_password, check_password, create_token, login_required, admin_required,
    validate_password_strength, create_refresh_token, verify_refresh_token,
    revoke_refresh_token, revoke_all_refresh_tokens,
)
from .encryption import encrypt_document, decrypt_document

try:
    from firebase_admin import messaging as fcm_messaging
except ImportError:
    fcm_messaging = None

# ---------- Gemini setup ----------

## `gemini-2.5-flash` (not `-lite`) is required because google_search
## grounding is only supported on flash and pro variants.
## Use the Generative Language API endpoint (`generativelanguage.googleapis.com`)
## because it accepts API-key auth via `?key=`. The `aiplatform.googleapis.com`
## variant requires an OAuth bearer token, which is why API-key requests there
## intermittently fail with the generic "Upstream error" surfaced to the app.
GEMINI_API_URL = (
    'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent'
    f'?key={settings.GEMINI_API_KEY}'
)

GEMINI_STREAM_URL = (
    'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:streamGenerateContent'
    f'?alt=sse&key={settings.GEMINI_API_KEY}'
)

# Google Search grounding lets the model fetch fresh info from the web.
GEMINI_TOOLS = [{'google_search': {}}]

SYSTEM_PROMPT = (
    "You are CareAI, a helpful and friendly health assistant for the CareMe app. "
    "You ONLY answer questions related to health, medicine, medications, appointments, "
    "lab results, symptoms, wellness, nutrition, fitness, and mental health. "
    "If a user asks about anything unrelated to health or medicine, politely decline and say: "
    "\"I can only help with health and medical-related questions. Please ask me something about your health!\" "
    "Do not answer questions about politics, entertainment, coding, math, history, or any non-medical topic. "
    "Be concise, caring, and accurate. If you are unsure about medical advice, recommend consulting a doctor. "
    "Do not diagnose conditions. Keep responses short and helpful. "
    "You have access to Google Search -- use it when the user asks about recent or time-sensitive "
    "health information (new guidelines, recalls, outbreaks, current drug availability, recent research). "
    "When you rely on search results, briefly summarise the finding in plain language. Prefer reputable "
    "medical sources (WHO, CDC, NHS, peer-reviewed journals, established medical organisations). "
    "\n\nOUTPUT STYLE (strict):\n"
    "Use plain ASCII characters only. Do NOT use emojis, em-dashes, en-dashes, smart quotes, "
    "curly apostrophes, arrows, or any decorative Unicode characters. For dashes use \"--\". "
    "For quotes use straight \" and '. For arrows use \"->\". Keep formatting simple: short paragraphs, "
    "plain bullet points with \"-\", and bold via Markdown (**text**) only when it really helps. "
    "\n\nLANGUAGE (highest priority, overrides every other rule below):\n"
    "Look at the LAST user message in this conversation and identify the language it is written in. "
    "You MUST reply in EXACTLY that language, regardless of the app's UI locale, regardless of what "
    "language earlier turns used, and regardless of the language this system prompt is in. Examples:\n"
    "- User writes in Arabic -> entire reply in Arabic, including the safety warning, doctor labels, "
    "  refusals, and the consult-your-doctor reminder. Use Arabic medical terminology.\n"
    "- User writes in French -> entire reply in French.\n"
    "- User writes in Spanish -> entire reply in Spanish.\n"
    "- User writes in mixed languages -> reply in the dominant language of their message.\n"
    "- User writes a single word or emoji that doesn't reveal a language -> use the 'User UI locale' "
    "  hint at the end of this prompt.\n"
    "Translate ALL fixed phrases, including warnings and disclaimers, into the user's message language. "
    "Never reply in English just because this prompt is in English. The user's message language ALWAYS "
    "wins, with the locale hint only used as a tiebreaker when the message has no detectable language. "
    "\n\nMEDICATION SAFETY:\n"
    "WHENEVER you mention, suggest, recommend, or discuss a specific medication, including "
    "over-the-counter drugs, supplements, dosages, or alternatives, you MUST end that response with a "
    "clear warning that the user should consult a qualified healthcare professional (such as a doctor "
    "or pharmacist) before starting, stopping, or changing any medication. Phrase it naturally, for "
    "example: \"Please talk to your doctor or pharmacist before taking any medication. They can "
    "check it is safe for you, your other meds, and your health conditions.\" Never imply that your "
    "suggestion is a substitute for professional medical judgment. "
    "\n\nPERSONALISED SAFETY CHECK (MANDATORY ON EVERY SINGLE RESPONSE, NO EXCEPTIONS):\n"
    "Before composing ANY reply -- including casual answers, greetings, follow-up clarifications, and "
    "questions about something seemingly unrelated -- you MUST silently re-read the \"User's active "
    "medications\" and \"User's recent lab tests\" lists supplied below from scratch. Do NOT rely on what "
    "you may have remembered from earlier turns; the lists may have changed (the user can add or "
    "remove items at any time). Treat these as the ground truth of what the user is currently taking "
    "and any results they have on file. If files (PDFs or images) are attached, read them and use their "
    "contents too -- the most recently uploaded file is most relevant.\n"
    "Apply this safety check even when the user's question seems trivial: a question about a food, an "
    "exercise, a vitamin, alcohol, caffeine, dental work, vaccinations, sleep, supplements, herbal "
    "remedies, or any health topic CAN interact with their meds and labs. Skim the list every time, "
    "then proceed with the answer.\n"
    "- If the user asks about a NEW medication, supplement, OTC, or dosage change, you MUST check it against "
    "every active medication the user is on. If you spot a known interaction, contraindication, duplicate "
    "drug class, or risk amplified by their lab results (e.g. NSAIDs with poor kidney function, statins with "
    "certain antibiotics, anticoagulants with antiplatelets), START the response with a clearly labelled "
    "WARNING block listing the conflicting drug(s) and the specific risk. Use Google Search to verify "
    "interactions when you are not certain.\n"
    "- If the user mentions a SURGERY, procedure, dental work, biopsy, or anything involving cuts, anaesthesia, "
    "or invasive intervention, scan their active medications and lab tests for surgical risks (e.g. aspirin, "
    "warfarin, clopidogrel, DOACs, SSRIs, NSAIDs -> bleeding risk; metformin -> lactic acidosis with contrast; "
    "ACE inhibitors -> hypotension under anaesthesia; herbal supplements like ginkgo, garlic, fish oil -> "
    "bleeding) and abnormal labs that affect surgical safety (e.g. low platelets, abnormal INR, anaemia, "
    "uncontrolled glucose). Open the response with a WARNING block naming each medication or lab finding and "
    "the concrete risk it creates for that procedure, then advise the user to inform their surgeon and follow "
    "their pre-op instructions.\n"
    "- If no relevant interaction or surgical risk is found, briefly note that you reviewed the user's active "
    "medications/labs and did not find an obvious conflict, then continue with the regular answer. Always "
    "remind the user that this is not a substitute for clinical judgment.\n"
    "- Never invent medications or lab results that are not in the supplied lists. If a list is empty, say so "
    "and ask the user to confirm what they are taking before you give a safety opinion. "
    "\n\nDOCTOR & PHARMACY RECOMMENDATIONS:\n"
    "When the user describes a sickness, condition, symptom, or asks which doctor to see, "
    "follow these steps: "
    "(1) Identify the medical specialty that treats that condition or symptom "
    "(e.g. chest pain -> Cardiology, skin rash -> Dermatology, toothache -> Dentistry, "
    "depression/anxiety -> Psychiatry, broken bone -> Orthopedics, stomach pain -> Gastroenterology, "
    "child illness -> Pediatrics, eye problems -> Ophthalmology, ear/nose/throat -> ENT, "
    "pregnancy -> Obstetrics/Gynecology, general checkup -> General Practitioner / Family Medicine). "
    "(2) Look through the \"Nearby doctors\" list below and pick EVERY doctor whose specialty "
    "matches (exact match OR clearly related specialty). "
    "(3) List ALL matching doctors, not just one, sorted by distance (closest first). "
    "For each one, show the full details: name, specialty, address, phone, and distance. "
    "(4) If no doctor in the list matches the needed specialty, say so and suggest the nearest "
    "General Practitioner / Family Medicine doctor if one exists; otherwise tell the user that "
    "no suitable doctor is currently listed. "
    "(5) If the user asks about filling a prescription or buying medicine, list the nearby "
    "pharmacies with full contact info, sorted by distance. "
    "ONLY recommend doctors/pharmacies that appear in the lists below. Never invent entries. "
    "If no nearby list is available, tell the user to set their address in the account screen. "
    "\n\nACTIONS (adding records on the user's behalf):\n"
    "If, AND ONLY IF, the user clearly asks you to ADD / CREATE / SCHEDULE / RECORD a medication or "
    "appointment for them (examples: \"add ibuprofen 400mg twice a day\", \"schedule a dentist visit "
    "next Friday at 10am\", \"please save this prescription\"), follow this two-phase flow.\n"
    "\n"
    "DEFAULT DOSE UNIT: When the user gives a number with no unit (e.g. \"500\", \"100\"), assume **mg** "
    "and write it that way in the dosage field (e.g. \"500 mg\"). Only use a different unit (mcg, g, mL, IU, "
    "drops, puffs) when the user explicitly says so.\n"
    "\n"
    "PRN (TAKEN-WHEN-NEEDED) DETECTION: If the user describes the medication with phrases like "
    "\"as needed\", \"when needed\", \"PRN\", \"only when X\", \"if I have a headache\", or any equivalent "
    "in any language, treat it as a PRN medication: SKIP all schedule questions (no days, no times, no "
    "start/end date), and set `prn` to true in the action fields. Reminders are not set for PRN meds.\n"
    "\n"
    "LIFETIME DETECTION: If the user says \"forever\", \"always\", \"lifetime\", \"ongoing\", \"indefinitely\", "
    "\"for life\", or any equivalent in any language, set `lifetime` to true in the action fields. "
    "In that case do not require an end date; only ask for the start date if missing.\n"
    "\n"
    "PHASE 1 -- COLLECT MISSING DETAILS.\n"
    "Before you emit any action block you must have enough info to save the record. Do NOT guess or "
    "invent values. If anything required is missing, REPLY WITH QUESTIONS ONLY -- no action block on "
    "this turn. Be friendly and group your questions into one short message, not one at a time.\n"
    "  For add_medication you need:\n"
    "    - the medication name,\n"
    "    - the dosage (apply the mg default above if no unit was given),\n"
    "    - EITHER the user marks it as PRN (then nothing else is needed),\n"
    "    - OR the schedule (days of the week, times of day) AND a start date AND either an end date "
    "      or a lifetime flag.\n"
    "    If the user has not specified PRN or a schedule, ASK for the days, times, and start/end date "
    "    in plain language. Example: \"Got it -- which days should I remind you? What times of day? "
    "    When do you want to start, and is it short-term (give me an end date) or ongoing (forever / "
    "    lifetime)?\"\n"
    "  For add_appointment you need:\n"
    "    - title (who/what the appointment is with),\n"
    "    - date (YYYY-MM-DD),\n"
    "    - time (HH:MM, 24-hour).\n"
    "\n"
    "PHASE 2 -- EMIT THE ACTION BLOCK.\n"
    "Once you have everything required, write a short, friendly **rundown** of exactly what you are "
    "adding (e.g. \"I've added Ibuprofen 400 mg, every day at 08:00 and 20:00, starting today, lifetime.\") "
    "WITH the medication-safety warning when relevant, then end the reply with a SINGLE fenced code "
    "block exactly in this form, on its own lines:\n"
    "```careme-action\n"
    "{\"action\":\"add_medication\",\"fields\":{\"name\":\"...\",\"dosage\":\"...\",\"frequency\":\"...\","
    "\"purpose\":\"...\",\"sideEffects\":\"...\",\"prn\":false,\"lifetime\":false,"
    "\"startDate\":\"YYYY-MM-DD\",\"endDate\":\"YYYY-MM-DD\","
    "\"schedule\":[{\"day\":\"Monday\",\"times\":[\"08:00\",\"20:00\"]}]}}\n"
    "```\n"
    "or\n"
    "```careme-action\n"
    "{\"action\":\"add_appointment\",\"fields\":{\"title\":\"...\",\"date\":\"YYYY-MM-DD\","
    "\"time\":\"HH:MM\",\"type\":\"...\",\"location\":\"...\"}}\n"
    "```\n"
    "The app saves the record IMMEDIATELY when it sees this block -- it will NOT ask the user to "
    "confirm. So your rundown text IS the confirmation; phrase it in the past tense (\"I've added\") "
    "rather than \"I'm going to add\".\n"
    "\n"
    "Schedule rules:\n"
    "  - `prn`: true means PRN, omit `schedule`, `startDate`, `endDate`, `lifetime` (or set them to "
    "    empty string / false). The app will save the medication with the taken-when-needed checkbox on.\n"
    "  - `lifetime`: true means no end date; you may omit `endDate` (or send empty string).\n"
    "  - `schedule`: an array of objects {day, times}, where `day` is one of "
    "    Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday, and `times` is an array of "
    "    \"HH:MM\" strings (24-hour). Use this WHENEVER the user gave specific days/times. If they said "
    "    \"every day at 8am and 8pm\", emit one entry per weekday.\n"
    "  - `frequency` is a free-text human-readable summary (e.g. \"Daily at 08:00 and 20:00\", \"As needed\").\n"
    "  - `startDate` / `endDate` use YYYY-MM-DD. If the user said \"starting today\", use today's date.\n"
    "\n"
    "DELETE AND UPDATE ACTIONS:\n"
    "When the user asks you to REMOVE / DELETE / STOP / take off a medication or appointment, emit:\n"
    "```careme-action\n"
    "{\"action\":\"delete_medication\",\"fields\":{\"name\":\"Aspirin\"}}\n"
    "```\n"
    "or\n"
    "```careme-action\n"
    "{\"action\":\"delete_appointment\",\"fields\":{\"title\":\"Dentist\",\"date\":\"YYYY-MM-DD\"}}\n"
    "```\n"
    "Match the existing record by name (medication) or by title + date (appointment) -- both must come "
    "from the lists supplied below in this prompt. If the user is ambiguous (e.g. they have two "
    "appointments with similar titles), ASK which one before emitting the block. If the named "
    "record doesn't exist in the lists, tell the user and DO NOT emit a block.\n"
    "\n"
    "When the user asks you to CHANGE / EDIT / MOVE / RESCHEDULE / RENAME / mark-as-history a "
    "medication or appointment, emit `update_medication` / `update_appointment`:\n"
    "```careme-action\n"
    "{\"action\":\"update_medication\",\"fields\":{\"name\":\"Aspirin\",\"dosage\":\"200 mg\","
    "\"history\":false,\"prn\":false,\"lifetime\":true,\"schedule\":[{\"day\":\"Monday\",\"times\":[\"09:00\"]}]}}\n"
    "```\n"
    "or\n"
    "```careme-action\n"
    "{\"action\":\"update_appointment\",\"fields\":{\"title\":\"Dentist\",\"date\":\"2026-05-10\","
    "\"newTitle\":\"Dentist follow-up\",\"newDate\":\"2026-05-12\",\"newTime\":\"15:00\","
    "\"location\":\"...\",\"type\":\"...\"}}\n"
    "```\n"
    "Update rules:\n"
    "  - For `update_medication`, the `name` field identifies WHICH med to change (must match an "
    "    existing med in the user's list). All OTHER fields are the new values; only include fields "
    "    the user actually wants to change.\n"
    "  - To rename a medication, supply `newName`. To mark as history (taken off), supply `history: true`.\n"
    "  - For `update_appointment`, `title` + `date` identify WHICH appointment. Supply `newTitle`, "
    "    `newDate`, `newTime`, `type`, or `location` for the changes.\n"
    "  - When the user describes the change in past tense (e.g. \"I stopped taking aspirin\"), set "
    "    `history: true` for that medication; do NOT delete it (the user wants the record preserved).\n"
    "\n"
    "Rules for the action block:\n"
    "(a) The JSON must be valid and use straight quotes.\n"
    "(b) Fill in only the fields the user actually specified plus the schedule/prn/lifetime flags you "
    "    inferred from their wording per the rules above; leave free-text fields you have no info for "
    "    as empty strings, do NOT invent values.\n"
    "(c) Date format YYYY-MM-DD, time format 24-hour HH:MM.\n"
    "(d) Emit AT MOST one action block per reply, and ONLY in Phase 2 (or directly when the user's "
    "    delete / update intent is unambiguous).\n"
    "(e) Do NOT emit an action block if the user is just asking ABOUT a medication or scheduling option, "
    "    only when they explicitly want a record added, removed, or changed.\n"
    "(f) Do NOT emit an action block while you are still missing required details listed in Phase 1.\n"
    "(g) Always show your rundown reply BEFORE the block. Phrase it in the past tense for adds, "
    "    deletes, and updates (\"I've added\", \"I've removed\", \"I've updated\") -- the app saves "
    "    immediately when it sees the block, no popup."
)


def _haversine_km(lat1, lon1, lat2, lon2):
    r = 6371.0
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dl = math.radians(lon2 - lon1)
    a = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dl / 2) ** 2
    return 2 * r * math.asin(math.sqrt(a))


def _nearby_contacts(db, collection, user_lat, user_lng, limit=5, max_km=50.0):
    docs = list(db[collection].find())
    scored = []
    for d in docs:
        lat = d.get('latitude')
        lng = d.get('longitude')
        if user_lat is not None and user_lng is not None and lat is not None and lng is not None:
            try:
                dist = _haversine_km(float(user_lat), float(user_lng), float(lat), float(lng))
            except (TypeError, ValueError):
                dist = None
        else:
            dist = None
        scored.append((dist, d))

    if user_lat is not None and user_lng is not None:
        with_dist = [(dist, d) for dist, d in scored if dist is not None and dist <= max_km]
        with_dist.sort(key=lambda x: x[0])
        picked = with_dist[:limit]
    else:
        picked = [(None, d) for d in docs[:limit]]

    lines = []
    for dist, d in picked:
        name = d.get('name', '')
        addr = d.get('address', '')
        phone = d.get('phone', '')
        specialty = d.get('specialty', '')
        parts = [name]
        if specialty:
            parts.append(f"specialty: {specialty}")
        if addr:
            parts.append(f"address: {addr}")
        if phone:
            parts.append(f"tel: {phone}")
        if dist is not None:
            parts.append(f"{dist:.1f} km away")
        lines.append(' | '.join(parts))
    return lines

# ---------- helpers ----------

def _age_from_dob(dob_str):
    """Compute integer age in years from an ISO-ish date-of-birth string
    (e.g. "1998-04-12" or "1998-04-12T00:00:00Z"). Returns None if we can't
    parse it or the value is empty."""
    if not dob_str:
        return None
    try:
        dt = datetime.fromisoformat(str(dob_str).replace('Z', '+00:00'))
    except (ValueError, TypeError):
        return None
    today = datetime.now().date()
    born = dt.date()
    years = today.year - born.year - (
        (today.month, today.day) < (born.month, born.day)
    )
    return years if years >= 0 else None


def _parse_body(request):
    return json.loads(request.body)


def _str_id(doc):
    """Convert MongoDB _id to string 'id' field."""
    if doc and '_id' in doc:
        doc['id'] = str(doc['_id'])
        del doc['_id']
    return doc


def _valid_email(email):
    return re.match(r'^[^@\s]+@[^@\s]+\.[^@\s]+$', email or '')


# Gemini's inline_data rejects generic types like application/octet-stream.
# Map filename extensions to the subset Gemini accepts for the file kinds we
# actually upload (lab reports). Kept conservative on purpose — adding a type
# here means we expect Gemini to read it.
_GEMINI_MIME_BY_EXT = {
    'pdf': 'application/pdf',
    'png': 'image/png',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'webp': 'image/webp',
    'heic': 'image/heic',
    'heif': 'image/heif',
    'txt': 'text/plain',
}
_GEMINI_MIME_ALLOWED = set(_GEMINI_MIME_BY_EXT.values())


def _infer_gemini_mime(filename, fallback=None):
    """Return a Gemini-supported MIME for `filename`, or None if we can't
    classify it. If `fallback` is already in the supported set, prefer it."""
    if fallback and fallback in _GEMINI_MIME_ALLOWED:
        return fallback
    if not filename:
        return None
    ext = filename.rsplit('.', 1)[-1].lower() if '.' in filename else ''
    return _GEMINI_MIME_BY_EXT.get(ext)


# ---------- Auth ----------

@csrf_exempt
@require_http_methods(['POST'])
def register(request):
    data = _parse_body(request)
    name = (data.get('name') or '').strip()
    email = (data.get('email') or '').strip().lower()
    password = data.get('password') or ''

    if not name or not email or not password:
        return JsonResponse({'error': 'Name, email, and password are required'}, status=400)
    if not _valid_email(email):
        return JsonResponse({'error': 'Invalid email format'}, status=400)

    # Strong password policy
    valid, error = validate_password_strength(password)
    if not valid:
        return JsonResponse({'error': error}, status=400)

    db = get_db()
    if db.users.find_one({'email': email}):
        return JsonResponse({'error': 'Email already registered'}, status=409)

    user = {
        'name': name,
        'email': email,
        'password': hash_password(password),
        'created_at': datetime.utcnow(),
        # Admin flag is seeded via scripts/seed_admins.py; never via self-register.
        'is_admin': False,
    }
    result = db.users.insert_one(user)
    user_id = str(result.inserted_id)
    access_token = create_token(user_id, email)
    refresh_token = create_refresh_token(user_id, email)

    return JsonResponse({
        'token': access_token,
        'refresh_token': refresh_token,
        'user': {'id': user_id, 'name': name, 'email': email, 'is_admin': False},
    }, status=201)


@csrf_exempt
@require_http_methods(['POST'])
def login(request):
    data = _parse_body(request)
    email = (data.get('email') or '').strip().lower()
    password = data.get('password') or ''

    if not email or not password:
        return JsonResponse({'error': 'Email and password are required'}, status=400)

    db = get_db()
    user = db.users.find_one({'email': email})
    if not user or not check_password(password, user['password']):
        return JsonResponse({'error': 'Invalid email or password'}, status=401)

    if user.get('deactivated'):
        return JsonResponse(
            {
                'error': 'This account has been deactivated.',
                'code': 'account_deactivated',
                'is_google_account': bool(user.get('google_account', False)),
            },
            status=403,
        )

    user_id = str(user['_id'])
    access_token = create_token(user_id, email)
    refresh_token = create_refresh_token(user_id, email)

    return JsonResponse({
        'token': access_token,
        'refresh_token': refresh_token,
        'user': {
            'id': user_id,
            'name': user['name'],
            'email': email,
            'is_admin': bool(user.get('is_admin', False)),
        },
    })


# ---------- Google Auth ----------

@csrf_exempt
@require_http_methods(['POST'])
def google_auth(request):
    """Sign in (or auto-register) a Google-authenticated user.
    Expects: { "name": "...", "email": "..." }
    Returns tokens + user object, identical to login/register responses."""
    data = _parse_body(request)
    name = (data.get('name') or '').strip()
    email = (data.get('email') or '').strip().lower()

    if not email:
        return JsonResponse({'error': 'Email is required'}, status=400)
    if not name:
        name = email.split('@')[0]

    db = get_db()
    user = db.users.find_one({'email': email})

    if user and user.get('deactivated'):
        return JsonResponse(
            {
                'error': 'This account has been deactivated.',
                'code': 'account_deactivated',
                'is_google_account': bool(user.get('google_account', False)),
            },
            status=403,
        )

    if user is None:
        # Auto-register (no password — Google-only account)
        user = {
            'name': name,
            'email': email,
            'password': '',
            'created_at': datetime.utcnow(),
            'is_admin': False,
            'google_account': True,
        }
        result = db.users.insert_one(user)
        user['_id'] = result.inserted_id

    user_id = str(user['_id'])
    is_admin = bool(user.get('is_admin', False))
    access_token = create_token(user_id, email)
    refresh_token = create_refresh_token(user_id, email)

    return JsonResponse({
        'token': access_token,
        'refresh_token': refresh_token,
        'user': {
            'id': user_id,
            'name': user.get('name', name),
            'email': email,
            'is_admin': is_admin,
        },
    })


# ---------- Token Refresh ----------

@csrf_exempt
@require_http_methods(['POST'])
def refresh_token_view(request):
    """Exchange a valid refresh token for a new access token."""
    data = _parse_body(request)
    refresh_token = data.get('refresh_token', '')

    if not refresh_token:
        return JsonResponse({'error': 'Refresh token is required'}, status=400)

    user_info = verify_refresh_token(refresh_token)
    if not user_info:
        return JsonResponse({'error': 'Invalid or expired refresh token'}, status=401)

    # Rotate: revoke old refresh token, issue new pair
    revoke_refresh_token(refresh_token)
    new_access_token = create_token(user_info['user_id'], user_info['email'])
    new_refresh_token = create_refresh_token(user_info['user_id'], user_info['email'])

    return JsonResponse({
        'token': new_access_token,
        'refresh_token': new_refresh_token,
    })


# ---------- Logout ----------

@csrf_exempt
@login_required
@require_http_methods(['POST'])
def logout(request):
    """Revoke the refresh token to log out."""
    data = _parse_body(request)
    refresh_token = data.get('refresh_token', '')
    if refresh_token:
        revoke_refresh_token(refresh_token)
    return JsonResponse({'message': 'Logged out successfully'})


# ---------- OTP ----------

@csrf_exempt
@require_http_methods(['POST'])
def send_otp(request):
    data = _parse_body(request)
    email = (data.get('email') or '').strip().lower()

    if not email or not _valid_email(email):
        return JsonResponse({'error': 'Valid email is required'}, status=400)

    db = get_db()
    code = str(random.randint(100000, 999999))

    # Store OTP with 10-minute expiry
    db.otp_codes.update_one(
        {'email': email},
        {'$set': {
            'email': email,
            'code': code,
            'created_at': datetime.utcnow(),
            'expires_at': datetime.utcnow() + timedelta(minutes=10),
        }},
        upsert=True,
    )

    try:
        send_mail(
            subject='CareMe - Your Verification Code',
            message=f'Your CareMe verification code is: {code}\n\nThis code expires in 10 minutes.',
            from_email=settings.DEFAULT_FROM_EMAIL,
            recipient_list=[email],
            fail_silently=False,
        )
    except Exception as e:
        return JsonResponse({'error': f'Failed to send email: {str(e)}'}, status=500)

    return JsonResponse({'message': 'OTP sent successfully'})


@csrf_exempt
@require_http_methods(['POST'])
def verify_otp(request):
    data = _parse_body(request)
    email = (data.get('email') or '').strip().lower()
    code = (data.get('code') or '').strip()

    if not email or not code:
        return JsonResponse({'error': 'Email and code are required'}, status=400)

    db = get_db()
    record = db.otp_codes.find_one({'email': email})

    if not record:
        return JsonResponse({'error': 'No OTP found. Please request a new one.'}, status=400)

    if datetime.utcnow() > record['expires_at']:
        db.otp_codes.delete_one({'email': email})
        return JsonResponse({'error': 'OTP has expired. Please request a new one.'}, status=400)

    if record['code'] != code:
        return JsonResponse({'error': 'Invalid OTP code.'}, status=400)

    # OTP is valid — clean up
    db.otp_codes.delete_one({'email': email})
    return JsonResponse({'message': 'OTP verified successfully'})


# ---------- Change Password ----------

@csrf_exempt
@login_required
@require_http_methods(['POST'])
def change_password(request):
    data = _parse_body(request)
    new_password = data.get('new_password') or ''

    valid, error = validate_password_strength(new_password)
    if not valid:
        return JsonResponse({'error': error}, status=400)

    db = get_db()
    db.users.update_one(
        {'_id': ObjectId(request.user_id)},
        {'$set': {'password': hash_password(new_password)}},
    )

    # Revoke all refresh tokens on password change for security
    revoke_all_refresh_tokens(request.user_id)

    return JsonResponse({'message': 'Password changed successfully. Please log in again.'})


# ---------- User Profile ----------

@csrf_exempt
@login_required
@require_http_methods(['GET', 'PUT'])
def profile(request):
    db = get_db()
    user = db.users.find_one({'_id': ObjectId(request.user_id)})
    if not user:
        return JsonResponse({'error': 'User not found'}, status=404)

    # Decrypt sensitive fields
    user = decrypt_document('users', user)

    if request.method == 'GET':
        return JsonResponse({
            'id': str(user['_id']),
            'name': user.get('name', ''),
            'email': user.get('email', ''),
            'phone': user.get('phone', ''),
            'dateOfBirth': user.get('dateOfBirth', ''),
            'address': user.get('address', ''),
            'latitude': user.get('latitude'),
            'longitude': user.get('longitude'),
        })

    # PUT - update profile
    data = _parse_body(request)
    updates = {}
    for field in ('name', 'phone', 'dateOfBirth', 'address', 'latitude', 'longitude'):
        if field in data:
            updates[field] = data[field]

    if updates:
        # Encrypt sensitive fields before storing
        updates = encrypt_document('users', updates)
        db.users.update_one({'_id': ObjectId(request.user_id)}, {'$set': updates})

    updated = db.users.find_one({'_id': ObjectId(request.user_id)})
    updated = decrypt_document('users', updated)
    return JsonResponse({
        'id': str(updated['_id']),
        'name': updated.get('name', ''),
        'email': updated.get('email', ''),
        'phone': updated.get('phone', ''),
        'dateOfBirth': updated.get('dateOfBirth', ''),
        'address': updated.get('address', ''),
        'latitude': updated.get('latitude'),
        'longitude': updated.get('longitude'),
    })


# ---------- Profile Photo ----------

@csrf_exempt
@login_required
@require_http_methods(['GET', 'POST', 'DELETE'])
def profile_photo(request):
    db = get_db()
    user = db.users.find_one({'_id': ObjectId(request.user_id)})
    if not user:
        return JsonResponse({'error': 'User not found'}, status=404)

    if request.method == 'GET':
        photo_data = user.get('profile_photo')
        if not photo_data:
            return JsonResponse({'error': 'No profile photo'}, status=404)
        image_bytes = base64.b64decode(photo_data)
        return HttpResponse(image_bytes, content_type='image/jpeg')

    if request.method == 'DELETE':
        db.users.update_one(
            {'_id': ObjectId(request.user_id)},
            {'$unset': {'profile_photo': ''}}
        )
        return JsonResponse({'message': 'Photo removed'})

    # POST - upload photo
    if 'photo' not in request.FILES:
        return JsonResponse({'error': 'No photo file provided'}, status=400)

    photo_file = request.FILES['photo']
    photo_bytes = photo_file.read()
    photo_b64 = base64.b64encode(photo_bytes).decode('utf-8')

    db.users.update_one(
        {'_id': ObjectId(request.user_id)},
        {'$set': {'profile_photo': photo_b64}}
    )
    return JsonResponse({'message': 'Photo uploaded'})


# ---------- FCM Push Notifications ----------

@csrf_exempt
@login_required
@require_http_methods(['POST'])
def register_fcm_token(request):
    """Store the user's FCM device token for push notifications."""
    data = _parse_body(request)
    token = data.get('fcm_token', '').strip()
    if not token:
        return JsonResponse({'error': 'fcm_token is required'}, status=400)

    db = get_db()
    db.users.update_one(
        {'_id': ObjectId(request.user_id)},
        {'$set': {'fcm_token': token}}
    )
    return JsonResponse({'message': 'FCM token registered'})


@csrf_exempt
@login_required
@require_http_methods(['POST'])
def send_medication_reminders(request):
    """Check all medications for the current user and send FCM for any due now."""
    if not fcm_messaging:
        return JsonResponse({'error': 'Firebase not configured'}, status=500)

    db = get_db()
    user = db.users.find_one({'_id': ObjectId(request.user_id)})
    if not user or not user.get('fcm_token'):
        return JsonResponse({'error': 'No FCM token registered'}, status=400)

    fcm_token = user['fcm_token']
    meds = list(db.medications.find({'user_id': request.user_id}))
    meds = [decrypt_document('medications', m) for m in meds]

    now = datetime.now()
    current_day = now.strftime('%A')  # Monday, Tuesday, etc.
    current_time = now.strftime('%H:%M')

    sent = 0
    for med in meds:
        schedule = med.get('schedule')
        if not schedule:
            continue

        # Check date range
        start_str = med.get('startDate')
        end_str = med.get('endDate')
        is_lifetime = med.get('isLifetime', False)

        if start_str:
            try:
                start_date = datetime.fromisoformat(start_str.replace('Z', '+00:00')).replace(tzinfo=None)
                if now < start_date:
                    continue
            except Exception:
                pass

        if not is_lifetime and end_str:
            try:
                end_date = datetime.fromisoformat(end_str.replace('Z', '+00:00')).replace(tzinfo=None)
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
                # Match within 1-minute window
                if t.strip() == current_time:
                    try:
                        message = fcm_messaging.Message(
                            notification=fcm_messaging.Notification(
                                title=f"Time for {med.get('name', 'medication')}",
                                body=f"Take {med.get('dosage', '')}",
                            ),
                            android=fcm_messaging.AndroidConfig(
                                priority='high',
                                notification=fcm_messaging.AndroidNotification(
                                    channel_id='meds_channel',
                                    priority='max',
                                    default_sound=True,
                                    default_vibrate_timings=True,
                                ),
                            ),
                            token=fcm_token,
                        )
                        fcm_messaging.send(message)
                        sent += 1
                    except Exception as e:
                        print(f"FCM send error: {e}")

    return JsonResponse({'sent': sent})


@csrf_exempt
@login_required
@require_http_methods(['POST'])
def test_fcm_notification(request):
    """Send a test FCM notification to verify the setup works."""
    if not fcm_messaging:
        return JsonResponse({'error': 'Firebase not configured'}, status=500)

    db = get_db()
    user = db.users.find_one({'_id': ObjectId(request.user_id)})
    if not user or not user.get('fcm_token'):
        return JsonResponse({'error': 'No FCM token registered. Open the app first.'}, status=400)

    try:
        message = fcm_messaging.Message(
            notification=fcm_messaging.Notification(
                title='CareMe Test',
                body='Push notifications are working!',
            ),
            android=fcm_messaging.AndroidConfig(
                priority='high',
                notification=fcm_messaging.AndroidNotification(
                    channel_id='meds_channel',
                    priority='max',
                    default_sound=True,
                    default_vibrate_timings=True,
                ),
            ),
            token=user['fcm_token'],
        )
        response = fcm_messaging.send(message)
        return JsonResponse({'message': 'Test notification sent', 'response': response})
    except Exception as e:
        return JsonResponse({'error': f'FCM send failed: {e}'}, status=500)


# ---------- Medications ----------

@csrf_exempt
@login_required
@require_http_methods(['GET', 'POST'])
def medications(request):
    db = get_db()

    if request.method == 'GET':
        meds = list(db.medications.find({'user_id': request.user_id}))
        return JsonResponse(
            [_str_id(decrypt_document('medications', m)) for m in meds],
            safe=False,
        )

    # POST - add new medication
    data = _parse_body(request)
    med = {
        'user_id': request.user_id,
        'name': data.get('name', ''),
        'dosage': data.get('dosage', ''),
        'frequency': data.get('frequency', ''),
        'time': data.get('time', ''),
        'purpose': data.get('purpose', ''),
        'sideEffects': data.get('sideEffects', ''),
        'schedule': data.get('schedule'),
        'startDate': data.get('startDate'),
        'endDate': data.get('endDate'),
        'isLifetime': data.get('isLifetime', False),
        'isHistory': data.get('isHistory', False),
        'isPrn': data.get('isPrn', False),
    }

    if not med['name']:
        return JsonResponse({'error': 'Medication name is required'}, status=400)

    # Encrypt sensitive fields before storing
    med = encrypt_document('medications', med)
    result = db.medications.insert_one(med)
    med['id'] = str(result.inserted_id)
    del med['_id']
    # Decrypt for response
    med = decrypt_document('medications', med)
    return JsonResponse(med, status=201)


@csrf_exempt
@login_required
@require_http_methods(['PUT', 'DELETE'])
def medication_detail(request, med_id):
    db = get_db()

    try:
        obj_id = ObjectId(med_id)
    except Exception:
        return JsonResponse({'error': 'Invalid medication ID'}, status=400)

    existing = db.medications.find_one({'_id': obj_id, 'user_id': request.user_id})
    if not existing:
        return JsonResponse({'error': 'Medication not found'}, status=404)

    if request.method == 'DELETE':
        db.medications.delete_one({'_id': obj_id})
        return JsonResponse({'message': 'Deleted'})

    # PUT - update
    data = _parse_body(request)
    updates = {}
    for field in ('name', 'dosage', 'frequency', 'time', 'purpose', 'sideEffects',
                   'schedule', 'startDate', 'endDate', 'isLifetime', 'isHistory',
                   'isPrn'):
        if field in data:
            updates[field] = data[field]

    if updates:
        updates = encrypt_document('medications', updates)
        db.medications.update_one({'_id': obj_id}, {'$set': updates})

    updated = db.medications.find_one({'_id': obj_id})
    return JsonResponse(_str_id(decrypt_document('medications', updated)))


# ---------- Medication AI Suggestions ----------

# Tiny in-process cache keyed by lower-cased prefix. Saves tokens when the
# user types fast and triggers many calls back-to-back. TTL is 10 minutes.
_NAME_SUGGEST_CACHE = {}
_NAME_SUGGEST_TTL = timedelta(minutes=10)


def _gemini_json(prompt_text, timeout=15):
    """Call Gemini once expecting raw JSON in the reply. Returns the parsed
    JSON, or None on any failure. Used by the medication-suggest endpoints."""
    if not getattr(settings, 'GEMINI_API_KEY', ''):
        return None
    try:
        resp = requests.post(
            GEMINI_API_URL,
            json={
                'contents': [
                    {'role': 'user', 'parts': [{'text': prompt_text}]},
                ],
                'generationConfig': {
                    'response_mime_type': 'application/json',
                    'temperature': 0.2,
                },
            },
            timeout=timeout,
        )
        body = resp.json()
        text = body['candidates'][0]['content']['parts'][0].get('text', '')
        if not text:
            return None
        return json.loads(text)
    except Exception as e:
        print(f"_gemini_json error: {e}")
        return None


@csrf_exempt
@login_required
@require_http_methods(['POST'])
def suggest_medication_names(request):
    """Typeahead for the Add Medication name field. Body: {q: "para"}.
    Returns {names: ["Paracetamol", ...]}."""
    data = _parse_body(request)
    q = (data.get('q') or '').strip()
    if len(q) < 2:
        return JsonResponse({'names': []})

    key = q.lower()
    now = datetime.utcnow()
    cached = _NAME_SUGGEST_CACHE.get(key)
    if cached and now - cached[0] < _NAME_SUGGEST_TTL:
        return JsonResponse({'names': cached[1]})

    prompt = (
        "Return up to 8 real medication names that begin with or fuzzy-match "
        f"this prefix: \"{q}\". Output ONLY a JSON array of strings, no other "
        "text. Use generic names where common; capitalise normally. Example "
        "valid output: [\"Paracetamol\", \"Paroxetine\"]."
    )
    parsed = _gemini_json(prompt, timeout=10)

    names = []
    if isinstance(parsed, list):
        names = [str(n).strip() for n in parsed if isinstance(n, (str, int))][:8]
    # Trim duplicates while preserving order.
    seen = set()
    deduped = []
    for n in names:
        low = n.lower()
        if not n or low in seen:
            continue
        seen.add(low)
        deduped.append(n)

    _NAME_SUGGEST_CACHE[key] = (now, deduped)
    return JsonResponse({'names': deduped})


@csrf_exempt
@login_required
@require_http_methods(['POST'])
def suggest_medication_fields(request):
    """Fill purpose and side effects in the Add Medication dialog from the
    medication's name. Body: {name: "Paracetamol"}.
    Returns {purpose, sideEffects}."""
    data = _parse_body(request)
    name = (data.get('name') or '').strip()
    if not name:
        return JsonResponse({'error': 'name is required'}, status=400)

    locale = _request_locale(request)
    lang_clause = (
        f"Write the values in the user's language (locale code: {locale}). "
        "If the locale is 'ar' write in Arabic, 'fr' in French, 'es' in Spanish, "
        "etc. Default to English when the locale is 'en' or unknown."
    )

    prompt = (
        "You are filling a medication form for a patient app. Given the "
        f"medication name \"{name}\", return ONLY a JSON object with keys: "
        "purpose (one short sentence describing what it treats), "
        "sideEffects (comma-separated list of the most common ones).\n"
        f"{lang_clause}\n"
        "Use plain text only, no emojis, no smart quotes, no em-dashes. "
        "If you do not recognise the medication, return both values as empty "
        "strings. Do NOT include any disclaimer or extra text outside the JSON."
    )
    parsed = _gemini_json(prompt, timeout=15) or {}

    def _s(key):
        v = parsed.get(key, '') if isinstance(parsed, dict) else ''
        return (str(v) if v is not None else '').strip()

    return JsonResponse({
        'purpose': _s('purpose'),
        'sideEffects': _s('sideEffects'),
    })


# Cache for chat-input completions: {(user_id, prefix_lower) -> (timestamp, list)}.
# Saves Gemini calls when the user pauses then types the same prefix again.
_CHAT_SUGGEST_CACHE = {}
_CHAT_SUGGEST_TTL = timedelta(minutes=5)


@csrf_exempt
@login_required
@require_http_methods(['POST'])
def chat_suggest(request):
    """Inline completions for the chatbot input. Body:
        {q: "what's the best ", history: [{text, isUser}, ...]}
    Returns {suggestions: ["...", "...", "..."]}.

    The completions are short follow-up phrases the user might want to type
    next. Same language as the user's typed input. We pass a tiny slice of
    recent chat history so the completions stay on-topic."""
    data = _parse_body(request)
    q = (data.get('q') or '')
    if len(q.strip()) < 2:
        return JsonResponse({'suggestions': []})

    history = data.get('history') or []

    cache_key = (request.user_id, q.strip().lower())
    now = datetime.utcnow()
    cached = _CHAT_SUGGEST_CACHE.get(cache_key)
    if cached and now - cached[0] < _CHAT_SUGGEST_TTL:
        return JsonResponse({'suggestions': cached[1]})

    # Trim history to the last 4 turns of plain text so the prompt stays small.
    recent = []
    for m in (history or [])[-4:]:
        role = 'user' if m.get('isUser') else 'assistant'
        text = (m.get('text') or '').strip()
        if text:
            recent.append(f"{role}: {text[:300]}")
    history_block = "\n".join(recent) if recent else "(no prior turns)"

    prompt = (
        "You are autocompleting a health-app chat input. The user has typed "
        f"this partial message:\n\n\"{q}\"\n\n"
        "Recent conversation (for context only, do NOT echo it back):\n"
        f"{history_block}\n\n"
        "Return up to 3 short, natural completions or follow-ups the user "
        "MIGHT want to send next. Each suggestion should be a complete short "
        "sentence the user can tap to send -- not just the next word. Reply in "
        "the SAME LANGUAGE as the user's partial message. Stay strictly on "
        "health, medications, appointments, lab results, symptoms, wellness. "
        "Output ONLY a JSON array of strings, no other text. Example output: "
        "[\"What are the side effects of ibuprofen?\", \"Can I take it with paracetamol?\"]."
    )
    parsed = _gemini_json(prompt, timeout=8)

    suggestions = []
    if isinstance(parsed, list):
        for s in parsed[:3]:
            if isinstance(s, str) and s.strip():
                suggestions.append(s.strip())
    _CHAT_SUGGEST_CACHE[cache_key] = (now, suggestions)
    return JsonResponse({'suggestions': suggestions})


# ---------- Lab Tests ----------

@csrf_exempt
@login_required
@require_http_methods(['GET', 'POST'])
def lab_tests(request):
    db = get_db()

    if request.method == 'GET':
        labs = list(db.lab_tests.find({'user_id': request.user_id}))
        return JsonResponse(
            [_str_id(decrypt_document('lab_tests', l)) for l in labs],
            safe=False,
        )

    # POST - supports both JSON and multipart form data (file upload)
    content_type = request.content_type or ''

    if 'multipart/form-data' in content_type:
        name = request.POST.get('name', '')
        date = request.POST.get('date', '')
        doctor = request.POST.get('doctor', '')
        file_obj = request.FILES.get('file')

        if not name:
            return JsonResponse({'error': 'Lab test name is required'}, status=400)

        file_id = None
        file_name = ''
        if file_obj:
            fs = GridFS(db)
            file_id = fs.put(
                file_obj.read(),
                filename=file_obj.name,
                content_type=file_obj.content_type,
                user_id=request.user_id,
            )
            file_name = file_obj.name

        lab = {
            'user_id': request.user_id,
            'name': name,
            'date': date,
            'doctor': doctor,
            'fileName': file_name,
            'fileId': str(file_id) if file_id else '',
            'created_at': datetime.utcnow(),
        }
    else:
        data = _parse_body(request)
        file_data = data.get('fileData')
        file_name = data.get('fileName', '')
        file_id = None

        if file_data and file_name:
            fs = GridFS(db)
            file_bytes = base64.b64decode(file_data)
            file_id = fs.put(
                file_bytes,
                filename=file_name,
                content_type=(_infer_gemini_mime(file_name)
                              or 'application/octet-stream'),
                user_id=request.user_id,
            )

        lab = {
            'user_id': request.user_id,
            'name': data.get('name', ''),
            'date': data.get('date', ''),
            'doctor': data.get('doctor', ''),
            'fileName': file_name,
            'fileId': str(file_id) if file_id else '',
            'created_at': datetime.utcnow(),
        }

    if not lab['name']:
        return JsonResponse({'error': 'Lab test name is required'}, status=400)

    # Encrypt sensitive fields before storing
    lab = encrypt_document('lab_tests', lab)
    result = db.lab_tests.insert_one(lab)
    lab['id'] = str(result.inserted_id)
    del lab['_id']
    lab = decrypt_document('lab_tests', lab)
    return JsonResponse(lab, status=201)


@csrf_exempt
@login_required
@require_http_methods(['DELETE'])
def lab_test_detail(request, lab_id):
    db = get_db()
    try:
        obj_id = ObjectId(lab_id)
    except Exception:
        return JsonResponse({'error': 'Invalid lab test ID'}, status=400)

    # Delete the associated file from GridFS if it exists
    lab = db.lab_tests.find_one({'_id': obj_id, 'user_id': request.user_id})
    if not lab:
        return JsonResponse({'error': 'Lab test not found'}, status=404)

    if lab.get('fileId'):
        try:
            fs = GridFS(db)
            fs.delete(ObjectId(lab['fileId']))
        except Exception:
            pass

    db.lab_tests.delete_one({'_id': obj_id})
    return JsonResponse({'message': 'Deleted'})


@csrf_exempt
@login_required
@require_http_methods(['GET'])
def lab_test_file(request, lab_id):
    """Download a lab test file from GridFS."""
    db = get_db()
    try:
        obj_id = ObjectId(lab_id)
    except Exception:
        return JsonResponse({'error': 'Invalid lab test ID'}, status=400)

    lab = db.lab_tests.find_one({'_id': obj_id, 'user_id': request.user_id})
    if not lab or not lab.get('fileId'):
        return JsonResponse({'error': 'File not found'}, status=404)

    fs = GridFS(db)
    try:
        grid_file = fs.get(ObjectId(lab['fileId']))
    except Exception:
        return JsonResponse({'error': 'File not found in storage'}, status=404)

    response = HttpResponse(grid_file.read(), content_type=grid_file.content_type or 'application/octet-stream')
    response['Content-Disposition'] = f'attachment; filename="{grid_file.filename}"'
    return response


# ---------- Doctors & Pharmacies (admin-managed directory) ----------

def _contact_from_doc(doc):
    return {
        'id': str(doc['_id']),
        'name': doc.get('name', ''),
        'address': doc.get('address', ''),
        'phone': doc.get('phone', ''),
        'latitude': doc.get('latitude'),
        'longitude': doc.get('longitude'),
        'specialty': doc.get('specialty', ''),
    }


def _contacts_list_create(request, collection_name):
    db = get_db()
    coll = db[collection_name]

    if request.method == 'GET':
        docs = list(coll.find().sort('name', 1))
        return JsonResponse({'items': [_contact_from_doc(d) for d in docs]})

    # POST — admin only for mutations
    data = _parse_body(request)
    name = (data.get('name') or '').strip()
    address = (data.get('address') or '').strip()
    phone = (data.get('phone') or '').strip()
    if not name or not address or not phone:
        return JsonResponse({'error': 'name, address, and phone are required'}, status=400)

    doc = {
        'name': name,
        'address': address,
        'phone': phone,
        'latitude': data.get('latitude'),
        'longitude': data.get('longitude'),
        'created_at': datetime.utcnow(),
    }
    if collection_name == 'doctors':
        doc['specialty'] = (data.get('specialty') or '').strip()
    result = coll.insert_one(doc)
    doc['_id'] = result.inserted_id
    return JsonResponse(_contact_from_doc(doc), status=201)


def _contacts_detail(request, collection_name, item_id):
    db = get_db()
    coll = db[collection_name]
    try:
        obj_id = ObjectId(item_id)
    except Exception:
        return JsonResponse({'error': 'Invalid id'}, status=400)

    if request.method == 'DELETE':
        result = coll.delete_one({'_id': obj_id})
        if result.deleted_count == 0:
            return JsonResponse({'error': 'Not found'}, status=404)
        return JsonResponse({'message': 'Deleted'})

    return JsonResponse({'error': 'Method not allowed'}, status=405)


@csrf_exempt
@require_http_methods(['GET', 'POST'])
def doctors(request):
    if request.method == 'POST':
        return admin_required(lambda r: _contacts_list_create(r, 'doctors'))(request)
    return login_required(lambda r: _contacts_list_create(r, 'doctors'))(request)


@csrf_exempt
@admin_required
@require_http_methods(['DELETE'])
def doctor_detail(request, doctor_id):
    return _contacts_detail(request, 'doctors', doctor_id)


@csrf_exempt
@require_http_methods(['GET', 'POST'])
def pharmacies(request):
    if request.method == 'POST':
        return admin_required(lambda r: _contacts_list_create(r, 'pharmacies'))(request)
    return login_required(lambda r: _contacts_list_create(r, 'pharmacies'))(request)


@csrf_exempt
@admin_required
@require_http_methods(['DELETE'])
def pharmacy_detail(request, pharmacy_id):
    return _contacts_detail(request, 'pharmacies', pharmacy_id)


# ---------- Deactivate Account ----------

@csrf_exempt
@login_required
@require_http_methods(['POST'])
def deactivate_account(request):
    """Soft-disable the account. Data is preserved; login is blocked until
    the user is reactivated by support."""
    db = get_db()
    user_id = request.user_id

    db.users.update_one(
        {'_id': ObjectId(user_id)},
        {'$set': {
            'deactivated': True,
            'deactivated_at': datetime.utcnow(),
        }},
    )

    # Force sign-out everywhere: revoke all refresh tokens.
    revoke_all_refresh_tokens(user_id)

    return JsonResponse({'message': 'Account deactivated'})


@csrf_exempt
@login_required
@require_http_methods(['POST'])
def delete_account(request):
    """Permanently delete the user and all related data."""
    db = get_db()
    user_id = request.user_id

    # Remove uploaded lab-test files from GridFS first.
    fs = GridFS(db)
    for lab in db.lab_tests.find({'user_id': user_id}, {'fileId': 1}):
        file_id = lab.get('fileId')
        if not file_id:
            continue
        try:
            fs.delete(ObjectId(file_id))
        except Exception:
            pass

    db.medications.delete_many({'user_id': user_id})
    db.lab_tests.delete_many({'user_id': user_id})
    db.audit_logs.delete_many({'user_id': user_id})

    user = db.users.find_one({'_id': ObjectId(user_id)}, {'email': 1})
    if user and user.get('email'):
        db.otp_codes.delete_many({'email': user['email']})

    db.users.delete_one({'_id': ObjectId(user_id)})

    revoke_all_refresh_tokens(user_id)

    return JsonResponse({'message': 'Account deleted'})


@csrf_exempt
@require_http_methods(['POST'])
def reactivate_account(request):
    """Re-enable a deactivated account.
    Body: { email, password (omitted for Google accounts), otp_code }.
    Verifies the user's credentials and the OTP, clears the deactivated flag,
    and returns a fresh token pair so the client can sign in immediately."""
    data = _parse_body(request)
    email = (data.get('email') or '').strip().lower()
    password = data.get('password') or ''
    otp_code = (data.get('otp_code') or '').strip()

    if not email or not _valid_email(email):
        return JsonResponse({'error': 'Valid email is required'}, status=400)
    if not otp_code:
        return JsonResponse({'error': 'Verification code is required'}, status=400)

    db = get_db()
    user = db.users.find_one({'email': email})
    if not user:
        return JsonResponse({'error': 'Account not found'}, status=404)

    if not user.get('deactivated'):
        return JsonResponse({'error': 'Account is already active'}, status=400)

    is_google = bool(user.get('google_account', False))
    if not is_google:
        if not password:
            return JsonResponse({'error': 'Password is required'}, status=400)
        if not check_password(password, user.get('password', '')):
            return JsonResponse({'error': 'Invalid email or password'}, status=401)

    # Verify OTP
    record = db.otp_codes.find_one({'email': email})
    if not record:
        return JsonResponse({'error': 'No verification code found. Please request a new one.'}, status=400)
    if datetime.utcnow() > record['expires_at']:
        db.otp_codes.delete_one({'email': email})
        return JsonResponse({'error': 'Verification code has expired. Please request a new one.'}, status=400)
    if record['code'] != otp_code:
        return JsonResponse({'error': 'Invalid verification code.'}, status=400)
    db.otp_codes.delete_one({'email': email})

    # Reactivate
    db.users.update_one(
        {'_id': user['_id']},
        {
            '$unset': {'deactivated': '', 'deactivated_at': ''},
            '$set': {'reactivated_at': datetime.utcnow()},
        },
    )

    user_id = str(user['_id'])
    access_token = create_token(user_id, email)
    refresh_token = create_refresh_token(user_id, email)

    return JsonResponse({
        'token': access_token,
        'refresh_token': refresh_token,
        'user': {
            'id': user_id,
            'name': user.get('name', ''),
            'email': email,
            'is_admin': bool(user.get('is_admin', False)),
        },
    })


# ---------- Export User Data ----------

@csrf_exempt
@login_required
@require_http_methods(['POST'])
def export_data(request):
    db = get_db()
    user_id = request.user_id
    user = db.users.find_one({'_id': ObjectId(user_id)})
    user_name = user.get('name', 'User') if user else 'User'

    # Get medications from DB and decrypt
    meds = list(db.medications.find({'user_id': user_id}))
    meds = [decrypt_document('medications', m) for m in meds]

    # Split active vs history. A med is "history" when isHistory=True OR its
    # end date has already passed (and it isn't marked lifetime).
    today = datetime.now().date()

    def _is_history(m):
        if m.get('isHistory'):
            return True
        if m.get('isLifetime'):
            return False
        end_str = m.get('endDate')
        if not end_str:
            return False
        try:
            end_dt = datetime.fromisoformat(end_str.replace('Z', '+00:00')).date()
            return end_dt < today
        except (ValueError, TypeError):
            return False

    active_meds = [m for m in meds if not _is_history(m)]
    history_meds = [m for m in meds if _is_history(m)]

    # Get appointments from request body (stored client-side)
    data = _parse_body(request)
    appointments = data.get('appointments', [])

    def _apt_is_past(a):
        full = a.get('fullDate')
        if not full:
            return False
        try:
            d = datetime.fromisoformat(full.replace('Z', '+00:00')).date()
            return d < today
        except (ValueError, TypeError):
            return False

    upcoming_apts = [a for a in appointments if not _apt_is_past(a)]
    previous_apts = [a for a in appointments if _apt_is_past(a)]

    # Format ISO date strings for PDF output
    def _fmt_date(iso_str):
        if not iso_str:
            return '—'
        try:
            return datetime.fromisoformat(iso_str.replace('Z', '+00:00')).strftime('%b %d, %Y')
        except (ValueError, TypeError):
            return iso_str

    # Build PDF
    buf = io.BytesIO()
    doc = SimpleDocTemplate(buf, pagesize=letter, topMargin=0.75 * inch, bottomMargin=0.75 * inch)
    styles = getSampleStyleSheet()
    title_style = ParagraphStyle('CustomTitle', parent=styles['Title'], fontSize=22, textColor=colors.HexColor('#1E3A5F'), spaceAfter=6)
    subtitle_style = ParagraphStyle('Subtitle', parent=styles['Normal'], fontSize=10, textColor=colors.grey, spaceAfter=20)
    heading_style = ParagraphStyle('SectionHeading', parent=styles['Heading2'], fontSize=14, textColor=colors.HexColor('#1E3A5F'), spaceBefore=20, spaceAfter=10)

    def _table_style():
        return TableStyle([
            ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#1E3A5F')),
            ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
            ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
            ('FONTSIZE', (0, 0), (-1, 0), 9),
            ('FONTSIZE', (0, 1), (-1, -1), 8),
            ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
            ('GRID', (0, 0), (-1, -1), 0.5, colors.lightgrey),
            ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, colors.HexColor('#F3F4F6')]),
            ('VALIGN', (0, 0), (-1, -1), 'TOP'),
            ('TOPPADDING', (0, 0), (-1, -1), 6),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
        ])

    def _med_rows(source):
        rows = [['Name', 'Dosage', 'Frequency', 'Start', 'End', 'Purpose', 'Side Effects']]
        for m in source:
            start = _fmt_date(m.get('startDate'))
            if m.get('isLifetime'):
                end = 'Lifetime'
            else:
                end = _fmt_date(m.get('endDate'))
            rows.append([
                m.get('name', ''),
                m.get('dosage', ''),
                m.get('frequency', ''),
                start,
                end,
                m.get('purpose', ''),
                m.get('sideEffects', ''),
            ])
        return rows

    def _apt_rows(source):
        rows = [['Date', 'Title', 'Time', 'Type', 'Location']]
        for a in source:
            date_val = _fmt_date(a.get('fullDate')) if a.get('fullDate') else str(a.get('date', ''))
            rows.append([
                date_val,
                a.get('title', ''),
                a.get('time', ''),
                a.get('type', ''),
                a.get('location', ''),
            ])
        return rows

    elements = []
    elements.append(Paragraph('CareMe - My Health Data', title_style))
    elements.append(Paragraph(f'Generated for {user_name} on {datetime.now().strftime("%B %d, %Y at %I:%M %p")}', subtitle_style))

    # Active Medications
    elements.append(Paragraph('Active Medications', heading_style))
    if active_meds:
        t = Table(_med_rows(active_meds), repeatRows=1)
        t.setStyle(_table_style())
        elements.append(t)
    else:
        elements.append(Paragraph('No active medications on record.', styles['Normal']))

    elements.append(Spacer(1, 20))

    # Medication History
    elements.append(Paragraph('Medication History', heading_style))
    if history_meds:
        t = Table(_med_rows(history_meds), repeatRows=1)
        t.setStyle(_table_style())
        elements.append(t)
    else:
        elements.append(Paragraph('No past medications on record.', styles['Normal']))

    elements.append(Spacer(1, 20))

    # Upcoming Appointments
    elements.append(Paragraph('Upcoming Appointments', heading_style))
    if upcoming_apts:
        t = Table(_apt_rows(upcoming_apts), repeatRows=1)
        t.setStyle(_table_style())
        elements.append(t)
    else:
        elements.append(Paragraph('No upcoming appointments on record.', styles['Normal']))

    elements.append(Spacer(1, 20))

    # Previous Appointments
    elements.append(Paragraph('Previous Appointments', heading_style))
    if previous_apts:
        t = Table(_apt_rows(previous_apts), repeatRows=1)
        t.setStyle(_table_style())
        elements.append(t)
    else:
        elements.append(Paragraph('No past appointments on record.', styles['Normal']))

    doc.build(elements)
    buf.seek(0)

    response = HttpResponse(buf.read(), content_type='application/pdf')
    response['Content-Disposition'] = 'attachment; filename="CareMe_MyData.pdf"'
    return response


# ---------- Chatbot ----------

def _lab_upload_dt(lab):
    """Best-effort upload date for a lab record. Falls back to ObjectId
    generation time so older rows (without `created_at`) still sort sensibly."""
    ca = lab.get('created_at')
    if ca:
        try:
            return ca.replace(tzinfo=None) if getattr(ca, 'tzinfo', None) else ca
        except Exception:
            return ca
    raw_id = lab.get('_id')
    if isinstance(raw_id, ObjectId):
        try:
            return raw_id.generation_time.replace(tzinfo=None)
        except Exception:
            return None
    return None


def _build_chat_contents(user_id, user_message, history, attachment=None, locale='en'):
    """Build the Gemini `contents` array from the user's stored context plus
    the supplied message + history. Shared by `chat` and `chat_stream`.

    `attachment` (optional): dict with keys `mimeType` and `data` (base64
    string). When present, the bytes are attached to the current user turn
    as `inline_data` so Gemini can read the image or document.

    `locale` (default 'en'): the user's app UI language. Used as a fallback
    hint when the language of the user's message is ambiguous; the system
    prompt instructs Gemini that the message language always wins."""
    db = get_db()

    meds = list(db.medications.find({'user_id': user_id}))
    meds = [decrypt_document('medications', m) for m in meds]
    labs = list(db.lab_tests.find({'user_id': user_id}))
    labs = [decrypt_document('lab_tests', l) for l in labs]
    user = db.users.find_one({'_id': ObjectId(user_id)})

    # Newest labs first so the model treats recent uploads as most relevant.
    labs.sort(key=lambda l: _lab_upload_dt(l) or datetime.min, reverse=True)

    today = datetime.now().date()

    def _med_is_history(m):
        if m.get('isHistory'):
            return True
        if m.get('isLifetime'):
            return False
        end_str = m.get('endDate')
        if not end_str:
            return False
        try:
            end_dt = datetime.fromisoformat(end_str.replace('Z', '+00:00')).date()
            return end_dt < today
        except (ValueError, TypeError):
            return False

    active_meds = [m for m in meds if not _med_is_history(m)]
    history_meds = [m for m in meds if _med_is_history(m)]

    def _med_line(m):
        parts = [m.get('name', '').strip() or 'Unnamed']
        if m.get('dosage'):
            parts.append(f"dosage {m['dosage']}")
        if m.get('frequency'):
            parts.append(f"frequency {m['frequency']}")
        if m.get('startDate'):
            parts.append(f"started {m['startDate']}")
        if m.get('isLifetime'):
            parts.append('lifetime')
        elif m.get('endDate'):
            parts.append(f"ends {m['endDate']}")
        return ' | '.join(parts)

    context_parts = [SYSTEM_PROMPT]

    context_parts.append(f"\n\nUser UI locale: {locale or 'en'}")

    if user:
        context_parts.append(f"\nUser name: {user.get('name', 'Unknown')}")
        user_age = _age_from_dob(user.get('dateOfBirth'))
        if user_age is not None:
            if user_age < 12:
                age_band = 'child'
            elif user_age < 18:
                age_band = 'adolescent'
            elif user_age >= 65:
                age_band = 'older adult'
            else:
                age_band = 'adult'
            context_parts.append(
                f"\nUser age: {user_age} ({age_band}). When suggesting any "
                "medication or dosage you MUST tailor it to this age group "
                "(paediatric weight-based dosing for children, reduced/geriatric "
                "doses for older adults, etc.). Never quote a generic adult dose "
                "for a child or older adult without flagging the adjustment."
            )
        else:
            context_parts.append(
                "\nUser age: not on file. Before suggesting a dosage, ask the user "
                "their age (or recommend they add a date of birth in their account) "
                "so you can give an age-appropriate dose."
            )

    if active_meds:
        context_parts.append(
            "\nUser's active medications (currently being taken, use these for interaction "
            "and pre-surgery checks):\n- "
            + "\n- ".join(_med_line(m) for m in active_meds)
        )
    else:
        context_parts.append(
            "\nUser's active medications: NONE on file. Ask the user to confirm what they are taking "
            "before giving a safety opinion."
        )

    if history_meds:
        history_line = ', '.join(
            f"{m.get('name', '')} ({m.get('dosage', '')})".strip() for m in history_meds
        )
        context_parts.append(
            f"\nUser's past medications (no longer active, for reference only, not interaction checks): {history_line}"
        )

    if labs:
        def _lab_text_line(l):
            bits = [l.get('name', '') or 'Unnamed test']
            if l.get('date'):
                bits.append(f"test date {l['date']}")
            if l.get('doctor'):
                bits.append(f"doctor {l['doctor']}")
            up = _lab_upload_dt(l)
            if up:
                bits.append(f"uploaded {up.strftime('%Y-%m-%d')}")
            if l.get('fileName'):
                bits.append(f"file {l['fileName']}")
            return ' | '.join(b for b in bits if b)

        context_parts.append(
            "\nUser's lab tests (newest upload first):\n- "
            + "\n- ".join(_lab_text_line(l) for l in labs)
        )
    else:
        context_parts.append("\nUser's recent lab tests: NONE on file.")

    user_lat = user.get('latitude') if user else None
    user_lng = user.get('longitude') if user else None
    user_addr = user.get('address') if user else None
    if user_addr:
        context_parts.append(f"\nUser's address: {user_addr}")

    doctors_nearby = _nearby_contacts(db, 'doctors', user_lat, user_lng, limit=10)
    pharmacies_nearby = _nearby_contacts(db, 'pharmacies', user_lat, user_lng, limit=5)
    if doctors_nearby:
        context_parts.append(
            "\nNearby doctors (admin-curated, sorted by proximity):\n- "
            + "\n- ".join(doctors_nearby)
        )
    if pharmacies_nearby:
        context_parts.append(
            "\nNearby pharmacies (admin-curated, sorted by proximity):\n- "
            + "\n- ".join(pharmacies_nearby)
        )

    system_context = ''.join(context_parts)

    # Auto-attach up to 5 most-recent uploaded lab files (PDFs / images) so
    # the AI always has the user's recent reports to refer to. Capped at 8 MB
    # total to stay well under Gemini's 20 MB inline_data limit and to keep
    # request latency reasonable.
    file_parts = []
    total_bytes = 0
    MAX_FILES = 5
    MAX_TOTAL_BYTES = 8 * 1024 * 1024
    try:
        fs = GridFS(db)
    except Exception:
        fs = None
    if fs is not None:
        for lab in labs:
            if len(file_parts) >= MAX_FILES:
                break
            file_id = lab.get('fileId')
            if not file_id:
                continue
            try:
                grid_file = fs.get(ObjectId(file_id))
            except Exception:
                continue
            try:
                file_bytes = grid_file.read()
            except Exception:
                continue
            if not file_bytes:
                continue
            if total_bytes + len(file_bytes) > MAX_TOTAL_BYTES:
                continue
            # Older uploads were stored as application/octet-stream; recover a
            # real MIME from the filename. If we still can't classify it,
            # skip — sending octet-stream causes Gemini to 400.
            mime = _infer_gemini_mime(
                getattr(grid_file, 'filename', '') or lab.get('fileName', ''),
                fallback=grid_file.content_type,
            )
            if not mime:
                continue
            file_parts.append({
                'inline_data': {
                    'mime_type': mime,
                    'data': base64.b64encode(file_bytes).decode('utf-8'),
                }
            })
            total_bytes += len(file_bytes)

    intro_parts = [{'text': system_context + '\n\nPlease acknowledge you understand your role.'}]
    if file_parts:
        intro_parts.append({
            'text': (
                f"\nThe next {len(file_parts)} attachment(s) are the user's recent uploaded lab "
                "report files, ordered newest first. Read them and use their contents when "
                "answering questions about labs, results, or trends."
            )
        })
        intro_parts.extend(file_parts)

    contents = [
        {'role': 'user', 'parts': intro_parts},
        {'role': 'model', 'parts': [{'text': "Understood! I'm CareAI, ready to help with your health needs."}]},
    ]

    for msg in history or []:
        role = 'user' if msg.get('isUser') else 'model'
        contents.append({'role': role, 'parts': [{'text': msg.get('text', '')}]})

    # Compose the final user turn. If an attachment is supplied, it goes
    # first as inline_data so Gemini can read the file, followed by the
    # user's text question. Reject MIME types Gemini won't accept (e.g.
    # application/octet-stream from an unrecognised extension) — sending
    # those causes a 400 mid-stream.
    user_parts = []
    if attachment and attachment.get('data') and attachment.get('mimeType'):
        att_mime = _infer_gemini_mime(
            attachment.get('name') or attachment.get('filename'),
            fallback=attachment.get('mimeType'),
        )
        if att_mime:
            user_parts.append({
                'inline_data': {
                    'mime_type': att_mime,
                    'data': attachment['data'],
                }
            })
    if user_message:
        user_parts.append({'text': user_message})
    # Fallback: always include at least one text part so the request is valid.
    if not user_parts:
        user_parts.append({'text': user_message or ''})

    contents.append({'role': 'user', 'parts': user_parts})
    return contents


def _request_locale(request):
    """Pick the user's preferred language code from the request. Looks at
    Accept-Language first (Flutter sends 'ar' or 'en'), then a body 'locale'
    field, then defaults to English."""
    raw = (request.META.get('HTTP_ACCEPT_LANGUAGE') or '').split(',')[0].strip()
    if raw:
        # Strip region: 'ar-SA' -> 'ar'
        return raw.split('-')[0].split(';')[0].lower() or 'en'
    return 'en'


@csrf_exempt
@login_required
@require_http_methods(['POST'])
def chat(request):
    data = _parse_body(request)
    user_message = (data.get('message') or '').strip()
    attachment = data.get('attachment')

    if not user_message and not attachment:
        return JsonResponse({'error': 'Message or attachment is required'}, status=400)

    history = data.get('history', [])
    locale = data.get('locale') or _request_locale(request)
    contents = _build_chat_contents(
        request.user_id, user_message, history,
        attachment=attachment, locale=locale)

    try:
        resp = requests.post(
            GEMINI_API_URL,
            json={'contents': contents, 'tools': GEMINI_TOOLS},
            timeout=30,
        )
        resp_data = resp.json()
        if 'candidates' in resp_data and resp_data['candidates']:
            reply = resp_data['candidates'][0]['content']['parts'][0]['text']
        else:
            error_msg = resp_data.get('error', {}).get('message', 'Unknown Error')
            print(f"Gemini API Error: {error_msg}")
            reply = "I'm having trouble connecting to my brain right now."
    except Exception as e:
        import traceback
        traceback.print_exc()
        print(f"Gemini API error: {e}")
        if 'resp' in locals():
            print(f"Response status: {resp.status_code}")
            print(f"Response body: {resp.text[:500]}")
        reply = "I'm sorry, I'm having trouble connecting right now. Please try again in a moment."

    return JsonResponse({'reply': reply})


@csrf_exempt
@login_required
@require_http_methods(['POST'])
def chat_stream(request):
    """Streaming variant of `chat`. Forwards Gemini's SSE chunks as
    `data: {"text": "..."}\\n\\n` events so the client can render tokens
    as they arrive."""
    data = _parse_body(request)
    user_message = (data.get('message') or '').strip()
    attachment = data.get('attachment')

    if not user_message and not attachment:
        return JsonResponse({'error': 'Message or attachment is required'}, status=400)

    history = data.get('history', [])
    locale = data.get('locale') or _request_locale(request)
    contents = _build_chat_contents(
        request.user_id, user_message, history,
        attachment=attachment, locale=locale)

    def _stream():
        # Track everything we've already emitted so we never re-send the same
        # text twice. Gemini streaming sometimes interleaves cumulative
        # snapshots and per-token deltas (especially when google_search
        # grounding kicks in), which previously made the bot say the same
        # answer twice. The check below works for either mode.
        emitted = ""
        try:
            with requests.post(
                GEMINI_STREAM_URL,
                json={'contents': contents, 'tools': GEMINI_TOOLS},
                stream=True,
                timeout=60,
            ) as resp:
                if resp.status_code != 200:
                    err_body = resp.text[:500]
                    print(f"Gemini stream error {resp.status_code}: {err_body}")
                    # Pull the human-readable message out of Google's standard
                    # error envelope so the user (and dev) sees what's wrong
                    # instead of a generic "Upstream error".
                    detail = ''
                    try:
                        parsed = json.loads(err_body)
                        if isinstance(parsed, dict):
                            detail = (parsed.get('error') or {}).get('message') or ''
                    except (ValueError, TypeError):
                        pass
                    if not detail:
                        detail = f'AI service returned HTTP {resp.status_code}'
                    yield f'data: {json.dumps({"error": detail})}\n\n'
                    return

                for raw_line in resp.iter_lines(decode_unicode=True):
                    if not raw_line:
                        continue
                    # SSE lines from Gemini look like: `data: {...}`
                    if not raw_line.startswith('data:'):
                        continue
                    payload = raw_line[5:].strip()
                    if not payload or payload == '[DONE]':
                        continue
                    try:
                        chunk = json.loads(payload)
                    except json.JSONDecodeError:
                        continue

                    # Concatenate every non-thought text part on candidate 0.
                    # The previous code only read parts[0] which dropped
                    # answer text whenever Gemini returned multiple parts
                    # (e.g. [{thought:true,...},{text:answer}]).
                    chunk_text = ''
                    try:
                        candidates = chunk.get('candidates') or []
                        if candidates:
                            parts = (candidates[0].get('content') or {}).get('parts') or []
                            for part in parts:
                                if part.get('thought'):
                                    continue
                                t = part.get('text') or ''
                                if t:
                                    chunk_text += t
                    except (KeyError, IndexError, TypeError, AttributeError):
                        chunk_text = ''

                    if not chunk_text:
                        continue

                    # Cumulative snapshot: chunk contains everything we have
                    # plus a new suffix. Only send the suffix.
                    if chunk_text.startswith(emitted) and len(chunk_text) > len(emitted):
                        new_text = chunk_text[len(emitted):]
                        emitted = chunk_text
                    elif chunk_text == emitted:
                        # Exact duplicate, swallow it.
                        continue
                    else:
                        # Delta: append as-is.
                        new_text = chunk_text
                        emitted += chunk_text

                    yield f'data: {json.dumps({"text": new_text})}\n\n'
                yield 'data: {"done": true}\n\n'
        except Exception as e:
            import traceback
            traceback.print_exc()
            print(f"chat_stream error: {e}")
            yield f'data: {json.dumps({"error": str(e)})}\n\n'

    response = StreamingHttpResponse(
        _stream(),
        content_type='text/event-stream',
    )
    # Discourage proxy buffering (ngrok, nginx, etc.)
    response['Cache-Control'] = 'no-cache'
    response['X-Accel-Buffering'] = 'no'
    return response
