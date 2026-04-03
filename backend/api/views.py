import io
import json
import re
import random
import base64
import requests
from datetime import datetime, timedelta
from bson import ObjectId
from django.conf import settings
from django.http import JsonResponse, HttpResponse
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
from .auth_utils import hash_password, check_password, create_token, login_required

# ---------- Gemini setup ----------

GEMINI_API_URL = (
    'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent'
    f'?key={settings.GEMINI_API_KEY}'
)

SYSTEM_PROMPT = (
    "You are CareAI, a helpful and friendly health assistant for the CareMe app. "
    "You ONLY answer questions related to health, medicine, medications, appointments, "
    "lab results, symptoms, wellness, nutrition, fitness, and mental health. "
    "If a user asks about anything unrelated to health or medicine, politely decline and say: "
    "'I can only help with health and medical-related questions. Please ask me something about your health!' "
    "Do not answer questions about politics, entertainment, coding, math, history, or any non-medical topic. "
    "Be concise, caring, and accurate. If you are unsure about medical advice, recommend consulting a doctor. "
    "Do not diagnose conditions. Keep responses short and helpful."
)

# ---------- helpers ----------

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
    if len(password) < 6:
        return JsonResponse({'error': 'Password must be at least 6 characters'}, status=400)

    db = get_db()
    if db.users.find_one({'email': email}):
        return JsonResponse({'error': 'Email already registered'}, status=409)

    user = {
        'name': name,
        'email': email,
        'password': hash_password(password),
    }
    result = db.users.insert_one(user)
    user_id = str(result.inserted_id)
    token = create_token(user_id, email)

    return JsonResponse({
        'token': token,
        'user': {'id': user_id, 'name': name, 'email': email},
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

    user_id = str(user['_id'])
    token = create_token(user_id, email)

    return JsonResponse({
        'token': token,
        'user': {'id': user_id, 'name': user['name'], 'email': email},
    })


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

    if len(new_password) < 8:
        return JsonResponse({'error': 'Password must be at least 8 characters'}, status=400)
    if not re.search(r'[A-Z]', new_password):
        return JsonResponse({'error': 'Password must contain an uppercase letter'}, status=400)
    if not re.search(r'[a-z]', new_password):
        return JsonResponse({'error': 'Password must contain a lowercase letter'}, status=400)
    if not re.search(r'[0-9]', new_password):
        return JsonResponse({'error': 'Password must contain a number'}, status=400)
    if not re.search(r'[!@#$%^&*(),.?":{}|<>]', new_password):
        return JsonResponse({'error': 'Password must contain a special character'}, status=400)

    db = get_db()
    db.users.update_one(
        {'_id': ObjectId(request.user_id)},
        {'$set': {'password': hash_password(new_password)}},
    )
    return JsonResponse({'message': 'Password changed successfully'})


# ---------- User Profile ----------

@csrf_exempt
@login_required
@require_http_methods(['GET', 'PUT'])
def profile(request):
    db = get_db()
    user = db.users.find_one({'_id': ObjectId(request.user_id)})
    if not user:
        return JsonResponse({'error': 'User not found'}, status=404)

    if request.method == 'GET':
        return JsonResponse({
            'id': str(user['_id']),
            'name': user.get('name', ''),
            'email': user.get('email', ''),
            'phone': user.get('phone', ''),
            'dateOfBirth': user.get('dateOfBirth', ''),
            'address': user.get('address', ''),
        })

    # PUT - update profile
    data = _parse_body(request)
    updates = {}
    for field in ('name', 'phone', 'dateOfBirth', 'address'):
        if field in data:
            updates[field] = data[field]

    if updates:
        db.users.update_one({'_id': ObjectId(request.user_id)}, {'$set': updates})

    updated = db.users.find_one({'_id': ObjectId(request.user_id)})
    return JsonResponse({
        'id': str(updated['_id']),
        'name': updated.get('name', ''),
        'email': updated.get('email', ''),
        'phone': updated.get('phone', ''),
        'dateOfBirth': updated.get('dateOfBirth', ''),
        'address': updated.get('address', ''),
    })


# ---------- Medications ----------

@csrf_exempt
@login_required
@require_http_methods(['GET', 'POST'])
def medications(request):
    db = get_db()

    if request.method == 'GET':
        meds = list(db.medications.find({'user_id': request.user_id}))
        return JsonResponse([_str_id(m) for m in meds], safe=False)

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
    }

    if not med['name']:
        return JsonResponse({'error': 'Medication name is required'}, status=400)

    result = db.medications.insert_one(med)
    med['id'] = str(result.inserted_id)
    del med['_id']
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
                   'schedule', 'startDate', 'endDate', 'isLifetime'):
        if field in data:
            updates[field] = data[field]

    if updates:
        db.medications.update_one({'_id': obj_id}, {'$set': updates})

    updated = db.medications.find_one({'_id': obj_id})
    return JsonResponse(_str_id(updated))


# ---------- Lab Tests ----------

@csrf_exempt
@login_required
@require_http_methods(['GET', 'POST'])
def lab_tests(request):
    db = get_db()

    if request.method == 'GET':
        labs = list(db.lab_tests.find({'user_id': request.user_id}))
        return JsonResponse([_str_id(l) for l in labs], safe=False)

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
                content_type='application/octet-stream',
                user_id=request.user_id,
            )

        lab = {
            'user_id': request.user_id,
            'name': data.get('name', ''),
            'date': data.get('date', ''),
            'doctor': data.get('doctor', ''),
            'fileName': file_name,
            'fileId': str(file_id) if file_id else '',
        }

    if not lab['name']:
        return JsonResponse({'error': 'Lab test name is required'}, status=400)

    result = db.lab_tests.insert_one(lab)
    lab['id'] = str(result.inserted_id)
    del lab['_id']
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


# ---------- Delete Account ----------

@csrf_exempt
@login_required
@require_http_methods(['DELETE'])
def delete_account(request):
    db = get_db()
    user_id = request.user_id

    # Delete all user files from GridFS
    fs = GridFS(db)
    labs = list(db.lab_tests.find({'user_id': user_id}))
    for lab in labs:
        if lab.get('fileId'):
            try:
                fs.delete(ObjectId(lab['fileId']))
            except Exception:
                pass

    # Delete all user data
    db.medications.delete_many({'user_id': user_id})
    db.lab_tests.delete_many({'user_id': user_id})
    db.users.delete_one({'_id': ObjectId(user_id)})

    return JsonResponse({'message': 'Account deleted'})


# ---------- Export User Data ----------

@csrf_exempt
@login_required
@require_http_methods(['POST'])
def export_data(request):
    db = get_db()
    user_id = request.user_id
    user = db.users.find_one({'_id': ObjectId(user_id)})
    user_name = user.get('name', 'User') if user else 'User'

    # Get medications from DB
    meds = list(db.medications.find({'user_id': user_id}))

    # Get appointments from request body (stored client-side)
    data = _parse_body(request)
    appointments = data.get('appointments', [])

    # Build PDF
    buf = io.BytesIO()
    doc = SimpleDocTemplate(buf, pagesize=letter, topMargin=0.75 * inch, bottomMargin=0.75 * inch)
    styles = getSampleStyleSheet()
    title_style = ParagraphStyle('CustomTitle', parent=styles['Title'], fontSize=22, textColor=colors.HexColor('#1E3A5F'), spaceAfter=6)
    subtitle_style = ParagraphStyle('Subtitle', parent=styles['Normal'], fontSize=10, textColor=colors.grey, spaceAfter=20)
    heading_style = ParagraphStyle('SectionHeading', parent=styles['Heading2'], fontSize=14, textColor=colors.HexColor('#1E3A5F'), spaceBefore=20, spaceAfter=10)

    elements = []

    # Header
    elements.append(Paragraph('CareMe - My Health Data', title_style))
    elements.append(Paragraph(f'Generated for {user_name} on {datetime.now().strftime("%B %d, %Y")}', subtitle_style))

    # Medications section
    elements.append(Paragraph('Medications', heading_style))
    if meds:
        med_data = [['Name', 'Dosage', 'Frequency', 'Time', 'Purpose', 'Side Effects']]
        for m in meds:
            med_data.append([
                m.get('name', ''),
                m.get('dosage', ''),
                m.get('frequency', ''),
                m.get('time', ''),
                m.get('purpose', ''),
                m.get('sideEffects', ''),
            ])
        med_table = Table(med_data, repeatRows=1)
        med_table.setStyle(TableStyle([
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
        ]))
        elements.append(med_table)
    else:
        elements.append(Paragraph('No medications on record.', styles['Normal']))

    elements.append(Spacer(1, 20))

    # Appointments section
    elements.append(Paragraph('Appointments', heading_style))
    if appointments:
        apt_data = [['Date', 'Title', 'Time', 'Type', 'Location']]
        for a in appointments:
            date_val = a.get('date', '')
            if isinstance(date_val, int):
                date_val = datetime.fromtimestamp(date_val / 1000).strftime('%b %d, %Y')
            apt_data.append([
                date_val,
                a.get('title', ''),
                a.get('time', ''),
                a.get('type', ''),
                a.get('location', ''),
            ])
        apt_table = Table(apt_data, repeatRows=1)
        apt_table.setStyle(TableStyle([
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
        ]))
        elements.append(apt_table)
    else:
        elements.append(Paragraph('No appointments on record.', styles['Normal']))

    doc.build(elements)
    buf.seek(0)

    response = HttpResponse(buf.read(), content_type='application/pdf')
    response['Content-Disposition'] = 'attachment; filename="CareMe_MyData.pdf"'
    return response


# ---------- Chatbot ----------

@csrf_exempt
@login_required
@require_http_methods(['POST'])
def chat(request):
    data = _parse_body(request)
    user_message = (data.get('message') or '').strip()

    if not user_message:
        return JsonResponse({'error': 'Message is required'}, status=400)

    history = data.get('history', [])

    db = get_db()

    # Fetch user context for personalized responses
    meds = list(db.medications.find({'user_id': request.user_id}))
    labs = list(db.lab_tests.find({'user_id': request.user_id}))
    user = db.users.find_one({'_id': ObjectId(request.user_id)})

    context_parts = [SYSTEM_PROMPT]

    if user:
        context_parts.append(f"\nUser name: {user.get('name', 'Unknown')}")

    if meds:
        med_list = ', '.join(f"{m.get('name', '')} ({m.get('dosage', '')})" for m in meds)
        context_parts.append(f"\nUser's current medications: {med_list}")

    if labs:
        lab_list = ', '.join(f"{l.get('name', '')} on {l.get('date', '')}" for l in labs)
        context_parts.append(f"\nUser's recent lab tests: {lab_list}")

    system_context = ''.join(context_parts)

    # Build conversation contents for Gemini REST API
    contents = [
        {'role': 'user', 'parts': [{'text': system_context + '\n\nPlease acknowledge you understand your role.'}]},
        {'role': 'model', 'parts': [{'text': "Understood! I'm CareAI, ready to help with your health needs."}]},
    ]

    for msg in history:
        role = 'user' if msg.get('isUser') else 'model'
        contents.append({'role': role, 'parts': [{'text': msg.get('text', '')}]})

    contents.append({'role': 'user', 'parts': [{'text': user_message}]})

    try:
        resp = requests.post(GEMINI_API_URL, json={'contents': contents}, timeout=30)
        resp_data = resp.json()
        reply = resp_data['candidates'][0]['content']['parts'][0]['text']
    except Exception as e:
        import traceback
        traceback.print_exc()
        print(f"Gemini API error: {e}")
        if 'resp' in locals():
            print(f"Response status: {resp.status_code}")
            print(f"Response body: {resp.text[:500]}")
        reply = "I'm sorry, I'm having trouble connecting right now. Please try again in a moment."

    return JsonResponse({'reply': reply})
