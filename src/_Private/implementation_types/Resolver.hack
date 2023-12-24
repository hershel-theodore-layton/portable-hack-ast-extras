/** portable-hack-ast-extras is MIT licensed, see /LICENSE. */
namespace HTL\Pha\_Private;

newtype Resolver = NameResolver;

function resolver_hide(NameResolver $resolver)[]: Resolver {
  return $resolver;
}

function resolver_reveal(Resolver $resolver)[]: NameResolver {
  return $resolver;
}
