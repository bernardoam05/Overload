# Overload

App de registo de treinos de ginásio, inspirada em apps como o Liftoff, mas **100% local**: sem contas, sem servidor, todos os dados ficam numa base de dados SQLite no dispositivo.

## Funcionalidades

- **Treino ativo**: séries com peso/reps (ou duração), tipos de série (aquecimento, drop, falha), coluna "anterior" com a última performance, ✓ com um toque usa os valores anteriores, temporizador de descanso automático, o treino sobrevive ao fecho da app.
- **Rotinas**: Push/Pull/Pernas/Corpo inteiro de exemplo; criar, editar, reordenar, duplicar, guardar um treino como rotina.
- **Ranks por grupo muscular** (Ferro → Lenda, divisões III–I) calculados pelo 1RM estimado relativo ao peso corporal, ajustados ao sexo.
- **XP e níveis**, **streak semanal** com objetivo configurável, **25 conquistas**.
- **Recordes pessoais** (1RM estimado, peso máximo, melhor série, reps, duração) e gráficos de progresso por exercício.
- **Histórico** com calendário mensal, detalhe, edição e repetição de treinos.
- **Biblioteca** de ~75 exercícios + exercícios personalizados.
- **Peso corporal** com gráfico, **calculadoras** de 1RM e de discos.
- **Backup** exportar/partilhar/restaurar em JSON, tema escuro/claro, kg/lb.

## Arquitetura

```
lib/
  domain/     regras puras e testáveis (ranks, XP, streaks, recordes, estatísticas)
  data/       drift (SQLite) — tabelas, seed e repositórios
  app/        tema, router (go_router), providers (Riverpod)
  features/   ecrãs por funcionalidade (workout, train, ranks, history, profile…)
  widgets/    componentes partilhados
```

- **Flutter + Riverpod 3** para estado; os repositórios expõem `Stream`s do drift e todo o resto (ranks, níveis, recordes) é derivado em providers síncronos.
- **drift** para persistência tipada com migrações; o treino em curso é guardado como JSON numa tabela chave/valor.

## Desenvolvimento

```bash
flutter pub get
dart run build_runner build   # gera lib/data/database.g.dart
flutter test
flutter run
```
