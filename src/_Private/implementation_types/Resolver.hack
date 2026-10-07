/** portable-hack-ast-extras is MIT licensed, see /LICENSE. */
namespace HTL\Pha\_Private;

newtype Resolver = NameResolverInterface;

function resolver_hide(NameResolverInterface $resolver)[]: Resolver {
  return $resolver;
}

function resolver_reveal(Resolver $resolver)[]: NameResolverInterface {
  return $resolver;
}
