import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/enums.dart';
import '../providers/game_provider.dart';

class NewGameScreen extends ConsumerStatefulWidget {
  const NewGameScreen({super.key});

  @override
  ConsumerState<NewGameScreen> createState() => _NewGameScreenState();
}

class _NewGameScreenState extends ConsumerState<NewGameScreen> {
  final _nameController = TextEditingController(text: 'Commander');
  DifficultyLevel _selectedDifficulty = DifficultyLevel.normal;
  int _pilot = 1;
  int _fighter = 1;
  int _trader = 1;
  int _engineer = 1;

  int get _totalPoints => _pilot + _fighter + _trader + _engineer;
  int get _maxPoints => _selectedDifficulty.startingSkillPoints;
  int get _remaining => _maxPoints - _totalPoints;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _resetSkills() {
    setState(() {
      _pilot = 1;
      _fighter = 1;
      _trader = 1;
      _engineer = 1;
    });
  }

  void _adjustSkill(String skill, int delta) {
    setState(() {
      switch (skill) {
        case 'pilot':
          final v = (_pilot + delta).clamp(1, 10);
          if (delta > 0 && _remaining <= 0) return;
          _pilot = v;
        case 'fighter':
          final v = (_fighter + delta).clamp(1, 10);
          if (delta > 0 && _remaining <= 0) return;
          _fighter = v;
        case 'trader':
          final v = (_trader + delta).clamp(1, 10);
          if (delta > 0 && _remaining <= 0) return;
          _trader = v;
        case 'engineer':
          final v = (_engineer + delta).clamp(1, 10);
          if (delta > 0 && _remaining <= 0) return;
          _engineer = v;
      }
    });
  }

  void _startGame() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a commander name.')),
      );
      return;
    }

    // Distribute remaining points to pilot.
    final finalPilot = _pilot + _remaining;

    final notifier = ref.read(gameProvider.notifier);
    notifier.newGame(name, _selectedDifficulty);
    // Override with user's custom skill distribution.
    notifier.applySkills(name, finalPilot, _fighter, _trader, _engineer);

    context.go('/game');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('NEW COMMANDER'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Commander name
                _SectionHeader('COMMANDER IDENTITY'),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Commander Name',
                    hintText: 'Enter your name',
                  ),
                  maxLength: 20,
                  style: TextStyle(color: cs.onSurface, fontSize: 16),
                ),
                const SizedBox(height: 32),

                // Difficulty selection
                _SectionHeader('DIFFICULTY'),
                const SizedBox(height: 12),
                ...DifficultyLevel.values.map((d) => _DifficultyCard(
                      difficulty: d,
                      isSelected: _selectedDifficulty == d,
                      onTap: () {
                        setState(() {
                          _selectedDifficulty = d;
                          _resetSkills();
                        });
                      },
                    )),
                const SizedBox(height: 32),

                // Skill allocation
                _SectionHeader('SKILL ALLOCATION'),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Points remaining:', style: tt.bodyMedium),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: _remaining > 0
                            ? cs.secondary.withOpacity(0.2)
                            : cs.surface,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: _remaining > 0 ? cs.secondary : cs.primary,
                        ),
                      ),
                      child: Text(
                        '$_remaining',
                        style: tt.titleMedium?.copyWith(
                          color: _remaining > 0 ? cs.secondary : cs.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SkillRow(
                  label: 'Pilot',
                  description: 'Affects warp success & evasion',
                  value: _pilot,
                  onDecrease: () => _adjustSkill('pilot', -1),
                  onIncrease: () => _adjustSkill('pilot', 1),
                  canIncrease: _remaining > 0,
                  canDecrease: _pilot > 1,
                ),
                const SizedBox(height: 12),
                _SkillRow(
                  label: 'Fighter',
                  description: 'Combat damage & hit chance',
                  value: _fighter,
                  onDecrease: () => _adjustSkill('fighter', -1),
                  onIncrease: () => _adjustSkill('fighter', 1),
                  canIncrease: _remaining > 0,
                  canDecrease: _fighter > 1,
                ),
                const SizedBox(height: 12),
                _SkillRow(
                  label: 'Trader',
                  description: 'Buy low, sell high',
                  value: _trader,
                  onDecrease: () => _adjustSkill('trader', -1),
                  onIncrease: () => _adjustSkill('trader', 1),
                  canIncrease: _remaining > 0,
                  canDecrease: _trader > 1,
                ),
                const SizedBox(height: 12),
                _SkillRow(
                  label: 'Engineer',
                  description: 'Repair efficiency & auto-repair',
                  value: _engineer,
                  onDecrease: () => _adjustSkill('engineer', -1),
                  onIncrease: () => _adjustSkill('engineer', 1),
                  canIncrease: _remaining > 0,
                  canDecrease: _engineer > 1,
                ),
                const SizedBox(height: 40),

                // Starting info summary
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: cs.primary.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('STARTING CONDITIONS',
                          style: tt.labelLarge?.copyWith(fontSize: 11)),
                      const SizedBox(height: 12),
                      _InfoRow('Ship', 'Gnat (starter)'),
                      _InfoRow('Credits', '1,000 cr'),
                      if (_selectedDifficulty.startingDebt > 0)
                        _InfoRow('Debt',
                            '${_selectedDifficulty.startingDebt} cr'),
                      _InfoRow('Location', 'Sol (Democracy, Tech 7)'),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Launch button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _startGame,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('LAUNCH INTO SPACE'),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            color: cs.primary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.5,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 1,
            color: cs.primary.withOpacity(0.2),
          ),
        ),
      ],
    );
  }
}

class _DifficultyCard extends StatelessWidget {
  final DifficultyLevel difficulty;
  final bool isSelected;
  final VoidCallback onTap;

  const _DifficultyCard({
    required this.difficulty,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? cs.primary.withOpacity(0.12) : cs.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? cs.primary : const Color(0xFF1e2d42),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? cs.primary : cs.onSurface.withOpacity(0.3),
                  width: 2,
                ),
                color: isSelected ? cs.primary : Colors.transparent,
              ),
              child: isSelected
                  ? Icon(Icons.check,
                      size: 12,
                      color: cs.background)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    difficulty.displayName.toUpperCase(),
                    style: tt.titleSmall?.copyWith(
                      color: isSelected ? cs.primary : cs.onSurface,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    difficulty.description,
                    style: tt.bodySmall,
                  ),
                ],
              ),
            ),
            Text(
              '${difficulty.startingSkillPoints} pts',
              style: tt.labelMedium?.copyWith(
                color: isSelected ? cs.secondary : cs.onSurface.withOpacity(0.5),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkillRow extends StatelessWidget {
  final String label;
  final String description;
  final int value;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final bool canIncrease;
  final bool canDecrease;

  const _SkillRow({
    required this.label,
    required this.description,
    required this.value,
    required this.onDecrease,
    required this.onIncrease,
    required this.canIncrease,
    required this.canDecrease,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1e2d42)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: tt.titleSmall),
                Text(description, style: tt.bodySmall),
              ],
            ),
          ),
          IconButton(
            onPressed: canDecrease ? onDecrease : null,
            icon: const Icon(Icons.remove),
            iconSize: 18,
            style: IconButton.styleFrom(
              foregroundColor: cs.primary,
              disabledForegroundColor:
                  cs.onSurface.withOpacity(0.2),
            ),
          ),
          SizedBox(
            width: 32,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: tt.titleMedium?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            onPressed: canIncrease ? onIncrease : null,
            icon: const Icon(Icons.add),
            iconSize: 18,
            style: IconButton.styleFrom(
              foregroundColor: cs.primary,
              disabledForegroundColor:
                  cs.onSurface.withOpacity(0.2),
            ),
          ),
          // Skill bar
          const SizedBox(width: 8),
          SizedBox(
            width: 60,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: List.generate(
                    10,
                    (i) => Container(
                      margin: const EdgeInsets.only(left: 2),
                      width: 4,
                      height: 12,
                      decoration: BoxDecoration(
                        color: i < value
                            ? cs.primary
                            : cs.onSurface.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: tt.bodyMedium),
          Text(value, style: tt.bodyMedium?.copyWith(color: cs.primary)),
        ],
      ),
    );
  }
}
