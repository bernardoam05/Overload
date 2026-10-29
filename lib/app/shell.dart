import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../features/settings/update_dialog.dart';
import '../features/workout/active_workout_controller.dart';
import 'providers.dart';
import 'theme.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeWorkoutProvider.select((w) => w != null));
    // Checked once per launch; failures and "up to date" stay silent.
    ref.listen(updateProvider, (_, next) {
      final info = next.value;
      if (info == null) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('Nova versão ${info.version} disponível'),
          duration: const Duration(seconds: 10),
          action: SnackBarAction(
            label: 'Atualizar',
            onPressed: () => showUpdateDialog(context, info),
          ),
        ));
    });
    return Scaffold(
      body: shell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (active) const _ActiveWorkoutBar(),
          NavigationBar(
            selectedIndex: shell.currentIndex,
            onDestinationSelected: (i) =>
                shell.goBranch(i, initialLocation: i == shell.currentIndex),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Início',
              ),
              NavigationDestination(
                icon: Icon(Icons.fitness_center_outlined),
                selectedIcon: Icon(Icons.fitness_center),
                label: 'Treinar',
              ),
              NavigationDestination(
                icon: Icon(Icons.military_tech_outlined),
                selectedIcon: Icon(Icons.military_tech),
                label: 'Ranks',
              ),
              NavigationDestination(
                icon: Icon(Icons.calendar_month_outlined),
                selectedIcon: Icon(Icons.calendar_month),
                label: 'Histórico',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: 'Perfil',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Hosts the tab navigators in a [PageView] so tabs can be changed with a
/// horizontal swipe as well as from the navigation bar.
class SwipeableBranches extends StatefulWidget {
  const SwipeableBranches({
    super.key,
    required this.shell,
    required this.children,
  });

  final StatefulNavigationShell shell;
  final List<Widget> children;

  @override
  State<SwipeableBranches> createState() => _SwipeableBranchesState();
}

class _SwipeableBranchesState extends State<SwipeableBranches> {
  late final PageController _controller = PageController(
    initialPage: widget.shell.currentIndex,
  );

  /// True while the page is moved programmatically (tab tap), so the
  /// intermediate pages it passes don't switch branches.
  bool _jumping = false;

  @override
  void didUpdateWidget(SwipeableBranches old) {
    super.didUpdateWidget(old);
    final target = widget.shell.currentIndex;
    if (_controller.hasClients &&
        (_controller.page?.round() ?? target) != target) {
      _jumping = true;
      _controller
          .animateToPage(
            target,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
          )
          .whenComplete(() => _jumping = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView(
      controller: _controller,
      onPageChanged: (i) {
        if (!_jumping && i != widget.shell.currentIndex) {
          widget.shell.goBranch(i);
        }
      },
      children: [for (final child in widget.children) _KeepAlive(child: child)],
    );
  }
}

class _KeepAlive extends StatefulWidget {
  const _KeepAlive({required this.child});

  final Widget child;

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

/// Persistent strip that brings the user back to the running workout.
class _ActiveWorkoutBar extends ConsumerStatefulWidget {
  const _ActiveWorkoutBar();

  @override
  ConsumerState<_ActiveWorkoutBar> createState() => _ActiveWorkoutBarState();
}

class _ActiveWorkoutBarState extends ConsumerState<_ActiveWorkoutBar> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final workout = ref.watch(
      activeWorkoutProvider.select(
        (w) => w == null
            ? null
            : (
                name: w.name,
                isEditing: w.isEditing,
                startedAt: w.startedAt,
                restEndsAt: w.restEndsAt,
                doneSets: w.doneSets,
              ),
      ),
    );
    if (workout == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final rest = workout.restEndsAt?.difference(DateTime.now());
    final resting = rest != null && !rest.isNegative;
    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      child: InkWell(
        onTap: () => context.push('/workout'),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  gradient: Brand.emberGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.local_fire_department,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      workout.isEditing
                          ? 'A editar: ${workout.name}'
                          : workout.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    Text(
                      resting
                          ? 'Descanso ${formatClock(rest)}'
                          : workout.isEditing
                          ? '${workout.doneSets} séries'
                          : '${formatClock(DateTime.now().difference(workout.startedAt))} · ${workout.doneSets} séries',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: resting
                            ? theme.colorScheme.secondary
                            : theme.colorScheme.onSurfaceVariant,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.keyboard_arrow_up_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
