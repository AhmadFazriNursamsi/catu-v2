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
    },
  };
}
