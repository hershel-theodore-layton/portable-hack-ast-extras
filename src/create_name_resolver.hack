/** portable-hack-ast-extras is MIT licensed, see /LICENSE. */
namespace HTL\Pha;

use namespace HH\Lib\{C, Dict, Str, Vec};
use type HTL\Pha\_Private\{NameResolver, NamespaceResolution, UseInfo, UseKind};

/**
 * @param $aliased_namespaces When using the `hhvm.aliased_namespaces` ini +
 * `auto_namespace_map` hhconfig settings, some default namespaces are used.
 * So for example, mapping `Vec` to `HH\Lib\Vec` acts as if every file started
 * with `if (!exists(use clause "Vec")) use namespace HH\Lib\Vec as Vec;`.
 * You can pass the result of `\ini_get("hhvm.aliased_namespaces")` to make
 * `resolve_names` take your pre resolved names into account.
 *
 * @param $auto_imported_functions a list of functions that are available in any
 * hack file without an explicit use clause. If your hhvm version has different
 * auto imported names, and you care, you can pass a different list of names.
 *
 * @param $auto_imported_types a list of types that are available in any
 * hack file without an explicit use clause. If your hhvm version has different
 * auto imported names, and you care, you can pass a different list of names.
 */
function create_name_resolver(
  Script $script,
  SyntaxIndex $syntax_index,
  TokenIndex $token_index,
  dict<string, string> $aliased_namespaces = dict[],
  ?keyset<string> $auto_imported_functions = null,
  ?keyset<string> $auto_imported_types = null,
)[]: Resolver {
  $auto_imported_functions = _Private\AUTO_IMPORTED_FUNCTIONS;
  $auto_imported_types = _Private\AUTO_IMPORTED_TYPES;

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
  $is_qualfied_name = create_syntax_matcher($script, KIND_QUALIFIED_NAME);
  $is_type = create_token_matcher($script, KIND_TYPE);

  $get_function_name = create_member_accessor($script, MEMBER_FUNCTION_NAME);
  $get_namespace_body = create_member_accessor($script, MEMBER_NAMESPACE_BODY);
  $get_namespace_declarations =
    create_member_accessor($script, MEMBER_NAMESPACE_DECLARATIONS);
  $get_namespace_group_use_prefix =
    create_member_accessor($script, MEMBER_NAMESPACE_GROUP_USE_PREFIX);
  $get_namespace_header =
    create_member_accessor($script, MEMBER_NAMESPACE_HEADER);
  $get_namespace_name = create_member_accessor($script, MEMBER_NAMESPACE_NAME);
  $get_namespace_use_clauses = create_member_accessor(
    $script,
    MEMBER_NAMESPACE_USE_CLAUSES,
    MEMBER_NAMESPACE_GROUP_USE_CLAUSES,
  );
  $get_namespace_use_alias =
    create_member_accessor($script, MEMBER_NAMESPACE_USE_ALIAS);
  $get_namespace_use_name =
    create_member_accessor($script, MEMBER_NAMESPACE_USE_NAME);
  $get_namespace_use_kind = create_member_accessor(
    $script,
    MEMBER_NAMESPACE_USE_KIND,
    MEMBER_NAMESPACE_GROUP_USE_KIND,
  );

  $namespaces = () ==> {
    $declaration_list =
      node_get_first_childx($script, SCRIPT_NODE) |> as_syntax($$);

    $to_use_infos = $uses ==> Vec\map($uses, $use ==> {
      $use = as_syntax($use);
      $kind = $get_namespace_use_kind($use);
      if ($is_const($kind)) {
        $kind = UseKind::CONST;
      } else if ($is_function($kind)) {
        $kind = UseKind::FUNCTION;
      } else if ($is_namespace($kind)) {
        $kind = UseKind::NAMESPACE;
      } else if ($is_type($kind)) {
        $kind = UseKind::TYPE;
      } else {
        $kind = UseKind::NONE;
      }

      if ($is_namespace_group_use_declaration($use)) {
        $prefix = $get_namespace_group_use_prefix($use)
          |> node_get_code_compressed($script, $$);
      } else {
        $prefix = '';
      }

      $make_use_infos_for_kind = ($kind) ==> $get_namespace_use_clauses($use)
        |> as_syntax($$)
        |> list_get_items_of_children($script, $$)
        |> Vec\map($$, as_syntax<>)
        |> Vec\map(
          $$,
          $clause ==> {
            $use_name_text = $get_namespace_use_name($clause)
              |> node_get_code_compressed($script, $$);

            $last_part = Str\split($use_name_text, '\\') |> C\lastx($$);

            $alias = $get_namespace_use_alias($clause);
            if ($is_missing($alias)) {
              $local_name = $last_part;
            } else {
              $local_name = node_get_code_compressed($script, $alias);
            }

            return new UseInfo(
              $kind,
              $clause,
              $kind === UseKind::NAMESPACE
                ? $prefix.$use_name_text
                : Str\strip_suffix($prefix.$use_name_text, $last_part),
              $local_name,
              $last_part,
            );
          },
        );

      return $kind === UseKind::NONE
        ? Vec\concat(
            vec[$make_use_infos_for_kind(UseKind::NAMESPACE)],
            vec[$make_use_infos_for_kind(UseKind::TYPE)],
          )
          |> Vec\flatten($$)
        : $make_use_infos_for_kind($kind);
    })
      |> Vec\flatten($$)
      |> Dict\group_by($$, $u ==> $u->getKind());

    $namespace_blocks =
      index_get_nodes_by_kind($syntax_index, KIND_NAMESPACE_DECLARATION)
      |> Vec\map($$, $n ==> {
        $scope = $get_namespace_body($n)
          |> $is_namespace_body($$)
            ? as_syntax($$)
              |> $get_namespace_declarations($$)
              |> as_syntax($$)
            : $declaration_list;

        $uses = node_get_children($script, $scope)
          |> Vec\filter($$, $is_namespace_use_or_group_use_declaration);

        $name = $get_namespace_header($n)
          |> as_syntax($$)
          |> $get_namespace_name($$)
          |> node_get_code_compressed($script, $$).'\\';

        return shape(
          'namespace' =>
            $is_namespace_body($get_namespace_body($n)) ? $n : SCRIPT_NODE,
          'scope' => $scope,
          'uses' => $to_use_infos($uses),
          'name' => $name,
        );
      });

    if (C\is_empty($namespace_blocks)) {
      $namespace_blocks = vec[
        shape(
          'namespace' => SCRIPT_NODE,
          'scope' => $declaration_list,
          'uses' => $to_use_infos(
            node_get_children($script, $declaration_list)
              |> Vec\filter($$, $is_namespace_use_or_group_use_declaration),
          ),
          'name' => '',
        ),
      ];
    }

    $namespaces = dict[];

    foreach ($namespace_blocks as $block) {
      $parent = C\find(
        node_get_ancestors($script, $block['namespace']),
        $a ==> C\contains_key($namespaces, node_get_source_order($a)),
      )
        |> $$ is null ? null : $namespaces[node_get_source_order($$)];

      $namespaces[node_get_source_order($block['namespace'])] =
        new NamespaceResolution(
          $block['scope'],
          node_get_last_descendant_or_self($script, $block['scope']),
          $block['name'],
          $block['uses'],
          $parent,
        );
    }

    return Vec\reverse($namespaces);
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
  );

  // Many places where a name token can appear don't need to be resolved,
  // for example `$x->noNeedToResolveThisUseAsIs`.
  $should_be_resolved_as_is = ($grand_parent, $parent, $node) ==>
    $is_a_parent_that_should_be_resolved_as_is($parent) &&
      $get_a_member_that_should_be_resolved_as_is($parent) === $node ||
    // This check needs to be performed separately, because KIND_NAMESPACE_USE_CLAUSE
    // has two members that need to be resolved as-is, alias and name.
    // You therefore can't include this in the member accessor.
    $is_namespace_use_clause($parent) &&
      $get_namespace_use_name($parent) === $node ||
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

    if ($should_be_resolved_with_local_rules($parent, $n)) {
      return $get_closest_namespace($n)
        |> $$ is null ? $name_text : $$->getName().$name_text;
    }

    return null;
  };

  return index_get_nodes_by_kind($token_index, KIND_NAME)
    |> Vec\map(
      $$,
      $n ==> node_get_ancestors($script, $n)
        |> C\find($$, $is_qualfied_name) ?? $n,
    )
    |> Vec\unique_by($$, node_get_id<>)
    |> Dict\pull($$, $resolve_name, node_get_id<>)
    |> Dict\filter_nulls($$)
    |> new NameResolver(
      $script,
      $namespaces,
      $$,
      $aliased_namespaces,
      $auto_imported_functions,
      $auto_imported_types,
    )
    |> _Private\resolver_hide($$);
}
