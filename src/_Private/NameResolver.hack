/** portable-hack-ast-extras is MIT licensed, see /LICENSE. */
namespace HTL\Pha\_Private;

use namespace HH\Lib\{C, Str, Vec};
use namespace HTL\Pha;

final class NameResolver {
  private (function(Pha\Node)[]: bool) $parentMakesMeGuessItIsAType;

  public function __construct(
    Pha\Script $script,
    private vec<NamespaceResolution> $namespaceResolution,
    private dict<NodeId, string> $resolvedNames,
    private dict<string, string> $aliasedNamespaces,
    private keyset<string> $autoImportedFunctions,
    private keyset<string> $autoImportedTypes,
  )[] {
    $this->parentMakesMeGuessItIsAType = Pha\create_syntax_matcher(
      $script,
      Pha\KIND_GENERIC_TYPE_SPECIFIER,
      Pha\KIND_SCOPE_RESOLUTION_EXPRESSION,
      Pha\KIND_SIMPLE_TYPE_SPECIFIER,
    );
  }

  public function resolveName(
    Pha\Node $name,
    Pha\Syntax $parent,
    string $compressed_code,
    Pha\ResolveStrategy $strategy = Pha\ResolveStrategy::JUST_GUESS,
  )[]: (string, NillableSyntax) {
    if (Str\starts_with($compressed_code, '\\')) {
      return tuple(Str\strip_prefix($compressed_code, '\\'), NIL);
    }

    $resolved_name = idx($this->resolvedNames, node_get_id($name));
    if ($resolved_name is nonnull) {
      return tuple($resolved_name, NIL);
    }

    $parts = Str\split($compressed_code, '\\');
    $first_part = $parts[0];
    $suffix = C\count($parts) > 1
      ? Vec\slice($parts, 1) |> Str\join($$, '\\') |> '\\'.$$
      : $first_part;

    switch ($strategy) {
      case Pha\ResolveStrategy::JUST_GUESS:
        if (static::isUnderscoreOrBuiltinAttribute($compressed_code)) {
          return tuple($compressed_code, NIL);
        }
        $kind = $this->guessKind($parent, $parts);
    }

    $original_namespace =
      C\findx($this->namespaceResolution, $n ==> $n->isInRange($name));

    for (
      $namespace = $original_namespace;
      $namespace is nonnull;
      $namespace = $namespace->getParent()
    ) {
      $use = idx($namespace->getUses(), $kind, vec[])
        |> C\find($$, $u ==> $u->getLocalName() === $first_part);

      if ($use is nonnull) {
        return tuple(
          $kind === UseKind::NAMESPACE
            ? $use->getPrefix().$suffix
            : $use->getPrefix().$use->getPreAliasName(),
          $use->getClause(),
        );
      }
    }

    if ($kind === UseKind::NAMESPACE) {
      $aliassed_namespace = idx($this->aliasedNamespaces, $first_part);
      if ($aliassed_namespace is nonnull) {
        return tuple($aliassed_namespace.$suffix, NIL);
      }
    }

    if (
      $kind === UseKind::FUNCTION &&
      C\contains_key($this->autoImportedFunctions, $first_part)
    ) {
      return tuple($first_part, NIL);
    }

    if (
      $kind === UseKind::TYPE &&
      C\contains_key($this->autoImportedTypes, $first_part)
    ) {
      return tuple($first_part, NIL);
    }

    return tuple($original_namespace->getName().$compressed_code, NIL);
  }

  private function guessKind(
    Pha\Syntax $parent,
    vec<string> $parts,
  )[]: UseKind {
    if (C\count($parts) !== 1) {
      return UseKind::NAMESPACE;
    }

    if (($this->parentMakesMeGuessItIsAType)($parent)) {
      return UseKind::TYPE;
    }

    $last_part = C\lastx($parts);

    if (Str\lowercase($last_part) === $last_part) {
      return UseKind::FUNCTION;
    }

    if (Str\uppercase($last_part) === $last_part) {
      return UseKind::CONST;
    }

    return UseKind::TYPE;
  }

  private static function isUnderscoreOrBuiltinAttribute(
    string $compressed_code,
  )[]: bool {
    return $compressed_code === '_' ||
      Str\starts_with($compressed_code, '__') &&
        !Str\contains($compressed_code, '\\');
  }
}
