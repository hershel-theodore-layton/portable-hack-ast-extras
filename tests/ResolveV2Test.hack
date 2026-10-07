/** portable-hack-ast-extras is MIT licensed, see /LICENSE. */
namespace HTL\Pha\Tests;

use namespace HH;
use namespace HH\Lib\{C, Str, Vec};
use namespace HTL\{Pha, TestChain};

<<TestChain\Discover>>
function resolve_v2_test(TestChain\Chain $chain)[]: TestChain\Chain {
  return $chain->group(__FUNCTION__)
    ->testWith2Params(
      'namespace_and_context_regressions',
      () ==> vec[
        tuple(
          'namespace A; function foo(): Thing {} namespace B; function bar(): Other {}',
          vec['A\foo', 'A\Thing', 'B', 'B\bar', 'B\Other'],
        ),
        tuple(
          'namespace A; use type X\Thing; function f(): Thing {} namespace A; use type Y\Thing; function g(): Thing {} namespace C; function h(): Thing {}',
          vec[
            'A\f',
            'X\Thing',
            'A',
            'Y\Thing',
            'A\g',
            'Y\Thing',
            'C',
            'C\h',
            'C\Thing',
          ],
        ),
        tuple(
          'namespace A; function f(): void { namespace\func(); }',
          vec['A\func'],
        ),
        tuple(
          'namespace A; use namespace B as C; function f(): namespace\C\T {}',
          vec['A\C\T'],
        ),
        tuple(
          'namespace A; use const B\K; function f(): void { namespace\K; }',
          vec['A\K'],
        ),
        tuple(
          'namespace { function f(): namespace\Thing {} }',
          vec['f', 'Thing'],
        ),
        tuple('namespace { function foo(): Thing {} }', vec['foo', 'Thing']),
        tuple(
          'namespace A; use type B\Thing; function f(): void { nameof Thing; }',
          vec['B\Thing'],
        ),
        tuple(
          'namespace A; use type B\Thing; use const C\Thing; type T = Thing::Foo;',
          vec['A\T', 'B\Thing', 'Foo'],
        ),
        tuple(
          'namespace A; use type B\Thing; use const C\Thing; function f(): void { Thing#Label; }',
          vec['B\Thing', 'Label'],
        ),
        tuple(
          'namespace A; class C { const type T = int; const int F = 1; }',
          vec['A\C', 'T', 'F'],
        ),
        tuple(
          'namespace A; class C { const ctx Ctx = []; public function f()[this::Ctx]: void {} }',
          vec['f', 'Ctx'],
        ),
        tuple('namespace A; const int F = 1;', vec['A\F']),
        tuple(
          'namespace A; function f(): void { new __Thing(); }',
          vec['A\__Thing'],
        ),
        tuple(
          'namespace A; <<Foo(new __Thing())>> function f(): void {}',
          vec['A\Foo', 'A\__Thing', 'A\f'],
        ),
        tuple(
          'namespace A; class __Thing {} function f(): __Thing {}',
          vec['A\__Thing', 'A\f', 'A\__Thing'],
        ),
        tuple(
          'namespace A; const int __FOO__ = 1; function f(): void { __FOO__; }',
          vec['A\__FOO__'],
        ),
        tuple(
          'namespace A; use type B\defaults; function f()[defaults::Ctx]: void {}',
          vec['B\defaults', 'Ctx'],
        ),
        tuple(
          'namespace A; function f()[defaults, write_props]: void {}',
          vec['defaults', 'write_props'],
        ),
        tuple(
          'namespace A; <<__EntryPoint>> function f(): void { __FUNCTION_CREDENTIAL__; }',
          vec['__EntryPoint', 'A\f', '__FUNCTION_CREDENTIAL__'],
        ),
        tuple(
          '<<file: Foo>> namespace A { use type B\Foo; function f(): void {} }',
          vec['Foo', 'A', 'B\Foo', 'A\f'],
        ),
        tuple(
          '<<file: Foo>> namespace A {} namespace B {}',
          vec['Foo', 'A', 'B'],
        ),
        tuple(
          '<<file: __EnableUnstableFeatures("x")>> namespace A {}',
          vec['__EnableUnstableFeatures', 'A'],
        ),
        tuple(
          '<<file: Foo>> namespace A { function f():',
          vec['Foo', 'A', 'A\f'],
        ),
        tuple(
          'namespace A { namespace B { use type X\Thing; } function f(): Thing {} }',
          vec['X\Thing', 'A\f', 'A\Thing'],
        ),
      ],
      (string $code, vec<string> $expected)[]: void ==> {
        list($script, $tokens, $resolver) = parse($code, true);
        // HHVM 4 parsers do not yet support nameof expressions.
        if (
          Str\contains($code, 'nameof ') &&
          C\is_empty(Pha\index_get_nodes_by_kind(
            Pha\create_syntax_kind_index($script),
            Pha\KIND_NAMEOF_EXPRESSION,
          ))
        ) {
          return;
        }
        $is_qualified =
          Pha\create_syntax_matcher($script, Pha\KIND_QUALIFIED_NAME);
        $names = Pha\index_get_nodes_by_kind($tokens, Pha\KIND_NAME)
          |> Vec\map(
            $$,
            $n ==>
              C\find(Pha\node_get_ancestors($script, $n), $is_qualified) ?? $n,
          )
          |> Vec\unique_by($$, Pha\node_get_id<>)
          |> Vec\sort_by($$, Pha\node_get_source_order<>);
        $names = Vec\slice($names, C\count($names) - C\count($expected));
        expect(Vec\map($names, $n ==> Pha\resolve_name($resolver, $script, $n)))
          ->toEqual($expected);
      },
    )
    ->testWith2Params(
      'import_provenance',
      () ==> vec[
        tuple(
          'use type \B\Thing; function f(): Thing {}',
          tuple('B\Thing', '\B\Thing'),
        ),
        tuple(
          'use function \B\f; function g(): void { f(); }',
          tuple('B\f', '\B\f'),
        ),
        tuple(
          'use const \B\K; function g(): void { K; }',
          tuple('B\K', '\B\K'),
        ),
        tuple(
          'use namespace \B\C; function g(): C\Thing {}',
          tuple('B\C\Thing', '\B\C'),
        ),
        tuple(
          'use \B\{type Thing}; function f(): Thing {}',
          tuple('B\Thing', 'type Thing'),
        ),
        tuple(
          'use \B\{function f, const K}; function g(): void { f(); }',
          tuple('B\f', 'function f'),
        ),
        tuple(
          'use \B\{function f, const K}; function g(): void { K; }',
          tuple('B\K', 'const K'),
        ),
        tuple(
          'use B\{function f as x, const K as Y, type Thing as T, namespace C as D}; function g(): void { x(); }',
          tuple('B\f', 'function f as x'),
        ),
        tuple(
          'use B\{function f as x, const K as Y, type Thing as T, namespace C as D}; function g(): void { Y; }',
          tuple('B\K', 'const K as Y'),
        ),
        tuple(
          'use B\{function f as x, const K as Y, type Thing as T, namespace C as D}; function g(): T {}',
          tuple('B\Thing', 'type Thing as T'),
        ),
        tuple(
          'use B\{function f as x, const K as Y, type Thing as T, namespace C as D}; function g(): D\Thing {}',
          tuple('B\C\Thing', 'namespace C as D'),
        ),
        tuple(
          'use function \B\{f}; function g(): void { f(); }',
          tuple('B\f', 'f'),
        ),
        tuple('use const \B\{K}; function g(): void { K; }', tuple('B\K', 'K')),
        tuple(
          'use type \B\{Thing}; function g(): Thing {}',
          tuple('B\Thing', 'Thing'),
        ),
        tuple(
          'use namespace \B\{C}; function g(): C\Thing {}',
          tuple('B\C\Thing', 'C'),
        ),
        tuple(
          'use B\{Thing}; function g(): Thing {}',
          tuple('B\Thing', 'Thing'),
        ),
        tuple(
          'use B\{Thing}; function g(): Thing\T {}',
          tuple('B\Thing\T', 'Thing'),
        ),
        tuple(
          'use type B\__Thing; function f(): __Thing {}',
          tuple('B\__Thing', 'B\__Thing'),
        ),
        tuple(
          'use const B\__FOO__; function f(): void { __FOO__; }',
          tuple('B\__FOO__', 'B\__FOO__'),
        ),
        tuple(
          'use type B\defaults; function f(): defaults {}',
          tuple('B\defaults', 'B\defaults'),
        ),
        tuple(
          'use type B\Thing; use const C\Thing; function f(): void { nameof Thing; }',
          tuple('B\Thing', 'B\Thing'),
        ),
        tuple('use type B\Thing; type T = Thing::Foo;', tuple('Foo', null)),
        tuple(
          'use type B\Thing; use const C\Thing; type T = Thing::Foo;',
          tuple('Foo', null),
        ),
        tuple(
          'use const B\Foo; class C { const type Foo = int; }',
          tuple('Foo', null),
        ),
        tuple(
          'use const B\Foo; class C { const int Foo = 1; }',
          tuple('Foo', null),
        ),
        tuple(
          'use type B\Thing; namespace B; function f(): Thing {}',
          tuple('B\Thing', null),
        ),
        tuple(
          'use type B\Thing; namespace A; function f(): Thing {}',
          tuple('A\Thing', null),
        ),
        tuple(
          'use type B\Thing; function f(): void { Thing#Label; }',
          tuple('Label', null),
        ),
        tuple(
          'use namespace B as C; function f(): namespace\C\Thing {}',
          tuple('A\C\Thing', null),
        ),
      ],
      (string $code, (string, ?string) $expected)[]: void ==> {
        list($script, $tokens, $resolver) = parse('namespace A; '.$code, true);
        // Exercise nameof only on parsers that understand the syntax.
        if (
          Str\contains($code, 'nameof ') &&
          C\is_empty(Pha\index_get_nodes_by_kind(
            Pha\create_syntax_kind_index($script),
            Pha\KIND_NAMEOF_EXPRESSION,
          ))
        ) {
          return;
        }
        $name =
          Pha\index_get_nodes_by_kind($tokens, Pha\KIND_NAME) |> C\lastx($$);
        list($resolved, $clause) =
          Pha\resolve_name_and_use_clause($resolver, $script, $name);
        expect($resolved)->toEqual($expected[0]);
        expect($clause === Pha\NIL ? null : Pha\node_get_code($script, $clause))
          ->toEqual($expected[1]);
      },
    )
    ->testWith2Params(
      'legacy_compatibility',
      () ==> vec[
        tuple(
          'namespace A; function f(): void { namespace\\func(); }',
          'A\\namespace\\func',
        ),
        tuple(
          'namespace A; use type \\B\\Thing; function f(): Thing {}',
          '\\B\\Thing',
        ),
        tuple('namespace { function f(): Thing {} }', '\\Thing'),
        tuple(
          'namespace A; use type B\\__Thing; function f(): __Thing {}',
          '__Thing',
        ),
        tuple(
          'namespace A; use const B\\__FOO__; function f(): void { __FOO__; }',
          '__FOO__',
        ),
        tuple(
          'namespace A; use type B\\defaults; function f(): defaults {}',
          'defaults',
        ),
        tuple(
          'namespace A; function f(): T {} namespace B; function g(): U {}',
          'A\\B\\U',
        ),
      ],
      (string $code, string $expected)[]: void ==> {
        list($script, $tokens, $resolver) = parse($code);
        $name =
          Pha\index_get_nodes_by_kind($tokens, Pha\KIND_NAME) |> C\lastx($$);
        expect(Pha\resolve_name($resolver, $script, $name))->toEqual($expected);
      },
    )
    ->testWith2Params(
      'lexical_type_parameters',
      () ==> vec[
        tuple('namespace A; use type B\\T; class C<T> { <<T>> public function f(T $x): T {} }', vec['B\\T', 'T', 'B\\T', 'T', 'T']),

        tuple('namespace A; function f<T>(T $x): T { new T(); } function g(): T {}', vec['T', 'T', 'T', 'T', 'A\\T']),
        tuple('namespace A; use type B\\T; function f<T>(T $x): T {} function g(): T {}', vec['B\\T', 'T', 'T', 'T', 'B\\T']),
        tuple('namespace A; class C<T> { public function f(T $x): T {} public function g<T>(T $x): T {} } function h(): T {}', vec['T', 'T', 'T', 'T', 'T', 'T', 'A\\T']),
        tuple('namespace A; type Box<T> = vec<T>; type Outside = T;', vec['T', 'T', 'A\\T']),
        tuple('namespace A; function f<T as U, U>(T $x): U {}', vec['T', 'T']),
        tuple('namespace A; function f<T>(T $x): T::Item {}', vec['T', 'T', 'T']),
        tuple('namespace A; function f<T>(): void { T(); T; }', vec['T', 'A\\T', 'A\\T']),
        tuple('namespace A; function f<T>(): \\T {}', vec['T', 'T']),
      ],
      ($code, $expected) ==> {
        list($script, $tokens, $resolver) = parse($code, true);
        $names = Pha\index_get_nodes_by_kind($tokens, Pha\KIND_NAME)
          |> Vec\filter($$, $n ==> Pha\node_get_code_compressed($script, $n) === 'T');
        expect(Vec\map($names, $n ==> Pha\resolve_name($resolver, $script, $n)))
          ->toEqual($expected);
      },
    )
    ->test('generic_context_and_shadowing', () ==> {
      list($script, $tokens, $resolver) = parse(
        'namespace A; class C<T> { public function f(T $x): T {} public function g<T>(T $x): T {} }',
        true,
      );
      $names = Pha\index_get_nodes_by_kind($tokens, Pha\KIND_NAME)
        |> Vec\filter($$, $n ==> Pha\node_get_code_compressed($script, $n) === 'T');
      $outer = Pha\node_get_parent($script, $names[0]);
      $inner = Pha\node_get_parent($script, $names[3]);
      foreach ($names as $i => $name) {
        $result = Pha\resolve_name_in_ctx($resolver, $script, $name);
        expect($result->getName())->toEqual('T');
        expect($result->getKind())->toEqual(Pha\ResolverNameKind::TYPE);
        expect($result->getDependency())->toEqual(Pha\TypeDependency::TYPE_PARAMETER);
        expect($result->getTypeParameter() === ($i < 3 ? $outer : $inner))->toEqual(true);
        expect($result->getUseClause())->toBeNil();
      }
    })
    ->test('type_access_context', () ==> {
      list($script, $tokens, $resolver) = parse(
        'namespace A; use type B\\Thing; class C<T> { public function f(): T::Item::Nested {} public function g(): this::Item {} public function h(): self::Item {} public function i(): void { static::Item; } public function j(): Thing::Item {} }',
        true,
      );
      $syntax = Pha\create_syntax_kind_index($script);
      $accesses = Pha\index_get_nodes_by_kind($syntax, Pha\KIND_TYPE_CONSTANT);
      $results = Vec\map($accesses, $n ==> Pha\resolve_name_in_ctx($resolver, $script, $n));
      expect(Vec\map($results, $r ==> $r->getName()))->toEqual(vec[
        'T::Item::Nested',
        'T::Item',
        'this::Item',
        'self::Item',
        'B\\Thing::Item',
      ]);
      expect(Vec\map($results, $r ==> $r->getDependency()))->toEqual(vec[
        Pha\TypeDependency::TYPE_PARAMETER,
        Pha\TypeDependency::TYPE_PARAMETER,
        Pha\TypeDependency::THIS,
        Pha\TypeDependency::SELF,
        Pha\TypeDependency::NONE,
      ]);
      $items = Pha\index_get_nodes_by_kind($tokens, Pha\KIND_NAME)
        |> Vec\filter($$, $n ==> Pha\node_get_code_compressed($script, $n) === 'Item');
      $generic_item = Pha\resolve_name_in_ctx($resolver, $script, $items[0]);
      expect($generic_item->getKind())->toEqual(Pha\ResolverNameKind::MEMBER);
      expect($generic_item->getDependency())->toEqual(Pha\TypeDependency::TYPE_PARAMETER);
      expect($generic_item->getName())->toEqual('Item');
      expect($generic_item->getTypeParameter() !== Pha\NIL)->toEqual(true);
      expect(C\lastx($results)->getUseClause() !== Pha\NIL)->toEqual(true);
      $static = Pha\index_get_nodes_by_kind($tokens, Pha\KIND_STATIC) |> C\firstx($$);
      $static_result = Pha\resolve_name_in_ctx($resolver, $script, $static);
      expect($static_result->getDependency())->toEqual(Pha\TypeDependency::STATIC);
      expect($static_result->getKind())->toEqual(Pha\ResolverNameKind::TYPE);
      $scope = Pha\index_get_nodes_by_kind($syntax, Pha\KIND_SCOPE_RESOLUTION_EXPRESSION) |> C\firstx($$);
      $scope_result = Pha\resolve_name_in_ctx($resolver, $script, $scope);
      expect($scope_result->getName())->toEqual('static::Item');
      expect($scope_result->getDependency())->toEqual(Pha\TypeDependency::STATIC);
      expect($scope_result->getKind())->toEqual(Pha\ResolverNameKind::MEMBER);

    })
    ->test('context_name_kinds', () ==> {
      list($script, $tokens, $resolver) = parse(
        'namespace A; use type B\\Thing; <<__Memoize>> function f()[write_props]: Thing { g(); K; }',
        true,
      );
      $results = Pha\index_get_nodes_by_kind($tokens, Pha\KIND_NAME)
        |> Vec\map($$, $n ==> Pha\resolve_name_in_ctx($resolver, $script, $n));
      expect(Vec\map($results, $r ==> $r->getKind()))->toEqual(vec[
        Pha\ResolverNameKind::NAMESPACE,
        Pha\ResolverNameKind::TYPE,
        Pha\ResolverNameKind::TYPE,
        Pha\ResolverNameKind::ATTRIBUTE,
        Pha\ResolverNameKind::FUNCTION,
        Pha\ResolverNameKind::CONTEXT,
        Pha\ResolverNameKind::TYPE,
        Pha\ResolverNameKind::FUNCTION,
        Pha\ResolverNameKind::CONST,
      ]);
      expect(Pha\resolve_name_in_ctx($resolver, $script, Pha\NIL)->getKind())
        ->toEqual(Pha\ResolverNameKind::UNKNOWN);
    })
    ->test('legacy_context_api_rejected', () ==> {
      list($script, $_) = Pha\parse('namespace A; function f<T>(T $x): T {}', Pha\create_context());
      $syntax = Pha\create_syntax_kind_index($script);
      $tokens = Pha\create_token_kind_index($script);
      $resolver = Pha\create_name_resolver($script, $syntax, $tokens);
      expect(Pha\resolve_name($resolver, $script, C\lastx(Pha\index_get_nodes_by_kind($tokens, Pha\KIND_NAME))))->toEqual('A\\T');
      foreach (vec[Pha\NIL, Pha\index_get_nodes_by_kind($tokens, Pha\KIND_NAME)[0]] as $name) {
        $threw = false;
        try {
          Pha\resolve_name_in_ctx($resolver, $script, $name);
        } catch (HH\InvariantException $_) {
          $threw = true;
        }
        expect($threw)->toEqual(true);
      }
    })
    ->test('configured_imports_and_sentinels', () ==> {
      list($script, $_) = Pha\parse(
        'namespace A; function f(): C\\Thing { custom(); }',
        Pha\create_context(),
      );
      $syntax_index = Pha\create_syntax_kind_index($script);
      $tokens = Pha\create_token_kind_index($script);
      $resolver = Pha\create_name_resolver_v2(
        $script,
        $syntax_index,
        $tokens,
        dict['C' => '\\B\\'],
        keyset['custom'],
        keyset[],
      );
      $names = Pha\index_get_nodes_by_kind($tokens, Pha\KIND_NAME);
      expect(Pha\resolve_name($resolver, $script, $names[3]))->toEqual(
        'B\\Thing',
      );
      expect(Pha\resolve_name($resolver, $script, C\lastx($names)))->toEqual(
        'custom',
      );
      expect(Pha\resolve_name_and_use_clause($resolver, $script, Pha\NIL)[0])
        ->toEqual('');
      expect(Pha\resolve_name_and_use_clause($resolver, $script, Pha\NIL)[1])
        ->toBeNil();
      $qualified =
        Pha\index_get_nodes_by_kind($syntax_index, Pha\KIND_QUALIFIED_NAME)
        |> C\firstx($$);
      expect(Pha\resolve_name($resolver, $script, $qualified))->toEqual(
        'B\\Thing',
      );
      expect(Pha\resolve_name($resolver, $script, Pha\SCRIPT_NODE))
        ->toEqual(Pha\node_get_code_compressed($script, Pha\SCRIPT_NODE));
    });
}
