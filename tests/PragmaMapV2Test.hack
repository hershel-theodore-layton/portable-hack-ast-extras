/** portable-hack-ast-extras is MIT licensed, see /LICENSE. */
namespace HTL\Pha\Tests;

use namespace HH\Lib\Vec;
use namespace HTL\{Pha, TestChain};

<<TestChain\Discover>>
function pragma_map_v2_test(TestChain\Chain $chain)[]: TestChain\Chain {
  return $chain->group(__FUNCTION__)
    ->testWith2Params(
      'resolved_pragmas',
      () ==> vec[
        tuple(
          "namespace A; use function HTL\\Pragma\\pragma; pragma('A'); namespace B; pragma('B');",
          vec[vec["'A'"]],
        ),
        tuple(
          "namespace A; use function HTL\\Pragma\\pragma; pragma('A'); namespace A; pragma('B');",
          vec[vec["'A'"]],
        ),
        tuple(
          "namespace A { use type HTL\\Pragma\\Pragmas; <<Pragmas(vec['A'])>> function f(): void {} } namespace B { <<Pragmas(vec['B'])>> function g(): void {} }",
          vec[vec["'A'"]],
        ),
        tuple(
          "use type HTL\\Pragma\\Pragmas; use function HTL\\Pragma\\pragma; <<Pragmas(vec['attribute'])>> function f(): void {} pragma('call');",
          vec[vec["'attribute'"], vec["'call'"]],
        ),
        tuple("// use function HTL\\Pragma\\pragma;\npragma('X');", vec[]),
        tuple(
          "namespace A; use type HTL\\Pragma\\Pragmas; <<file: Pragmas(vec['file'])>>",
          vec[vec["'file'"]],
        ),
        tuple('function f(): void {}', vec[]),
      ],
      ($source, $expected) ==> {
        list($script, $_) = Pha\parse($source, Pha\create_context());
        $syntax_index = Pha\create_syntax_kind_index($script);
        $resolver = Pha\create_name_resolver_v2(
          $script,
          $syntax_index,
          Pha\create_token_kind_index($script),
        );
        $actual = Pha\create_pragma_map_v2($script, $syntax_index, $resolver)
          ->getAllPragmas()
          |> Vec\map($$, $pragma ==> $pragma[2]);
        expect($actual)->toEqual($expected);
      },
    );
}
