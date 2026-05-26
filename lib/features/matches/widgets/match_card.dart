import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
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
      final home = widget.existingPrediction!.homeGuess.toString();
      final away = widget.existingPrediction!.awayGuess.toString();
      if (_homeCtrl.text != home) _homeCtrl.text = home;
      if (_awayCtrl.text != away) _awayCtrl.text = away;
    }
  }

  @override
  void dispose() {
    _homeCtrl.dispose();
    _awayCtrl.dispose();
    super.dispose();
  }

  bool _canEdit() {
    final kickoff = widget.match.kickoff;
    if (kickoff == null) return true;
    final lockHours = widget.match.lockHoursBefore ?? 12;
    return DateTime.now().isBefore(
      kickoff.subtract(Duration(hours: lockHours)),
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade400 : null,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _savePrediction() async {
    final l10n = AppLocalizations.of(context)!;
    if (_homeCtrl.text.isEmpty || _awayCtrl.text.isEmpty) return;

    if (!_canEdit() && widget.existingPrediction != null) {
      _showMessage(l10n.closedBefore);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showMessage(l10n.notAuthenticated, isError: true);
        return;
      }

      final result = await FirebaseFunctions.instance
          .httpsCallable('validatePredictionEdit')
          .call({
            'matchId': widget.match.id,
            'homeGuess': int.parse(_homeCtrl.text),
            'awayGuess': int.parse(_awayCtrl.text),
          });

      if (result.data['success'] == true) {
        _showMessage(l10n.saved);
      } else {
        _showMessage('${l10n.error}: ${result.data['error']}', isError: true);
      }

      if (mounted) setState(() => _loadPrediction());
    } catch (e) {
      _showMessage('${l10n.error}: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.match.phase,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
                if (isFinished)
                  Text(
                    l10n.finished,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                if (!isFinished && !isLocked)
                  Text(
                    _timeLeft(l10n),
                    style: const TextStyle(fontSize: 10, color: Colors.green),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _scoreboardRow(),
            if (!isFinished || hasPrediction) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: _buildPredictionArea(l10n, isLocked, hasPrediction),
              ),
            ],
            if (_venueLabel() != null) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.stadium, size: 14, color: Colors.grey.shade700),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      _venueLabel()!,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ],
            if (widget.match.kickoff != null) ...[
              const SizedBox(height: 8),
              Text(
                _kickoffLabel(l10n),
                style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPredictionArea(
    AppLocalizations l10n,
    bool isLocked,
    bool hasPrediction,
  ) {
    if (hasPrediction) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${l10n.yourPrediction} ',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
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
      );
    }

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

    return const Icon(Icons.lock_outline, color: Colors.red, size: 20);
  }

  Widget _scoreboardRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: _teamName(widget.match.homeTeam, TextAlign.right)),
        const SizedBox(width: 8),
        _teamLogo(widget.match.homeTeamLogo),
        const SizedBox(width: 10),
        Container(
          width: 76,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: widget.match.status == MatchStatus.live
                ? Colors.red.shade50
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: widget.match.status == MatchStatus.live
                ? Border.all(color: Colors.red.shade200)
                : null,
          ),
          child: Text(
            _matchCenterLabel(),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: widget.match.status == MatchStatus.live ? 13 : 16,
              color: widget.match.status == MatchStatus.live
                  ? Colors.red.shade700
                  : Colors.black87,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 10),
        _teamLogo(widget.match.awayTeamLogo),
        const SizedBox(width: 8),
        Expanded(child: _teamName(widget.match.awayTeam, TextAlign.left)),
      ],
    );
  }

  Widget _teamName(String name, TextAlign align) {
    return Text(
      name,
      textAlign: align,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontWeight: FontWeight.bold),
    );
  }

  String _matchCenterLabel() {
    final hasScore =
        widget.match.homeScore != null && widget.match.awayScore != null;
    if (hasScore) {
      return '${widget.match.homeScore} - ${widget.match.awayScore}';
    }
    final kickoff = widget.match.kickoff;
    if (kickoff == null) return '-';
    return DateFormat('HH:mm').format(kickoff.toLocal());
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

  Widget _teamLogo(String? logoUrl) {
    final hasLogo = logoUrl != null && logoUrl.trim().isNotEmpty;
    return SizedBox(
      width: 28,
      height: 28,
      child: hasLogo
          ? Image.network(
              logoUrl,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.sports_soccer, size: 22, color: Colors.grey),
            )
          : const Icon(Icons.sports_soccer, size: 22, color: Colors.grey),
    );
  }

  String _timeLeft(AppLocalizations l10n) {
    final kickoff = widget.match.kickoff;
    if (kickoff == null) return l10n.dateTba;

    final diff = kickoff.difference(DateTime.now());
    if (diff.inMinutes < 0) return l10n.inPlay;
    if (diff.inHours < 24) {
      return l10n.todayAt(DateFormat('HH:mm').format(kickoff.toLocal()));
    }
    return DateFormat('d/M HH:mm').format(kickoff.toLocal());
  }

  String _kickoffLabel(AppLocalizations l10n) {
    final kickoff = widget.match.kickoff;
    if (kickoff == null) return l10n.dateToBeConfirmed;
    final local = kickoff.toLocal();
    final formatted = DateFormat('EEEE d/MM/y HH:mm').format(local);
    return l10n.localDeviceTime(formatted, _timezoneLabel(local));
  }

  String _timezoneLabel(DateTime local) {
    final offset = local.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final absOffset = offset.abs();
    final hours = absOffset.inHours.toString().padLeft(2, '0');
    final minutes = (absOffset.inMinutes % 60).toString().padLeft(2, '0');
    final utcOffset = 'UTC$sign$hours:$minutes';
    final zoneName = local.timeZoneName.trim();
    if (zoneName.isEmpty || zoneName == utcOffset) {
      return utcOffset;
    }
    return '$zoneName, $utcOffset';
  }

  String? _venueLabel() {
    final venue = widget.match.venue?.trim();
    final city = widget.match.venueCity?.trim();
    if ((venue == null || venue.isEmpty) && (city == null || city.isEmpty)) {
      return null;
    }
    if (venue == null || venue.isEmpty) return city;
    if (city == null || city.isEmpty) return venue;
    return '$venue, $city';
  }
}
