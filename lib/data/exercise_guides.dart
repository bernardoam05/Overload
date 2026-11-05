import '../domain/enums.dart';

/// Technique guide of a library exercise: its category (default rest and
/// rep range), short cues to keep in mind during the set and the most
/// common mistake.
typedef ExerciseGuide = ({
  ExerciseCategory category,
  List<String> cues,
  String mistake,
});

const _hc = ExerciseCategory.heavyCompound;
const _c = ExerciseCategory.compound;
const _i = ExerciseCategory.isolation;
const _h = ExerciseCategory.highRep;

ExerciseGuide _g(
  ExerciseCategory category,
  List<String> cues,
  String mistake,
) => (category: category, cues: cues, mistake: mistake);

/// Guides by seed key. Exercises without one fall back to [_c] and no cues.
final Map<String, ExerciseGuide> exerciseGuides = {
  // Peito
  'bench': _g(_hc, [
    'Omoplatas juntas e para baixo, ligeiro arco, pés firmes no chão',
    'Desce controlado até tocar a meio do peito, cotovelos a ~45°',
    'Empurra para cima e ligeiramente para trás, na direção dos olhos',
  ], 'Abrir os cotovelos a 90° e deixar os ombros subir do banco.'),
  'incline_bench': _g(_hc, [
    'Banco a 30°: mais inclinado passa a ser exercício de ombro',
    'Desce à parte de cima do peito, logo abaixo das clavículas',
    'Omoplatas presas ao banco durante toda a série',
  ], 'Banco demasiado inclinado e a barra a descer ao pescoço.'),
  'decline_bench': _g(_hc, [
    'Pés bem presos e omoplatas juntas antes de tirar a barra',
    'Desce à parte de baixo do peito',
    'Pede ajuda a tirar e a pousar a barra',
  ], 'Deixar a barra bater no peito em vez de a controlar.'),
  'db_bench': _g(_c, [
    'Senta-te com os halteres nas coxas e deita-te a levá-los ao peito',
    'Desce até sentir alongamento, antebraços na vertical',
    'Empurra a aproximar ligeiramente os halteres no topo',
  ], 'Descer pouco por medo e perder a amplitude, a vantagem dos halteres.'),
  'db_incline': _g(_c, [
    'Banco a 30° (mede com o inclinómetro)',
    'Cotovelos ligeiramente à frente do tronco, não abertos',
    'Desce até os halteres ficarem ao nível do peito',
  ], 'Arquear demais e transformar o inclinado num supino reto.'),
  'db_fly': _g(_i, [
    'Cotovelos ligeiramente fletidos e fixos durante toda a série',
    'Abre como se abraçasses uma árvore grande',
    'Para quando sentires alongamento, sem forçar o ombro',
  ], 'Fletir os cotovelos a descer e transformar a abertura num supino.'),
  'cable_fly': _g(_i, [
    'Um passo à frente, tronco ligeiramente inclinado',
    'Junta as mãos à frente do peito a apertar 1 segundo',
    'Volta devagar até sentir o peito alongar',
  ], 'Usar os braços e os ombros em vez de fechar com o peito.'),
  'pec_deck': _g(_i, [
    'Assento à altura que põe as pegas ao nível do peito',
    'Costas e omoplatas coladas ao encosto',
    'Fecha devagar e controla a abertura',
  ], 'Deixar os ombros rodar para a frente no fim do movimento.'),
  'chest_press': _g(_c, [
    'Pegas à altura do meio do peito',
    'Costas e ombros encostados, sem ir tudo para trás',
    'Não estiques os cotovelos até bloquear',
  ], 'Tirar as omoplatas do encosto ao empurrar.'),
  'push_up': _g(_c, [
    'Corpo em linha reta da cabeça aos calcanhares',
    'Mãos um pouco mais abertas que os ombros',
    'Desce até o peito quase tocar no chão',
  ], 'Deixar a anca cair e fazer meias repetições.'),
  'incline_chest_press': _g(_c, [
    'Assento que põe as pegas na parte de cima do peito',
    'Omoplatas no encosto durante toda a série',
    'Controla a descida 2 segundos',
  ], 'Encolher os ombros ao empurrar.'),
  'smith_incline_bench': _g(_c, [
    'Banco a 30°, posicionado para a barra descer ao peito alto',
    'Destrava a barra rodando os pulsos',
    'Controla a descida, a guia não substitui a técnica',
  ], 'Banco mal posicionado: a barra desce ao pescoço ou à barriga.'),
  'cable_fly_low': _g(_i, [
    'Polias em baixo, braços ligeiramente fletidos',
    'Sobe as mãos até à altura dos olhos, a juntar à frente',
    'Foca a parte de cima do peito',
  ], 'Puxar com os ombros e os bíceps em vez do peito.'),

  // Costas
  'bb_row': _g(_hc, [
    'Tronco a ~45°, costas neutras, joelhos ligeiramente fletidos',
    'Puxa a barra ao umbigo, cotovelos junto ao corpo',
    'Junta as omoplatas em cima e controla a descida',
  ], 'Endireitar o tronco a cada repetição para levantar mais peso.'),
  'db_row': _g(_c, [
    'Mão e joelho no banco, costas paralelas ao chão',
    'Puxa o halter em direção à anca, não ao ombro',
    'Deixa a omoplata alongar em baixo',
  ], 'Rodar o tronco para dar balanço ao halter.'),
  'kneeling_cable_row': _g(_c, [
    'Ajoelhado, tronco direito e abdominal contraído',
    'Puxa as pegas para os lados das costelas',
    'Aperta as omoplatas no fim',
  ], 'Inclinar para trás e puxar com o peso do corpo.'),
  'cable_row': _g(_c, [
    'Peito alto e ligeira inclinação para trás no fim',
    'Puxa a pega até ao abdominal, cotovelos junto ao corpo',
    'Deixa os braços esticar e as omoplatas abrir à frente',
  ], 'Balançar o tronco para a frente e para trás em cada repetição.'),
  'lat_pulldown': _g(_c, [
    'Coxas presas, peito alto, ligeira inclinação para trás',
    'Puxa a barra à parte de cima do peito com os cotovelos para baixo',
    'Sobe devagar até esticar os braços',
  ], 'Puxar a barra atrás da nuca ou balançar o tronco.'),
  'pull_up': _g(_c, [
    'Começa pendurado com os braços esticados',
    'Puxa o peito à barra a levar os cotovelos às costelas',
    'Desce controlado até esticar de novo',
  ], 'Meias repetições: não descer até esticar os braços.'),
  'chin_up': _g(_c, [
    'Palmas viradas para ti, mãos à largura dos ombros',
    'Puxa até o queixo passar a barra',
    'Desce controlado até esticar',
  ], 'Balançar as pernas para ganhar impulso.'),
  't_bar_row': _g(_c, [
    'Tronco a ~45°, costas neutras',
    'Puxa a pega ao peito baixo',
    'Aperta as omoplatas 1 segundo em cima',
  ], 'Arredondar as costas para levantar mais peso.'),
  'machine_row': _g(_c, [
    'Peito encostado ao apoio, ajusta para chegares às pegas com os braços esticados',
    'Puxa com os cotovelos, não com as mãos',
    'Controla a volta até as omoplatas abrirem',
  ], 'Tirar o peito do apoio para dar balanço.'),
  'shrug': _g(_i, [
    'Braços esticados, halteres ao lado do corpo',
    'Sobe os ombros em direção às orelhas, sem rodar',
    'Segura 1 segundo em cima e desce devagar',
  ], 'Rodar os ombros em círculo: não ajuda e pode irritar a articulação.'),
  'straight_pulldown': _g(_i, [
    'Braços quase esticados, ligeira inclinação do tronco',
    'Leva a barra até às coxas a usar as dorsais',
    'Sobe devagar até sentires as costas alongar',
  ], 'Fletir os cotovelos e transformar o exercício num pushdown.'),
  'pull_up_assisted': _g(_c, [
    'Usa a menor ajuda que te deixa fazer as repetições com boa forma',
    'Puxa o peito à barra com os cotovelos para baixo',
    'Desce até esticar os braços',
  ], 'Ficar sempre com a mesma ajuda: reduz quando chegares ao topo das reps.'),
  'close_grip_pulldown': _g(_c, [
    'Peito alto, ligeira inclinação para trás',
    'Puxa o triângulo à parte de cima do abdominal',
    'Deixa os braços esticar em cima',
  ], 'Inclinar demasiado e transformar a puxada numa remada.'),
  'single_arm_pulldown': _g(_c, [
    'Senta-te de lado para a polia, tronco ligeiramente inclinado',
    'Puxa o cotovelo em direção à anca',
    'Deixa a dorsal alongar em cima',
  ], 'Rodar o tronco para puxar com o corpo.'),
  'back_extension': _g(_i, [
    'Apoio logo abaixo da anca, para dobrar pela anca',
    'Desce com as costas neutras, sobe até ficares em linha',
    'Não estendas para lá da linha do corpo',
  ], 'Hiperestender a lombar no topo.'),

  // Ombros
  'ohp': _g(_hc, [
    'Glúteos e abdominal contraídos, barra a começar nas clavículas',
    'Afasta a cabeça e empurra a barra em linha reta',
    'Cabeça "por dentro" no topo, barra por cima do meio do pé',
  ], 'Arquear a lombar para trás para empurrar mais peso.'),
  'db_shoulder_press': _g(_c, [
    'Banco a 80–90°, costas encostadas',
    'Desce os halteres ao nível das orelhas',
    'Empurra para cima sem bater os halteres',
  ], 'Descer pouco e fazer meias repetições.'),
  'arnold_press': _g(_c, [
    'Começa com as palmas viradas para ti à altura do queixo',
    'Roda as palmas para a frente enquanto empurras',
    'Inverte o movimento na descida',
  ], 'Fazer a rotação depressa e perder o controlo.'),
  'machine_shoulder_press': _g(_c, [
    'Assento que põe as pegas à altura dos ombros',
    'Costas encostadas, sem arquear',
    'Desce até as mãos chegarem às orelhas',
  ], 'Tirar as costas do encosto para empurrar.'),
  'lateral_raise': _g(_h, [
    'Ligeira inclinação para a frente, cotovelos ligeiramente fletidos',
    'Sobe até à altura dos ombros, a levar os cotovelos e não as mãos',
    'Desce em 2 segundos, sem pousar os halteres',
  ], 'Encolher os ombros e dar balanço com o tronco.'),
  'cable_lateral': _g(_h, [
    'Polia em baixo, cabo a passar por trás ou à frente do corpo',
    'Sobe até à altura do ombro com o cotovelo à frente da mão',
    'Mantém tensão em baixo, não deixes o peso pousar',
  ], 'Puxar com o trapézio e encolher o ombro.'),
  'front_raise': _g(_i, [
    'Braços quase esticados, tronco imóvel',
    'Sobe até à altura dos olhos',
    'Desce devagar',
  ], 'Balançar o corpo para levantar o peso.'),
  'rear_delt_fly': _g(_i, [
    'Tronco inclinado quase paralelo ao chão',
    'Abre os braços para os lados com os cotovelos ligeiramente fletidos',
    'Pensa em levar as mãos para longe, não em juntar as omoplatas',
  ], 'Juntar as omoplatas e fazer o exercício com o trapézio.'),
  'face_pull': _g(_i, [
    'Polia à altura dos olhos, corda',
    'Puxa à cara a separar as mãos e a rodar os braços para trás',
    'Cotovelos altos, ao nível dos ombros',
  ], 'Puxar com os cotovelos baixos, como numa remada.'),
  'upright_row': _g(_c, [
    'Pega à largura dos ombros ou mais aberta',
    'Leva os cotovelos para cima e para os lados',
    'Para quando os cotovelos chegarem à altura dos ombros',
  ], 'Pega demasiado fechada e subir alto demais, o que aperta o ombro.'),
  'reverse_pec_deck': _g(_i, [
    'Peito no encosto, pegas à altura dos ombros',
    'Abre os braços para trás com os cotovelos ligeiramente fletidos',
    'Empurra com a parte de fora da mão, sem apertar as omoplatas',
  ], 'Juntar as omoplatas e usar o trapézio em vez do deltoide posterior.'),
  'machine_lateral': _g(_h, [
    'Ombro alinhado com o eixo da máquina',
    'Sobe com os cotovelos até à altura dos ombros',
    'Desce devagar sem pousar o peso',
  ], 'Encolher os ombros durante a subida.'),

  // Bíceps
  'bb_curl': _g(_i, [
    'Cotovelos colados ao corpo e imóveis',
    'Sobe até contrair, sem levar os cotovelos à frente',
    'Desce até esticar os braços',
  ], 'Balançar o tronco para levantar a barra.'),
  'ez_curl': _g(_i, [
    'Pega nas curvas interiores da barra',
    'Cotovelos fixos junto ao corpo',
    'Controla a descida até esticar',
  ], 'Encurtar a amplitude no fundo.'),
  'db_curl': _g(_i, [
    'Começa com as palmas viradas para as coxas e roda ao subir',
    'Cotovelos imóveis ao lado do corpo',
    'Desce controlado até esticar',
  ], 'Dar balanço com o corpo nas últimas repetições.'),
  'hammer_curl': _g(_i, [
    'Palmas viradas uma para a outra durante todo o movimento',
    'Cotovelos fixos ao lado do corpo',
    'Sobe até o halter chegar ao ombro e desce devagar',
  ], 'Levar os cotovelos à frente para subir o peso.'),
  'preacher_curl': _g(_i, [
    'Axilas encostadas ao topo do apoio',
    'Desce até quase esticar, sem bloquear',
    'Sobe sem tirar os braços do apoio',
  ], 'Deixar cair o peso no fundo: é aí que o bíceps está mais vulnerável.'),
  'concentration_curl': _g(_i, [
    'Cotovelo apoiado na parte de dentro da coxa',
    'Sobe devagar e aperta no topo',
    'Desce até esticar o braço',
  ], 'Usar o ombro para ajudar a levantar.'),
  'cable_curl': _g(_i, [
    'Cotovelos fixos junto ao corpo',
    'Sobe até contrair e segura 1 segundo',
    'Desce até esticar sem perder a tensão',
  ], 'Inclinar para trás para puxar com o corpo.'),
  'incline_db_curl': _g(_i, [
    'Banco a 45–60°, braços pendurados atrás do tronco',
    'Sobe sem levar os cotovelos à frente',
    'Desce até esticar por completo',
  ], 'Levar os cotovelos à frente e perder o alongamento do bíceps.'),
  'machine_preacher_curl': _g(_i, [
    'Ajusta o assento para os braços ficarem bem apoiados',
    'Sobe até contrair, desce até quase esticar',
    'Controla a descida 2 segundos',
  ], 'Levantar os ombros para ajudar a subir.'),
  'bayesian_curl': _g(_i, [
    'De costas para a polia, braço atrás do corpo',
    'Mantém o cotovelo atrás do tronco durante a série',
    'Sobe até contrair e desce até alongar',
  ], 'Deixar o cotovelo ir à frente e perder o alongamento.'),

  // Tríceps
  'close_grip_bench': _g(_c, [
    'Mãos à largura dos ombros, não mais juntas',
    'Cotovelos junto ao corpo na descida',
    'Desce à parte de baixo do peito',
  ], 'Mãos demasiado juntas, o que força os pulsos.'),
  'pushdown': _g(_i, [
    'Cotovelos colados às costelas e imóveis',
    'Empurra até esticar por completo e aperta',
    'Sobe só até os antebraços ficarem paralelos ao chão',
  ], 'Deixar os cotovelos subir e usar os ombros.'),
  'skull_crusher': _g(_i, [
    'Braços ligeiramente inclinados para trás, não na vertical',
    'Desce a barra à testa ou atrás da cabeça, só a mexer os cotovelos',
    'Cotovelos apontados para cima, sem abrir',
  ], 'Abrir os cotovelos para os lados.'),
  'overhead_ext': _g(_i, [
    'Segura o halter com as duas mãos por baixo do disco de cima',
    'Desce atrás da cabeça até alongar bem o tríceps',
    'Cotovelos apontados para a frente, sem abrir muito',
  ], 'Arquear a lombar ao subir o peso.'),
  'overhead_ext_single': _g(_i, [
    'Braço junto à cabeça, cotovelo a apontar para cima',
    'Desce o halter atrás da cabeça até alongar',
    'Usa a outra mão para segurar o cotovelo no sítio',
  ], 'Deixar o cotovelo abrir para o lado.'),
  'dips': _g(_c, [
    'Tronco direito para focar o tríceps',
    'Desce até o braço ficar paralelo ao chão',
    'Ombros para baixo, longe das orelhas',
  ], 'Descer demasiado fundo com os ombros a rodar para a frente.'),
  'kickback': _g(_i, [
    'Tronco quase paralelo ao chão, braço colado ao corpo',
    'Estica o cotovelo até o braço ficar em linha',
    'Segura 1 segundo esticado',
  ], 'Balançar o braço em vez de mexer só o cotovelo.'),
  'db_skull_crusher': _g(_i, [
    'Palmas viradas uma para a outra',
    'Desce os halteres ao lado da cabeça',
    'Mexe só os cotovelos',
  ], 'Deixar os cotovelos abrir e fazer um supino.'),
  'rope_pushdown': _g(_i, [
    'Cotovelos colados ao corpo',
    'Em baixo, separa as pontas da corda para os lados',
    'Sobe controlado até 90°',
  ], 'Inclinar o tronco por cima da corda para empurrar com o peso do corpo.'),
  'cable_overhead_ext': _g(_i, [
    'De costas para a polia, corda atrás da cabeça',
    'Estica os braços para a frente e para cima',
    'Deixa o tríceps alongar bem atrás da cabeça',
  ], 'Mexer os ombros em vez de só os cotovelos.'),
  'dips_assisted': _g(_c, [
    'Usa a menor ajuda que permita boa forma',
    'Tronco direito, desce até 90° no cotovelo',
    'Ombros para baixo',
  ], 'Ficar sempre com a mesma ajuda.'),
  'machine_dip': _g(_c, [
    'Costas no encosto, pegas ao lado do corpo',
    'Empurra para baixo até esticar',
    'Sobe até 90° no cotovelo',
  ], 'Encolher os ombros ao empurrar.'),

  // Quadríceps
  'squat': _g(_hc, [
    'Barra no trapézio, respira fundo e contrai o abdominal antes de descer',
    'Joelhos na direção dos pés, peso no meio do pé',
    'Desce pelo menos até a anca ficar ao nível dos joelhos',
  ], 'Deixar os joelhos fugir para dentro ou levantar os calcanhares.'),
  'front_squat': _g(_hc, [
    'Barra apoiada nos ombros, cotovelos bem altos',
    'Tronco o mais direito possível',
    'Desce fundo e sobe a empurrar os cotovelos para cima',
  ], 'Deixar os cotovelos cair e a barra rolar para a frente.'),
  'leg_press': _g(_c, [
    'Pés à largura dos ombros, a meio da plataforma',
    'Desce até os joelhos chegarem perto do peito sem a lombar sair do encosto',
    'Não bloqueies os joelhos em cima',
  ], 'Descer tanto que a anca enrola e a lombar sai do encosto.'),
  'hack_squat': _g(_c, [
    'Costas bem encostadas, pés a meio da plataforma',
    'Desce fundo de forma controlada',
    'Empurra pelo meio do pé',
  ], 'Fazer meias repetições com muito peso.'),
  'leg_extension': _g(_i, [
    'Joelho alinhado com o eixo da máquina, rolo acima do tornozelo',
    'Estica e aperta 1 segundo em cima',
    'Desce devagar até 90°',
  ], 'Dar balanço e levantar a anca do assento.'),
  'bulgarian_split': _g(_c, [
    'Pé de trás no banco, pé da frente longe o suficiente',
    'Desce na vertical até o joelho de trás quase tocar no chão',
    'Tronco ligeiramente inclinado para mais glúteo, direito para mais quadríceps',
  ], 'Pé da frente demasiado perto do banco.'),
  'lunge': _g(_c, [
    'Passo largo à frente, tronco direito',
    'Desce até o joelho de trás quase tocar no chão',
    'Empurra pelo calcanhar da frente para voltar',
  ], 'Deixar o joelho da frente fugir para dentro.'),
  'goblet_squat': _g(_c, [
    'Segura o halter junto ao peito, cotovelos para baixo',
    'Desce fundo com os cotovelos por dentro dos joelhos',
    'Tronco direito',
  ], 'Deixar o tronco cair para a frente.'),
  'smith_squat': _g(_c, [
    'Pés um pouco à frente da barra',
    'Desce fundo com as costas neutras',
    'Empurra pelo meio do pé',
  ], 'Pés mesmo por baixo da barra, o que carrega demasiado os joelhos.'),
  'smith_bulgarian': _g(_c, [
    'Pé de trás no banco, barra no trapézio',
    'Desce na vertical seguindo a guia',
    'Mantém o joelho da frente alinhado com o pé',
  ], 'Banco mal colocado em relação à barra.'),
  'leg_extension_single': _g(_i, [
    'Uma perna de cada vez, joelho no eixo da máquina',
    'Estica e aperta em cima',
    'Desce devagar',
  ], 'Usar a outra perna para ajudar.'),
  'step_up': _g(_c, [
    'Pé inteiro no banco',
    'Sobe a empurrar só com a perna de cima',
    'Desce controlado',
  ], 'Dar impulso com a perna de baixo.'),

  // Posteriores e glúteos
  'deadlift': _g(_hc, [
    'Barra por cima do meio do pé, canelas quase a tocar',
    'Respira, contrai o abdominal e tira a folga da barra antes de puxar',
    'Empurra o chão com as pernas, barra junto às pernas',
  ], 'Arredondar a lombar ou deixar a barra afastar-se do corpo.'),
  'sumo_deadlift': _g(_hc, [
    'Pés bem abertos, pontas para fora, mãos por dentro das pernas',
    'Joelhos para fora, na direção dos pés',
    'Tronco mais direito que no peso morto convencional',
  ], 'Deixar os joelhos fechar ao arrancar.'),
  'rdl': _g(_hc, [
    'Joelhos ligeiramente fletidos e fixos',
    'Leva a anca para trás com a barra junto às pernas',
    'Desce até sentires os posteriores esticar, sem arredondar',
  ], 'Fletir os joelhos e transformar o exercício num agachamento.'),
  'hip_thrust': _g(_c, [
    'Omoplatas no banco, barra na dobra da anca (usa almofada)',
    'Pés de modo a ficar com as canelas na vertical em cima',
    'Sobe até a anca ficar em linha e aperta os glúteos',
  ], 'Arquear a lombar em cima em vez de estender a anca.'),
  'leg_curl': _g(_i, [
    'Joelho alinhado com o eixo, rolo acima do calcanhar',
    'Anca colada ao banco',
    'Flete até ao fim e desce devagar',
  ], 'Levantar a anca do banco para ajudar.'),
  'seated_leg_curl': _g(_i, [
    'Apoio das coxas bem apertado',
    'Inclina o tronco ligeiramente para a frente para alongar mais',
    'Flete até ao fim e controla a volta',
  ], 'Deixar o peso voltar depressa.'),
  'standing_leg_curl': _g(_i, [
    'Joelho alinhado com o eixo da máquina',
    'Anca imóvel, encostada ao apoio',
    'Flete até ao fim e desce devagar',
  ], 'Rodar a anca para subir o peso.'),
  'stiff': _g(_c, [
    'Joelhos quase esticados, costas neutras',
    'Abdominal contraído e respiração presa na descida',
    'Desce até sentir os posteriores, sem arredondar',
  ], 'Arredondar a lombar para chegar mais abaixo.'),
  'good_morning': _g(_c, [
    'Barra no trapézio, joelhos ligeiramente fletidos',
    'Leva a anca para trás com as costas neutras',
    'Começa leve: é muito exigente para a lombar',
  ], 'Arredondar as costas na descida.'),
  'kb_swing': _g(_c, [
    'Movimento de anca, não de agachamento',
    'Projeta a anca para a frente com força',
    'Os braços só guiam a kettlebell',
  ], 'Levantar a kettlebell com os ombros.'),
  'hip_abduction': _g(_h, [
    'Costas encostadas ou tronco ligeiramente inclinado à frente',
    'Abre e segura 1 segundo',
    'Fecha devagar sem deixar os pesos bater',
  ], 'Usar balanço e deixar o peso voltar de repente.'),
  'hip_adduction': _g(_h, [
    'Ajusta a abertura para sentir alongamento sem dor',
    'Fecha devagar e aperta',
    'Abre controlado',
  ], 'Abertura demasiado grande logo na primeira série.'),
  'hip_thrust_machine': _g(_c, [
    'Apoio na dobra da anca, omoplatas no encosto',
    'Sobe até a anca ficar em linha',
    'Aperta os glúteos em cima',
  ], 'Arquear a lombar em cima.'),
  'cable_kickback': _g(_i, [
    'Tornozeleira presa, tronco ligeiramente inclinado',
    'Leva a perna para trás com o joelho ligeiramente fletido',
    'Para antes de arquear a lombar',
  ], 'Arquear a lombar para levar a perna mais alto.'),

  // Gémeos
  'calf_raise': _g(_h, [
    'Ponta dos pés na beira do degrau',
    'Desce até alongar bem e segura 1 segundo em baixo',
    'Sobe o mais alto possível',
  ], 'Fazer repetições curtas e com ressalto.'),
  'seated_calf': _g(_h, [
    'Apoio por cima dos joelhos',
    'Alongamento completo em baixo, com pausa',
    'Sobe ao máximo e aperta',
  ], 'Ressaltar em baixo em vez de pausar.'),
  'leg_press_calf': _g(_h, [
    'Só a ponta dos pés na plataforma, joelhos quase esticados',
    'Desce até alongar bem',
    'Empurra com os dedos até ao máximo',
  ], 'Fletir os joelhos e empurrar com as pernas.'),

  // Core
  'plank': _g(_h, [
    'Antebraços no chão, cotovelos por baixo dos ombros',
    'Contrai glúteos e abdominal, corpo em linha',
    'Respira normalmente',
  ], 'Deixar a anca cair ou subir demais.'),
  'side_plank': _g(_h, [
    'Cotovelo por baixo do ombro',
    'Anca alta, corpo em linha',
    'Faz os dois lados',
  ], 'Deixar a anca descer.'),
  'crunch': _g(_h, [
    'Enrola o tronco a aproximar as costelas da anca',
    'Mãos junto à cabeça, sem puxar o pescoço',
    'Desce devagar',
  ], 'Puxar a cabeça com as mãos.'),
  'hanging_leg_raise': _g(_h, [
    'Pendurado, ombros ativos',
    'Enrola a anca a subir as pernas',
    'Desce devagar, sem balançar',
  ], 'Balançar e subir só as pernas sem enrolar a anca.'),
  'cable_crunch': _g(_h, [
    'Ajoelhado, corda junto à cabeça',
    'Enrola o tronco a levar os cotovelos às coxas',
    'A anca fica parada',
  ], 'Sentar-te para trás e puxar com a anca e os braços.'),
  'ab_wheel': _g(_h, [
    'Abdominal contraído, costas ligeiramente arredondadas',
    'Avança só até onde controlas sem a lombar ceder',
    'Volta a puxar com o abdominal',
  ], 'Deixar a lombar arquear ao avançar.'),
  'russian_twist': _g(_h, [
    'Tronco inclinado para trás, costas direitas',
    'Roda o tronco, não só os braços',
    'Movimento controlado',
  ], 'Mexer só os braços de um lado para o outro.'),
  'machine_crunch': _g(_h, [
    'Ajusta o assento para os ombros ficarem por baixo das pegas',
    'Enrola o tronco, não puxes com os braços',
    'Volta devagar',
  ], 'Usar os braços para puxar o peso.'),
  'captains_chair': _g(_h, [
    'Costas encostadas, antebraços nos apoios',
    'Sobe os joelhos a enrolar a anca',
    'Desce devagar',
  ], 'Balançar as pernas.'),

  // Antebraços
  'wrist_curl': _g(_h, [
    'Antebraços apoiados nas coxas ou num banco',
    'Deixa o halter rolar até aos dedos e fecha',
    'Mexe só os pulsos',
  ], 'Levantar os antebraços para ajudar.'),
  'farmer_walk': _g(_h, [
    'Halteres pesados, ombros para trás e para baixo',
    'Passos curtos e controlados',
    'Abdominal contraído, tronco direito',
  ], 'Deixar os ombros cair para a frente.'),

  // Corpo inteiro
  'power_clean': _g(_hc, [
    'Começa como num peso morto, barra junto às pernas',
    'Estende a anca com força e puxa a barra junto ao corpo',
    'Recebe a barra nos ombros com os cotovelos à frente',
  ], 'Puxar com os braços antes de estender a anca.'),
  'thruster': _g(_hc, [
    'Agachamento frontal seguido de press acima da cabeça',
    'Usa o impulso das pernas para empurrar a barra',
    'Tronco direito, cotovelos altos em baixo',
  ], 'Separar as duas partes e perder o impulso das pernas.'),
  'burpee': _g(_h, [
    'Mãos no chão, pés para trás, peito ao chão',
    'Pés de volta às mãos e salto',
    'Mantém um ritmo constante',
  ], 'Deixar a lombar ceder na posição de flexão.'),

  // Cardio
  'run': _g(_h, [
    'Passada curta e rápida, apoio por baixo do corpo',
    'Ombros relaxados',
  ], 'Passada longa a travar com o calcanhar.'),
  'bike': _g(_h, [
    'Selim à altura que deixa o joelho quase esticado em baixo',
    'Mantém a cadência estável',
  ], 'Selim baixo demais, o que carrega os joelhos.'),
  'rower': _g(_h, [
    'Ordem: pernas, tronco, braços; volta pela ordem inversa',
    'A maior parte da força vem das pernas',
  ], 'Puxar com os braços antes de empurrar com as pernas.'),
  'jump_rope': _g(_h, [
    'Saltos baixos na ponta dos pés',
    'A corda roda com os pulsos, não com os braços',
  ], 'Saltar alto demais e cansar logo.'),
  'elliptical': _g(_h, [
    'Tronco direito, usa também os braços',
    'Pés inteiros nos pedais',
  ], 'Apoiar o peso do corpo nos braços.'),
  'stairs': _g(_h, [
    'Tronco direito, não te apoies nos corrimões',
    'Pé inteiro em cada degrau',
  ], 'Pendurar-te nos corrimões e tirar o trabalho às pernas.'),
  'incline_walk': _g(_h, [
    'Inclinação entre 8 e 15 %, ritmo de caminhada rápida',
    'Larga os corrimões',
  ], 'Agarrar-te à passadeira, o que anula a inclinação.'),
};
