// All user-visible UI strings, keyed by translation key then language code.
// Fallback order when looking up: requested language -> English -> key itself.
//
// Keep keys snake_case. Group by feature prefix (common_, nav_, login_, ...).
//
// When adding a new key, add it to every language block in this file.

const Map<String, Map<String, String>> kTranslations = {
  'en': _en,
};


// ---------------------------------------------------------------------------
// English (source of truth — other languages mirror these keys)
// ---------------------------------------------------------------------------

const Map<String, String> _en = {
  // common
  'common_cancel': 'Cancel',
  'common_save': 'Save',
  'common_saving': 'Saving...',
  'common_delete': 'Delete',
  'common_edit': 'Edit',
  'common_close': 'Close',
  'common_back': 'Back',
  'common_add': 'Add',
  'common_confirm': 'Confirm',
  'common_ok': 'OK',
  'common_yes': 'Yes',
  'common_no': 'No',
  'common_loading': 'Loading...',
  'common_error': 'Error',
  'common_retry': 'Retry',
  'common_done': 'Done',
  'common_continue': 'Continue',
  'common_not_set': 'Not set',
  'common_search': 'Search',
  'common_remove': 'Remove',
  'common_send': 'Send',
  'common_saved': 'Saved',
  'common_later': 'Later',
  'common_open': 'Open',
  'common_next': 'Next',
  'common_select': 'Select',
  'common_all': 'All',
  'common_none': 'None',
  'common_required': 'Required',
  'common_optional': 'Optional',
  'common_update': 'Update',

  // app
  'app_name': 'CareMe',

  // nav
  'nav_home': 'Home',
  'nav_medications': 'Meds',
  'nav_calendar': 'Calendar',
  'nav_chat': 'Chat',
  'nav_account': 'Account',
  'nav_controller': 'Controller',
  'nav_settings': 'Settings',
  'nav_tab_home': 'Home',
  'nav_tab_health': 'Health',
  'nav_tab_appointments': 'Appointments',
  'nav_tab_account': 'Account',
  'nav_tab_dashboard': 'Dashboard',
  'nav_tab_settings': 'Settings',
  'fab_label_medication': 'Medication',
  'fab_label_lab_test': 'Lab Test',
  'fab_label_appointment': 'Appointment',

  // FAB tooltips
  'fab_add_medication': 'Add medication',
  'fab_add_lab': 'Add lab test',
  'fab_add_schedule': 'Add appointment',
  'fab_open_chat': 'Ask CareAI',

  // auth — shared
  'auth_email': 'Email',
  'auth_password': 'Password',
  'auth_full_name': 'Full Name',
  'auth_confirm_password': 'Confirm Password',

  // login
  'login_welcome': 'Welcome Back',
  'login_subtitle': 'Sign in to manage your health',
  'login_email_hint': 'Your email address',
  'login_password_hint': 'Enter your password',
  'login_forgot_password': 'Forgot password?',
  'login_sign_in': 'Sign In',
  'login_signing_in': 'Signing in...',
  'login_or': 'or',
  'login_with_google': 'Sign in with Google',
  'login_no_account': "Don't have an account?",
  'login_sign_up_link': 'Sign up',
  'login_invalid_credentials': 'Invalid email or password',
  'login_email_required': 'Email is required',
  'login_password_required': 'Password is required',
  'login_invalid_email': 'Please enter a valid email',
  'login_welcome_hello': 'Hello!',
  'login_welcome_tag': 'CareMe — your pocket health companion',
  'login_signin_failed': 'Sign-in failed',
  'login_google_failed': 'Google sign-in failed',
  'login_fill_all_fields': 'Please fill in all fields.',
  'login_invalid_email_msg': 'Please enter a valid email address.',
  'login_pw_mismatch': "The two passwords don't match.",
  'login_pw_not_meet_req': 'Your password does not meet all requirements yet.',
  'login_cant_reach_server':
      "Couldn't reach the server. Check your connection and try again.",
  'login_google_failed_try': 'Google sign-in failed. Please try again.',
  'login_accept_terms_error':
      'Please accept the Terms & Privacy Policy to continue.',
  'login_accept_terms_button': 'I Accept Terms & Privacy Policy',
  'login_verified_snack': 'Verified successfully!',
  'login_secure_badge': 'Secure \u2022 Private \u2022 HIPAA Compliant',
  'login_subtitle_signin': 'Sign in to continue',
  'login_subtitle_signup': 'Sign up to get started',
  'login_fullname_hint': 'Your full name',
  'login_signup_button': 'Create Account',
  'login_password_checklist_title': 'Your password needs:',
  'login_pw_rule_length': 'At least 8 characters',
  'login_pw_rule_upper': 'One uppercase letter (A-Z)',
  'login_pw_rule_lower': 'One lowercase letter (a-z)',
  'login_pw_rule_number': 'One number (0-9)',
  'login_pw_rule_special': 'One special character (!@#\$ etc.)',
  'login_strength_very_weak': 'Very Weak',
  'login_strength_weak': 'Weak',
  'login_strength_fair': 'Fair',
  'login_strength_good': 'Good',
  'login_strength_strong': 'Strong',
  'login_accept_prefix': 'I accept the ',
  'login_terms_privacy_link': 'Terms & Privacy Policy',
  'login_have_account_space': 'Already have an account? ',
  'login_no_account_space': "Don't have an account? ",
  'login_link_signup': 'Sign Up',
  'login_link_signin': 'Sign In',
  'login_deactivated_title': 'Account Deactivated',
  'login_deactivated_body': 'This account has been deactivated.',
  'login_deactivated_sub':
      'Your data is preserved. You can reactivate it now to sign back in.',
  'login_reactivate_button': 'Reactivate Account',

  // signup
  'signup_title': 'Create Account',
  'signup_subtitle': 'Start your health journey with CareMe',
  'signup_fullname_hint': 'Your full name',
  'signup_password_hint': 'At least 8 characters',
  'signup_confirm_hint': 'Re-enter your password',
  'signup_submit': 'Create Account',
  'signup_creating': 'Creating account...',
  'signup_have_account': 'Already have an account?',
  'signup_signin_link': 'Sign in',
  'signup_passwords_mismatch': 'Passwords do not match',
  'signup_name_required': 'Full name is required',
  'signup_password_too_short': 'Password must be at least 8 characters',
  'signup_failed': 'Registration failed',
  'signup_terms_agree': 'By signing up, you agree to our Terms of Service and Privacy Policy',

  // reset password
  'reset_title': 'Reset Password',
  'reset_subtitle': "Enter your email and we'll send you a verification code",
  'reset_send_code': 'Send Code',
  'reset_sending': 'Sending...',
  'reset_sent_ok': 'Verification code sent to your email',
  'reset_send_failed': 'Failed to send code',
  'reset_new_password': 'New Password',
  'reset_confirm_new_password': 'Confirm New Password',
  'reset_update_password': 'Update Password',
  'reset_updating': 'Updating...',
  'reset_password_updated': 'Password updated successfully',
  'reset_update_failed': 'Failed to update password',

  // otp
  'otp_verify_title': 'Verification',
  'otp_enter_code_email': 'Enter the 6-digit code we sent to {target}',
  'otp_enter_code_phone': 'Enter the 6-digit code we sent via SMS to {target}',
  'otp_verify_button': 'Verify',
  'otp_verifying': 'Verifying...',
  'otp_resend': 'Resend code',
  'otp_resend_in': 'Resend in {seconds}s',
  'otp_resent': 'New code sent',
  'otp_resend_failed': 'Failed to resend code',
  'otp_invalid': 'Invalid or expired code',
  'otp_didnt_receive': "Didn't receive the code?",
  'otp_header_title': 'Verification',
  'otp_card_title': 'Enter Verification Code',
  'otp_sent_prefix': "We've sent a 6-digit code to ",
  'otp_check_spam': "Can't find it? Check your spam or junk folder.",
  'otp_target_email_fallback': 'your email',
  'otp_target_phone_fallback': 'your phone',
  'otp_enter_all_digits': 'Please enter all 6 digits',
  'otp_verify_connection_error': 'Connection error. Please try again.',
  'otp_send_failed': 'Failed to send OTP: {error}',
  'otp_verify_button_code': 'Verify Code',
  'otp_success_snack': 'Verification successful!',
  'otp_resend_button': 'Resend Code',
  'otp_resend_available_in': 'Resend available in ',
  'otp_expires_note': 'For security reasons, this code will expire in 10 minutes',
  'otp_sending_code': 'Sending code...',

  // reactivate
  'reactivate_title': 'Reactivate Account',
  'reactivate_verify_title': 'Verify your account',
  'reactivate_desc_google':
      "We'll send a 6-digit verification code to your Google email to confirm it's you.",
  'reactivate_desc_password':
      "Enter your password to confirm your identity, then we'll send a verification code to your email.",
  'reactivate_password_required': 'Please enter your password.',
  'reactivate_send_code_button': 'Send Verification Code',
  'reactivate_code_note': 'A 6-digit code will be sent to your email.',
  'reactivate_server_error': "Couldn't reach the server. Please try again.",

  // change password
  'cp_title': 'Change Password',
  'cp_current': 'Current Password',
  'cp_current_hint': 'Enter your current password',
  'cp_new': 'New Password',
  'cp_new_hint': 'At least 8 characters',
  'cp_confirm': 'Confirm New Password',
  'cp_confirm_hint': 'Re-enter new password',
  'cp_update_button': 'Update Password',
  'cp_updating': 'Updating...',
  'cp_mismatch': 'New passwords do not match',
  'cp_too_short': 'Password must be at least 8 characters',
  'cp_wrong_current': 'Current password is incorrect',
  'cp_updated': 'Password updated successfully',
  'cp_update_failed': 'Failed to update password',
  'cp_create_new_title': 'Create New Password',
  'cp_requirements_note':
      'Password must contain at least 8 characters, uppercase, lowercase, number, and special character.',
  'cp_password_contains_prefix': 'Password must contain: {issues}',
  'cp_issue_length': 'at least 8 characters',
  'cp_issue_upper': 'an uppercase letter',
  'cp_issue_lower': 'a lowercase letter',
  'cp_issue_number': 'a number',
  'cp_issue_special': 'a special character',
  'cp_pw_mismatch_bang': 'Passwords do not match!',
  'cp_changed_success': 'Password changed successfully!',
  'cp_connection_error': 'Connection error. Please try again.',
  'cp_change_password_btn': 'Change Password',
  'cp_cancel': 'Cancel',

  // home
  'home_greeting_morning': 'Good morning',
  'home_greeting_afternoon': 'Good afternoon',
  'home_greeting_evening': 'Good evening',
  'home_greeting_night': 'Good night',
  'home_overview_tag': "Here's your health at a glance",
  'home_quick_actions': 'Quick Actions',
  'home_qa_add_med': 'Add medication',
  'home_qa_add_lab': 'Add lab test',
  'home_qa_add_schedule': 'Add appointment',
  'home_qa_ask_ai': 'Ask CareAI',
  'home_upcoming_title': 'Upcoming Appointments',
  'home_upcoming_empty': 'No upcoming appointments',
  'home_see_all': 'See all',
  'home_active_meds': 'Active Medications',
  'home_active_meds_empty': 'No active medications',
  'home_recent_labs': 'Recent Lab Tests',
  'home_recent_labs_empty': 'No lab tests yet',
  'home_ai_card_title': 'Have a health question?',
  'home_ai_card_subtitle': 'Ask CareAI — your personal health assistant',
  'home_most_frequent_meds': 'Most Frequent Medications',
  'home_no_meds_added': 'No medications added',
  'home_next_appointment': 'Next Appointment',
  'home_latest_labs': 'Latest Lab Tests',
  'home_no_labs_added': 'No lab tests added',
  'home_day_prefix': 'Day {date}',
  'month_jan': 'January',
  'month_feb': 'February',
  'month_mar': 'March',
  'month_apr': 'April',
  'month_may': 'May',
  'month_jun': 'June',
  'month_jul': 'July',
  'month_aug': 'August',
  'month_sep': 'September',
  'month_oct': 'October',
  'month_nov': 'November',
  'month_dec': 'December',

  // medications screen
  'meds_title': 'Medications',
  'meds_tab_active': 'Active',
  'meds_tab_history': 'History',
  'meds_tab_labs': 'Lab Tests',
  'meds_empty_active': 'No active medications',
  'meds_empty_active_hint': 'Tap + to add your first medication',
  'meds_empty_history': 'No medication history',
  'meds_empty_labs': 'No lab tests recorded',
  'meds_empty_labs_hint': 'Tap + to add your first lab test',
  'meds_search_placeholder': 'Search medications...',
  'meds_search_labs_placeholder': 'Search lab tests...',
  'meds_confirm_delete_title': 'Delete medication?',
  'meds_confirm_delete_body': 'This will remove {name} from your list.',
  'meds_confirm_delete_lab_title': 'Delete lab test?',
  'meds_confirm_delete_lab_body': 'This will remove {name} from your list.',
  'meds_move_to_history': 'Move to History',
  'meds_restore': 'Restore',
  'meds_dosage_label': 'Dosage',
  'meds_frequency_label': 'Frequency',
  'meds_time_label': 'Time',
  'meds_purpose_label': 'Purpose',
  'meds_side_effects_label': 'Side Effects',
  'meds_start_date_label': 'Start Date',
  'meds_end_date_label': 'End Date',
  'meds_lifetime_label': 'Lifetime',
  'meds_schedule_label': 'Schedule',
  'meds_deleted_snack': 'Medication deleted',
  'meds_added_snack': 'Medication added',
  'meds_updated_snack': 'Medication updated',
  'meds_failed_add': 'Failed to add',
  'meds_failed_update': 'Failed to update',
  'meds_failed_delete': 'Failed to delete',
  'meds_lab_deleted_snack': 'Lab test deleted',
  'meds_lab_added_snack': 'Lab test added',
  'meds_view_file': 'View file',
  'meds_download_file': 'Download file',
  'meds_no_file': 'No file attached',
  'meds_from': 'From {date}',
  'meds_to': 'to {date}',
  'meds_health_records_title': 'Health Records',
  'meds_section_meds': 'MEDICATIONS',
  'meds_section_labs': 'LAB TEST RESULTS',
  'meds_section_history': 'MEDICATION HISTORY',
  'meds_next_reminder_in': 'Next reminder in {time}',
  'meds_as_needed': 'As needed',
  'meds_frequency': 'Frequency',
  'meds_purpose': 'Purpose',
  'meds_possible_side_effects': 'Possible Side Effects',
  'meds_schedule_label_short': 'Schedule',
  'meds_taken_when_needed': 'Taken when needed',
  'meds_duration': 'Duration',
  'meds_from_short': 'From',
  'meds_to_short': 'To',
  'meds_lifetime_short': 'Lifetime',
  'meds_ordered_by': 'Ordered by',
  'meds_file_chip': 'File',
  'meds_no_file_uploaded': 'No file uploaded',
  'meds_downloading': 'Downloading...',
  'meds_download_not_supported_web': 'File download not supported on web',
  'meds_saved_to': 'Saved to {path}',
  'meds_download_failed': 'Download failed: {error}',
  'meds_save_dialog_title': 'Save {filename}',

  // add/edit medication dialog
  'dlg_add_medication_title': 'Add Medication',
  'dlg_edit_medication_title': 'Edit Medication',
  'dlg_med_name_label': 'Medication Name',
  'dlg_med_name_hint': 'Name of the medication',
  'dlg_med_dosage_hint': 'Amount per dose',
  'dlg_med_frequency_hint': 'How often to take it',
  'dlg_med_time_hint': 'When to take it',
  'dlg_med_purpose_hint': 'Why are you taking this?',
  'dlg_med_side_effects_hint': 'Any side effects to watch for',
  'dlg_med_lifetime_toggle': 'Take for life',
  'dlg_med_schedule_weekly': 'Weekly Schedule',
  'dlg_med_schedule_daily': 'Every day',
  'dlg_med_schedule_custom': 'Custom days',
  'dlg_med_add_time': 'Add time',
  'dlg_med_already_in_list': 'This medication is already in your list',
  'dlg_med_name_required': 'Medication name is required',
  'dlg_day_mon': 'Mon',
  'dlg_day_tue': 'Tue',
  'dlg_day_wed': 'Wed',
  'dlg_day_thu': 'Thu',
  'dlg_day_fri': 'Fri',
  'dlg_day_sat': 'Sat',
  'dlg_day_sun': 'Sun',
  'dlg_med_purpose_label': 'Purpose',
  'dlg_med_name_required_star': 'Medication Name *',
  'dlg_med_dosage_required_star': 'Dosage *',
  'dlg_med_purpose_placeholder': 'What the medication is for',
  'dlg_med_side_effects_placeholder': 'Known side effects, if any',
  'dlg_med_name_example': 'Name of the medication',
  'dlg_med_dosage_example': 'Amount per dose',
  'dlg_med_status_label': 'Status *',
  'dlg_med_reminder_schedule': 'Reminder Schedule',
  'dlg_med_reminder_schedule_star': 'Reminder Schedule *',
  'dlg_med_add_day': 'Add Day',
  'dlg_med_not_needed_history': 'Not needed for past medications',
  'dlg_med_choose_days_times': 'Choose which days and times to get reminders',
  'dlg_med_tap_add_day': 'Tap "Add Day" to set up your reminder schedule',
  'dlg_med_duration_label': 'Duration',
  'dlg_med_duration_label_star': 'Duration *',
  'dlg_med_start_date': 'Start Date',
  'dlg_med_end_date': 'End Date',
  'dlg_med_lifetime_medication': 'Lifetime medication',
  'dlg_med_added_success': 'Medication added successfully!',
  'dlg_med_interactions_with': '{name} has known interactions with:',
  'dlg_med_consult_doctor':
      'Please consult your doctor before taking this medication.',
  'dlg_med_add_btn': 'Add Medication',
  'dlg_med_save_btn': 'Save Changes',
  'dlg_med_status_active': 'Active',
  'dlg_med_status_history': 'History',
  'dlg_med_prn_label': 'Taken when needed',
  'dlg_med_prn_sub': 'No schedule or reminders. Use for as-needed meds like painkillers.',
  'dlg_med_tap_add_time': 'Tap "Add Time" below',
  'dlg_med_validation_name_dosage': 'Please fill in medication name and dosage.',
  'dlg_med_validation_schedule':
      'Add at least one day with a time in the Schedule section. This is required for reminder notifications.',
  'dlg_med_validation_start_date': 'Please select a start date.',
  'dlg_med_validation_end_date': 'Please select an end date or mark as lifetime.',
  'dlg_med_status_label_no_star': 'Status',
  'dlg_med_no_days_yet': 'No days added yet',
  'dlg_med_no_times': 'No times added',

  // add lab test dialog
  'dlg_add_lab_title': 'Add Lab Test',
  'dlg_lab_name_label': 'Test Name',
  'dlg_lab_name_hint': 'Name of the test',
  'dlg_lab_date_label': 'Test Date',
  'dlg_lab_result_label': 'Result',
  'dlg_lab_result_hint': 'Notes or result summary',
  'dlg_lab_attach_file': 'Attach File',
  'dlg_lab_change_file': 'Change File',
  'dlg_lab_name_required': 'Lab test name is required',
  'dlg_lab_validation_required': 'Please fill in the test name and date.',
  'dlg_lab_ordered_by': 'Ordered By',
  'dlg_lab_doctor_name_hint': "Who ordered the test",
  'dlg_lab_upload_label': 'Upload Results',
  'dlg_lab_choose_file': 'Choose file',
  'dlg_lab_add_btn': 'Add Lab Test',
  'dlg_tap_to_select_date': 'Tap to select date',

  // add/edit schedule dialog
  'dlg_add_schedule_title': 'New Appointment',
  'dlg_edit_schedule_title': 'Edit Appointment',
  'dlg_schedule_title_label': 'Title',
  'dlg_schedule_title_hint': 'What the appointment is for',
  'dlg_schedule_date_label': 'Date',
  'dlg_schedule_time_label': 'Time',
  'dlg_schedule_type_label': 'Type',
  'dlg_schedule_type_checkup': 'Check-up',
  'dlg_schedule_type_consultation': 'Consultation',
  'dlg_schedule_type_followup': 'Follow-up',
  'dlg_schedule_type_test': 'Lab Test',
  'dlg_schedule_type_vaccination': 'Vaccination',
  'dlg_schedule_type_other': 'Other',
  'dlg_schedule_location_label': 'Location',
  'dlg_schedule_location_hint': 'Clinic, hospital, address...',
  'dlg_schedule_notes_label': 'Notes',
  'dlg_schedule_added': 'Appointment added',
  'dlg_schedule_deleted': 'Appointment deleted',
  'dlg_schedule_updated': 'Appointment updated',
  'dlg_sched_add_title': 'Add Appointment',
  'dlg_sched_title_field': 'Title',
  'dlg_sched_title_hint': 'What the appointment is for',
  'dlg_sched_appointment_field': 'Appointment',
  'dlg_sched_appointment_hint': 'What the appointment is for',
  'dlg_sched_validation_required': 'Please fill in all required fields.',
  'dlg_sched_type_field': 'Appointment Type',
  'dlg_sched_type_hint': 'Kind of visit',
  'dlg_sched_doctor': 'Doctor/Specialist',
  'dlg_sched_doctor_hint': "Who you're seeing",
  'dlg_sched_location': 'Location',
  'dlg_sched_location_hint': 'Where the appointment is',
  'dlg_sched_date': 'Date',
  'dlg_sched_time': 'Time',
  'dlg_sched_tap_time': 'Tap to select time',
  'dlg_sched_google_connected': 'Google Calendar connected',
  'dlg_sched_google_signin': 'Sign in with Google',
  'dlg_sched_google_sync_sub': 'Sync this appointment to your Google Calendar',
  'dlg_sched_google_failed': 'Google sign-in failed: {error}',
  'dlg_sched_alert_synced': 'Appointment added & synced to Google Calendar!',
  'dlg_sched_alert_no_gcal':
      'Appointment added locally. Sign in with Google above to sync to your calendar.',
  'dlg_sched_alert_gcal_failed': 'Appointment added but Google Calendar sync failed.',
  'dlg_sched_alert_conflict': 'Warning: Time conflict detected with another appointment.',
  'dlg_sched_add_button': 'Add Appointment',
  'dlg_edit_appt_title': 'Edit Appointment',
  'dlg_edit_appt_date_day': 'Date (day)',
  'dlg_edit_appt_type': 'Type',

  // calendar
  'cal_title': 'Calendar',
  'cal_today': 'Today',
  'cal_tomorrow': 'Tomorrow',
  'cal_this_week': 'This Week',
  'cal_upcoming': 'Upcoming',
  'cal_past': 'Past',
  'cal_no_appointments': 'No appointments',
  'cal_add_first': 'Tap + to add your first appointment',
  'cal_delete_confirm_title': 'Delete appointment?',
  'cal_delete_confirm_body': 'This appointment will be permanently removed.',
  'cal_appointments_title': 'Appointments',
  'cal_section_upcoming': 'UPCOMING APPOINTMENTS',
  'cal_section_previous': 'PREVIOUS APPOINTMENTS',
  'cal_empty_add_next': 'Add your next appointment!',
  'month_abbr_jan': 'Jan',
  'month_abbr_feb': 'Feb',
  'month_abbr_mar': 'Mar',
  'month_abbr_apr': 'Apr',
  'month_abbr_may': 'May',
  'month_abbr_jun': 'Jun',
  'month_abbr_jul': 'Jul',
  'month_abbr_aug': 'Aug',
  'month_abbr_sep': 'Sep',
  'month_abbr_oct': 'Oct',
  'month_abbr_nov': 'Nov',
  'month_abbr_dec': 'Dec',

  // chatbot
  'chat_title': 'CareAI',
  'chat_ai_name': 'CareAI',
  'chat_header_subtitle': 'Always here to help',
  'chat_greeting':
      "Hello! I'm CareAI, your intelligent health assistant. I can help you with medications, appointments, lab results, and health questions. How can I assist you today?",
  'chat_retention_banner':
      "Hello! I'm CareAI, your intelligent health assistant. I can help you with medications, appointments, lab results, and health questions.\n\n*Note: I keep our chat history for the last 7 days. Messages older than 7 days are automatically deleted.*",
  'chat_qa_medications': 'Show my medications',
  'chat_qa_next_appointment': 'Next appointment',
  'chat_qa_latest_labs': 'Latest lab results',
  'chat_input_hint': 'Type your message...',
  'chat_input_hint_attachment': 'Ask a question about this file...',
  'chat_typing': 'CareAI is thinking...',
  'chat_generating': 'Generating...',
  'chat_send_tooltip': 'Send',
  'chat_stop_tooltip': 'Stop generating',
  'chat_no_reply': "I didn't catch that. Could you ask again?",
  'chat_error_timeout':
      'The request timed out. The AI server may be busy. Please try again in a moment.',
  'chat_error_no_connection':
      'Could not reach the server. Please check your internet connection and try again.',
  'chat_error_unknown':
      'Something went wrong: {error}. Please try again.',
  'chat_attach_tooltip': 'Attach a file or photo',
  'chat_pick_image': 'Photo',
  'chat_pick_file': 'File',
  'chat_remove_attachment': 'Remove attachment',
  'chat_image_attached': '[Image attached: {name}]',
  'chat_file_attached': '[File attached: {name}]',
  'chat_error_generic':
      "I'm sorry, I'm having trouble connecting right now. Please try again in a moment.",
  'chat_error_brain': "I'm having trouble connecting to my brain right now.",
  'chat_quick_actions_header': 'Quick Actions',
  'chat_attach_take_photo': 'Take photo',
  'chat_attach_from_gallery': 'Choose from gallery',
  'chat_attach_from_file': 'Choose a file',
  'chat_attach_camera_error': 'Could not open camera: {error}',
  'chat_attach_gallery_error': 'Could not open gallery: {error}',
  'chat_attach_file_error': 'Could not pick file: {error}',
  'chat_attach_too_large': 'File too large. Pick something under 15 MB.',
  'chat_history_tooltip': 'Previous chats',
  'chat_new_session_tooltip': 'New chat',
  'chat_history_title': 'Previous chats',
  'chat_history_subtitle': 'Kept for the last 7 days',
  'chat_history_empty_session': '(empty chat)',
  'chat_history_just_now': 'Just now',
  'chat_history_minutes_ago': '{n}m ago',
  'chat_history_hours_ago': '{n}h ago',
  'chat_history_yesterday': 'Yesterday',
  'chat_history_days_ago': '{n}d ago',
  'chat_history_delete_tooltip': 'Delete chat',
  'chat_history_delete_title': 'Delete this chat?',
  'chat_history_delete_body':
      'This conversation will be removed permanently from your device.',

  // account — main
  'account_title': 'Account',
  'account_section_personal': 'Personal Information',
  'account_section_settings': 'Settings',
  'account_section_support': 'Support',
  'account_info_email': 'Email',
  'account_info_phone': 'Phone',
  'account_info_dob': 'Date of Birth',
  'account_info_address': 'Address',
  'account_edit_profile': 'Edit Profile',
  'account_edit_profile_sub': 'Update your personal information',
  'account_security': 'Security & Privacy',
  'account_security_sub': 'Password, privacy controls',
  'account_dark_mode': 'Dark Mode',
  'account_dark_on': 'On',
  'account_dark_off': 'Off',
  'account_language': 'Language',
  'account_language_sub': 'Choose the app\u2019s display language',
  'account_help_support': 'Help & Support',
  'account_help_support_sub': 'FAQs and contact support',
  'account_terms_privacy': 'Terms & Privacy',
  'account_terms_privacy_sub': 'View policies',
  'account_about': 'About CareMe',
  'account_about_sub': 'Version 1.0.0',
  'account_sign_out': 'Sign Out',
  'account_closure_title': 'Delete / Deactivate Account',
  'account_closure_subtitle': 'Choose what you would like to do with your account.',
  'account_closure_nav_sub': 'Remove your account or pause it',
  'account_delete_title': 'Delete Account',
  'account_delete_subtitle': 'Permanently remove your account and all data.',
  'account_delete_confirm_body':
      'Are you sure you want to delete your account? Your account and all related data (medications, lab tests, files) will be permanently removed. This cannot be undone.',
  'account_delete_download_title': 'Delete and Download',
  'account_delete_download_subtitle':
      'Export your data as PDF, then delete the account.',
  'account_delete_download_confirm_body':
      'Are you sure you want to delete your account? Your data will first be exported as a PDF, then your account and all related data will be permanently removed. This cannot be undone.',
  'account_deactivate_subtitle':
      'Disable sign-in; your data is preserved for later.',
  'account_export_and_delete': 'Export & Delete',
  'account_deleted_snack': 'Account deleted',
  'account_delete_failed': 'Failed to delete account: {error}',

  // account — language picker
  'language_picker_title': 'Choose Language',
  'language_picker_subtitle': 'Applies to the whole app immediately',

  // account — edit profile
  'edit_profile_title': 'Edit Profile',
  'edit_profile_change_picture': 'Change profile picture',
  'edit_profile_remove_picture': 'Remove photo',
  'edit_profile_section_general': 'General Information',
  'edit_profile_name_label': 'Full Name',
  'edit_profile_phone_label': 'Phone Number',
  'edit_profile_phone_hint': 'Phone number',
  'edit_profile_dob_label': 'Date of Birth',
  'edit_profile_dob_hint': 'Tap to select date',
  'edit_profile_address_label': 'Address',
  'edit_profile_save': 'Save Changes',
  'edit_profile_saved': 'Profile updated successfully',
  'edit_profile_save_failed': 'Failed to save: {error}',
  'edit_profile_select_country': 'Select Country',
  'edit_profile_search_country': 'Search country...',

  // account — security & privacy
  'security_title': 'Security & Privacy',
  'security_section_password': 'Password & Authentication',
  'security_change_password': 'Change Password',
  'security_change_password_sub': 'Verify your identity first',
  'security_section_privacy': 'Privacy Controls',
  'security_download_data': 'Download My Data',
  'security_download_data_sub': 'Export all your information',
  'security_deactivate': 'Deactivate Account',
  'security_deactivate_sub': 'Disable account; data is preserved',
  'security_download_title': 'Save your health data',
  'security_download_filename': 'CareMe_MyData.pdf',
  'security_download_saved_at': 'Saved to {path}',
  'security_download_failed': 'Failed to download data: {error}',
  'security_deactivate_confirm_title': 'Deactivate Account',
  'security_deactivate_confirm_body':
      'This will deactivate your account and sign you out. Your data (medications, lab tests, files) is preserved and not deleted.\n\nYou will not be able to sign in again until you contact support to reactivate your account.',
  'security_deactivate_button': 'Deactivate',
  'security_deactivated_snack': 'Account deactivated',
  'security_deactivate_failed': 'Failed to deactivate account: {error}',

  // help & support
  'help_faq_title': 'Frequently Asked Questions',
  'help_contact_title': 'Contact Support',
  'help_contact_email_label': 'Email',
  'help_contact_email_value': 'support@careme.app',
  'help_response_time': 'Our support team typically responds within 24 hours.',
  'help_q1': 'How do I add a medication?',
  'help_a1':
      'Go to the Medications tab and tap the + button. Fill in the medication details and tap Save.',
  'help_q2': 'How do I upload lab results?',
  'help_a2':
      'Go to the Lab Tests tab and tap the + button. You can upload a file or enter the details manually.',
  'help_q3': 'Is my health data secure?',
  'help_a3':
      'Yes. Your data is encrypted in transit and at rest. We never sell or share your personal health information.',
  'help_q4': 'How do I change my password?',
  'help_a4':
      'Go to Settings > Security & Privacy > Change Password. You will need to verify your identity via email OTP first.',
  'help_q5': 'How do I deactivate my account?',
  'help_a5':
      'Go to Settings > Security & Privacy > Deactivate Account. Your data is preserved and you can contact support to reactivate anytime.',
  'help_q6': 'Can I export my data?',
  'help_a6':
      'Yes. Go to Settings > Security & Privacy > Download My Data to export your health records as a PDF.',

  // terms + privacy
  'terms_privacy_title': 'Terms & Privacy',
  'terms_section': 'Terms of Service',
  'privacy_section': 'Privacy Policy',
  'legal_canonical_note':
      'Note: The English version of this document is the legally controlling original. Translations are provided for convenience only.',
  'terms_text_full': '''Last updated: April 2026

1. Acceptance of Terms
By creating an account or otherwise using CareMe ("the App"), you confirm that you have read, understood, and agreed to be bound by these Terms of Service. If you do not agree, do not use the App.

2. Eligibility
You must be at least 18 years old, or use the App under the supervision of a parent or legal guardian. By using the App you represent that you meet these requirements.

3. Description of Service
CareMe is a personal health-management tool that lets you record and review your own medications, lab results, and appointments, set reminders, and chat with an AI assistant ("CareAI") for general wellness information. CareMe is provided "as is" and does not constitute medical advice, diagnosis, or treatment.

4. Medical Disclaimer
THE APP IS NOT A MEDICAL DEVICE. Information shown -- including content generated by CareAI -- is for informational purposes only and is not a substitute for professional medical judgment. Always consult a qualified healthcare provider before starting, changing, or stopping any treatment. In case of a medical emergency call your local emergency number immediately; do not rely on the App.

5. Account & Security
You are responsible for keeping your credentials confidential and for all activity that occurs under your account. Notify us immediately on WhatsApp at +961 78 889 290 if you suspect unauthorized access. We may suspend or terminate accounts that violate these Terms or applicable law.

6. User Content & Accuracy
You retain ownership of the data you enter ("User Content"). You alone are responsible for the accuracy, completeness, and legality of that data. By submitting content you grant CareMe a limited licence to store and process it solely to operate the App for you.

7. Acceptable Use
You agree not to: (a) misuse the App, attempt to disrupt our infrastructure, or reverse engineer it; (b) submit content you do not have the right to share; (c) use the App to harass, harm, or impersonate others; (d) rely on CareAI for emergency, diagnostic, or treatment decisions.

8. Third-Party Services
CareMe integrates with third-party services (e.g. Google Sign-In, Google Calendar, Google Maps, Google Generative Language API, Firebase Cloud Messaging). Your use of those services is governed by their own terms and privacy policies.

9. Changes to the Service or Terms
We may update the App or these Terms at any time. Material changes will be communicated through the App. Continued use after a change constitutes acceptance of the revised Terms.

10. Disclaimers & Limitation of Liability
TO THE MAXIMUM EXTENT PERMITTED BY LAW, CAREME AND ITS CONTRIBUTORS PROVIDE THE APP WITHOUT WARRANTIES OF ANY KIND AND ARE NOT LIABLE FOR ANY INDIRECT, INCIDENTAL, CONSEQUENTIAL, OR SPECIAL DAMAGES, INCLUDING LOSS OF DATA, ARISING FROM YOUR USE OF THE APP.

11. Termination
You may stop using the App at any time. We may suspend or terminate access where required by law or in response to misuse. You can deactivate your account from Settings -> Security & Privacy.

12. Governing Law
These Terms are governed by the laws of the user's country of residence, except where mandatory consumer-protection rules require otherwise.

13. Contact
Questions or concerns about these Terms: WhatsApp +961 78 889 290.''',
  'privacy_text_full': '''Last updated: April 2026

1. Who We Are
CareMe ("we", "us") is the operator of the CareMe mobile application. This Privacy Policy explains what information we collect about you, how we use it, and the choices you have.

2. Information We Collect
- Account information: name, email address, hashed password, date of birth, country code, phone number, and home address (with optional GPS coordinates for finding nearby providers).
- Health information you choose to record: medications, dosages, schedules, lab tests and uploaded files, appointments.
- Authentication data: when you sign in with Google we receive your Google profile name and email; we do not access your contacts or other Google data unless you grant calendar sync.
- Device data: a Firebase Cloud Messaging token used to deliver reminder notifications, and basic diagnostic logs.
- Chat content: messages you send to CareAI and any files you attach are sent to Google's Generative Language API to produce a response.

3. How We Use Your Information
We use your data only to provide the App's features: storing your records, sending medication reminders, generating personalized AI responses, and securing your account. We do not use your health data for advertising.

4. Legal Basis
We process personal data based on (a) the contract between you and us when you accept these Terms and (b) your consent for optional features such as location services, push notifications, camera, calendar sync, and AI chat.

5. Data Security
Your password is stored using a one-way hash. Sensitive health fields (medication, lab data) are encrypted at rest with a server-managed key. All traffic between the App and our servers travels over HTTPS/TLS.

6. Sharing & Third Parties
We do not sell, rent, or trade your personal information. We share data only with the service providers strictly required to run the App -- for example Google (Sign-In, Maps, Calendar, Generative Language API) and Firebase (push notifications). Each provider acts as our data processor and is bound by its own commitments.

7. Data Retention
We keep your data while your account is active. If you deactivate your account, your records are retained in a disabled state in case you wish to reactivate. You may request permanent deletion at any time by contacting us on WhatsApp at +961 78 889 290.

8. Your Rights
Depending on your jurisdiction (e.g. GDPR for the EU/EEA, CCPA for California), you may have the right to access, correct, export, restrict, or delete your personal data. Use Settings -> Security & Privacy -> Export My Data to export, or contact us to exercise other rights.

9. Children
CareMe is not directed to children under 13 (or the relevant local minimum age). We do not knowingly collect data from such users. If you believe a child has created an account, please contact us so we can remove it.

10. Health-Information Notice
CareMe is intended for personal recordkeeping and is not a HIPAA-covered entity. Records you store are not subject to HIPAA, but we apply commercially reasonable safeguards to protect them.

11. Changes to This Policy
We may update this policy as the App evolves. Material changes will be highlighted in-app. The "Last updated" date at the top reflects the current version.

12. Contact
Privacy questions or requests: WhatsApp +961 78 889 290.''',
  'help_contact_whatsapp_label': 'WhatsApp',

  // about
  'about_title': 'About CareMe',
  'about_version': 'Version 1.0.0',
  'about_description':
      'CareMe is your personal health companion, designed to help you stay on top of your health by managing medications, tracking lab results, and organizing medical appointments \u2014 all in one place.',
  'about_features_title': 'Key Features',
  'about_feature_med': 'Medication tracking & reminders',
  'about_feature_lab': 'Lab test records & file uploads',
  'about_feature_appt': 'Appointment scheduling',
  'about_feature_ai': 'AI-powered health assistant',
  'about_feature_pdf': 'Export health data as PDF',
  'about_feature_secure': 'Secure & private by design',
  'about_tagline': 'Built with care for your well-being.',

  // admin
  'admin_title': 'Admin Controller',
  'admin_tab_doctors': 'Doctors',
  'admin_tab_pharmacies': 'Pharmacies',
  'admin_settings_title': 'Admin Settings',
  'admin_add_doctor': 'Add Doctor',
  'admin_edit_doctor': 'Edit Doctor',
  'admin_add_pharmacy': 'Add Pharmacy',
  'admin_edit_pharmacy': 'Edit Pharmacy',
  'admin_name_label': 'Name',
  'admin_specialty_label': 'Specialty',
  'admin_address_label': 'Address',
  'admin_phone_label': 'Phone',
  'admin_latitude_label': 'Latitude',
  'admin_longitude_label': 'Longitude',
  'admin_save_button': 'Save',
  'admin_delete_confirm': 'Delete this entry?',
  'admin_no_doctors': 'No doctors yet',
  'admin_no_pharmacies': 'No pharmacies yet',
  'admin_added_doctor': 'Doctor added',
  'admin_updated_doctor': 'Doctor updated',
  'admin_deleted_doctor': 'Doctor deleted',
  'admin_added_pharmacy': 'Pharmacy added',
  'admin_updated_pharmacy': 'Pharmacy updated',
  'admin_deleted_pharmacy': 'Pharmacy deleted',
  'admin_required_fields': 'Name, address, and phone are required',
  'admin_name_required': 'Name is required',
  'admin_specialty_required': 'Specialty is required',
  'admin_pick_address_first': 'Pick an address on the map first.',
  'admin_doctor_added_snack': 'Doctor added successfully!',
  'admin_pharmacy_added_snack': 'Pharmacy added successfully!',
  'admin_failed_prefix': 'Failed: {error}',
  'admin_controller_title_full': 'Admin Controller',
  'admin_specialty_hint': 'Medical specialty',
  'admin_name_doctor_hint': "Doctor's full name",
  'admin_name_pharmacy_hint': 'Pharmacy name',
  'admin_phone_hint': 'Contact phone number',
  'admin_section_doctors': 'DOCTORS',
  'admin_section_pharmacies': 'PHARMACIES',
  'admin_no_doctors_yet': 'No doctors yet.',
  'admin_no_pharmacies_yet': 'No pharmacies yet.',
  'admin_delete_failed': 'Delete failed: {error}',
  'common_retry_btn': 'Retry',
  // availability (working hours)
  'admin_availability_label': 'Availability',
  'admin_availability_add_day': 'Add day',
  'admin_availability_none': 'No availability set.',
  'admin_availability_from': 'From',
  'admin_availability_to': 'To',
  'admin_availability_set_time': 'Set time',
  'admin_availability_invalid': 'Each day needs a valid "from" and "to" time.',
  'admin_availability_choose_day': 'Choose a day',
  'admin_availability_closes_before_opens': '{day}: closing time is before opening time.',

  // location picker
  'loc_label': 'Address',
  'loc_hint': 'Search or tap to detect',
  'loc_use_current': 'Use current location',
  'loc_search_hint': 'Search address or place...',
  'loc_detecting': 'Detecting your location...',
  'loc_permission_denied':
      'Location permission denied. Enable it in Settings.',
  'loc_service_disabled':
      'Location services are off. Turn them on to detect your address.',
  'loc_failed': 'Could not determine your address',
  'loc_no_results': 'No matches found',
  'loc_tap_to_confirm': 'Tap to confirm',
  'loc_tap_pick': 'Tap to pick a location',
  'loc_services_off': 'Location services are turned off on this device.',
  'loc_permission_denied_manual':
      'Location permission denied. You can still pick a place manually.',
  'loc_detect_failed': 'Could not detect location: {error}',
  'loc_pin_resolve_failed':
      'Could not resolve that pin to an address. Type it manually below.',
  'loc_no_results_query': 'No results for "{query}".',
  'loc_search_failed': 'Search failed: {error}',
  'loc_pin_no_address': 'No address found for that pin.',
  'loc_geocoding_failed': 'Geocoding failed: {error}',
  'loc_drop_pin_first': 'Drop a pin or search for an address first.',
  'loc_accept_before_confirm': 'Type or accept an address before confirming.',
  'loc_pick_title': 'Pick a location',
  'loc_confirm_caps': 'CONFIRM',
  'loc_search_placeholder': 'Search address, place, city\u2026',
  'loc_use_this_location': 'Use this location',
  'loc_address_label': 'Address',

  // country picker
  'country_picker_title': 'Select Country',
  'country_picker_search': 'Search country...',
  'phone_required': 'Phone is required',

  // snackbars / generic errors
  'generic_error': 'Something went wrong',
  'generic_network_error': 'Network error. Please try again.',
  'generic_saved': 'Saved',

  // sign in terms row
  'terms_agree_line':
      'By continuing, you agree to our Terms of Service and Privacy Policy',
};
