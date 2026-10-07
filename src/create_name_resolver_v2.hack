/** portable-hack-ast-extras is MIT licensed, see /LICENSE. */
namespace HTL\Pha;

use namespace HH\Lib\{C, Dict, Str, Vec};
use type HTL\Pha\_Private\{
  NameResolverV2,
  NamespaceResolution,
  UseInfo,
  UseKind,
};

/**
 * Creates a resolver for this script snapshot using corrected namespace rules.
 * Use the existing resolve_name() and resolve_name_and_use_clause() helpers.
 *
 * @param $aliased_namespaces When using the `hhvm.aliased_namespaces` ini +
 * `auto_namespace_map` hhconfig settings, some default namespaces are used.
 * So for example, mapping `Vec` to `HH\Lib\Vec` acts as if every file started
 * with `if (!exists(use clause "Vec")) use namespace HH\Lib\Vec as Vec;`.
 * You can pass the result of `\ini_get("hhvm.aliased_namespaces")` to make
 * `resolve_name` take your pre-resolved names into account.
 *
 * @param $auto_imported_functions a list of functions that are available in any
 * Hack file without an explicit use clause. If your HHVM version has different
 * auto-imported names, and you care, you can pass a different list of names.
 *
 * @param $auto_imported_types a list of types that are available in any
 * Hack file without an explicit use clause. If your HHVM version has different
 * auto-imported names, and you care, you can pass a different list of names.
 */
function create_name_resolver_v2(
  Script $script,
  SyntaxIndex $syntax_index,
  TokenIndex $token_index,
  dict<string, string> $aliased_namespaces = dict[],
  ?keyset<string> $auto_imported_functions = null,
  ?keyset<string> $auto_imported_types = null,
)[]: Resolver {
  $auto_imported_functions ??= _Private\AUTO_IMPORTED_FUNCTIONS;
  $auto_imported_types ??= _Private\AUTO_IMPORTED_TYPES;

  $is_const = create_token_matcher($script, KIND_CONST);
  $is_function = create_token_matcher($script, KIND_FUNCTION);
  $is_function_declaration_header =
    create_syntax_matcher($script, KIND_FUNCTION_DECLARATION_HEADER);
  $is_methodish_declaration =
    create_syntax_matcher($script, KIND_METHODISH_DECLARATION);
  $is_missing = create_syntax_matcher($script, KIND_MISSING);
  $is_namespace = create_token_matcher($script, KIND_NAMESPACE);
  $is_namespace_body = create_syntax_matcher($script, KIND_NAMESPACE_BODY);
  $is_namespace_declaration_header =
    create_syntax_matcher($script, KIND_NAMESPACE_DECLARATION_HEADER);
  $is_namespace_group_use_declaration =
    create_syntax_matcher($script, KIND_NAMESPACE_GROUP_USE_DECLARATION);
  $is_namespace_use_clause =
    create_syntax_matcher($script, KIND_NAMESPACE_USE_CLAUSE);
  $is_namespace_use_or_group_use_declaration = create_syntax_matcher(
    $script,
    KIND_NAMESPACE_USE_DECLARATION,
    KIND_NAMESPACE_GROUP_USE_DECLARATION,
  );
  $is_qualified_name = create_syntax_matcher($script, KIND_QUALIFIED_NAME);
  $is_type = create_token_matcher($script, KIND_TYPE);

  $get_function_name = create_member_accessor($script, MEMBER_FUNCTION_NAME);
  $get_namespace_body = create_member_accessor($script, MEMBER_NAMESPACE_BODY);
  $get_namespace_declarations =
    create_member_accessor($script, MEMBER_NAMESPACE_DECLARATIONS)
    |> returns_syntax($$);
  $get_namespace_group_use_prefix =
    create_member_accessor($script, MEMBER_NAMESPACE_GROUP_USE_PREFIX);
  $get_namespace_header =
    create_member_accessor($script, MEMBER_NAMESPACE_HEADER)
    |> returns_syntax($$);
  $get_namespace_name = create_member_accessor($script, MEMBER_NAMESPACE_NAME);
  $get_namespace_use_clauses = create_member_accessor(
    $script,
    MEMBER_NAMESPACE_USE_CLAUSES,
    MEMBER_NAMESPACE_GROUP_USE_CLAUSES,
  )
    |> returns_syntax($$);
  $get_namespace_use_alias =
    create_member_accessor($script, MEMBER_NAMESPACE_USE_ALIAS);
  $get_namespace_use_name =
    create_member_accessor($script, MEMBER_NAMESPACE_USE_NAME);
  $get_namespace_use_kind = create_member_accessor(
    $script,
    MEMBER_NAMESPACE_USE_KIND,
    MEMBER_NAMESPACE_GROUP_USE_KIND,
    MEMBER_NAMESPACE_USE_CLAUSE_KIND,
  );

  $namespaces = () ==> {
    $declaration_list =
      node_get_first_childx($script, SCRIPT_NODE) |> as_syntax($$);

    $to_use_infos = $uses ==> Vec\map($uses, $use ==> {
      $use = as_syntax($use);
      $outer_kind = $get_namespace_use_kind($use);
      $to_kind = $kind ==> {
        if ($is_const($kind)) {
          return UseKind::CONST;
        } else if ($is_function($kind)) {
          return UseKind::FUNCTION;
        } else if ($is_namespace($kind)) {
          return UseKind::NAMESPACE;
        } else if ($is_type($kind)) {
          return UseKind::TYPE;
        }
        return UseKind::NONE;
      };

      if ($is_namespace_group_use_declaration($use)) {
        $prefix = $get_namespace_group_use_prefix($use)
          |> node_get_code_compressed($script, $$);
      } else {
        $prefix = '';
      }

      return $get_namespace_use_clauses($use)
        |> list_get_items_of_children($script, $$)
        |> Vec\map($$, as_syntax<>)
        |> Vec\map($$, $clause ==> {
          $clause_kind = $get_namespace_use_kind($clause);
          $kind =
            $to_kind($is_missing($clause_kind) ? $outer_kind : $clause_kind);
          $use_name_text = $get_namespace_use_name($clause)
            |> node_get_code_compressed($script, $$);
          $full_name = Str\trim_left($prefix.$use_name_text, '\\');
          $last_part = Str\split($full_name, '\\') |> C\lastx($$);
          $alias = $get_namespace_use_alias($clause);
          $local_name = $is_missing($alias)
            ? $last_part
            : node_get_code_compressed($script, $alias);
          $kinds = $kind === UseKind::NONE
            ? vec[UseKind::NAMESPACE, UseKind::TYPE]
            : vec[$kind];
          return Vec\map(
            $kinds,
            $kind ==> new UseInfo(
              $kind,
              $clause,
              $kind === UseKind::NAMESPACE
                ? $full_name
                : Str\strip_suffix($full_name, $last_part),
              $local_name,
              $last_part,
            ),
          );
        })
        |> Vec\flatten($$);
    })
      |> Vec\flatten($$)
      |> Dict\group_by($$, $u ==> $u->getKind());

    $is_namespace_declaration =
      create_syntax_matcher($script, KIND_NAMESPACE_DECLARATION);
    $namespaces = dict[];

    // A file-level fallback also covers file attributes and incomplete input.
    // It must not borrow imports from any of the namespace bodies.
    $file_declarations = node_get_children($script, $declaration_list);
    $file_uses = vec[];
    foreach ($file_declarations as $declaration) {
      if ($is_namespace_declaration($declaration)) {
        break;
      }
      if ($is_namespace_use_or_group_use_declaration($declaration)) {
        $file_uses[] = $declaration;
      }
    }
    $fallback = new NamespaceResolution(
      SCRIPT_NODE,
      node_get_last_descendant_or_self($script, SCRIPT_NODE),
      '',
      $to_use_infos($file_uses),
      null,
    );

    foreach (
      index_get_nodes_by_kind($syntax_index, KIND_NAMESPACE_DECLARATION)
      |> Vec\sort_by($$, node_get_source_order<>) as $n
    ) {
      $body = $get_namespace_body($n);
      if ($is_namespace_body($body)) {
        $scope = $get_namespace_declarations(as_syntax($body));
        $declarations = node_get_children($script, $scope);
        $end = node_get_last_descendant_or_self($script, $n);
      } else {
        // Semicolon namespaces own only the following siblings up to the
        // next namespace declaration, even when the names repeat.
        $siblings = node_get_parent($script, $n)
          |> node_get_children($script, $$);
        $declarations = vec[];
        $in_scope = false;
        $end = node_get_last_descendant_or_self($script, $n);
        foreach ($siblings as $sibling) {
          if ($sibling === $n) {
            $in_scope = true;
            continue;
          }
          if (!$in_scope) {
            continue;
          }
          if ($is_namespace_declaration($sibling)) {
            break;
          }
          $declarations[] = $sibling;
          $end = node_get_last_descendant_or_self($script, $sibling);
        }
      }
      $uses =
        Vec\filter($declarations, $is_namespace_use_or_group_use_declaration);
      $name = $get_namespace_header($n)
        |> $get_namespace_name($$)
        |> node_get_code_compressed($script, $$)
        |> Str\trim($$, '\\');
      $parent = C\find(
        node_get_ancestors($script, $n),
        $a ==> C\contains_key($namespaces, node_get_source_order($a)),
      )
        |> $$ is null ? null : $namespaces[node_get_source_order($$)];
      $namespaces[node_get_source_order($n)] = new NamespaceResolution(
        $n,
        $end,
        $name === '' ? '' : $name.'\\',
        $to_use_infos($uses),
        $parent,
      );
    }
    $namespaces = Vec\reverse($namespaces);
    $namespaces[] = $fallback;
    return $namespaces;
  }();

  $get_closest_namespace = $node ==>
    C\find($namespaces, $n ==> $n->isInRange($node));

  $is_a_parent_that_should_be_resolved_as_is = create_syntax_matcher(
    $script,
    KIND_CONTEXT_CONST_DECLARATION,
    KIND_ENUMERATOR,
    KIND_ENUM_CLASS_ENUMERATOR,
    KIND_MARKUP_SUFFIX,
    KIND_MEMBER_SELECTION_EXPRESSION,
    KIND_NAMESPACE_GROUP_USE_DECLARATION,
    KIND_NAMESPACE_USE_CLAUSE,
    KIND_QUALIFIED_NAME,
    KIND_SAFE_MEMBER_SELECTION_EXPRESSION,
    KIND_SCOPE_RESOLUTION_EXPRESSION,
    KIND_TYPE_PARAMETER,
    KIND_TYPE_CONSTANT,
    KIND_ENUM_CLASS_LABEL,
    KIND_TYPE_CONST_DECLARATION,
  );

  $get_a_member_that_should_be_resolved_as_is = create_member_accessor(
    $script,
    MEMBER_CONTEXT_CONST_NAME,
    MEMBER_ENUM_CLASS_ENUMERATOR_NAME,
    MEMBER_ENUMERATOR_NAME,
    MEMBER_MARKUP_SUFFIX_NAME,
    MEMBER_MEMBER_NAME,
    MEMBER_NAMESPACE_GROUP_USE_PREFIX,
    MEMBER_NAMESPACE_USE_ALIAS,
    MEMBER_SAFE_MEMBER_NAME,
    MEMBER_SCOPE_RESOLUTION_NAME,
    MEMBER_TYPE_NAME,
    MEMBER_TYPE_CONSTANT_RIGHT_TYPE,
    MEMBER_ENUM_CLASS_LABEL_EXPRESSION,
    MEMBER_TYPE_CONST_NAME,
  );

  // Many places where a name token can appear don't need to be resolved,
  // for example `$x->noNeedToResolveThisUseAsIs`.
  $is_classish_body = create_syntax_matcher($script, KIND_CLASSISH_BODY);
  $is_constant_declarator =
    create_syntax_matcher($script, KIND_CONSTANT_DECLARATOR);
  $get_constant_name =
    create_member_accessor($script, MEMBER_CONSTANT_DECLARATOR_NAME);
  $should_be_resolved_as_is = ($grand_parent, $parent, $node) ==>
    $is_a_parent_that_should_be_resolved_as_is($parent) &&
      $get_a_member_that_should_be_resolved_as_is($parent) === $node ||
    // This check needs to be performed separately, because KIND_NAMESPACE_USE_CLAUSE
    // has two members that need to be resolved as-is, alias and name.
    // You therefore can't include this in the member accessor.
    $is_namespace_use_clause($parent) &&
      $get_namespace_use_name($parent) === $node ||
    // Class constants are members; top-level constants are declarations.
    $is_constant_declarator($parent) &&
      $get_constant_name($parent) === $node &&
      C\any(node_get_ancestors($script, $parent), $is_classish_body) ||
    // Function names are resolved using local rules, but method names are as-is.
    $is_methodish_declaration($grand_parent) &&
      $is_function_declaration_header($parent) &&
      $get_function_name($parent) === $node ||
    // Namespace declarations that aren't namespace blocks don't inherit prefixes.
    $is_namespace_declaration_header($parent) &&
      !$is_namespace_body($get_namespace_body($grand_parent));

  $is_a_parent_that_should_be_resolved_locally = create_syntax_matcher(
    $script,
    KIND_ALIAS_DECLARATION,
    KIND_CLASSISH_DECLARATION,
    KIND_CONTEXT_ALIAS_DECLARATION,
    KIND_CONSTANT_DECLARATOR,
    KIND_ENUM_CLASS_DECLARATION,
    KIND_ENUM_DECLARATION,
    KIND_FUNCTION_DECLARATION_HEADER,
    KIND_NAMESPACE_DECLARATION_HEADER,
    KIND_TYPE_CONST_DECLARATION,
  );

  $get_a_member_that_should_be_resolved_locally = create_member_accessor(
    $script,
    MEMBER_ALIAS_NAME,
    MEMBER_CLASSISH_NAME,
    MEMBER_CTX_ALIAS_NAME,
    MEMBER_CONSTANT_DECLARATOR_NAME,
    MEMBER_ENUM_CLASS_NAME,
    MEMBER_ENUM_NAME,
    MEMBER_FUNCTION_NAME,
    MEMBER_NAMESPACE_NAME,
    MEMBER_TYPE_CONST_NAME,
  );

  // In declarations, the declared name should be resolved in the local namespace.
  // `namespace A; function b(): void {}` is `\A\b`.
  $should_be_resolved_with_local_rules = ($parent, $node) ==>
    $is_a_parent_that_should_be_resolved_locally($parent) &&
    $get_a_member_that_should_be_resolved_locally($parent) === $node;

  $resolve_name = $n ==> {
    $name_text = node_get_code_compressed($script, $n);
    $parent = node_get_parent($script, $n) |> as_syntax($$);
    $grand_parent = syntax_get_parent($script, $parent);

    if ($should_be_resolved_as_is($grand_parent, $parent, $n)) {
      return $name_text;
    }

    if ($is_namespace_declaration_header($parent)) {
      return node_get_parent($script, $grand_parent)
        |> $get_closest_namespace($$)
        |> $$ is null ? $name_text : $$->getName().$name_text;
    }

    if ($should_be_resolved_with_local_rules($parent, $n)) {
      return $get_closest_namespace($n)
        |> $$ is null ? $name_text : $$->getName().$name_text;
    }

    return null;
  };

  // Bind each generic list to its lexical owner. A function header's
  // parameters also scope over its body, so use the enclosing declaration.
  $is_type_parameters = create_syntax_matcher($script, KIND_TYPE_PARAMETERS);
  $get_type_name = create_member_accessor($script, MEMBER_TYPE_NAME);
  $is_lambda_signature = create_syntax_matcher($script, KIND_LAMBDA_SIGNATURE);
  $generic_scopes = dict[];
  foreach (
    index_get_nodes_by_kind($syntax_index, KIND_TYPE_PARAMETER) as $parameter
  ) {
    $list = C\find(
      node_get_syntax_ancestors($script, $parameter),
      $is_type_parameters,
    );
    if ($list is null) {
      continue;
    }
    $owner = node_get_parent($script, $list) |> as_syntax($$);
    if (
      $is_function_declaration_header($owner) || $is_lambda_signature($owner)
    ) {
      $owner = node_get_parent($script, $owner) |> as_syntax($$);
    }
    $owner_id = node_get_id($owner);
    $bindings = idx($generic_scopes, $owner_id, dict[]);
    $bindings[node_get_code_compressed($script, $get_type_name($parameter))] =
      $parameter;
    $generic_scopes[$owner_id] = $bindings;
  }

  return index_get_nodes_by_kind($token_index, KIND_NAME)
    |> Vec\map(
      $$,
      $n ==> node_get_ancestors($script, $n)
        |> C\find($$, $is_qualified_name) ?? $n,
    )
    |> Vec\unique_by($$, node_get_id<>)
    |> Dict\pull($$, $resolve_name, node_get_id<>)
    |> Dict\filter_nulls($$)
    |> new NameResolverV2(
      $script,
      $namespaces,
      $$,
      $aliased_namespaces,
      $auto_imported_functions,
      $auto_imported_types,
      $generic_scopes,
    )
    |> _Private\resolver_hide($$);
}
