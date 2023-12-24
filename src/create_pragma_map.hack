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
    create_member_accessor($script, MEMBER_FUNCTION_CALL_ARGUMENT_LIST);
  $get_function_call_receiver =
    create_member_accessor($script, MEMBER_FUNCTION_CALL_RECEIVER);
  $get_constructor_arguments =
    create_member_accessor($script, MEMBER_CONSTRUCTOR_CALL_ARGUMENT_LIST);
  $get_constructor_type =
    create_member_accessor($script, MEMBER_CONSTRUCTOR_CALL_TYPE);
  $get_vec_members =
    create_member_accessor($script, MEMBER_VECTOR_INTRINSIC_MEMBERS);

  $parse_arguments = $node_list ==>
    list_get_items_of_children($script, $node_list)
    |> Vec\map($$, $a ==> node_get_code_compressed($script, $a));

  $parse_attributes = () ==> {
    $pragma_to_scope = $p ==> syntax_get_parent($script, $p)
      |> syntax_get_parent($script, $$)
      |> syntax_get_parent($script, $$)
      |> syntax_get_parent($script, $$)
      |> node_get_source_range($script, $$)
      |> source_range_to_line_and_column_numbers($script, $$);

    $pragmas = index_get_nodes_by_kind($syntax_index, KIND_CONSTRUCTOR_CALL)
      |> Vec\filter(
        $$,
        $c ==> $get_constructor_type($c)
          |> node_get_code_compressed($script, $$) === 'Pragmas',
      );

    $effects = Vec\map(
      $pragmas,
      $p ==> $get_constructor_arguments($p)
        |> as_syntax($$)
        |> list_get_items_of_children($script, $$)
        |> Vec\map(
          $$,
          $vec ==> as_syntax($vec)
            |> $get_vec_members($$)
            |> as_syntax($$)
            |> $parse_arguments($$),
        ),
    );

    $out = vec[];
    foreach ($pragmas as $i => $pragma) {
      $scope = $pragma_to_scope($pragma);
      foreach ($effects[$i] as $effect) {
        $out[] = tuple($pragma, $scope, $effect);
      }
    }

    return $out;
  };

  $parse_directives = () ==> {
    $pragma_to_scope = $p ==> node_get_ancestors($script, $p)
      |> C\find($$, $is_expression_statement) ?? $p
      |> node_get_source_range($script, $$)
      |> source_range_to_line_and_column_numbers($script, $$)
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
      $p ==> $get_function_call_arguments($p)
        |> as_syntax($$)
        |> $parse_arguments($$),
    );

    return _Private\three_way_zip(
      $pragmas,
      Vec\map($pragmas, $pragma_to_scope),
      $effects,
    );
  };

  $pragma_lines = vec[];

  if (Str\contains($source, 'use type HTL\\Pragma\\Pragmas;')) {
    $pragma_lines = $parse_attributes();
  }

  if (Str\contains($source, 'use function HTL\\Pragma\\pragma;')) {
    $pragma_lines = Vec\concat($pragma_lines, $parse_directives());
  }

  return new PragmaMap($pragma_lines);
}
