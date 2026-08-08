module dcompute.driver.d3d12.kernel;

import dcompute.driver.d3d12.bindings;

struct Kernel(F) if (is(F==function) || is(F==void))
{
    ID3D12PipelineState* pipelineState;
    ID3D12RootSignature* rootSignature;
    
    static struct Attributes
    {
        @(0) int maxThreadsPerBlock;
        @(1) int sharedSize;
        @(2) int constSize;
        @(3) int localSize;
        @(4) int numRegs;
        @(5) int dxilVersion;
    }
}
