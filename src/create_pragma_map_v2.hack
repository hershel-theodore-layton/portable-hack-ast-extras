/** portable-hack-ast-extras is MIT licensed, see /LICENSE. */
namespace HTL\Pha;

use namespace HH\Lib\Vec;

function create_pragma_map_v2(
  Script $script,
  SyntaxIndex $syntax_index,
  Resolver $resolver,
)[]: PragmaMap {
  $is_constructor = create_syntax_matcher($script, KIND_CONSTRUCTOR_CALL);
  $get_constructor_type =
    create_member_accessor($script, MEMBER_CONSTRUCTOR_CALL_TYPE);
  $get_simple_type =
    create_member_accessor($script, MEMBER_SIMPLE_TYPE_SPECIFIER);
  $get_function_call_receiver =
    create_member_accessor($script, MEMBER_FUNCTION_CALL_RECEIVER);

  $is_pragma = (Syntax $node) ==> {
    $is_attribute = $is_constructor($node);
    $name = $is_attribute
      ? $get_constructor_type($node)
        |> as_syntax($$)
        |> $get_simple_type($$)
      : $get_function_call_receiver($node);
    return resolve_name($resolver, $script, $name) ===
      ($is_attribute ? 'HTL\\Pragma\\Pragmas' : 'HTL\\Pragma\\pragma');
  };
  $map = create_pragma_map($script, $syntax_index);
  return new PragmaMap(
    Vec\filter($map->getAllPragmas(), $pragma ==> $is_pragma($pragma[0])),
    Vec\filter(
      $map->getExtractionDiagnostics(),
      $diagnostic ==> $is_pragma($diagnostic->getAttribute()),
    ),
  );
}
