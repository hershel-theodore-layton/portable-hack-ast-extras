/** portable-hack-ast-extras is MIT licensed, see /LICENSE. */
namespace HTL\Pha\_Private;

use namespace HH\Lib\{C, Str, Vec};
use namespace HTL\Pha;

final class NameResolverV2 implements NameResolverInterface {
  private (function(Pha\Node)[]: bool)
    $isAsIsContext,
    $isFunctionContext,
    $isQualifiedName,
    $isTypeContext,
    $isValidName,
    $isXhp,
    $isTypeParameter;

  private (function(Pha\Syntax)[]: Pha\Node) $getTypeParameterName;

  public function __construct(
    private Pha\Script $script,
    private vec<NamespaceResolution> $namespaceResolution,
    private dict<NodeId, string> $resolvedNames,
    private dict<string, string> $aliasedNamespaces,
    private keyset<string> $autoImportedFunctions,
    private keyset<string> $autoImportedTypes,
    private dict<NodeId, dict<string, Pha\Syntax>> $genericScopes,
  )[] {
    $this->isTypeParameter =
      Pha\create_syntax_matcher($script, Pha\KIND_TYPE_PARAMETER);
    $this->getTypeParameterName =
      Pha\create_member_accessor($script, Pha\MEMBER_TYPE_NAME);
    $this->isAsIsContext =
      Pha\create_syntax_matcher($script, Pha\KIND_PREFIXED_STRING);
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
      Pha\KIND_NAMEOF_EXPRESSION,
      Pha\KIND_TYPE_CONSTANT,
      Pha\KIND_ENUM_CLASS_LABEL,
      Pha\KIND_ATTRIBUTE_SYNTAX,
    );
    $this->isValidName = Pha\create_matcher(
      $script,
      vec[Pha\KIND_QUALIFIED_NAME],
      vec[Pha\KIND_NAME, Pha\KIND_XHP_CLASS_NAME, Pha\KIND_XHP_ELEMENT_NAME],
      vec[],
    );
    $this->isXhp = Pha\create_token_matcher(
      $script,
      Pha\KIND_XHP_CLASS_NAME,
      Pha\KIND_XHP_ELEMENT_NAME,
    );
  }

  public function bubbleQualifiedName(
    Pha\Node $name,
    vec<Pha\Syntax> $ancestors,
  )[]: Pha\Node {
    return C\find($ancestors, $this->isQualifiedName) ?? $name;
  }

  public function resolveName(
    Pha\Node $name,
    vec<Pha\Syntax> $ancestors,
    string $compressed_code,
  )[]: (string, NillableSyntax) {
    if (!($this->isValidName)($name)) {
      return tuple($compressed_code, NIL);
    }
    // The public helpers may have bubbled a token to its qualified name.
    // Classify that entire name by its own parent, not an interior list item.
    foreach ($ancestors as $i => $ancestor) {
      if ($ancestor === $name) {
        $ancestors = Vec\slice($ancestors, $i + 1);
        break;
      }
    }
    $parent = $ancestors[0];

    // XHP names are a special case, they use `:` as a namespace separator.
    // By making those names look like regular qualified names,
    // we can treat them as normal names for the purposes of resolving names.
    $compressed_code = Str\replace($compressed_code, ':', '\\');

    if (Str\starts_with($compressed_code, '\\')) {
      return tuple(Str\strip_prefix($compressed_code, '\\'), NIL);
    }

    if (($this->isAsIsContext)($parent)) {
      return tuple($compressed_code, NIL);
    }

    $binding = $this->findTypeParameter($name, $ancestors, $compressed_code);
    if ($binding !== NIL) {
      return tuple($compressed_code, NIL);
    }

    $resolved_name = idx($this->resolvedNames, node_get_id($name));
    if ($resolved_name is nonnull) {
      return tuple($resolved_name, NIL);
    }

    $kind = $this->determineKind($name, $parent, $compressed_code);

    if (
      $kind === UseKind::TYPE &&
      $this->isBuiltinType($parent, $ancestors, $compressed_code)
    ) {
      return tuple($compressed_code, NIL);
    }

    if ($kind === UseKind::CONST && static::isBuiltinConst($compressed_code)) {
      return tuple($compressed_code, NIL);
    }

    $original_namespace =
      C\findx($this->namespaceResolution, $n ==> $n->isInRange($name));
    if (Str\starts_with($compressed_code, 'namespace\\')) {
      return tuple(
        $original_namespace->getName().
        Str\strip_prefix($compressed_code, 'namespace\\'),
        NIL,
      );
    }

    $parts = Str\split($compressed_code, '\\');
    $first_part = $parts[0];
    $suffix = Vec\slice($parts, 1) |> Str\join($$, '\\') |> '\\'.$$;

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
      $aliased_namespace = idx($this->aliasedNamespaces, $first_part);
      if ($aliased_namespace is nonnull) {
        return tuple(Str\trim($aliased_namespace, '\\').$suffix, NIL);
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

  private function nameAncestors(
    Pha\Node $name,
    vec<Pha\Syntax> $ancestors,
  )[]: vec<Pha\Syntax> {
    foreach ($ancestors as $i => $ancestor) {
      if ($ancestor === $name) {
        return Vec\slice($ancestors, $i + 1);
      }
    }
    return $ancestors;
  }

  private function findTypeParameter(
    Pha\Node $name,
    vec<Pha\Syntax> $ancestors,
    string $spelling,
  )[]: NillableSyntax {
    if (C\is_empty($this->genericScopes)) {
      return NIL;
    }
    $ancestors = $this->nameAncestors($name, $ancestors);
    $parent = C\first($ancestors);
    if ($parent is null || Str\contains($spelling, '\\')) {
      return NIL;
    }
    if (
      ($this->isTypeParameter)($parent) &&
      ($this->getTypeParameterName)($parent) === $name
    ) {
      return $parent;
    }
    // Declaration and member names are already classified as literal names.
    if (
      C\contains_key($this->resolvedNames, node_get_id($name)) ||
      $this->determineKind($name, $parent, $spelling) !== UseKind::TYPE
    ) {
      return NIL;
    }
    // Attribute class names are symbols, even when a generic has that name.
    $is_attribute = Pha\create_syntax_matcher(
      $this->script,
      Pha\KIND_ATTRIBUTE_SYNTAX,
      Pha\KIND_OLD_ATTRIBUTE_SPECIFICATION,
      Pha\KIND_FILE_ATTRIBUTE_SPECIFICATION,
    );
    $is_constructor =
      Pha\create_syntax_matcher($this->script, Pha\KIND_CONSTRUCTOR_CALL);
    $is_list = Pha\create_syntax_matcher(
      $this->script,
      Pha\KIND_NODE_LIST,
      Pha\KIND_LIST_ITEM,
    );
    $outer = Vec\slice($ancestors, 1) |> C\find($$, $a ==> !$is_list($a));
    if (
      $is_attribute($parent) ||
      $is_constructor($parent) && $outer is nonnull && $is_attribute($outer)
    ) {
      return NIL;
    }
    foreach ($ancestors as $ancestor) {
      $bindings = idx($this->genericScopes, node_get_id($ancestor), dict[]);
      $binding = idx($bindings, $spelling);
      if ($binding is nonnull) {
        return $binding;
      }
    }
    return NIL;
  }

  public function resolveNameInContext(
    Pha\NillableNode $name,
    vec<Pha\Syntax> $ancestors,
    string $spelling,
  )[]: Pha\NameResolution {
    if ($name === NIL) {
      return Pha\NameResolution::create(
        '',
        Pha\ResolverNameKind::UNKNOWN,
        Pha\TypeDependency::NONE,
        NIL,
        NIL,
      );
    }
    $name = cast_away_nil($name);
    $ancestors = $this->nameAncestors($name, $ancestors);
    $is_type_access = Pha\create_syntax_matcher(
      $this->script,
      Pha\KIND_TYPE_CONSTANT,
      Pha\KIND_SCOPE_RESOLUTION_EXPRESSION,
    );
    $parent = C\first($ancestors);
    if (
      $is_type_access($name) || $parent is nonnull && $is_type_access($parent)
    ) {
      $get_left = Pha\create_member_accessor(
        $this->script,
        Pha\MEMBER_TYPE_CONSTANT_LEFT_TYPE,
        Pha\MEMBER_SCOPE_RESOLUTION_QUALIFIER,
      );
      $get_right = Pha\create_member_accessor(
        $this->script,
        Pha\MEMBER_TYPE_CONSTANT_RIGHT_TYPE,
        Pha\MEMBER_SCOPE_RESOLUTION_NAME,
      );
      if ($is_type_access($name)) {
        $access = Pha\as_syntax($name);
      } else {
        invariant($parent is nonnull, 'A member access must have a parent');
        $access = $parent;
      }
      $is_type_constant =
        Pha\create_syntax_matcher($this->script, Pha\KIND_TYPE_CONSTANT);
      if ($is_type_access($name) || $get_right($access) === $name) {
        $left = $get_left($access);
        $root = $this->resolveNameInContext(
          $left,
          Pha\node_get_syntax_ancestors($this->script, $left),
          Pha\node_get_code_compressed($this->script, $left),
        );
        return Pha\NameResolution::create(
          $is_type_access($name)
            ? $root->getName().
              '::'.
              Pha\node_get_code_compressed($this->script, $get_right($access))
            : $spelling,
          $is_type_access($name) && $is_type_constant($access)
            ? Pha\ResolverNameKind::TYPE
            : Pha\ResolverNameKind::MEMBER,
          $root->getDependency(),
          $root->getTypeParameter(),
          $is_type_access($name) ? $root->getUseClause() : NIL,
        );
      }
    }
    list($resolved, $use_clause) =
      $this->resolveName($name, $ancestors, $spelling);
    $binding = $this->findTypeParameter($name, $ancestors, $spelling);
    $kind = $this->nameKind($name, $ancestors);
    $dependency = Pha\TypeDependency::NONE;
    if ($binding !== NIL) {
      $dependency = Pha\TypeDependency::TYPE_PARAMETER;
    } else if (
      $kind === Pha\ResolverNameKind::TYPE ||
      $kind === Pha\ResolverNameKind::CONTEXT
    ) {
      switch ($spelling) {
        case 'this':
          $dependency = Pha\TypeDependency::THIS;
          break;
        case 'self':
          $dependency = Pha\TypeDependency::SELF;
          break;
        case 'static':
          $dependency = Pha\TypeDependency::STATIC;
          break;
        default:
          break;
      }
    }
    return Pha\NameResolution::create(
      $resolved,
      $kind,
      $dependency,
      $binding,
      $use_clause,
    );
  }

  private function nameKind(
    Pha\Node $name,
    vec<Pha\Syntax> $ancestors,
  )[]: Pha\ResolverNameKind {
    $parent = C\first($ancestors);
    if ($parent is null) {
      return Pha\ResolverNameKind::UNKNOWN;
    }
    $get_member = Pha\create_member_accessor(
      $this->script,
      Pha\MEMBER_MEMBER_NAME,
      Pha\MEMBER_SAFE_MEMBER_NAME,
      Pha\MEMBER_SCOPE_RESOLUTION_NAME,
      Pha\MEMBER_TYPE_CONSTANT_RIGHT_TYPE,
      Pha\MEMBER_TYPE_CONST_NAME,
      Pha\MEMBER_CONTEXT_CONST_NAME,
      Pha\MEMBER_ENUMERATOR_NAME,
      Pha\MEMBER_ENUM_CLASS_ENUMERATOR_NAME,
      Pha\MEMBER_ENUM_CLASS_LABEL_EXPRESSION,
    );
    $is_member_parent = Pha\create_syntax_matcher(
      $this->script,
      Pha\KIND_MEMBER_SELECTION_EXPRESSION,
      Pha\KIND_SAFE_MEMBER_SELECTION_EXPRESSION,
      Pha\KIND_SCOPE_RESOLUTION_EXPRESSION,
      Pha\KIND_TYPE_CONSTANT,
      Pha\KIND_TYPE_CONST_DECLARATION,
      Pha\KIND_CONTEXT_CONST_DECLARATION,
      Pha\KIND_ENUMERATOR,
      Pha\KIND_ENUM_CLASS_ENUMERATOR,
      Pha\KIND_ENUM_CLASS_LABEL,
    );
    if ($is_member_parent($parent) && $get_member($parent) === $name) {
      return Pha\ResolverNameKind::MEMBER;
    }
    $is_context_alias = Pha\create_syntax_matcher(
      $this->script,
      Pha\KIND_CONTEXT_ALIAS_DECLARATION,
    );
    if ($is_context_alias($parent)) {
      return Pha\ResolverNameKind::CONTEXT;
    }
    $is_constant =
      Pha\create_syntax_matcher($this->script, Pha\KIND_CONSTANT_DECLARATOR);
    if ($is_constant($parent)) {
      $is_class_body =
        Pha\create_syntax_matcher($this->script, Pha\KIND_CLASSISH_BODY);
      return C\any($ancestors, $is_class_body)
        ? Pha\ResolverNameKind::MEMBER
        : Pha\ResolverNameKind::CONST;
    }
    $is_use =
      Pha\create_syntax_matcher($this->script, Pha\KIND_NAMESPACE_USE_CLAUSE);
    $is_group = Pha\create_syntax_matcher(
      $this->script,
      Pha\KIND_NAMESPACE_GROUP_USE_DECLARATION,
    );
    if ($is_group($parent)) {
      return Pha\ResolverNameKind::NAMESPACE;
    }
    if ($is_use($parent)) {
      $get_use_kind = Pha\create_member_accessor(
        $this->script,
        Pha\MEMBER_NAMESPACE_USE_CLAUSE_KIND,
        Pha\MEMBER_NAMESPACE_USE_KIND,
        Pha\MEMBER_NAMESPACE_GROUP_USE_KIND,
      );
      $use_kind =
        Pha\node_get_code_compressed($this->script, $get_use_kind($parent));
      if ($use_kind === '') {
        $is_use_owner = Pha\create_syntax_matcher(
          $this->script,
          Pha\KIND_NAMESPACE_USE_DECLARATION,
          Pha\KIND_NAMESPACE_GROUP_USE_DECLARATION,
        );
        $owner = C\find($ancestors, $is_use_owner);
        if ($owner is nonnull) {
          $use_kind =
            Pha\node_get_code_compressed($this->script, $get_use_kind($owner));
        }
      }
      switch ($use_kind) {
        case 'function':
          return Pha\ResolverNameKind::FUNCTION;
        case 'const':
          return Pha\ResolverNameKind::CONST;
        case 'namespace':
          return Pha\ResolverNameKind::NAMESPACE;
        default:
          return Pha\ResolverNameKind::TYPE;
      }
    }
    $is_namespace = Pha\create_syntax_matcher(
      $this->script,
      Pha\KIND_NAMESPACE_DECLARATION_HEADER,
    );
    if ($is_namespace($parent)) {
      return Pha\ResolverNameKind::NAMESPACE;
    }
    $is_contexts = Pha\create_syntax_matcher($this->script, Pha\KIND_CONTEXTS);
    $is_list = Pha\create_syntax_matcher(
      $this->script,
      Pha\KIND_NODE_LIST,
      Pha\KIND_LIST_ITEM,
    );
    $outer = Vec\slice($ancestors, 1) |> C\find($$, $a ==> !$is_list($a));
    if ($outer is nonnull && $is_contexts($outer)) {
      return Pha\ResolverNameKind::CONTEXT;
    }
    $is_attribute =
      Pha\create_syntax_matcher($this->script, Pha\KIND_ATTRIBUTE_SYNTAX);
    $is_attribute_container = Pha\create_syntax_matcher(
      $this->script,
      Pha\KIND_OLD_ATTRIBUTE_SPECIFICATION,
      Pha\KIND_FILE_ATTRIBUTE_SPECIFICATION,
    );
    $is_constructor =
      Pha\create_syntax_matcher($this->script, Pha\KIND_CONSTRUCTOR_CALL);
    if (
      $is_attribute($parent) ||
      $is_constructor($parent) &&
        $outer is nonnull &&
        $is_attribute_container($outer)
    ) {
      return Pha\ResolverNameKind::ATTRIBUTE;
    }
    $is_function_header = Pha\create_syntax_matcher(
      $this->script,
      Pha\KIND_FUNCTION_DECLARATION_HEADER,
    );
    $get_function_name =
      Pha\create_member_accessor($this->script, Pha\MEMBER_FUNCTION_NAME);
    if ($is_function_header($parent) && $get_function_name($parent) === $name) {
      $is_method = Pha\create_syntax_matcher(
        $this->script,
        Pha\KIND_METHODISH_DECLARATION,
      );
      return $outer is nonnull && $is_method($outer)
        ? Pha\ResolverNameKind::MEMBER
        : Pha\ResolverNameKind::FUNCTION;
    }
    $is_type_declaration = Pha\create_syntax_matcher(
      $this->script,
      Pha\KIND_CLASSISH_DECLARATION,
      Pha\KIND_ALIAS_DECLARATION,
      Pha\KIND_ENUM_DECLARATION,
      Pha\KIND_ENUM_CLASS_DECLARATION,
    );
    if ($is_type_declaration($parent) || ($this->isTypeContext)($parent)) {
      return Pha\ResolverNameKind::TYPE;
    }
    if (($this->isFunctionContext)($parent)) {
      return Pha\ResolverNameKind::FUNCTION;
    }
    if (($this->isValidName)($name)) {
      return Pha\ResolverNameKind::CONST;
    }
    // Keywords such as this/self/static are valid type roots, but are not
    // KIND_NAME tokens and therefore need no namespace expansion.
    $is_type_root = Pha\create_syntax_matcher(
      $this->script,
      Pha\KIND_TYPE_CONSTANT,
      Pha\KIND_SIMPLE_TYPE_SPECIFIER,
      Pha\KIND_SCOPE_RESOLUTION_EXPRESSION,
    );
    return $is_type_root($parent)
      ? Pha\ResolverNameKind::TYPE
      : Pha\ResolverNameKind::UNKNOWN;
  }

  private function determineKind(
    Pha\Node $node,
    Pha\Syntax $parent,
    string $compressed_code,
  )[]: UseKind {
    if (($this->isQualifiedName)($node)) {
      return UseKind::NAMESPACE;
    }

    if (($this->isXhp)($node)) {
      return Str\contains($compressed_code, '\\')
        ? UseKind::NAMESPACE
        : UseKind::TYPE;
    }

    if (($this->isFunctionContext)($parent)) {
      return UseKind::FUNCTION;
    }

    if (($this->isTypeContext)($parent)) {
      return UseKind::TYPE;
    }

    return UseKind::CONST;
  }

  private function isBuiltinType(
    Pha\Syntax $parent,
    vec<Pha\Syntax> $ancestors,
    string $name,
  )[]: bool {
    if ($name === '_') {
      return true;
    }
    $is_attribute = Pha\create_syntax_matcher(
      $this->script,
      Pha\KIND_ATTRIBUTE_SYNTAX,
      Pha\KIND_OLD_ATTRIBUTE_SPECIFICATION,
      Pha\KIND_FILE_ATTRIBUTE_SPECIFICATION,
    );
    // Only the attribute's class name gets the reserved attribute shortcut.
    $is_constructor =
      Pha\create_syntax_matcher($this->script, Pha\KIND_CONSTRUCTOR_CALL);
    $is_list = Pha\create_syntax_matcher(
      $this->script,
      Pha\KIND_NODE_LIST,
      Pha\KIND_LIST_ITEM,
    );
    $attribute_owner = Vec\slice($ancestors, 1)
      |> C\find($$, $a ==> !$is_list($a));
    if (
      Str\starts_with($name, '__') &&
      (
        $is_attribute($parent) ||
        $is_constructor($parent) &&
          $attribute_owner is nonnull &&
          $is_attribute($attribute_owner)
      )
    ) {
      return true;
    }
    $is_contexts = Pha\create_syntax_matcher($this->script, Pha\KIND_CONTEXTS);
    $is_simple_type =
      Pha\create_syntax_matcher($this->script, Pha\KIND_SIMPLE_TYPE_SPECIFIER);
    return $is_simple_type($parent) &&
      C\contains(BUILTIN_CONTEXT_NAMES, $name) &&
      $attribute_owner is nonnull &&
      $is_contexts($attribute_owner);
  }

  private static function isBuiltinConst(string $const_name)[]: bool {
    return C\contains(
      keyset[
        '__LINE__',
        '__FILE__',
        '__DIR__',
        '__FUNCTION__',
        '__CLASS__',
        '__TRAIT__',
        '__METHOD__',
        '__NAMESPACE__',
        '__FUNCTION_CREDENTIAL__',
      ],
      $const_name,
    );
  }
}
