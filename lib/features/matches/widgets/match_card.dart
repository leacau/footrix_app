// import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../models/match_model.dart';
import '../models/prediction_model.dart';

class MatchCard extends StatefulWidget {
  final FootballMatch match;
  final Prediction? existingPrediction;

  const MatchCard({super.key, required this.match, this.existingPrediction});

  @override
  State<MatchCard> createState() => _MatchCardState();
}

class _MatchCardState extends State<MatchCard> {
  final _homeCtrl = TextEditingController();
  final _awayCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPrediction();
  }

  @override
  void didUpdateWidget(covariant MatchCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.existingPrediction?.id != widget.existingPrediction?.id) {
      _loadPrediction();
    }
  }

  void _loadPrediction() {
    if (widget.existingPrediction != null) {
      // ✅ Solo actualizar si los valores son distintos (evita parpadeo)
      if (_homeCtrl.text != widget.existingPrediction!.homeGuess.toString()) {
        _homeCtrl.text = widget.existingPrediction!.homeGuess.toString();
      }
      if (_awayCtrl.text != widget.existingPrediction!.awayGuess.toString()) {
        _awayCtrl.text = widget.existingPrediction!.awayGuess.toString();
      }
    }
  }

  @override
  void dispose() {
    _homeCtrl.dispose();
    _awayCtrl.dispose();
    super.dispose();
  }

  bool _canEdit() {
    final now = DateTime.now();

    // ✅ Usar lockHoursBefore del match, con fallback a 12 si no existe
    final lockHours = widget.match.lockHoursBefore ?? 12;
    final lockTime = widget.match.kickoff.subtract(Duration(hours: lockHours));

    return now.isBefore(lockTime);
  }

  // ✅ FUNCIÓN AUXILIAR: Muestra SnackBar sin usar context después de await
  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return; // Usamos 'mounted' del State, no context
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade400 : null,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _savePrediction() async {
    if (_homeCtrl.text.isEmpty || _awayCtrl.text.isEmpty) return;

    // Validación cliente-side de 12hs (síncrona, sin async gap)
    if (!_canEdit() && widget.existingPrediction != null) {
      _showMessage('🔒 Cerrado 12hs antes');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showMessage('❌ No autenticado', isError: true);
        return;
      }

      // ✅ Usamos predictionId para evitar warning de "unused"
      // final predictionId = '${user.uid}_${widget.match.id}';

      // =====================================================
      // OPCIÓN A: Escritura directa a Firestore (Comentada)
      // =====================================================
      /*
      await FirebaseFirestore.instance
          .collection('predictions')
          .doc(predictionId)
          .set({
            'userId': user.uid,
            'matchId': widget.match.id,
            'homeGuess': int.parse(_homeCtrl.text),
            'awayGuess': int.parse(_awayCtrl.text),
            'status': 'pending',
            'submittedAt': FieldValue.serverTimestamp(),
            'kickoffTime': widget.match.kickoff.millisecondsSinceEpoch,
          }, SetOptions(merge: true));
      
      _showMessage('✅ Guardada');
      if (mounted) setState(() => _loadPrediction());
      */

      // =====================================================
      // OPCIÓN B: Usar Firebase Functions (ACTIVA)
      // =====================================================
      final result = await FirebaseFunctions.instance
          .httpsCallable('validatePredictionEdit')
          .call({
            'matchId': widget.match.id,
            'homeGuess': int.parse(_homeCtrl.text),
            'awayGuess': int.parse(_awayCtrl.text),
          });

      // ✅ Llamamos a función auxiliar que verifica 'mounted' internamente
      if (result.data['success'] == true) {
        _showMessage('✅ Guardada');
      } else {
        _showMessage('❌ ${result.data['error']}', isError: true);
      }

      // ✅ Actualizar UI solo si el widget sigue montado
      if (mounted) {
        setState(() => _loadPrediction());
      }
    } catch (e) {
      // ✅ Manejo de errores con función auxiliar
      _showMessage('❌ $e', isError: true);
    } finally {
      // ✅ Resetear loading solo si el widget sigue montado
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLocked = widget.match.isLocked || !_canEdit();
    final isFinished = widget.match.status == MatchStatus.finished;
    final hasPrediction = widget.existingPrediction != null;

    return Card(
      key: ValueKey(
        '${widget.match.id}_${widget.existingPrediction?.homeGuess}_${widget.existingPrediction?.awayGuess}',
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // Encabezado
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.match.phase,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
                if (isFinished)
                  const Text(
                    'FINALIZADO',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                if (!isFinished && !isLocked)
                  Text(
                    _timeLeft(widget.match.kickoff),
                    style: const TextStyle(fontSize: 10, color: Colors.green),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // FILA 1: Equipos + Inputs/Resultado
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    widget.match.homeTeam,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _buildPredictionArea(
                    isFinished,
                    isLocked,
                    hasPrediction,
                  ),
                ),
                Expanded(
                  child: Text(
                    widget.match.awayTeam,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),

            // FILA 2: Resultado real (solo si finalizó)
            if (isFinished) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.emoji_events,
                      color: Colors.amber,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Resultado: ${widget.match.homeScore ?? 0} - ${widget.match.awayScore ?? 0}',
                      style: TextStyle(
                        color: Colors.green.shade800,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPredictionArea(
    bool isFinished,
    bool isLocked,
    bool hasPrediction,
  ) {
    // ✅ Siempre mostrar la predicción del usuario (si existe)
    if (hasPrediction) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Fila 1: Predicción del usuario
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _homeCtrl.text,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.blue,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text('-'),
              ),
              Text(
                _awayCtrl.text,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.blue,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (isLocked) ...[
                const SizedBox(width: 4),
                const Icon(Icons.lock, size: 12, color: Colors.grey),
              ],
            ],
          ),
        ],
      );
    }

    // Si no hay predicción y terminó: mostrar solo resultado real
    if (isFinished) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${widget.match.homeScore ?? 0}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text('-'),
          ),
          Text(
            '${widget.match.awayScore ?? 0}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      );
    }

    // Si no hay predicción y no terminó: mostrar inputs o candado
    if (!isLocked) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _inputBox(_homeCtrl),
          const Text('-'),
          _inputBox(_awayCtrl),
          IconButton(
            icon: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_circle, color: Colors.blue),
            iconSize: 20,
            padding: EdgeInsets.zero,
            onPressed: _isLoading ? null : _savePrediction,
          ),
        ],
      );
    }

    // Bloqueado sin predicción
    return const Icon(Icons.lock_outline, color: Colors.red, size: 20);
  }

  Widget _inputBox(TextEditingController ctrl) {
    return SizedBox(
      width: 35,
      child: TextField(
        controller: ctrl,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.zero,
          border: InputBorder.none,
        ),
      ),
    );
  }

  String _timeLeft(DateTime kickoff) {
    final diff = kickoff.difference(DateTime.now());
    if (diff.inMinutes < 0) return 'En juego';
    if (diff.inHours < 24) {
      return 'Hoy ${kickoff.hour}:${kickoff.minute.toString().padLeft(2, '0')}';
    }
    return '${kickoff.day}/${kickoff.month}';
  }
}
