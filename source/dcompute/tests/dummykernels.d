@compute(CompileFor.deviceOnly)
module dcompute.tests.dummykernels;
pragma(LDC_no_moduleinfo);

import ldc.dcompute;
import dcompute.std.index;

@kernel() void saxpy(GlobalPointer!(float) res,
                   float alpha,GlobalPointer!(float) x,
                   GlobalPointer!(float) y, 
                   size_t N)
{
    auto i = GlobalIndex.x;
    if (i >= N) return;
    res[i] = alpha*x[i] + y[i];
}

alias aagf = AutoIndexed!(GlobalPointer!(float));

@kernel() void auto_index_test(aagf a,
                             aagf b,
                             aagf c)
{
    a = b + c;
}

struct ComplexScalar {
    float x;
    float y;
    int z;
}

@kernel() void abi_test(
    int scalar1,                     // Scalar at start
    GlobalPointer!(float) buf0,      // u0
    ComplexScalar scalar2,           // Struct scalar
    GlobalPointer!(int) buf1,        // u1
    float scalar3,                   // Trailing scalar
    GlobalPointer!(float) buf2,      // u2
    size_t N                         // Scalar size_t
)
{
    auto i = GlobalIndex.x;
    if (i >= N) return;
    
    // Write out the scalars to the buffers to prove they were passed correctly
    buf0[i] = scalar2.x + scalar2.y + scalar3;
    buf1[i] = scalar1 + scalar2.z;
    buf2[i] = buf0[i] * cast(float)buf1[i];
}
