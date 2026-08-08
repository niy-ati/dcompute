module dcompute.driver.d3d12.program;

import dcompute.driver.d3d12;

struct Program
{
    const(void)* byteCode;
    size_t byteCodeLength;

    Kernel!void getKernelByName(immutable(char)* name)
    {
        Kernel!void ret;
        // Build UAV(u0) Root Signature exactly like main.cpp
        D3D12_DESCRIPTOR_RANGE1 range;
        range.RangeType = D3D12_DESCRIPTOR_RANGE_TYPE_UAV;
        range.NumDescriptors = 1;
        range.BaseShaderRegister = 0;
        range.RegisterSpace = 0;
        range.Flags = D3D12_DESCRIPTOR_RANGE_FLAG_DESCRIPTORS_VOLATILE;

        D3D12_ROOT_PARAMETER1 param;
        param.ParameterType = D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE;
        param.ShaderVisibility = D3D12_SHADER_VISIBILITY_ALL;
        param.DescriptorTable.NumDescriptorRanges = 1;
        param.DescriptorTable.pDescriptorRanges = &range;

        D3D12_VERSIONED_ROOT_SIGNATURE_DESC rsDesc;
        rsDesc.Version = D3D_ROOT_SIGNATURE_VERSION_1_1;
        rsDesc.Desc_1_1.NumParameters = 1;
        rsDesc.Desc_1_1.pParameters = &param;

        ID3DBlob* rsBlob;
        ID3DBlob* rsErr;
        D3D12SerializeVersionedRootSignature(&rsDesc, cast(void**)&rsBlob, cast(void**)&rsErr);

        Device.get.raw.lpVtbl.CreateRootSignature(Device.get.raw, 0, rsBlob.lpVtbl.GetBufferPointer(rsBlob), rsBlob.lpVtbl.GetBufferSize(rsBlob), cast(void**)&ret.rootSignature);

        D3D12_COMPUTE_PIPELINE_STATE_DESC psoDesc;
        psoDesc.pRootSignature = cast(void*)ret.rootSignature;
        psoDesc.CS.pShaderBytecode = byteCode;
        psoDesc.CS.BytecodeLength = byteCodeLength;

        Device.get.raw.lpVtbl.CreateComputePipelineState(Device.get.raw, &psoDesc, cast(void**)&ret.pipelineState);

        return ret;
    }

    Kernel!(typeof(k)) getKernel(alias k)()
    {
        return cast(typeof(return)) getKernelByName(k.mangleof.ptr);
    }

    static Program fromFile(string name)
    {
        Program ret;
        // Load file contents into byteCode
        return ret;
    }

    __gshared static Program globalProgram;
}
