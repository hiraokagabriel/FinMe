import '../../../core/utils/text_normalize.dart';
import '../../categories/domain/category_tree.dart';
import '../../categories/domain/transaction_category.dart';

/// Entrada do dicionário de estabelecimentos. Guarda o nome da categoria, não o id,
/// para funcionar com qualquer conjunto de categorias e sobreviver a backups.
class DictionaryEntry {
  const DictionaryEntry({
    required this.id,
    required this.pattern,
    required this.categoryName,
  });

  factory DictionaryEntry.fromMap(Map<String, dynamic> map) => DictionaryEntry(
    id: map['id'] as String,
    pattern: map['pattern'] as String,
    categoryName: map['categoryName'] as String,
  );

  final String id;

  /// Já em foldText (ex.: 'UBER', 'PAO DE ACUCAR', 'APPLE.COM').
  final String pattern;

  /// Nome da categoria, resolvido por nome (SPEC §5.13).
  final String categoryName;

  DictionaryEntry copyWith({
    String? id,
    String? pattern,
    String? categoryName,
  }) => DictionaryEntry(
    id: id ?? this.id,
    pattern: pattern ?? this.pattern,
    categoryName: categoryName ?? this.categoryName,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'pattern': pattern,
    'categoryName': categoryName,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DictionaryEntry &&
          other.id == id &&
          other.pattern == pattern &&
          other.categoryName == categoryName;

  @override
  int get hashCode => Object.hash(id, pattern, categoryName);

  @override
  String toString() => 'DictionaryEntry($pattern -> $categoryName)';
}

/// Padrões genéricos (pattern já em foldText, nome da categoria padrão do seed).
/// Ordem do SPEC §5.13; "mais longo vence" é decidido no categorizador.
const List<(String, String)> kDefaultDictionary = [
  // Transporte
  ('UBER', 'Transporte'),
  ('99APP', 'Transporte'),
  ('99 POP', 'Transporte'),
  ('99 TAXI', 'Transporte'),
  ('CABIFY', 'Transporte'),
  ('ESTACIONAMENTO', 'Transporte'),
  ('ESTAPAR', 'Transporte'),
  ('PEDAGIO', 'Transporte'),
  ('SEM PARAR', 'Transporte'),
  ('CONECTCAR', 'Transporte'),
  ('VELOE', 'Transporte'),
  ('METRO', 'Transporte'),
  ('BILHETE UNICO', 'Transporte'),
  // Combustível (fallback Transporte)
  ('POSTO', 'Combustível'),
  ('COMBUSTIVEL', 'Combustível'),
  ('IPIRANGA', 'Combustível'),
  ('SHELL', 'Combustível'),
  ('SHELLBOX', 'Combustível'),
  // Alimentação
  ('IFOOD', 'Alimentação'),
  ('UBER EATS', 'Alimentação'),
  ('RAPPI', 'Alimentação'),
  ('RESTAURANTE', 'Alimentação'),
  ('LANCHONETE', 'Alimentação'),
  ('LANCHES', 'Alimentação'),
  ('PADARIA', 'Alimentação'),
  ('PANIFICADORA', 'Alimentação'),
  ('PIZZARIA', 'Alimentação'),
  ('BURGER', 'Alimentação'),
  ('MCDONALDS', 'Alimentação'),
  ('MC DONALDS', 'Alimentação'),
  ('SUBWAY', 'Alimentação'),
  ('STARBUCKS', 'Alimentação'),
  ('CAFE', 'Alimentação'),
  ('CAFETERIA', 'Alimentação'),
  // Mercado
  ('SUPERMERCADO', 'Mercado'),
  ('MERCADO', 'Mercado'),
  ('ATACADAO', 'Mercado'),
  ('ASSAI', 'Mercado'),
  ('CARREFOUR', 'Mercado'),
  ('PAO DE ACUCAR', 'Mercado'),
  ('HORTIFRUTI', 'Mercado'),
  ('SACOLAO', 'Mercado'),
  // Saúde
  ('FARMACIA', 'Saúde'),
  ('DROGA', 'Saúde'),
  // Prefixos de DROGA que o padrão "DROGA" não casa (exige fim de palavra).
  ('DROGASIL', 'Saúde'),
  ('DROGARIA', 'Saúde'),
  ('DROGAO', 'Saúde'),
  ('DROGA RAIA', 'Saúde'),
  ('RAIA', 'Saúde'),
  ('PANVEL', 'Saúde'),
  ('PAGUE MENOS', 'Saúde'),
  ('HOSPITAL', 'Saúde'),
  ('CLINICA', 'Saúde'),
  ('LABORATORIO', 'Saúde'),
  ('ODONTO', 'Saúde'),
  ('ODONTOPREV', 'Saúde'),
  ('ODONTOLOGIA', 'Saúde'),
  // Assinaturas
  ('NETFLIX', 'Assinaturas'),
  ('SPOTIFY', 'Assinaturas'),
  ('DISNEY', 'Assinaturas'),
  ('DISNEYPLUS', 'Assinaturas'),
  ('PRIME VIDEO', 'Assinaturas'),
  ('AMAZON PRIME', 'Assinaturas'),
  ('HBO', 'Assinaturas'),
  ('HBOMAX', 'Assinaturas'),
  ('GLOBOPLAY', 'Assinaturas'),
  ('DEEZER', 'Assinaturas'),
  ('YOUTUBE PREMIUM', 'Assinaturas'),
  ('APPLE.COM', 'Assinaturas'),
  ('PARAMOUNT', 'Assinaturas'),
  ('CRUNCHYROLL', 'Assinaturas'),
  // Compras
  ('MERCADOLIVRE', 'Compras'),
  ('MERCADO LIVRE', 'Compras'),
  ('AMAZON', 'Compras'),
  ('SHOPEE', 'Compras'),
  ('MAGALU', 'Compras'),
  ('MAGAZINE LUIZA', 'Compras'),
  ('ALIEXPRESS', 'Compras'),
  ('SHEIN', 'Compras'),
  ('AMERICANAS', 'Compras'),
  ('CASAS BAHIA', 'Compras'),
  ('RENNER', 'Compras'),
  ('RIACHUELO', 'Compras'),
  // Contas e serviços
  ('CLARO', 'Contas e serviços'),
  ('VIVO', 'Contas e serviços'),
  ('TELEFONICA', 'Contas e serviços'),
  ('ENERGIA', 'Contas e serviços'),
  ('SANEAMENTO', 'Contas e serviços'),
  ('AGUA', 'Contas e serviços'),
  ('INTERNET', 'Contas e serviços'),
  ('ANUIDADE', 'Contas e serviços'),
  ('TARIFA', 'Contas e serviços'),
  ('IOF', 'Contas e serviços'),
  ('SEGURO', 'Contas e serviços'),
  // Moradia
  ('ALUGUEL', 'Moradia'),
  ('CONDOMINIO', 'Moradia'),
  ('IPTU', 'Moradia'),
  // Educação
  ('ESCOLA', 'Educação'),
  ('COLEGIO', 'Educação'),
  ('FACULDADE', 'Educação'),
  ('UNIVERSIDADE', 'Educação'),
  ('CURSO', 'Educação'),
  ('UDEMY', 'Educação'),
  ('ALURA', 'Educação'),
  ('LIVRARIA', 'Educação'),
  // Lazer
  ('CINEMA', 'Lazer'),
  ('CINEMARK', 'Lazer'),
  ('INGRESSO', 'Lazer'),
  ('INGRESSORAPIDO', 'Lazer'),
  ('STEAM', 'Lazer'),
  ('STEAMGAMES', 'Lazer'),
  ('PLAYSTATION', 'Lazer'),
  ('XBOX', 'Lazer'),
  ('TEATRO', 'Lazer'),
  // Viagem
  ('HOTEL', 'Viagem'),
  ('POUSADA', 'Viagem'),
  ('AIRBNB', 'Viagem'),
  ('BOOKING', 'Viagem'),
  ('DECOLAR', 'Viagem'),
  ('LATAM', 'Viagem'),
  ('AZUL LINHAS', 'Viagem'),
  ('GOL LINHAS', 'Viagem'),
  ('PASSAGEM', 'Viagem'),
  // Salário
  ('SALARIO', 'Salário'),
  ('PROVENTOS', 'Salário'),
  // Rendimentos
  ('RENDIMENTO', 'Rendimentos'),
  ('DIVIDENDOS', 'Rendimentos'),
];

/// foldText(nome) → foldText(nome) de categoria do dicionário ausente no seed.
const Map<String, String> kDictionaryFallbacks = {'COMBUSTIVEL': 'TRANSPORTE'};

final RegExp _nonIdCharRe = RegExp('[^a-z0-9]');
final RegExp _alnumUpperRe = RegExp('[A-Z0-9]');
final RegExp _letterUpperRe = RegExp('[A-Z]');

/// Dicionário embutido. id = 'dict_' + pattern minúsculo com não-alfanumérico → '_'.
List<DictionaryEntry> defaultDictionary() => [
  for (final (pattern, categoryName) in kDefaultDictionary)
    DictionaryEntry(
      id: 'dict_${pattern.toLowerCase().replaceAll(_nonIdCharRe, '_')}',
      pattern: foldText(pattern),
      categoryName: categoryName,
    ),
];

/// Separador de caminho com espaços: ' › ' ou ' > '. Sem espaços ('A>B') não divide.
final RegExp _pathSepRe = RegExp(
  '${RegExp.escape(kCategoryPathSeparator)}| > ',
);

/// id da categoria para [name] (SPEC §5.13): nome inteiro primeiro (ex.: 'A>B'), senão caminho 'Pai › Filha', senão nome simples, senão fallback; senão null.
String? resolveCategoryByName(
  String name,
  Iterable<TransactionCategory> categories,
) {
  final cats = categories.toList();
  final whole = _idByName(foldText(name.trim()), cats);
  if (whole != null) {
    return whole;
  }
  var wanted = name;
  final parts = name
      .split(_pathSepRe)
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.length == 2) {
    final id = _childIdByPath(parts[0], parts[1], cats);
    if (id != null) {
      return id;
    }
    wanted = parts[1];
  }
  final folded = foldText(wanted);
  final direct = _idByName(folded, cats);
  if (direct != null) {
    return direct;
  }
  final fallback = kDictionaryFallbacks[folded];
  return fallback == null ? null : _idByName(fallback, cats);
}

/// Filha F de uma raiz R (parentId null) com os nomes dados; null se não houver.
String? _childIdByPath(
  String rootName,
  String childName,
  List<TransactionCategory> cats,
) {
  final root = foldText(rootName);
  final child = foldText(childName);
  for (final r in cats) {
    if (r.parentId != null || foldText(r.name) != root) {
      continue;
    }
    for (final f in cats) {
      if (f.parentId == r.id && foldText(f.name) == child) {
        return f.id;
      }
    }
  }
  return null;
}

/// Raiz homônima (1ª na ordem de entrada) ou única candidata; 2+ subcategorias homônimas → null (ambíguo).
String? _idByName(String folded, List<TransactionCategory> cats) {
  final same = cats.where((c) => foldText(c.name) == folded).toList();
  for (final c in same) {
    if (c.parentId == null) {
      return c.id;
    }
  }
  return same.length == 1 ? same.single.id : null;
}

/// [pattern] casa em [foldedDescription] numa palavra inteira: começa palavra (início ou caractere anterior
/// fora de [A-Z0-9]) e não é seguido de letra (MERCADO não casa MERCADOPAGO; DROGA não casa DROGASIL).
/// Aceita um 'S' final opcional antes do fim de palavra (SUPERMERCADOS, FARMACIAS).
bool dictionaryPatternMatches(String pattern, String foldedDescription) {
  if (pattern.isEmpty) {
    return false;
  }
  var i = foldedDescription.indexOf(pattern);
  while (i >= 0) {
    final end = i + pattern.length;
    final startsWord =
        i == 0 || !_alnumUpperRe.hasMatch(foldedDescription[i - 1]);
    final plural =
        end < foldedDescription.length && foldedDescription[end] == 'S';
    final endsWord =
        _endsWordAt(foldedDescription, end) ||
        (plural && _endsWordAt(foldedDescription, end + 1));
    if (startsWord && endsWord) {
      return true;
    }
    i = foldedDescription.indexOf(pattern, i + 1);
  }
  return false;
}

/// Fim de palavra em [end]: fim do texto ou caractere que não é letra.
bool _endsWordAt(String s, int end) =>
    end == s.length || !_letterUpperRe.hasMatch(s[end]);
