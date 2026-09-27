@compute(CompileFor.deviceOnly) module dcompute.std.directx.index;

import ldc.dcompute;
pure: nothrow: @nogc:

// SV_DispatchThreadID (Global Thread ID)
pragma(LDC_intrinsic, "llvm.dx.thread.id.x")
uint global_id_x();

pragma(LDC_intrinsic, "llvm.dx.thread.id.y")
uint global_id_y();

pragma(LDC_intrinsic, "llvm.dx.thread.id.z")
uint global_id_z();

// SV_GroupThreadID (Local Thread ID inside a block)
pragma(LDC_intrinsic, "llvm.dx.thread.id.in.group.x")
uint local_id_x();

pragma(LDC_intrinsic, "llvm.dx.thread.id.in.group.y")
uint local_id_y();

pragma(LDC_intrinsic, "llvm.dx.thread.id.in.group.z")
uint local_id_z();

// SV_GroupID (Block ID)
pragma(LDC_intrinsic, "llvm.dx.group.id.x")
uint group_id_x();

pragma(LDC_intrinsic, "llvm.dx.group.id.y")
uint group_id_y();

pragma(LDC_intrinsic, "llvm.dx.group.id.z")
uint group_id_z();

// SV_GroupIndex (Flattened local thread ID)
pragma(LDC_intrinsic, "llvm.dx.flattened.thread.id.in.group")
uint flattened_local_id();
