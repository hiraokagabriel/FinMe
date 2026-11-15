/// Resolve um enum salvo por `name`. Valor ausente ou desconhecido → primeiro valor.
T enumByName<T extends Enum>(List<T> values, Object? name) {
  for (final value in values) {
    if (value.name == name) {
      return value;
    }
  }
  return values.first;
}
