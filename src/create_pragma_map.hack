/** portable-hack-ast-extras is MIT licensed, see /LICENSE. */
namespace HTL\Pha;

use namespace HH\Lib\{C, Str, Vec};

function create_pragma_map(
  Script $script,
  SyntaxIndex $syntax_index,
)[]: PragmaMap {
  $source = node_get_code($script, SCRIPT_NODE);

  $is_expression_statement =
    create_syntax_matcher($script, KIND_EXPRESSION_STATEMENT);

  $get_function_call_arguments =
    create_member_accessor($script, MEMBER_FUNCTION_CALL_ARGUMENT_LIST)
    |> returns_syntax($$);
  $get_function_call_receiver =
    create_member_accessor($script, MEMBER_FUNCTION_CALL_RECEIVER);
  $get_constructor_arguments =
    create_member_accessor($script, MEMBER_CONSTRUCTOR_CALL_ARGUMENT_LIST)
    |> returns_syntax($$);
  $get_constructor_type =
    create_member_accessor($script, MEMBER_CONSTRUCTOR_CALL_TYPE);
  $get_vec_members =
    create_member_accessor($script, MEMBER_VECTOR_INTRINSIC_MEMBERS)
    |> returns_syntax($$);

  $parse_arguments = $node_list ==>
    list_get_items_of_children($script, $node_list)
    |> Vec\map($$, $a ==> node_get_code_compressed($script, $a));

  // Scope starts at syntax, not attached comments, and ends on the last
  // token's actual line. Token text ranges have exclusive endpoints.
  $get_scope = $node ==> {
    if ($node === SCRIPT_NODE) {
      return node_get_line_and_column_numbers($script, $node);
    }
    $tokens = node_get_descendants($script, $node)
      |> Vec\filter($$, is_token<>)
      |> Vec\map($$, as_token<>);
    $first = C\firstx($tokens)
      |> token_get_text_trivium($script, $$)
      |> node_get_line_and_column_numbers($script, $$);
    $last = C\lastx($tokens)
      |> token_get_text_trivium($script, $$)
      |> node_get_line_and_column_numbers($script, $$);
    return new LineAndColumnNumbers(
      $first->getStartLine(),
      $first->getStartColumn(),
      $last->getEndLine() - ($last->getEndColumn() === 0 ? 1 : 0),
      $last->getEndColumn(),
    );
  };

  $parse_attributes = () ==> {
    $is_vec = create_syntax_matcher($script, KIND_VECTOR_INTRINSIC_EXPRESSION);
    $pragmas = vec[];
    $diagnostics = vec[];
    foreach (
      index_get_nodes_by_kind($syntax_index, KIND_CONSTRUCTOR_CALL) as $pragma
    ) {
      if (
        node_get_code_compressed($script, $get_constructor_type($pragma)) !==
          'Pragmas'
      ) {
        continue;
      }
      // A constructor must be an immediate attribute-list item. Merely having
      // an annotated declaration as an ancestor also matches ordinary `new`.
      $item = syntax_get_parent($script, $pragma);
      if (node_get_kind($script, $item) !== KIND_LIST_ITEM) {
        continue;
      }
      $list = syntax_get_parent($script, $item);
      if (node_get_kind($script, $list) !== KIND_NODE_LIST) {
        continue;
      }
      $spec = syntax_get_parent($script, $list);
      $kind = node_get_kind($script, $spec);
      if ($kind === KIND_FILE_ATTRIBUTE_SPECIFICATION) {
        $scope = $get_scope(SCRIPT_NODE);
      } else if ($kind === KIND_OLD_ATTRIBUTE_SPECIFICATION) {
        $declaration = syntax_get_parent($script, $spec);
        if (
          !C\contains(
            keyset[
              KIND_CLASSISH_DECLARATION,
              KIND_ENUM_DECLARATION,
              KIND_ENUM_CLASS_DECLARATION,
              KIND_FUNCTION_DECLARATION,
              KIND_METHODISH_DECLARATION,
            ],
            node_get_kind($script, $declaration),
          )
        ) {
          continue;
        }
        $scope = $get_scope($declaration);
      } else {
        continue;
      }
      foreach (
        list_get_items_of_children(
          $script,
          $get_constructor_arguments($pragma),
        ) as $argument
      ) {
        if (!$is_vec($argument)) {
          $diagnostics[] = new PragmaExtractionDiagnostic(
            $pragma,
            $argument,
            'Expected a vec literal; constant expressions are not evaluated.',
          );
          continue;
        }
        $effect = $get_vec_members(as_syntax($argument))
          |> $parse_arguments($$);
        $pragmas[] = tuple($pragma, $scope, $effect);
      }
    }
    return tuple($pragmas, $diagnostics);
  };

  $parse_directives = () ==> {
    $pragma_to_scope = $p ==> node_get_ancestors($script, $p)
      |> C\find($$, $is_expression_statement) ?? $p
      |> $get_scope($$)
      |> new LineAndColumnNumbers(
        $$->getStartLine(),
        $$->getStartColumn(),
        $$->getEndLine() + 1,
        $$->getEndColumn(),
      );

    $pragmas =
      index_get_nodes_by_kind($syntax_index, KIND_FUNCTION_CALL_EXPRESSION)
      |> Vec\filter(
        $$,
        $f ==> $get_function_call_receiver($f)
          |> node_get_code_compressed($script, $$) === 'pragma',
      );

    $effects = Vec\map(
      $pragmas,
      $p ==> $get_function_call_arguments($p) |> $parse_arguments($$),
    );

    return _Private\three_way_zip(
      $pragmas,
      Vec\map($pragmas, $pragma_to_scope),
      $effects,
    );
  };

  $pragma_lines = vec[];
  $diagnostics = vec[];

  if (Str\contains($source, 'use type HTL\\Pragma\\Pragmas;')) {
    list($pragma_lines, $diagnostics) = $parse_attributes();
  }

  if (Str\contains($source, 'use function HTL\\Pragma\\pragma;')) {
    $pragma_lines = Vec\concat($pragma_lines, $parse_directives());
  }

  return new PragmaMap($pragma_lines, $diagnostics);
}
