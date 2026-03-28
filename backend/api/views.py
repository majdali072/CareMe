import json
import re
import base64
from bson import ObjectId
from django.http import JsonResponse, HttpResponse
from django.views.decorators.http import require_http_methods
from django.views.decorators.csrf import csrf_exempt
from gridfs import GridFS
from .db import get_db
from .auth_utils import hash_password, check_password, create_token, login_required

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
    for field in ('name', 'dosage', 'frequency', 'time', 'purpose', 'sideEffects'):
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
