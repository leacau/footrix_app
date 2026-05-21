import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/match_model.dart';

class PredictionForm extends StatefulWidget {
  final FootballMatch match;
  const PredictionForm({super.key, required this.match});

  @override
  State<PredictionForm> createState() => _PredictionFormState();
}

class _PredictionFormState extends State<PredictionForm> {
  final _homeCtrl = TextEditingController();
  final _awayCtrl = TextEditingController();
  bool _loading = false;

  Future<void> _submit() async {
    if (_homeCtrl.text.isEmpty || _awayCtrl.text.isEmpty) return;
    setState(() => _loading = true);
    try {
      await FirebaseFunctions.instance.httpsCallable('validatePredictionEdit').call({
        'matchId': widget.match.id,
        'homeGuess': int.parse(_homeCtrl.text),
        'awayGuess': int.parse(_awayCtrl.text),
      });

      // ✅ CORRECCIÓN: bloque if con llaves
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      // ✅ CORRECCIÓN: bloque if con llaves
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      // ✅ CORRECCIÓN: bloque if con llaves
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.match.isLocked) {
      return const Text('🔒 Partido bloqueado');
    }
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _homeCtrl,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(labelText: 'Local'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: _awayCtrl,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(labelText: 'Visita'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const CircularProgressIndicator()
              : const Text('Enviar Predicción'),
        ),
      ],
    );
  }
}
