/** portable-hack-ast-extras is MIT licensed, see /LICENSE. */
namespace HTL\Pha\Tests;

use type Facebook\HackTest\{DataProvider, HackTest};
use namespace HH\Lib\C;
use namespace HTL\Pha;

final class ResolveTest extends HackTest {
  public function provide_resolve_name()[]: vec<(string, string)> {
    // The last name is always picked.
    return vec[
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
        // Generics are resolved as-if they were normal names in the namespace.
        // The caller is responsible for bookinging bound names in scope.
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
    ];
  }

  <<DataProvider('provide_resolve_name')>>
  public function test_resolve_name(
    string $code,
    string $expected_name,
  )[]: void {
    list($script, $token_index, $resolver) = static::parse($code);
    $is_qualified_name =
      Pha\create_syntax_matcher($script, Pha\KIND_QUALIFIED_NAME);

    $name = Pha\index_get_nodes_by_kind($token_index, Pha\KIND_NAME)
      |> C\lastx($$)
      |> C\find(Pha\node_get_ancestors($script, $$), $is_qualified_name) ?? $$
      |> Pha\resolve_name($resolver, $script, $$);

    expect($name)->toEqual($expected_name);
  }

  private static function parse(
    string $code,
  )[]: (Pha\Script, Pha\TokenIndex, Pha\Resolver) {
    $ctx = Pha\create_context();
    list($script, $ctx) = Pha\parse($code, $ctx);
    $syntax_index = Pha\create_syntax_kind_index($script);
    $token_index = Pha\create_token_kind_index($script);
    $resolver = Pha\create_name_resolver($script, $syntax_index, $token_index);
    return tuple($script, $token_index, $resolver);
  }
}
