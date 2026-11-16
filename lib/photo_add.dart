// «Добавить по фото» (Android / ПК / веб): фото продуктов или чека → бесплатный сервер Нутрика (POST /vision,
// Workers AI) → английские названия → продукты нашей базы (тот же разбор, что у «Списком») → честный лист
// проверки: галочки, количество, место, срок. Ничего не добавляется без подтверждения; фото нигде не хранится.
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show TargetPlatform, compute, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as imglib;
import 'package:image_picker/image_picker.dart';

import 'food_icons.dart';
import 'l10n.dart';
import 'main.dart';

/// Фото → JPEG не больше 768 px по длинной стороне, с учётом поворота и без EXIF (геометка, модель телефона).
/// null — картинку не удалось прочитать.
Uint8List? prepareVisionJpeg(Uint8List bytes) {
  try {
    final src = imglib.decodeImage(bytes);
    if (src == null || src.width < 8 || src.height < 8) return null;
    var im = imglib.bakeOrientation(src);
    final long = max(im.width, im.height);
    if (long > 768) {
      im = im.width >= im.height
          ? imglib.copyResize(im, width: 768, interpolation: imglib.Interpolation.average)
          : imglib.copyResize(im, height: 768, interpolation: imglib.Interpolation.average);
    }
    im.exif = imglib.ExifData();
    return imglib.encodeJpg(im, quality: 82);
  } catch (_) {
    return null;
  }
}

enum VisionFail { limit, unavailable, offline, badImage, camera }

class VisionItem {
  final String name;
  final int qty;
  final double confidence;
  const VisionItem(this.name, this.qty, this.confidence);
}

class VisionService {
  static Future<(List<VisionItem>, VisionFail?)> recognize(Uint8List jpeg, String mode) async {
    try {
      final res = await http
          .post(
            Uri.parse('${SmartAiService.serverUrl}/vision'),
            headers: {'content-type': 'application/json', 'x-nutrimate-client': clientTag},
            body: jsonEncode({'deviceId': await aiService.deviceId(), 'image': base64Encode(jpeg), 'mode': mode, 'language': appLang}),
          )
          .timeout(const Duration(seconds: 45));
      if (res.statusCode == 429) return (const <VisionItem>[], VisionFail.limit);
      if (res.statusCode == 400 || res.statusCode == 413) return (const <VisionItem>[], VisionFail.badImage);
      if (res.statusCode != 200) return (const <VisionItem>[], VisionFail.unavailable);
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      final raw = body is Map ? body['items'] : null;
      final items = <VisionItem>[];
      if (raw is List) {
        for (final it in raw) {
          if (it is! Map) continue;
          final name = '${it['name'] ?? ''}'.trim();
          if (name.isEmpty) continue;
          final q = (it['qty'] is num ? (it['qty'] as num).round() : 1).clamp(1, 99).toInt();
          final c = it['confidence'] is num ? (it['confidence'] as num).toDouble().clamp(0.0, 1.0) : 0.5;
          items.add(VisionItem(name, q, c));
        }
      }
      return (items, null);
    } on TimeoutException {
      return (const <VisionItem>[], VisionFail.unavailable);
    } catch (_) {
      return (const <VisionItem>[], VisionFail.offline);
    }
  }
}

/// Английское название от ИИ («Bananas», «Red Apple», «Whole Milk») → продукт базы (разбор как у «Списком»).
FoodItem? visionMatch(String name) {
  final w = QuickAddParse.words(name);
  if (w.isEmpty) return null;
  final f = QuickAddParse.match(w);
  if (f != null) return f;
  if (w.endsWith('es')) return QuickAddParse.match(w.substring(0, w.length - 2)) ?? QuickAddParse.match(w.substring(0, w.length - 1));
  if (w.endsWith('s')) return QuickAddParse.match(w.substring(0, w.length - 1));
  return null;
}

/// Кнопка 📷 на «Поиске» и в «Холодильнике».
Future<void> photoAddSheet(BuildContext ctx, AppState s) async {
  if (!s.smartAi) {
    final on = await showDialog<bool>(
      context: ctx,
      builder: (c) => AlertDialog(
        title: Text('📷 ${tr('Add by photo')}'),
        content: Text(tr('Photo recognition works with Smart Nutrik (online AI). Turn it on?')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Cancel'))),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: burgundy), onPressed: () => Navigator.pop(c, true), child: Text(tr('Turn on'))),
        ],
      ),
    );
    if (on != true || !ctx.mounted) return;
    s.setSmartAi(true);
  }
  if (!s.photoNoticeSeen) {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (c) => AlertDialog(
        title: Text('🔒 ${tr('About photos')}'),
        content: Text(tr("Your photo is sent to Smart Nutrik only to recognize the products and is not stored anywhere. Recognition can make mistakes — you check everything before it's added.")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Cancel'))),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: burgundy), onPressed: () => Navigator.pop(c, true), child: Text(tr('Got it'))),
        ],
      ),
    );
    if (ok != true || !ctx.mounted) return;
    s.markPhotoNoticeSeen();
  }
  if (!ctx.mounted) return;
  await showModalBottomSheet(
    context: ctx,
    backgroundColor: cream,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => PhotoAddSheet(state: s, host: ctx),
  );
}

class _Row {
  final FoodItem food;
  final String seen;
  int qty;
  double confidence;
  Storage place;
  bool on;
  _Row(this.food, this.seen, this.qty, this.confidence) : place = defaultStorage(food), on = confidence >= 0.5;
}

enum _Phase { pick, busy, result, failed }

class PhotoAddSheet extends StatefulWidget {
  final AppState state;
  final BuildContext host;
  const PhotoAddSheet({super.key, required this.state, required this.host});
  @override
  State<PhotoAddSheet> createState() => _PhotoAddSheetState();
}

class _PhotoAddSheetState extends State<PhotoAddSheet> {
  String mode = 'food';
  _Phase phase = _Phase.pick;
  VisionFail? fail;
  final rows = <_Row>[];
  final unknown = <String>[];

  static bool get _hasCamera => !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> _pick(ImageSource src) async {
    XFile? x;
    try {
      x = await ImagePicker().pickImage(source: src, maxWidth: 1600, maxHeight: 1600, imageQuality: 90);
    } catch (_) {
      if (mounted) {
        setState(() {
          phase = _Phase.failed;
          fail = src == ImageSource.camera ? VisionFail.camera : VisionFail.badImage;
        });
      }
      return;
    }
    if (x == null || !mounted) return;
    setState(() => phase = _Phase.busy);
    Uint8List? jpeg;
    try {
      jpeg = await compute(prepareVisionJpeg, await x.readAsBytes());
    } catch (_) {
      jpeg = null;
    }
    if (!mounted) return;
    if (jpeg == null) {
      setState(() {
        phase = _Phase.failed;
        fail = VisionFail.badImage;
      });
      return;
    }
    final (items, f) = await VisionService.recognize(jpeg, mode);
    if (!mounted) return;
    rows.clear();
    unknown.clear();
    for (final it in items) {
      final food = visionMatch(it.name);
      if (food == null) {
        if (!unknown.contains(it.name)) unknown.add(it.name);
        continue;
      }
      _Row? same;
      for (final r in rows) {
        if (r.food == food) same = r;
      }
      if (same != null) {
        same.qty = (same.qty + it.qty).clamp(1, 99).toInt();
        same.confidence = max(same.confidence, it.confidence);
        same.on = same.confidence >= 0.5;
      } else {
        rows.add(_Row(food, it.name, it.qty, it.confidence));
      }
    }
    setState(() {
      fail = f;
      phase = f == null ? _Phase.result : _Phase.failed;
    });
  }

  void _searchManually() {
    Navigator.pop(context);
    searchRequest.value = unknown.isEmpty ? '' : unknown.first;
    tabRequest.value = 1;
  }

  void _addList() {
    Navigator.pop(context);
    if (widget.host.mounted) quickAddSheet(widget.host, widget.state);
  }

  void _add() {
    final chosen = [for (final r in rows) if (r.on) (r.food, r.qty, r.place)];
    final units = chosen.fold<int>(0, (a, e) => a + e.$2);
    widget.state.addPlaced(chosen);
    Navigator.pop(context);
    if (!widget.host.mounted) return;
    ScaffoldMessenger.of(widget.host)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: burgundy,
          content: Text(tr("{0} put away — I'll watch the dates 👀", [trp(units, 'product|products')])),
        ),
      );
  }

  static const _sub = TextStyle(fontSize: 12, color: Colors.black54);

  Widget _modePicker() => SegmentedButton<String>(
    style: SegmentedButton.styleFrom(selectedBackgroundColor: burgundy, selectedForegroundColor: Colors.white, foregroundColor: burgundy),
    showSelectedIcon: false,
    segments: [
      ButtonSegment(value: 'food', icon: const Icon(Icons.shopping_basket_outlined), label: Text(tr('Products'))),
      ButtonSegment(value: 'receipt', icon: const Icon(Icons.receipt_long_outlined), label: Text(tr('Receipt'))),
    ],
    selected: {mode},
    onSelectionChanged: (v) => setState(() => mode = v.first),
  );

  Widget _pickButtons() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (_hasCamera)
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: burgundy, padding: const EdgeInsets.symmetric(vertical: 14)),
          onPressed: () => _pick(ImageSource.camera),
          icon: const Icon(Icons.photo_camera),
          label: Text(tr('Take a photo')),
        ),
      if (_hasCamera) ...[
        const SizedBox(height: 8),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: burgundy, padding: const EdgeInsets.symmetric(vertical: 14)),
          onPressed: () => _pick(ImageSource.gallery),
          icon: const Icon(Icons.photo_library_outlined),
          label: Text(tr('Choose a photo')),
        ),
      ] else
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: burgundy, padding: const EdgeInsets.symmetric(vertical: 14)),
          onPressed: () => _pick(ImageSource.gallery),
          icon: const Icon(Icons.photo_library_outlined),
          label: Text(tr('Choose a photo')),
        ),
    ],
  );

  Widget _row(_Row r) {
    final hint = r.place == Storage.freezer ? tr('~3 months in the freezer') : tr('keeps ~{0}', [trp(r.food.shelf, 'day|days')]);
    return Opacity(
      opacity: r.on ? 1 : 0.5,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Checkbox(value: r.on, activeColor: burgundy, onChanged: (v) => setState(() => r.on = v == true)),
            FoodIcon(r.food, size: 30),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tn(r.food.name), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    r.confidence < 0.5 ? '“${r.seen}” · ${tr('not sure')}' : '“${r.seen}”',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _sub,
                  ),
                  PopupMenuButton<Storage>(
                    tooltip: tr('Place'),
                    initialValue: r.place,
                    onSelected: (v) => setState(() => r.place = v),
                    itemBuilder: (_) => [for (final st in Storage.values) PopupMenuItem(value: st, child: Text(storageLabel[st]!))],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: '${storageLabel[r.place]} ▾', style: const TextStyle(color: burgundy, fontWeight: FontWeight.w600)),
                            TextSpan(text: ' · $hint'),
                          ],
                        ),
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.remove_circle_outline, color: burgundy),
              onPressed: r.qty <= 1 ? null : () => setState(() => r.qty--),
            ),
            Text('×${r.qty}', style: const TextStyle(fontWeight: FontWeight.bold)),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.add_circle_outline, color: burgundy),
              onPressed: r.qty >= 99 ? null : () => setState(() => r.qty++),
            ),
          ],
        ),
      ),
    );
  }

  String _failText(VisionFail f) => switch (f) {
    VisionFail.limit => tr("Today's photo limit is used up — try again tomorrow or use Add a list."),
    VisionFail.offline => tr('No internet — photo recognition needs a connection. You can use Add a list.'),
    VisionFail.badImage => tr("I couldn't open this image. Try a JPEG or PNG photo."),
    VisionFail.camera => tr("Couldn't open the camera — allow camera access in Settings, or choose a photo."),
    VisionFail.unavailable => tr('Photo recognition is unavailable right now — try Add a list.'),
  };

  List<Widget> _body() {
    switch (phase) {
      case _Phase.pick:
        return [
          Text('📷 ${tr('Add by photo')}', style: titleStyle),
          const SizedBox(height: 6),
          Text(tr("Take a photo of your groceries or a receipt — I'll find the products, and you check them before anything is added."), style: _sub),
          const SizedBox(height: 14),
          Center(child: _modePicker()),
          const SizedBox(height: 16),
          _pickButtons(),
          const SizedBox(height: 8),
        ];
      case _Phase.busy:
        return [
          const SizedBox(height: 24),
          const Center(child: CircularProgressIndicator(color: burgundy)),
          const SizedBox(height: 16),
          Center(child: Text(tr('Looking at your photo…'), style: headStyle)),
          const SizedBox(height: 32),
        ];
      case _Phase.failed:
        return [
          const SizedBox(height: 8),
          const Center(child: Text('🙈', style: TextStyle(fontSize: 48))),
          const SizedBox(height: 8),
          Text(_failText(fail ?? VisionFail.unavailable), textAlign: TextAlign.center, style: const TextStyle(fontSize: 15)),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: burgundy, padding: const EdgeInsets.symmetric(vertical: 14)),
            onPressed: _addList,
            icon: const Icon(Icons.playlist_add),
            label: Text(tr('Add a list')),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: burgundy, padding: const EdgeInsets.symmetric(vertical: 14)),
            onPressed: () => setState(() => phase = _Phase.pick),
            icon: const Icon(Icons.refresh),
            label: Text(tr('Try another photo')),
          ),
          const SizedBox(height: 8),
        ];
      case _Phase.result:
        if (rows.isEmpty) {
          return [
            const SizedBox(height: 8),
            const Center(child: Text('🤔', style: TextStyle(fontSize: 48))),
            const SizedBox(height: 8),
            Text(tr("I couldn't find any food I know in this photo."), textAlign: TextAlign.center, style: const TextStyle(fontSize: 15)),
            if (unknown.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(tr('Also saw (not in my food base): {0}', [unknown.join(', ')]), textAlign: TextAlign.center, style: _sub),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: burgundy, padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: _searchManually,
              icon: const Icon(Icons.search),
              label: Text(tr('Search manually')),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: burgundy, padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: () => setState(() => phase = _Phase.pick),
              icon: const Icon(Icons.refresh),
              label: Text(tr('Try another photo')),
            ),
            const SizedBox(height: 8),
          ];
        }
        return [
          Text('📷 ${tr('Found')} · ${rows.length}', style: titleStyle),
          const SizedBox(height: 4),
          Text(tr("Check what I found — untick anything that's wrong."), style: _sub),
          const SizedBox(height: 8),
          for (final r in rows) _row(r),
          if (unknown.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(tr('Also saw (not in my food base): {0}', [unknown.join(', ')]), style: _sub),
          ],
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => phase = _Phase.pick),
              icon: const Icon(Icons.refresh, color: burgundy),
              label: Text(tr('Try another photo'), style: const TextStyle(color: burgundy)),
            ),
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final units = rows.where((r) => r.on).fold<int>(0, (a, r) => a + r.qty);
    final showAdd = phase == _Phase.result && rows.isNotEmpty;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                children: _body(),
              ),
            ),
            if (showAdd)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: burgundy, padding: const EdgeInsets.symmetric(vertical: 14)),
                    icon: const Icon(Icons.kitchen),
                    label: Text(units == 0 ? tr('Nothing to add yet') : tr('Add {0}', [trp(units, 'product|products')])),
                    onPressed: units == 0 ? null : _add,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
