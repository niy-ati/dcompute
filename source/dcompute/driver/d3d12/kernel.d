module dcompute.driver.d3d12.kernel;

import dcompute.driver.d3d12.bindings;

/// D3D12 kernel: wraps a compiled Pipeline State Object + Root Signature pair.
/// Mirrors dcompute.driver.cuda.kernel.
struct Kernel(F) if (is(F == function) || is(F == void))
{
    ID3D12PipelineState  pipelineState;
    ID3D12RootSignature  rootSignature;

    /// Thread-group dimensions baked into the DXIL metadata by LDC.
    /// (HLSL: [numthreads(X, Y, Z)])
    uint[3] numThreads = [1, 1, 1];

    /// D3D12-specific kernel attributes, analogous to CUDA Kernel.Attributes.
    static struct Attributes
    {
        @(0) int maxThreadsPerBlock;
        @(1) int sharedSize;        // groupshared memory in bytes
        @(2) int constSize;         // cbuffer memory in bytes
        @(3) int localSize;         // thread-local scratch in bytes
        @(4) int numRegs;           // register pressure
        @(5) int dxilVersionMajor;
        @(6) int dxilVersionMinor;
        @(7) int shaderModel;       // e.g. 66 for SM 6.6
    }

    bool isValid() const
    {
        return pipelineState.lpVtbl !is null;
    }

    void release()
    {
        if (pipelineState.lpVtbl !is null)
        {
            (*pipelineState.lpVtbl).Release(cast(void*)&pipelineState);
            pipelineState = ID3D12PipelineState.init;
        }
        if (rootSignature.lpVtbl !is null)
        {
            (*rootSignature.lpVtbl).Release(cast(void*)&rootSignature);
            rootSignature = ID3D12RootSignature.init;
        }
    }
}
