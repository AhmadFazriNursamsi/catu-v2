import 'package:flutter/material.dart';
import 'reschedule_validation.dart';
import 'reschedule_widgets.dart';

const _reasonChips = [
  'Bentrok dengan jadwal pelayanan lain',
  'Ada keperluan pastoral mendadak',
  'Kondisi kesehatan kurang baik',
  'Kendala perjalanan / transportasi',
];

/// Menampilkan form pengajuan perubahan jadwal. [onSubmit] mengembalikan pesan error
/// (form tetap terbuka agar isian tidak hilang) atau null bila berhasil (form ditutup).
Future<void> showRescheduleSheet({
  required BuildContext context,
  required String itemName,
  required DateTime? currentDate,
  required TimeOfDay? currentStart,
  required TimeOfDay? currentEnd,
  int rejectedCount = 0,
  required Future<String?> Function(RescheduleRequest request) onSubmit,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => RescheduleSheet(
      itemName: itemName,
      currentDate: currentDate,
      currentStart: currentStart,
      currentEnd: currentEnd,
      rejectedCount: rejectedCount,
      onSubmit: onSubmit,
    ),
  );
}

class RescheduleSheet extends StatefulWidget {
  final String itemName;
  final DateTime? currentDate;
  final TimeOfDay? currentStart, currentEnd;
  final int rejectedCount;
  final Future<String?> Function(RescheduleRequest request) onSubmit;

  const RescheduleSheet({
    super.key,
    required this.itemName,
    required this.currentDate,
    required this.currentStart,
    required this.currentEnd,
    this.rejectedCount = 0,
    required this.onSubmit,
  });

  @override
  State<RescheduleSheet> createState() => _RescheduleSheetState();
}

class _RescheduleSheetState extends State<RescheduleSheet> {
  final _reasonCtrl = TextEditingController();
  late DateTime _date;
  late TimeOfDay _start;
  TimeOfDay? _end;
  bool _attempted = false, _submitting = false;
  String? _serverError;

  DateTime get _today => DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

  @override
  void initState() {
    super.initState();
    final cur = widget.currentDate;
    _date = (cur == null || cur.isBefore(_today)) ? _today : cur;
    _start = widget.currentStart ?? const TimeOfDay(hour: 18, minute: 0);
    _end = widget.currentEnd;
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  RescheduleErrors get _errors => !_attempted
      ? const RescheduleErrors()
      : validateReschedule(
          date: _date,
          start: _start,
          end: _end,
          reason: _reasonCtrl.text,
          now: DateTime.now(),
          currentDate: widget.currentDate,
          currentStart: widget.currentStart,
          currentEnd: widget.currentEnd,
        );

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isBefore(_today) ? _today : _date,
      firstDate: _today,
      lastDate: _today.add(const Duration(days: kRescheduleMaxDaysAhead)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<TimeOfDay?> _pickTime(TimeOfDay initial) => showTimePicker(
        context: context,
        initialTime: initial,
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        ),
      );

  Future<void> _pickStart() async {
    final picked = await _pickTime(_start);
    if (picked == null) return;
    setState(() {
      final end = _end;
      // Pertahankan durasi: geser jam selesai bila jam mulai baru melewatinya.
      if (end != null && minutesOf(end) <= minutesOf(picked)) {
        final shifted = minutesOf(picked) + 90;
        _end = shifted >= 24 * 60 ? const TimeOfDay(hour: 23, minute: 59) : TimeOfDay(hour: shifted ~/ 60, minute: shifted % 60);
      }
      _start = picked;
    });
  }

  Future<void> _pickEnd() async {
    final picked = await _pickTime(_end ?? TimeOfDay(hour: (_start.hour + 1) % 24, minute: _start.minute));
    if (picked != null) setState(() => _end = picked);
  }

  Future<void> _submit() async {
    setState(() {
      _attempted = true;
      _serverError = null;
    });
    if (_errors.hasAny) return;
    setState(() => _submitting = true);
    final error = await widget.onSubmit(RescheduleRequest(
      newDate: formatIsoDate(_date),
      newTimeStart: formatHm(_start),
      newTimeEnd: _end == null ? null : formatHm(_end!),
      reason: _reasonCtrl.text.trim(),
    ));
    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context);
    } else {
      setState(() {
        _submitting = false;
        _serverError = error;
      });
    }
  }

  bool get _closed => widget.rejectedCount >= kRescheduleMaxRejections;

  @override
  Widget build(BuildContext context) {
    final e = _errors;
    if (_closed) return _closedView();
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 14),
            _header(),
            const SizedBox(height: 14),
            RescheduleInfoCard(title: 'Jadwal saat ini', text: rescheduleScheduleText(widget.currentDate, widget.currentStart, widget.currentEnd)),
            if (widget.rejectedCount > 0) ...[
              const SizedBox(height: 10),
              RescheduleInfoCard(
                highlight: true,
                title: 'Perhatian',
                text: 'Pengajuan sebelumnya ditolak ${widget.rejectedCount}x. Sisa kesempatan: ${kRescheduleMaxRejections - widget.rejectedCount}. Bila ditolak lagi, ubah jam ditutup.',
              ),
            ],
            const SizedBox(height: 18),
            rescheduleLabel('Tanggal baru'),
            _dateChips(),
            const SizedBox(height: 8),
            ReschedulePickerField(icon: Icons.calendar_today_rounded, text: formatLongDate(_date), error: e.date, onTap: _pickDate),
            const SizedBox(height: 16),
            _timeRow(e),
            const SizedBox(height: 16),
            rescheduleLabel('Alasan perubahan'),
            _reasonSection(e.reason),
            if (_changed) ...[const SizedBox(height: 14), RescheduleInfoCard(highlight: true, title: 'Yang akan diajukan ke Umat', text: rescheduleScheduleText(_date, _start, _end))],
            const SizedBox(height: 16),
            rescheduleBanner(e.general ?? _serverError),
            if (_attempted && e.hasAny && e.general == null) rescheduleBanner('Periksa kembali isian yang ditandai merah.'),
            const SizedBox(height: 8),
            _actions(),
          ],
        ),
      ),
    );
  }

  Widget _closedView() => Container(
        padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 20),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 18),
            const Icon(Icons.lock_clock_rounded, size: 44, color: kRescheduleMuted),
            const SizedBox(height: 10),
            const Text('Ubah Jam Sudah Ditutup', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: kRescheduleInk)),
            const SizedBox(height: 8),
            Text(
              'Pengajuan ubah jam${widget.itemName.isNotEmpty ? ' untuk ${widget.itemName}' : ''} telah ditolak ${widget.rejectedCount} kali, sehingga jadwal tidak dapat diubah lagi. '
              'Pelayanan dilaksanakan sesuai jadwal terakhir. Bila ada kendala, hubungi Umat melalui grup chat.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: kRescheduleMuted, height: 1.45),
            ),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Mengerti'))),
          ],
        ),
      );

  Widget _header() => Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(color: kRescheduleAmber.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: const Icon(Icons.edit_calendar_rounded, color: kRescheduleAmber, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Ajukan Perubahan Jadwal', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: kRescheduleInk)),
                if (widget.itemName.isNotEmpty)
                  Text(widget.itemName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: kRescheduleMuted)),
              ],
            ),
          ),
        ],
      );

  Widget _dateChips() {
    final options = {'Hari ini': 0, 'Besok': 1, 'Lusa': 2};
    return Wrap(
      spacing: 8,
      children: options.entries.map((o) {
        final target = _today.add(Duration(days: o.value));
        return rescheduleChip(o.key, selected: _date == target, onTap: () => setState(() => _date = target));
      }).toList(),
    );
  }

  Widget _timeRow(RescheduleErrors e) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              rescheduleLabel('Jam mulai'),
              ReschedulePickerField(icon: Icons.access_time_rounded, text: formatHm(_start), error: e.start, onTap: _pickStart),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              rescheduleLabel('Jam selesai (opsional)'),
              ReschedulePickerField(
                icon: Icons.access_time_rounded,
                text: _end == null ? 'Belum diatur' : formatHm(_end!),
                error: e.end,
                onTap: _pickEnd,
                onClear: _end == null ? null : () => setState(() => _end = null),
              ),
            ]),
          ),
        ],
      );

  Widget _reasonSection(String? error) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            children: _reasonChips.map((r) => rescheduleChip(r, selected: _reasonCtrl.text == r, onTap: () => setState(() => _reasonCtrl.text = r))).toList(),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _reasonCtrl,
            maxLines: 3,
            maxLength: kRescheduleReasonMax,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Jelaskan singkat agar Umat memahami alasan perubahan...',
              hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: error != null ? Colors.red : Colors.grey.shade300, width: error != null ? 1.6 : 1)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: error != null ? Colors.red : kRescheduleAmber, width: 1.8)),
            ),
          ),
          if (error != null) rescheduleErrorText(error),
        ],
      );

  bool get _changed {
    final c = widget.currentDate;
    return c == null || c != _date || widget.currentStart != _start || widget.currentEnd != _end;
  }

  Widget _actions() => Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: kRescheduleAmber,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _submitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                  : const Text('Kirim Pengajuan ke Umat', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ),
          TextButton(onPressed: _submitting ? null : () => Navigator.pop(context), child: const Text('Batal')),
        ],
      );
}
