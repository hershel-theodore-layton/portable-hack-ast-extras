/** portable-hack-ast-extras is MIT licensed, see /LICENSE. */
namespace HTL\Pha\_Private;

use namespace HH\Lib\{C, Str, Vec};
use namespace HTL\Pha;

final class NameResolver {
  /**
   * Generated by scanning public sources and printing distinct parent kinds.
   * Then, by reasoning about the ancestors, determine the kind.
   */
  private (function(Pha\Node)[]: bool)
    $isFunctionContext,
    $isQualifiedName,
    $isTypeContext;

  public function __construct(
    Pha\Script $script,
    private vec<NamespaceResolution> $namespaceResolution,
    private dict<NodeId, string> $resolvedNames,
    private dict<string, string> $aliasedNamespaces,
    private keyset<string> $autoImportedFunctions,
    private keyset<string> $autoImportedTypes,
  )[] {
    $this->isFunctionContext = Pha\create_syntax_matcher(
      $script,
      Pha\KIND_FUNCTION_CALL_EXPRESSION,
      Pha\KIND_FUNCTION_POINTER_EXPRESSION,
    );
    $this->isQualifiedName =
      Pha\create_syntax_matcher($script, Pha\KIND_QUALIFIED_NAME);
    $this->isTypeContext = Pha\create_syntax_matcher(
      $script,
      Pha\KIND_CONSTRUCTOR_CALL,
      Pha\KIND_GENERIC_TYPE_SPECIFIER,
      Pha\KIND_SCOPE_RESOLUTION_EXPRESSION,
      Pha\KIND_SIMPLE_TYPE_SPECIFIER,
      Pha\KIND_TYPE_PARAMETER,
    );
  }

  public function resolveName(
    Pha\Node $name,
    Pha\Syntax $parent,
    string $compressed_code,
  )[]: (string, NillableSyntax) {
    if (Str\starts_with($compressed_code, '\\')) {
      return tuple(Str\strip_prefix($compressed_code, '\\'), NIL);
    }

    $resolved_name = idx($this->resolvedNames, node_get_id($name));
    if ($resolved_name is nonnull) {
      return tuple($resolved_name, NIL);
    }

    $kind = $this->determineKind($name, $parent);

    if ($kind === UseKind::TYPE && static::isBuiltinType($compressed_code)) {
      return tuple($compressed_code, NIL);
    }

    if ($kind === UseKind::CONST && static::isBuiltinConst($compressed_code)) {
      return tuple($compressed_code, NIL);
    }

    $parts = Str\split($compressed_code, '\\');
    $first_part = $parts[0];
    $suffix = Vec\slice($parts, 1) |> Str\join($$, '\\') |> '\\'.$$;
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

  private function determineKind(
    Pha\Node $node,
    Pha\Syntax $parent,
  )[]: UseKind {
    if (($this->isQualifiedName)($node)) {
      return UseKind::NAMESPACE;
    }

    if (($this->isFunctionContext)($parent)) {
      return UseKind::FUNCTION;
    }

    if (($this->isTypeContext)($parent)) {
      return UseKind::TYPE;
    }

    return UseKind::CONST;
  }

  private static function isBuiltinConst(string $const_name)[]: bool {
    return
      Str\starts_with($const_name, '__') && Str\ends_with($const_name, '__');
  }

  private static function isBuiltinType(string $type_name)[]: bool {
    return $type_name === '_' ||
      Str\starts_with($type_name, '__') ||
      C\contains(BUILTIN_CONTEXT_NAMES, $type_name);
  }
}
