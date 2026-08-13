import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageService {
  static final ValueNotifier<String> currentLanguage =
      ValueNotifier<String>('id');

  static const String _prefKey = 'user_language_code';

  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLang = prefs.getString(_prefKey);
      if (savedLang != null && _translations.containsKey(savedLang)) {
        currentLanguage.value = savedLang;
      }
    } catch (_) {}
  }

  static Future<void> setLanguage(String code) async {
    if (_translations.containsKey(code)) {
      currentLanguage.value = code;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefKey, code);
      } catch (_) {}
    }
  }

  static String tr(String key) {
    final lang = currentLanguage.value;
    final map = _translations[lang] ?? _translations['id']!;
    return map[key] ?? _translations['id']![key] ?? key;
  }

  static final Map<String, Map<String, String>> _translations = {
    'id': {
      // Common & App
      'app_name': 'CATU Mobile',
      'welcome': 'Selamat Datang',
      'save': 'Simpan',
      'save_changes': 'Simpan Perubahan',
      'cancel': 'Batal',
      'back': 'Kembali',
      'close': 'Tutup',
      'close_save': 'Simpan & Tutup',
      'loading': 'Memuat...',

      // Bottom Nav / Tabs
      'nav_home': 'Beranda',
      'nav_history': 'Riwayat',
      'nav_schedule': 'Jadwal',
      'nav_profile': 'Akun Saya',

      // Home Screen
      'greeting_umat': 'Umat Beriman',
      'home_title': 'Pelayanan Keumatan',
      'home_subtitle': 'Aplikasi Pelayanan Gereja Katolik',
      'quick_services': 'Layanan Cepat',
      'service_perminyakan': 'Perminyakan Orang Sakit',
      'service_kedukaan': 'Pelayanan Kedukaan',
      'service_misa': 'Permohonan Intentia Misa',
      'recent_orders': 'Pelayanan Terkini',

      // Profile / Main Menu
      'menu_title': 'Akun & Pengaturan',
      'edit_profile': 'Ubah Profil',
      'personal_info': 'INFORMASI PRIBADI',
      'church_data': 'DATA KEUMATAN & GEREJA',
      'address_info': 'ALAMAT TEMPAT TINGGAL',
      'account_security': 'AKUN & KEAMANAN',
      'app_settings': 'Setelan Aplikasi',
      'language': 'Bahasa',
      'theme': 'Tema Aplikasi',
      'notification_pelayanan': 'Notifikasi Pelayanan',
      'notification_chat': 'Notifikasi Chat Romo',
      'help_center': 'Pusat Bantuan',
      'logout': 'Keluar Akun',
      'logout_confirm': 'Apakah Anda yakin ingin keluar dari aplikasi?',
      'change_photo': 'Ubah Foto Profil',
      'take_camera': 'Ambil Foto dari Kamera',
      'choose_gallery': 'Pilih dari Galeri / File',
      'delete_photo': 'Hapus Foto Profil',

      // Profile Fields
      'first_name': 'Nama Depan',
      'last_name': 'Nama Belakang',
      'birth_date': 'Tanggal Lahir',
      'phone_number': 'Nomor WhatsApp / HP',
      'email': 'Email',
      'address': 'Alamat Jalan / Rumah',
      'province': 'Provinsi',
      'city': 'Kota / Kabupaten',
      'role': 'Peran / Status',
      'keuskupan': 'Keuskupan',
      'paroki': 'Paroki',
      'wilayah': 'Wilayah',
      'lingkungan': 'Lingkungan',
      'ordo': 'Ordo / Kongregasi',

      // Auth / Login / Register
      'login_title': 'Masuk Akun CATU',
      'register_title': 'Buat Akun CATU',
      'password': 'Password',
      'confirm_password': 'Konfirmasi Password',
      'login_button': 'MASUK AKUN',
      'register_button': 'DAFTAR AKUN',
      'no_account': 'Belum punya akun?',
      'has_account': 'Sudah punya akun?',
      'register_here': 'Daftar di sini',
      'login_here': 'Masuk di sini',
      'select_role': 'Pilih Role Akun',

      // Menu & Status
      'main_menu': 'Menu Utama',
      'account_approved': 'Akun Disetujui',
      'pending_verification': 'Menunggu Verifikasi',
      'service_request_list': 'Daftar\nPermintaan\nPelayanan',
      'create_service_request': 'Buat Permintaan\nPelayanan',
      'no_active_schedule': 'Tidak ada jadwal pelayanan aktif saat ini.\nJadwal terdahulu dapat dilihat di tab Histori.',
      'settings_saved': 'Setelan berhasil disimpan',
      'account': 'Akun',
      'my_profile': 'Profil Saya',
      'my_profile_sub': 'Data diri, alamat & kontak',
      'verification': 'Verifikasi Data & Jabatan',
      'verification_sub': 'Status kepengurusan lingkungan & paroki',
      'privacy_security': 'Privasi & Keamanan',
      'privacy_security_sub': 'Ubah kata sandi & akses',
      'linked_accounts': 'Akun Tertaut',
      'linked_accounts_sub': 'WhatsApp & SSO Paroki',
      'settings': 'Setelan',
      'settings_sub': 'Notifikasi, bahasa & tampilan',
      'about_app': 'Tentang Catu',
      'about_app_sub': 'Versi aplikasi v2.4.0 & lisensi',
      'logout_sub': 'Keluar dari akun CATU',
      'help_center_sub': 'Kontak sekretariat paroki & FAQ',

      // Status Labels
      'status_pending': 'Menunggu Konfirmasi',
      'status_confirmed': 'Kehadiran Dikonfirmasi',
      'status_in_progress': 'Berlangsung',
      'status_done': 'Selesai',
      'status_closed': 'Ditutup',
      'status_failed': 'Gagal',
      'status_pending_short': 'Menunggu',

      // Orders / Services
      'create_service': 'Buat Permintaan Pelayanan',
      'submit_service': 'BUAT PERMINTAAN PELAYANAN',
      'send_service': 'KIRIM PELAYANAN',
      'cancel_action': 'BATALKAN',
      'recipient_data': 'Data Penerima Sakramen',
      'recipient_name': 'Nama Lengkap Penerima Sakramen',
      'request_details': 'Detail Permintaan & Urgensi',
      'schedule_location': 'Jadwal & Lokasi Pelayanan',
      'address_detail': 'Alamat Detail',
      'parish_address': 'Alamat Paroki Penerima Sakramen',
      'same_parish': 'Paroki yang sama?',
      'deceased_data': 'Data Almarhum / Almarhumah',
      'deceased_name': 'Nama Yang Meninggal',
      'relation_deceased': 'Hubungan Dengan Yang Meninggal',
      'date_of_death': 'Tanggal Meninggal',
      'mass_schedule': 'Jadwal & Lokasi Misa Kedukaan',
      'select_mass': 'Pilih Misa',
      'add_mass': 'TAMBAHKAN MISA',
      'added_mass_list': 'Daftar Misa Yang Ditambahkan:',
      'time_location': 'Waktu & Lokasi',
      'name_label': 'Nama',
      'parish_region': 'Paroki & Wilayah',
      'notes_applicant': 'Catatan & Pemohon',
      'service_discussion': 'Diskusi Pelayanan',
      'view_detail': 'Lihat Detail',
      'search_hint': 'Cari nama, kategori, lokasi...',

      // Form Errors
      'error_form_incomplete': 'Harap lengkapi semua kolom wajib dengan benar.',
      'error_date_unselected': 'Tanggal pelayanan belum dipilih.',
      'error_time_unselected': 'Jam mulai dan selesai harus dipilih.',
      'error_end_before_start': 'Jam selesai harus lebih besar dari jam mulai.',

      // History
      'history_title': 'Histori Permintaan',
      'no_requests': 'Belum Ada Permintaan',
      'sort_title': 'Urutkan',

      // Schedule
      'schedule_title': 'Daftar Pelayanan',
      'schedule_subtitle': 'Jadwal aktif & mendatang',
      'today_label': 'Hari Ini',
      'filter_label': 'Filter',
      'view_all_days': 'Lihat Semua Hari',
      'mon': 'SEN', 'tue': 'SEL', 'wed': 'RAB', 'thu': 'KAM', 'fri': 'JUM', 'sat': 'SAB', 'sun': 'MIN',

      // Register
      'start_date': 'TANGGAL MULAI',
      'end_date': 'TANGGAL SELESAI',
      'umat_role_label': 'Jabatan / Peran Umat',

      // Romo Dashboard
      'active_role': 'Jabatan Aktif',
      'see_more': 'Lihat Lainnya',
      'today_schedule': 'Jadwal\nPelayanan\nHari Ini',
      'refresh_data': 'Refresh Data Pelayanan',
    },
    'en': {
      // Common & App
      'app_name': 'CATU Mobile',
      'welcome': 'Welcome',
      'save': 'Save',
      'save_changes': 'Save Changes',
      'cancel': 'Cancel',
      'back': 'Back',
      'close': 'Close',
      'close_save': 'Save & Close',
      'loading': 'Loading...',

      // Bottom Nav / Tabs
      'nav_home': 'Home',
      'nav_history': 'History',
      'nav_schedule': 'Schedule',
      'nav_profile': 'My Account',

      // Home Screen
      'greeting_umat': 'Faithful Member',
      'home_title': 'Pastoral Services',
      'home_subtitle': 'Catholic Church Pastoral Care App',
      'quick_services': 'Quick Services',
      'service_perminyakan': 'Anointing of the Sick',
      'service_kedukaan': 'Funeral Pastoral Care',
      'service_misa': 'Mass Intentions Request',
      'recent_orders': 'Recent Services',

      // Profile / Main Menu
      'menu_title': 'Account & Settings',
      'edit_profile': 'Edit Profile',
      'personal_info': 'PERSONAL INFORMATION',
      'church_data': 'PARISH & CHURCH DETAILS',
      'address_info': 'RESIDENTIAL ADDRESS',
      'account_security': 'ACCOUNT & SECURITY',
      'app_settings': 'App Settings',
      'language': 'Language',
      'theme': 'Display Theme',
      'notification_pelayanan': 'Service Notifications',
      'notification_chat': 'Priest Chat Notifications',
      'help_center': 'Help Center',
      'logout': 'Sign Out',
      'logout_confirm': 'Are you sure you want to sign out of the app?',
      'change_photo': 'Change Profile Photo',
      'take_camera': 'Take Photo with Camera',
      'choose_gallery': 'Choose from Gallery / File',
      'delete_photo': 'Remove Profile Photo',

      // Profile Fields
      'first_name': 'First Name',
      'last_name': 'Last Name',
      'birth_date': 'Date of Birth',
      'phone_number': 'WhatsApp / Phone Number',
      'email': 'Email Address',
      'address': 'Street Address / Home',
      'province': 'Province',
      'city': 'City / District',
      'role': 'Role / Status',
      'keuskupan': 'Diocese',
      'paroki': 'Parish',
      'wilayah': 'Region / Sector',
      'lingkungan': 'Community / Neighborhood',
      'ordo': 'Religious Order',

      // Auth / Login / Register
      'login_title': 'Sign In to CATU',
      'register_title': 'Create CATU Account',
      'password': 'Password',
      'confirm_password': 'Confirm Password',
      'login_button': 'SIGN IN',
      'register_button': 'REGISTER ACCOUNT',
      'no_account': "Don't have an account?",
      'has_account': 'Already have an account?',
      'register_here': 'Register here',
      'login_here': 'Sign in here',
      'select_role': 'Select Account Role',

      // Menu & Status
      'main_menu': 'Main Menu',
      'account_approved': 'Account Approved',
      'pending_verification': 'Pending Verification',
      'service_request_list': 'Service\nRequest\nList',
      'create_service_request': 'Create Service\nRequest',
      'no_active_schedule': 'No active service schedule at this time.\nPast schedules can be viewed in the History tab.',
      'settings_saved': 'Settings saved successfully',
      'account': 'Account',
      'my_profile': 'My Profile',
      'my_profile_sub': 'Personal details, address & contact',
      'verification': 'Data & Position Verification',
      'verification_sub': 'Community & parish leadership status',
      'privacy_security': 'Privacy & Security',
      'privacy_security_sub': 'Change password & access',
      'linked_accounts': 'Linked Accounts',
      'linked_accounts_sub': 'WhatsApp & Parish SSO',
      'settings': 'Settings',
      'settings_sub': 'Notifications, language & display',
      'about_app': 'About Catu',
      'about_app_sub': 'App version v2.4.0 & licenses',
      'logout_sub': 'Sign out from CATU account',
      'help_center_sub': 'Parish secretariat contact & FAQ',

      // Status Labels
      'status_pending': 'Pending Confirmation',
      'status_confirmed': 'Attendance Confirmed',
      'status_in_progress': 'In Progress',
      'status_done': 'Completed',
      'status_closed': 'Closed',
      'status_failed': 'Failed',
      'status_pending_short': 'Pending',

      // Orders / Services
      'create_service': 'Create Service Request',
      'submit_service': 'SUBMIT SERVICE REQUEST',
      'send_service': 'SEND SERVICE',
      'cancel_action': 'CANCEL',
      'recipient_data': 'Sacrament Recipient Data',
      'recipient_name': 'Recipient Full Name',
      'request_details': 'Request Details & Urgency',
      'schedule_location': 'Service Schedule & Location',
      'address_detail': 'Detailed Address',
      'parish_address': 'Recipient Parish Address',
      'same_parish': 'Same parish?',
      'deceased_data': 'Deceased Person Data',
      'deceased_name': 'Name of Deceased',
      'relation_deceased': 'Relation to Deceased',
      'date_of_death': 'Date of Death',
      'mass_schedule': 'Funeral Mass Schedule & Location',
      'select_mass': 'Select Mass',
      'add_mass': 'ADD MASS',
      'added_mass_list': 'Added Mass List:',
      'time_location': 'Time & Location',
      'name_label': 'Name',
      'parish_region': 'Parish & Region',
      'notes_applicant': 'Notes & Applicant',
      'service_discussion': 'Service Discussion',
      'view_detail': 'View Detail',
      'search_hint': 'Search name, category, location...',

      // Form Errors
      'error_form_incomplete': 'Please fill in all required fields correctly.',
      'error_date_unselected': 'Service date has not been selected.',
      'error_time_unselected': 'Start and end time must be selected.',
      'error_end_before_start': 'End time must be later than start time.',

      // History
      'history_title': 'Request History',
      'no_requests': 'No Requests Yet',
      'sort_title': 'Sort',

      // Schedule
      'schedule_title': 'Service List',
      'schedule_subtitle': 'Active & upcoming schedule',
      'today_label': 'Today',
      'filter_label': 'Filter',
      'view_all_days': 'View All Days',
      'mon': 'MON', 'tue': 'TUE', 'wed': 'WED', 'thu': 'THU', 'fri': 'FRI', 'sat': 'SAT', 'sun': 'SUN',

      // Register
      'start_date': 'START DATE',
      'end_date': 'END DATE',
      'umat_role_label': 'Position / Parishioner Role',

      // Romo Dashboard
      'active_role': 'Active Position',
      'see_more': 'See More',
      'today_schedule': 'Today\'s\nService\nSchedule',
      'refresh_data': 'Refresh Service Data',
    },
    'la': {
      // Common & App
      'app_name': 'CATU Mobile',
      'welcome': 'Pax et Bonum',
      'save': 'Servare',
      'save_changes': 'Mutata Servare',
      'cancel': 'Cancellare',
      'back': 'Redire',
      'close': 'Claudere',
      'close_save': 'Servare et Claudere',
      'loading': 'Onerandum...',

      // Bottom Nav / Tabs
      'nav_home': 'Domus',
      'nav_history': 'Historia',
      'nav_schedule': 'Horarium',
      'nav_profile': 'Ratio Mea',

      // Home Screen
      'greeting_umat': 'Christifidelis',
      'home_title': 'Ministeria Pastoralia',
      'home_subtitle': 'Applicatio Ecclesiae Catholicae',
      'quick_services': 'Ministeria Celeria',
      'service_perminyakan': 'Unctio Infirmorum',
      'service_kedukaan': 'Cura Exsequialis',
      'service_misa': 'Intentio Missae',
      'recent_orders': 'Ministeria Recentia',

      // Profile / Main Menu
      'menu_title': 'Ratio et Configurator',
      'edit_profile': 'Mutare Rationem',
      'personal_info': 'NOTITIAE PERSONALES',
      'church_data': 'NOTITIAE ECCLESIASTICAE',
      'address_info': 'DOMICILIUM',
      'account_security': 'SECURITAS RATIONIS',
      'app_settings': 'Configuratio Applicationis',
      'language': 'Lingua',
      'theme': 'Modus Tanti',
      'notification_pelayanan': 'Nuntii Ministerii',
      'notification_chat': 'Nuntii Sacerdotis',
      'help_center': 'Centrum Auxilii',
      'logout': 'Exire',
      'logout_confirm': 'Esne certus te velle exire ex applicatione?',
      'change_photo': 'Mutare Imaginem',
      'take_camera': 'Capere ex Camera',
      'choose_gallery': 'Eligere ex Pinacotheca',
      'delete_photo': 'Delere Imaginem',

      // Profile Fields
      'first_name': 'Nomen',
      'last_name': 'Cognomen',
      'birth_date': 'Dies Natalis',
      'phone_number': 'Numerus Telephonici',
      'email': 'Cursus Computatralis',
      'address': 'Via et Domus',
      'province': 'Provincia',
      'city': 'Civitas / Urbs',
      'role': 'Status / Munus',
      'keuskupan': 'Dioecesis',
      'paroki': 'Paroecia',
      'wilayah': 'Regio',
      'lingkungan': 'Vicinia',
      'ordo': 'Ordo Religiosus',

      // Auth / Login / Register
      'login_title': 'Inire in CATU',
      'register_title': 'Creare Rationem CATU',
      'password': 'Tessera Fidei',
      'confirm_password': 'Confirmare Tesseram',
      'login_button': 'INIRE',
      'register_button': 'REGISTRARE',
      'no_account': 'Nondum habes rationem?',
      'has_account': 'Iam habes rationem?',
      'register_here': 'Registrare hic',
      'login_here': 'Inire hic',
      'select_role': 'Eligere Munus',

      // Menu & Status
      'main_menu': 'Tabula Principalis',
      'account_approved': 'Ratio Approbata',
      'pending_verification': 'Verificatio Pendente',
      'service_request_list': 'Index\nPetitionum\nMinisterii',
      'create_service_request': 'Creare Petitionem\nMinisterii',
      'no_active_schedule': 'Nulla ministeria activa in praesenti.\nPraeterita in Historia videri possunt.',
      'settings_saved': 'Configuratio servata est',
      'account': 'Ratio',
      'my_profile': 'Ratio Mea',
      'my_profile_sub': 'Notitiae personales et contactus',
      'verification': 'Verificatio Datorum',
      'verification_sub': 'Status moderationis communitatis',
      'privacy_security': 'Secretum et Securitas',
      'privacy_security_sub': 'Mutare tesseram et accessum',
      'linked_accounts': 'Rationes Connexae',
      'linked_accounts_sub': 'WhatsApp et SSO Paroeciae',
      'settings': 'Configuratio',
      'settings_sub': 'Nuntii, lingua et modus',
      'about_app': 'De Applicatione',
      'about_app_sub': 'Versio applicationis v2.4.0',
      'logout_sub': 'Exire ex ratione CATU',
      'help_center_sub': 'Contactus secretariatus et FAQ',

      // Status Labels
      'status_pending': 'Confirmatio Pendente',
      'status_confirmed': 'Praesentia Confirmata',
      'status_in_progress': 'In Cursu',
      'status_done': 'Completum',
      'status_closed': 'Clausum',
      'status_failed': 'Defectum',
      'status_pending_short': 'Pendente',

      // Orders / Services
      'create_service': 'Creare Petitionem Ministerii',
      'submit_service': 'MITTERE PETITIONEM',
      'send_service': 'MITTERE MINISTERIUM',
      'cancel_action': 'CANCELLARE',
      'recipient_data': 'Data Recipientis Sacramenti',
      'recipient_name': 'Nomen Integrum Recipientis',
      'request_details': 'Singula Petitionis et Urgentia',
      'schedule_location': 'Horarium et Locus Ministerii',
      'address_detail': 'Domicilium Singulare',
      'parish_address': 'Domicilium Paroeciae Recipientis',
      'same_parish': 'Eadem paroecia?',
      'deceased_data': 'Data Defuncti',
      'deceased_name': 'Nomen Defuncti',
      'relation_deceased': 'Relatio cum Defuncto',
      'date_of_death': 'Dies Obitus',
      'mass_schedule': 'Horarium Missae Exsequialis',
      'select_mass': 'Eligere Missam',
      'add_mass': 'ADDERE MISSAM',
      'added_mass_list': 'Index Missarum Additarum:',
      'time_location': 'Tempus et Locus',
      'name_label': 'Nomen',
      'parish_region': 'Paroecia et Regio',
      'notes_applicant': 'Notae et Petitor',
      'service_discussion': 'Disputatio Ministerii',
      'view_detail': 'Videre Singula',
      'search_hint': 'Quaerere nomen, genus, locum...',

      // Form Errors
      'error_form_incomplete': 'Omnia campi necessarii recte complendi sunt.',
      'error_date_unselected': 'Dies ministerii nondum selectus est.',
      'error_time_unselected': 'Hora initii et finis eligenda sunt.',
      'error_end_before_start': 'Hora finis posterior hora initii esse debet.',

      // History
      'history_title': 'Historia Petitionum',
      'no_requests': 'Nullae Petitiones Adhuc',
      'sort_title': 'Ordinare',

      // Schedule
      'schedule_title': 'Index Ministeriorum',
      'schedule_subtitle': 'Horaria activa et ventura',
      'today_label': 'Hodie',
      'filter_label': 'Filtrum',
      'view_all_days': 'Videre Omnes Dies',
      'mon': 'LUN', 'tue': 'MAR', 'wed': 'MER', 'thu': 'IOV', 'fri': 'VEN', 'sat': 'SAB', 'sun': 'DOM',

      // Register
      'start_date': 'DIES INITII',
      'end_date': 'DIES FINIS',
      'umat_role_label': 'Munus Christifidelis',

      // Romo Dashboard
      'active_role': 'Munus Activum',
      'see_more': 'Videre Plura',
      'today_schedule': 'Horarium\nMinisterii\nHodierni',
      'refresh_data': 'Renovare Data Ministerii',
    },
  };
}
