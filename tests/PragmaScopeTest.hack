/** portable-hack-ast-extras is MIT licensed, see /LICENSE. */
namespace HTL\Pha\Tests;

use namespace HH\Lib\{C, Str, Vec};
use namespace HTL\{Pha, TestChain};

<<TestChain\Discover>>
function pragma_scope_test(TestChain\Chain $chain)[]: TestChain\Chain {
  return $chain->group(__FUNCTION__)
    ->testWith2Params(
      'scope_lines',
      () ==> vec[
        tuple(
          "use function HTL\\Pragma\\pragma;\n// leading\npragma('X');\nfoo();\nbar();\n",
          vec[2, 3],
        ),
        tuple(
          "use function HTL\\Pragma\\pragma;\npragma(\n  'X',\n);\n\nfoo();\n",
          vec[1, 2, 3, 4],
        ),
        tuple(
          "use function HTL\\Pragma\\pragma;\r\npragma('X');\r\nfoo();\r\nbar();\r\n",
          vec[1, 2],
        ),
        tuple("use function HTL\\Pragma\\pragma;\npragma('X');", vec[1, 2]),
        tuple(
          "use type HTL\\Pragma\\Pragmas;\n// leading\n<<Pragmas(vec['X'])>>\nfunction f(): void {}\nfunction g(): void {}\n",
          vec[2, 3],
        ),
        tuple(
          "use type HTL\\Pragma\\Pragmas;\r\n<<Pragmas(vec['X'])>>\r\nclass C {\r\n  public function f(): void {}\r\n}\r\n// trailing\r\nclass D {}",
          vec[1, 2, 3, 4],
        ),
        tuple(
          "use type HTL\\Pragma\\Pragmas;\nclass C {\n  // leading\n  <<Pragmas(vec['X'])>>\n  public function f(): void {}\n  public function g(): void {}\n}\n",
          vec[3, 4],
        ),
        tuple(
          "use type HTL\\Pragma\\Pragmas;\n<<Pragmas(vec['X'])>> function f(): void {} function g(): void {}",
          vec[1],
        ),
        tuple(
          "use type HTL\\Pragma\\Pragmas;\n<<file: Pragmas(vec['X'])>>\nfunction f(): void {}\n",
          vec[0, 1, 2, 3],
        ),
      ],
      ($source, $expected) ==> {
        list($script, $_) = Pha\parse($source, Pha\create_context());
        $map =
          Pha\create_pragma_map($script, Pha\create_syntax_kind_index($script));
        $actual = vec[];
        // Also query one line beyond EOF to catch inclusive-end spillover.
        foreach (
          Vec\range(0, Str\split($source, "\n") |> C\count($$)) as $line
        ) {
          $matches = $map->getOverlappingPragmas(
            new Pha\LineAndColumnNumbers($line, 0, $line, 1),
          );
          if (!C\is_empty($matches)) {
            expect($matches)->toEqual(vec[vec["'X'"]]);
            $actual[] = $line;
          }
        }
        expect($actual)->toEqual($expected);
      },
    );
}
