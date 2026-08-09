module dcompute.driver.d3d12.traits;

import dcompute.driver.d3d12.buffer;

/// Transforms a kernel function's parameter types into the corresponding host
/// types. Specifically, replaces `GlobalPointer!T` with `Buffer!T`.
template HostArgsOf(F) {
    import std.meta, std.traits;
    import ldc.dcompute : Pointer; // Pointer!T is aliased to GlobalPointer!T in dcompute
    alias HostArgsOf = staticMap!(ReplaceTemplate!(Pointer, Buffer), Parameters!F);
}

private template ReplaceTemplate(alias needle, alias replacement) {
    template ReplaceTemplate(T) {
        static if (is(T : needle!Args, Args...)) {
            // Replaces Pointer!T with Buffer!T
            alias ReplaceTemplate = replacement!(Args[1]);
        } else {
            alias ReplaceTemplate = T;
        }
    }
}
