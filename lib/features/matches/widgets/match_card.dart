import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
    if (widget.existingPrediction != null) {
      _homeCtrl.text = widget.existingPrediction!.homeGuess.toString();
      _awayCtrl.text = widget.existingPrediction!.awayGuess.toString();
    }
  }

  @override
  void dispose() {
    _homeCtrl.dispose();
    _awayCtrl.dispose();
    super.dispose();
  }

  Future<void> _savePrediction() async {
    if (_homeCtrl.text.isEmpty || _awayCtrl.text.isEmpty) {
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return;
      }

      final predictionId = '${user.uid}_${widget.match.id}';

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
          }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Guardada'),
            duration: Duration(seconds: 1),
          ),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('❌ $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLocked = widget.match.isLocked;
    final isFinished = widget.match.status == MatchStatus.finished;
    final hasPrediction = widget.existingPrediction != null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
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
                  child: _buildScoreArea(isFinished, isLocked, hasPrediction),
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
          ],
        ),
      ),
    );
  }

  Widget _buildScoreArea(bool isFinished, bool isLocked, bool hasPrediction) {
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

    if (hasPrediction) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _homeCtrl.text,
            style: const TextStyle(fontSize: 16, color: Colors.blue),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text('-'),
          ),
          Text(
            _awayCtrl.text,
            style: const TextStyle(fontSize: 16, color: Colors.blue),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.lock, size: 12, color: Colors.grey),
        ],
      );
    }

    if (isLocked && !hasPrediction) {
      return const Icon(Icons.lock_outline, color: Colors.red, size: 20);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 35,
          child: TextField(
            controller: _homeCtrl,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
            ),
          ),
        ),
        const Text('-'),
        SizedBox(
          width: 35,
          child: TextField(
            controller: _awayCtrl,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
            ),
          ),
        ),
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

  String _timeLeft(DateTime kickoff) {
    final diff = kickoff.difference(DateTime.now());
    if (diff.inMinutes < 0) {
      return 'En juego';
    }
    if (diff.inHours < 24) {
      return 'Hoy ${kickoff.hour}:${kickoff.minute.toString().padLeft(2, '0')}';
    }
    return '${kickoff.day}/${kickoff.month}';
  }
}
