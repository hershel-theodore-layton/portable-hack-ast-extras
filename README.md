# portable-hack-ast-extras

_Extra utilities for use with portable-hack-ast._

### Why this repo?

_Why is this not part of portable-hack-ast?_

I had assumed that upgrading to HHVM 6.33+ (in Meta's version number range),
might require a lot of effort. Looking back, this was not the case. This
repository exists because of historical circumstances. It would have been part
of portable-hack-ast with the benefit of hindsight.

### Name resolution

`create_name_resolver()` uses an old, slightly broken implementation. The new
`create_name_resolver_v2()` returns a `Resolver`, just like the old API, but is
much more aware of the context of a name. It resolves generics, and complex
multi-namespace files better. You can pre-adopt v2 or wait for it to become
stable. When it does, `create_name_resolver()` will be an alias for the new
implementation. Until then, v2 is explicitly experimental, and may change for
any reason. If you depend on the quirks of `create_name_resolver()`, get ready
for the switch-over release.

`resolve_name()` can only return you a string, which means you cannot distinguish
between `function<T>identity(T $t)[]: T { return $t; }` returning an instance of
the `\T` class or a generic `T`. `resolve_name_in_ctx()` returns the context,
so you are able to distinguish between these cases. If you call it with an old
name resolver, an exception is thrown.
