import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/format.dart';
import '../../domain/enums.dart';
import '../../widgets/common.dart';
import '../../widgets/rank_badge.dart';
import '../../domain/ranks.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pages = PageController();
  final _name = TextEditingController();
  final _weight = TextEditingController();
  int _page = 0;
  Sex _sex = Sex.unspecified;
  WeightUnit _unit = WeightUnit.kg;
  int _goal = 3;
  bool _saving = false;

  @override
  void dispose() {
    _pages.dispose();
    _name.dispose();
    _weight.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < 2) {
      _pages.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    final raw = parseDecimal(_weight.text);
    double? kg;
    if (raw != null) {
      kg = fromDisplayWeight(raw, _unit);
      if (kg < 20 || kg > 400) {
        showMessage(
          context,
          'Indica um peso entre 20 e 400 kg, ou deixa em branco.',
        );
        return;
      }
    }
    setState(() => _saving = true);
    if (kg != null) {
      await ref.read(bodyWeightRepositoryProvider).log(DateTime.now(), kg);
    }
    await ref
        .read(settingsRepositoryProvider)
        .saveProfile(
          ref
              .read(currentProfileProvider)
              .copyWith(
                name: _name.text.trim(),
                sex: _sex,
                unit: _unit,
                weeklyGoal: _goal,
                onboarded: true,
              ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                children: [
                  for (var i = 0; i < 3; i++)
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: i <= _page
                              ? theme.colorScheme.primary
                              : theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (p) => setState(() => _page = p),
                children: [_welcome(theme), _about(theme), _goals(theme)],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Row(
                children: [
                  if (_page > 0)
                    TextButton(
                      onPressed: () => _pages.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                      ),
                      child: const Text('Voltar'),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _saving ? null : _next,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(160, 52),
                    ),
                    child: Text(_page == 2 ? 'Começar' : 'Continuar'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _welcome(ThemeData theme) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            gradient: Brand.emberGradient,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Brand.ember.withValues(alpha: 0.45),
                blurRadius: 40,
              ),
            ],
          ),
          child: const Icon(
            Icons.fitness_center_rounded,
            size: 64,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 28),
        Text('Overload', style: theme.textTheme.displaySmall),
        const SizedBox(height: 8),
        Text(
          'Regista treinos, bate recordes e sobe de rank em cada grupo muscular.',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final s in const [1.5, 3.5, 5.5, 7.5])
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: RankBadge(standing: RankStanding(score: s), size: 52),
              ),
          ],
        ),
        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              '100% local. Sem contas, sem servidores.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _about(ThemeData theme) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Text('Sobre ti', style: theme.textTheme.headlineMedium),
      const SizedBox(height: 6),
      Text(
        'Usado para personalizar a app e calcular os teus ranks.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 24),
      TextField(
        controller: _name,
        maxLength: 40,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(labelText: 'Nome (opcional)'),
      ),
      const SizedBox(height: 8),
      Text('Unidades', style: theme.textTheme.titleSmall),
      const SizedBox(height: 8),
      SegmentedButton<WeightUnit>(
        segments: const [
          ButtonSegment(value: WeightUnit.kg, label: Text('Quilogramas (kg)')),
          ButtonSegment(value: WeightUnit.lb, label: Text('Libras (lb)')),
        ],
        selected: {_unit},
        onSelectionChanged: (s) => setState(() => _unit = s.first),
      ),
      const SizedBox(height: 20),
      TextField(
        controller: _weight,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
        ],
        decoration: InputDecoration(
          labelText: 'Peso corporal',
          suffixText: _unit.label,
        ),
      ),
      const SizedBox(height: 20),
      Text('Padrões de força', style: theme.textTheme.titleSmall),
      const SizedBox(height: 8),
      SegmentedButton<Sex>(
        segments: [
          for (final s in Sex.values)
            ButtonSegment(value: s, label: Text(s.label)),
        ],
        selected: {_sex},
        onSelectionChanged: (s) => setState(() => _sex = s.first),
      ),
    ],
  );

  Widget _goals(ThemeData theme) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Objetivo semanal', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 6),
        Text(
          'Quantos dias queres treinar por semana? Cumpre o objetivo para manter a tua streak.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 40),
        Center(
          child: Text(
            '$_goal',
            style: theme.textTheme.displaySmall?.copyWith(
              fontSize: 88,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        Center(
          child: Text(
            _goal == 1 ? 'dia por semana' : 'dias por semana',
            style: theme.textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 24),
        Slider(
          value: _goal.toDouble(),
          min: 1,
          max: 7,
          divisions: 6,
          label: '$_goal',
          onChanged: (v) => setState(() => _goal = v.round()),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            switch (_goal) {
              1 || 2 => 'Um bom começo — consistência acima de tudo.',
              3 || 4 => 'O ponto ideal para a maioria das pessoas.',
              _ => 'Ambicioso! Não te esqueças de descansar.',
            },
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    ),
  );
}
