import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../domain/enums.dart';
import '../../domain/models.dart';
import 'active_workout.dart';

/// One editable set line: type · previous · weight · reps · done.
class SetRow extends StatelessWidget {
  const SetRow({
    super.key,
    required this.index,
    required this.set,
    required this.kind,
    required this.unit,
    required this.previous,
    required this.onWeight,
    required this.onReps,
    required this.onToggle,
    required this.onType,
    required this.onDelete,
    this.peekHint = false,
    this.comparison,
  });

  /// Number shown for working sets (warm-ups show "A").
  final int index;
  final ActiveSet set;
  final ExerciseKind kind;
  final WeightUnit unit;
  final SetEntry? previous;
  final ValueChanged<double?> onWeight;
  final ValueChanged<int?> onReps;
  final VoidCallback onToggle;
  final ValueChanged<SetType> onType;
  final VoidCallback onDelete;

  /// Plays a one-off nudge that reveals the swipe-to-delete action.
  final bool peekHint;

  /// For completed sets: 1 beat the previous set, 0 matched it, -1 fell short.
  final int? comparison;

  void _openOptions(BuildContext context) => showSetOptions(
    context,
    set: set,
    index: index,
    onType: onType,
    onDelete: onDelete,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final done = set.done;
    final showWeight = kind != ExerciseKind.duration;

    final row = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: done ? Brand.success.withValues(alpha: 0.10) : Colors.transparent,
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: _TypeButton(
              set: set,
              index: index,
              onTap: () => _openOptions(context),
            ),
          ),
          Expanded(
            flex: 3,
            child: _PreviousCell(
              text: previous == null ? '—' : formatSet(previous!, kind, unit),
              comparison: comparison,
            ),
          ),
          if (showWeight)
            Expanded(
              flex: 2,
              child: _NumberField(
                key: ValueKey('w-${set.id}'),
                value: set.weightKg == null
                    ? null
                    : toDisplayWeight(set.weightKg!, unit),
                hint: previous == null
                    ? switch (kind) {
                        ExerciseKind.bodyweight => '+0',
                        ExerciseKind.assisted => 'ajuda',
                        _ => unit.label,
                      }
                    : editableNumber(toDisplayWeight(previous!.weightKg, unit)),
                decimal: true,
                done: done,
                onChanged: (v) =>
                    onWeight(v == null ? null : fromDisplayWeight(v, unit)),
              ),
            ),
          Expanded(
            flex: 2,
            child: kind == ExerciseKind.duration
                ? _DurationField(
                    key: ValueKey('d-${set.id}'),
                    seconds: set.reps,
                    hint: previous?.reps,
                    done: done,
                    onChanged: onReps,
                  )
                : _NumberField(
                    key: ValueKey('r-${set.id}'),
                    value: set.reps?.toDouble(),
                    hint: previous?.reps.toString() ?? 'reps',
                    decimal: false,
                    done: done,
                    onChanged: (v) => onReps(v?.round()),
                  ),
          ),
          SizedBox(
            width: 48,
            child: IconButton(
              onPressed: onToggle,
              style: IconButton.styleFrom(
                backgroundColor: done
                    ? Brand.success
                    : scheme.surfaceContainerHighest,
                foregroundColor: done ? Colors.black : scheme.onSurfaceVariant,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                minimumSize: const Size(38, 34),
                fixedSize: const Size(38, 34),
              ),
              icon: const Icon(Icons.check_rounded, size: 20),
            ),
          ),
        ],
      ),
    );

    final deleteBackground = Container(
      color: scheme.error,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      child: Icon(Icons.delete_outline, color: scheme.onError),
    );

    return Dismissible(
      key: ValueKey('dismiss-${set.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: deleteBackground,
      child: GestureDetector(
        onLongPress: () {
          HapticFeedback.selectionClick();
          _openOptions(context);
        },
        child: peekHint
            ? _SwipePeek(
                background: deleteBackground,
                child: ColoredBox(color: scheme.surfaceContainer, child: row),
              )
            : row,
      ),
    );
  }
}

/// The "previous" value; once the set is done it shows whether it was
/// beaten (↑), matched (=) or not reached (↓).
class _PreviousCell extends StatelessWidget {
  const _PreviousCell({required this.text, required this.comparison});

  final String text;
  final int? comparison;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (icon, color, tooltip) = switch (comparison) {
      1 => (
        Icons.arrow_upward_rounded,
        Brand.success,
        'Melhor do que da última vez',
      ),
      0 => (
        Icons.drag_handle_rounded,
        scheme.onSurfaceVariant,
        'Igual à última vez',
      ),
      -1 => (Icons.arrow_downward_rounded, Brand.amber, 'Abaixo da última vez'),
      _ => (null, scheme.onSurfaceVariant, null),
    };
    final label = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 2),
        ],
        Flexible(
          child: Text(
            text,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: comparison == 1 ? FontWeight.w700 : null,
            ),
          ),
        ),
      ],
    );
    return tooltip == null ? label : Tooltip(message: tooltip, child: label);
  }
}

/// Slides its child left and back once, revealing [background] behind it.
class _SwipePeek extends StatefulWidget {
  const _SwipePeek({required this.child, required this.background});

  final Widget child;
  final Widget background;

  @override
  State<_SwipePeek> createState() => _SwipePeekState();
}

class _SwipePeekState extends State<_SwipePeek>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  late final Animation<double> _dx = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 0.0,
        end: -0.22,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 35,
    ),
    TweenSequenceItem(tween: ConstantTween(-0.22), weight: 30),
    TweenSequenceItem(
      tween: Tween(
        begin: -0.22,
        end: 0.0,
      ).chain(CurveTween(curve: Curves.easeInOutCubic)),
      weight: 35,
    ),
  ]).animate(_c);

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: widget.background),
        AnimatedBuilder(
          animation: _dx,
          builder: (context, child) => FractionalTranslation(
            translation: Offset(_dx.value, 0),
            child: child,
          ),
          child: widget.child,
        ),
      ],
    );
  }
}

String _typeDescription(SetType t) => switch (t) {
  SetType.normal => 'Série de trabalho. Conta para volume, recordes e ranks.',
  SetType.warmup => 'Não conta para volume, recordes nem ranks.',
  SetType.drop => 'Feita logo a seguir à anterior, com menos peso.',
  SetType.failure => 'Levada até não conseguires fazer mais repetições.',
};

Color setTypeColor(SetType t, ColorScheme scheme) => switch (t) {
  SetType.normal => scheme.onSurface,
  SetType.warmup => Brand.amber,
  SetType.drop => const Color(0xFFB18CFF),
  SetType.failure => scheme.error,
};

/// Bottom sheet with the set type choices and delete.
Future<void> showSetOptions(
  BuildContext context, {
  required ActiveSet set,
  required int index,
  required ValueChanged<SetType> onType,
  required VoidCallback onDelete,
}) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (context) {
      final theme = Theme.of(context);
      final scheme = theme.colorScheme;
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                set.type == SetType.normal
                    ? 'Série $index'
                    : 'Série · ${set.type.label}',
                style: theme.textTheme.titleLarge,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 4),
              child: Text(
                'TIPO DE SÉRIE',
                style: theme.textTheme.labelSmall?.copyWith(
                  letterSpacing: 1.2,
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            for (final t in SetType.values)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                leading: Container(
                  width: 36,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    t.short.isEmpty ? '$index' : t.short,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: setTypeColor(t, scheme),
                    ),
                  ),
                ),
                title: Text(
                  t.label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(_typeDescription(t)),
                trailing: set.type == t
                    ? Icon(Icons.check_rounded, color: scheme.primary)
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  if (t != set.type) onType(t);
                },
              ),
            const Divider(height: 16),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              leading: Icon(Icons.delete_outline_rounded, color: scheme.error),
              title: Text(
                'Apagar série',
                style: TextStyle(
                  color: scheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: const Text(
                'Também podes deslizar a série para a esquerda.',
              ),
              onTap: () {
                Navigator.pop(context);
                onDelete();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

class _TypeButton extends StatelessWidget {
  const _TypeButton({
    required this.set,
    required this.index,
    required this.onTap,
  });

  final ActiveSet set;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: 'Tipo de série',
      child: Material(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: SizedBox(
            height: 32,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  set.type == SetType.normal ? '$index' : set.type.short,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: setTypeColor(set.type, scheme),
                  ),
                ),
                // Small caret hinting that the number opens options.
                Positioned(
                  right: 1,
                  bottom: 0,
                  child: Icon(
                    Icons.arrow_drop_down_rounded,
                    size: 14,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NumberField extends StatefulWidget {
  const _NumberField({
    super.key,
    required this.value,
    required this.hint,
    required this.decimal,
    required this.done,
    required this.onChanged,
  });

  final double? value;
  final String hint;
  final bool decimal;
  final bool done;
  final ValueChanged<double?> onChanged;

  @override
  State<_NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<_NumberField> {
  late final TextEditingController _controller = TextEditingController(
    text: _text(widget.value),
  );
  final _focus = FocusNode();

  String _text(double? v) => v == null ? '' : editableNumber(v);

  @override
  void didUpdateWidget(_NumberField old) {
    super.didUpdateWidget(old);
    // Reflect external changes (e.g. auto-fill on completion) while not typing.
    if (!_focus.hasFocus && parseDecimal(_controller.text) != widget.value) {
      _controller.text = _text(widget.value);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: SizedBox(
        height: 36,
        child: TextField(
          controller: _controller,
          focusNode: _focus,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.numberWithOptions(
            decimal: widget.decimal,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(
              RegExp(widget.decimal ? r'[0-9.,]' : r'[0-9]'),
            ),
            LengthLimitingTextInputFormatter(widget.decimal ? 7 : 4),
          ],
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: TextStyle(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
              fontWeight: FontWeight.w600,
            ),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 8,
              horizontal: 4,
            ),
            fillColor: widget.done
                ? Colors.transparent
                : scheme.surfaceContainerHighest,
          ),
          onChanged: (t) => widget.onChanged(parseDecimal(t)),
          onTap: () => _controller.selection = TextSelection(
            baseOffset: 0,
            extentOffset: _controller.text.length,
          ),
        ),
      ),
    );
  }
}

/// Time entry as mm:ss via a picker sheet.
class _DurationField extends StatelessWidget {
  const _DurationField({
    super.key,
    required this.seconds,
    required this.hint,
    required this.done,
    required this.onChanged,
  });

  final int? seconds;
  final int? hint;
  final bool done;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: done ? Colors.transparent : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () async {
            final picked = await pickDuration(context, seconds ?? hint ?? 60);
            if (picked != null) onChanged(picked);
          },
          child: SizedBox(
            height: 36,
            child: Center(
              child: Text(
                seconds != null
                    ? formatSeconds(seconds!)
                    : (hint != null ? formatSeconds(hint!) : 'tempo'),
                style: TextStyle(
                  fontWeight: seconds != null
                      ? FontWeight.w800
                      : FontWeight.w600,
                  color: seconds != null
                      ? scheme.onSurface
                      : scheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<int?> pickDuration(BuildContext context, int initialSeconds) {
  var minutes = initialSeconds ~/ 60;
  var seconds = initialSeconds % 60;
  return showModalBottomSheet<int>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        Widget wheel(
          int count,
          int value,
          ValueChanged<int> onChanged,
          String suffix,
        ) => SizedBox(
          width: 100,
          height: 160,
          child: ListWheelScrollView.useDelegate(
            itemExtent: 40,
            controller: FixedExtentScrollController(initialItem: value),
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: onChanged,
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: count,
              builder: (_, i) => Center(
                child: Text(
                  '${i.toString().padLeft(2, '0')} $suffix',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        );
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Duração', style: Theme.of(context).textTheme.titleMedium),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    wheel(121, minutes, (v) => minutes = v, 'min'),
                    wheel(60, seconds, (v) => seconds = v, 's'),
                  ],
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () =>
                      Navigator.pop(context, minutes * 60 + seconds),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                  child: const Text('Confirmar'),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
