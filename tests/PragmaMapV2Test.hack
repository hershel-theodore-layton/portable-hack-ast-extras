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
    )
    ->testWith2Params(
      'attribute_context_and_arguments',
      () ==> vec[
        tuple(
          "function f(vec<string> \$values): void { new Pragmas(\$values); new Pragmas(vec['ordinary']); }",
          tuple(vec[], vec[]),
        ),
        tuple(
          "<<Pragmas(vec['class'])>> class C { <<Pragmas(vec['method'])>> public function f(): void { new Pragmas(vec['ordinary']); } } <<Pragmas(vec['function'])>> function f(): void {} <<Pragmas(vec['enum'])>> enum E: int { A = 1; } <<Pragmas(vec['enum_class'])>> enum class EC: int { int A = 1; }",
          tuple(
            vec[
              vec["'class'"],
              vec["'method'"],
              vec["'function'"],
              vec["'enum'"],
              vec["'enum_class'"],
            ],
            vec[],
          ),
        ),
        tuple(
          "<<file: Pragmas(vec['file'])>>",
          tuple(vec[vec["'file'"]], vec[]),
        ),
        tuple(
          "<<Pragmas(VALUES, vec['ok'], 1, vec['last'])>> function f(): void {}",
          tuple(vec[vec["'ok'"], vec["'last'"]], vec['VALUES', '1']),
        ),
        tuple(
          "<<Pragmas(new Pragmas(vec['nested']))>> function f(): void {}",
          tuple(vec[], vec["newPragmas(vec['nested'])"]),
        ),
        tuple(
          "<<Pragmas(vec[LIBRARY, 'a'.'b', \"quoted\"])>> function f(): void {}",
          tuple(vec[vec['LIBRARY', "'a'.'b'", '"quoted"']], vec[]),
        ),
        tuple('<<Pragmas()>> function f(): void {}', tuple(vec[], vec[])),
        tuple(
          "class C { <<Pragmas(vec['property'])>> public int \$p = 0; public function f(<<Pragmas(vec['parameter'])>> int \$p): void {} }",
          tuple(vec[], vec[]),
        ),
        tuple(
          "<<__EntryPoint, Pragmas(vec['entry'])>> function main(): void {}",
          tuple(vec[vec["'entry'"]], vec[]),
        ),
        tuple(
          "<<Pragmas(VALUES)>> function f(): void {} <<Pragmas(vec['later'])>> function g(): void {}",
          tuple(vec[vec["'later'"]], vec['VALUES']),
        ),

      ],
      ($source, $expected) ==> {
        $source = 'use type HTL\\Pragma\\Pragmas; '.$source;
        list($script, $_) = Pha\parse($source, Pha\create_context());
        $index = Pha\create_syntax_kind_index($script);
        $resolver = Pha\create_name_resolver_v2(
          $script,
          $index,
          Pha\create_token_kind_index($script),
        );
        foreach (
          vec[
            Pha\create_pragma_map($script, $index),
            Pha\create_pragma_map_v2($script, $index, $resolver),
          ] as $map
        ) {
          expect($map->getAllPragmas() |> Vec\map($$, $p ==> $p[2]))
            ->toEqual($expected[0]);
          expect(
            $map->getExtractionDiagnostics()
              |> Vec\map(
                $$,
                $d ==> Pha\node_get_code_compressed($script, $d->getArgument()),
              ),
          )->toEqual($expected[1]);
          foreach ($map->getExtractionDiagnostics() as $diagnostic) {
            expect(Pha\node_get_kind($script, $diagnostic->getAttribute()))
              ->toEqual(Pha\KIND_CONSTRUCTOR_CALL);
            expect($diagnostic->getMessage())
              ->toEqual(
                'Expected a vec literal; constant expressions are not evaluated.',
              );
          }
        }
      },
    )
    ->test(
      'diagnostics_follow_resolved_imports',
      () ==> {
        $source =
          'namespace A { use type HTL\\Pragma\\Pragmas; <<Pragmas(VALUES)>> function f(): void {} } namespace B { class Pragmas {} <<Pragmas(OTHER)>> function g(): void {} }';
        list($script, $_) = Pha\parse($source, Pha\create_context());
        $index = Pha\create_syntax_kind_index($script);
        $resolver = Pha\create_name_resolver_v2(
          $script,
          $index,
          Pha\create_token_kind_index($script),
        );
        $map = Pha\create_pragma_map_v2($script, $index, $resolver);
        expect($map->getAllPragmas())->toEqual(vec[]);
        expect(
          $map->getExtractionDiagnostics()
            |> Vec\map(
              $$,
              $d ==> Pha\node_get_code_compressed($script, $d->getArgument()),
            ),
        )
          ->toEqual(vec['VALUES']);
      },
    );
}
