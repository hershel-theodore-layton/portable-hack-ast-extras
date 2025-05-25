/** portable-hack-ast-extras is MIT licensed, see /LICENSE. */
namespace HTL\Pha\Tests;

use namespace HH\Lib\{C, Vec};
use namespace HTL\{Pha, TestChain};

<<TestChain\Discover>>
function resolve_test(TestChain\Chain $chain)[]: TestChain\Chain {
  return $chain->group(__FUNCTION__)
    ->testWith2Params(
      'provide_resolve_name',
      () ==> vec[
        tuple(
          'namespace Toplevel\Namespaces\AreResolved\AsIs;',
          'Toplevel\Namespaces\AreResolved\AsIs',
        ),
        tuple(
          'namespace Nested { namespace Namespaces { } }',
          'Nested\Namespaces',
        ),
        tuple(
          'namespace A { namespace B { } namespace C { const int D = 4; } }',
          'A\C\D',
        ),

        tuple(
          'namespace A; use namespace SomeNamespace; const int C = SomeNamespace\C;',
          'SomeNamespace\C',
        ),
        tuple(
          'namespace A; use namespace Some\Name\Space; const int C = Space\C;',
          'Some\Name\Space\C',
        ),
        tuple(
          'namespace A; use namespace Some\Name\Space as S; const int C = S\K;',
          'Some\Name\Space\K',
        ),

        tuple(
          'namespace A; use const SOME_CONST; const int C = SOME_CONST;',
          'SOME_CONST',
        ),
        tuple(
          'namespace A; use const Some\Name\Space\X; const int C = X;',
          'Some\Name\Space\X',
        ),
        tuple(
          'namespace A; use const Some\Name\Space\X as S; const int C = S;',
          'Some\Name\Space\X',
        ),

        tuple(
          'namespace A; use function some_func; const mixed C = some_func<>;',
          'some_func',
        ),
        tuple(
          'namespace A; use function Some\Name\Space\x; const mixed C = x<>;',
          'Some\Name\Space\x',
        ),
        tuple(
          'namespace A; use function Some\Name\Space\x as s; const mixed C = s<>;',
          'Some\Name\Space\x',
        ),

        tuple(
          'namespace A; use namespace LongNamespace; const int C = LongNamespace\C;',
          'LongNamespace\C',
        ),
        tuple(
          'namespace A; use namespace Some\Name\Space; const int C = Space\C;',
          'Some\Name\Space\C',
        ),
        tuple(
          'namespace A; use namespace Some\Name\Space as None; const int C = None\C;',
          'Some\Name\Space\C',
        ),

        tuple(
          'namespace A { namespace B { use const C\D\E; const int X = E; }}',
          'C\D\E',
        ),

        tuple(
          'namespace Some\Name\Space; function func1(): void {}',
          'Some\Name\Space\func1',
        ),
        tuple(
          'namespace Some\Name\Space; function func1(): RetType {}',
          'Some\Name\Space\RetType',
        ),

        tuple(
          'namespace MyApp; use type HT\ML\div; function func1(): mixed { return <div /> }',
          'HT\ML\div',
        ),
        tuple(
          'namespace MyApp; use namespace HT\ML; function func1(): mixed { return <ML:div /> }',
          'HT\ML\div',
        ),
        tuple(
          'namespace MyApp; function func1(): mixed { return <:HT:ML:div /> }',
          'HT\ML\div',
        ),
        tuple(
          'namespace MyApp; use type HT\ML\div; function func1(): div {}',
          'HT\ML\div',
        ),
        // The test case `function func1(): ML:div {}` is intentionally missing.
        // This is a parse error in the Hack typechecker.
        tuple('namespace MyApp; function func1(): :HT:ML:div {}', 'HT\ML\div'),

        tuple('namespace MyApp; final xhp class Element {}', 'MyApp\Element'),
        tuple(
          'namespace MyApp; final xhp class Ui:Element {}',
          'MyApp\Ui\Element',
        ),
        tuple(
          'namespace MyApp; final xhp class Element { attribute :HT:ML:div; }',
          'HT\ML\div',
        ),

        tuple(
          // Generics are resolved as-if they were normal names in the namespace.
          // The caller is responsible for bookkeeping bound names in scope.
          'namespace Some\Name\Space; function func1<T>(): T {}',
          'Some\Name\Space\T',
        ),
        tuple(
          // The `_` name is special
          'namespace A; function long_function_name(): void { A as vec<_>; }',
          '_',
        ),
        tuple(
          // Attributes starting with `__` are special.
          'namespace A; function func1(): void { <<__Attribute>> () ==> 0; }',
          '__Attribute',
        ),
        tuple(
          'namespace A; function func1(): void { <<_Attribute>> () ==> 0; }',
          'A\_Attribute',
        ),
        tuple(
          // The same goes for constants with a double underscore.
          'namespace A; function func1(): void { __FUNCTION_CREDENTIAL__; }',
          '__FUNCTION_CREDENTIAL__',
        ),
        tuple(
          'namespace A; function func1(): void { _FUNCTION_CREDENTIAL_; }',
          'A\_FUNCTION_CREDENTIAL_',
        ),

        tuple(
          'namespace A; use No\Kind; function func1(): void { Kind\Ness; }',
          'No\Kind\Ness',
        ),
        tuple(
          'namespace A; use Please\Dont; function func1(): Dont { }',
          'Please\Dont',
        ),
        tuple(
          'namespace A; function contexts()[write_props]: void {}',
          'write_props',
        ),
        tuple('namespace A; function regex(): void { re"/a/"; }', 're'),
        tuple(
          'namespace A; use type My\Dsl; function dsl(): void { Dsl`1`; }',
          'My\\Dsl',
        ),

        tuple(
          // Invariant pseudo syntax
          'namespace A; function func1(): void { invariant(true, "Indeed"); }',
          'invariant',
        ),
        tuple(
          // Exit pseudo syntax
          'namespace A; function func1(): void { write_test(); exit(); }',
          'exit',
        ),
        tuple(
          // Auto imported type
          'namespace A; function func1(): InvariantException { return 0; }',
          'InvariantException',
        ),
        tuple(
          // Overwriting auto imported types is evil!
          'namespace A; use type IAmEvil as InvariantException; function func1(): InvariantException { return 0; }',
          'IAmEvil',
        ),
      ],
      (string $code, string $expected_name)[]: void ==> {
        list($script, $token_index, $resolver) = parse($code);

        $name = Vec\concat(
          Pha\index_get_nodes_by_kind($token_index, Pha\KIND_XHP_CLASS_NAME),
          Pha\index_get_nodes_by_kind($token_index, Pha\KIND_XHP_ELEMENT_NAME),
          Pha\index_get_nodes_by_kind($token_index, Pha\KIND_NAME),
        )
          |> Vec\sort_by($$, Pha\node_get_source_order<>)
          |> C\lastx($$)
          |> Pha\resolve_name($resolver, $script, $$);

        expect($name)->toEqual($expected_name);
      },
    );
}

function parse(string $code)[]: (Pha\Script, Pha\TokenIndex, Pha\Resolver) {
  $ctx = Pha\create_context();
  list($script, $ctx) = Pha\parse($code, $ctx);
  $syntax_index = Pha\create_syntax_kind_index($script);
  $token_index = Pha\create_token_kind_index($script);
  $resolver = Pha\create_name_resolver($script, $syntax_index, $token_index);
  return tuple($script, $token_index, $resolver);
}
