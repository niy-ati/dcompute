module dcompute.driver.d3d12.program;

import dcompute.driver.d3d12.bindings;
import dcompute.driver.d3d12.kernel;
import dcompute.driver.d3d12.device;

/// D3D12 program: loads DXIL byte code and creates Pipeline State Objects.
/// Mirrors dcompute.driver.cuda.program.
///
/// In CUDA, a "module" is a .ptx/.cubin blob that contains multiple kernels.
/// In D3D12, the equivalent is a signed DXIL container (.dxil) that we load
/// and use to create compute PSOs.
struct Program
{
    const(ubyte)[] dxilBlob;   // raw DXIL container bytes (DXBC header)

    /// Build a Root Signature for N UAV buffers at u0..u(N-1), space0.
    /// This matches the LDC DirectX target's ABI where each GlobalPointer
    /// argument maps to a consecutive UAV binding.
    private ID3D12RootSignature buildRootSignature(ID3D12Device device, uint numUAVs)
    {
        D3D12_DESCRIPTOR_RANGE1 range;
        range.RangeType          = D3D12_DESCRIPTOR_RANGE_TYPE.UAV;
        range.NumDescriptors     = numUAVs;
        range.BaseShaderRegister = 0;
        range.RegisterSpace      = 0;
        range.Flags              = D3D12_DESCRIPTOR_RANGE_FLAGS.DESCRIPTORS_VOLATILE;

        D3D12_ROOT_PARAMETER1 param;
        param.ParameterType              = D3D12_ROOT_PARAMETER_TYPE.DESCRIPTOR_TABLE;
        param.ShaderVisibility           = D3D12_SHADER_VISIBILITY.ALL;
        param.DescriptorTable.NumDescriptorRanges = 1;
        param.DescriptorTable.pDescriptorRanges   = &range;

        D3D12_VERSIONED_ROOT_SIGNATURE_DESC rsDesc;
        rsDesc.Version                    = D3D_ROOT_SIGNATURE_VERSION._1_1;
        rsDesc.Desc_1_1.NumParameters     = 1;
        rsDesc.Desc_1_1.pParameters       = &param;
        rsDesc.Desc_1_1.NumStaticSamplers = 0;
        rsDesc.Desc_1_1.pStaticSamplers   = null;
        rsDesc.Desc_1_1.Flags             = D3D12_ROOT_SIGNATURE_FLAGS.NONE;

        ID3DBlob rsBlob, rsErr;
        auto hr = D3D12SerializeVersionedRootSignature(&rsDesc, &rsBlob, &rsErr);
        if (FAILED(hr))
            return ID3D12RootSignature.init;

        ID3D12RootSignature rootSig;
        hr = (*device.lpVtbl).CreateRootSignature(
            cast(void*)&device,
            0, // node mask
            (*rsBlob.lpVtbl).GetBufferPointer(cast(void*)&rsBlob),
            (*rsBlob.lpVtbl).GetBufferSize(cast(void*)&rsBlob),
            &IID_ID3D12RootSignature,
            cast(void**)&rootSig
        );

        // Release the serialised blob
        (*rsBlob.lpVtbl).Release(cast(void*)&rsBlob);
        if (rsErr.lpVtbl !is null)
            (*rsErr.lpVtbl).Release(cast(void*)&rsErr);

        if (FAILED(hr))
            return ID3D12RootSignature.init;

        return rootSig;
    }

    /// Create a kernel (PSO) by name, with N UAV bindings.
    /// numUAVs defaults to 1 (single u0 — matches harness_kernel.d).
    Kernel!void getKernelByName(immutable(char)* name, uint numUAVs = 1)
    {
        Kernel!void ret;

        auto device = Runtime.defaultDevice.raw;
        if (device.lpVtbl is null)
            return ret;

        // Build the root signature dynamically based on argument count
        ret.rootSignature = buildRootSignature(device, numUAVs);
        if (ret.rootSignature.lpVtbl is null)
            return ret;

        // Build the compute PSO
        D3D12_COMPUTE_PIPELINE_STATE_DESC psoDesc;
        psoDesc.pRootSignature      = cast(void*)&ret.rootSignature;
        psoDesc.CS.pShaderBytecode  = dxilBlob.ptr;
        psoDesc.CS.BytecodeLength   = dxilBlob.length;
        psoDesc.NodeMask            = 0;

        auto hr = (*device.lpVtbl).CreateComputePipelineState(
            cast(void*)&device,
            &psoDesc,
            &IID_ID3D12PipelineState,
            cast(void**)&ret.pipelineState
        );

        if (FAILED(hr))
        {
            ret.rootSignature.release();
            ret = Kernel!void.init;
        }

        return ret;
    }

    /// Compile-time kernel lookup (mirrors CUDA Program.getKernel).
    Kernel!(typeof(k)) getKernel(alias k)()
    {
        // Count the number of GlobalPointer arguments to determine UAV count
        import std.traits : Parameters;
        alias Params = Parameters!(typeof(k));
        enum numUAVs = Params.length > 0 ? Params.length : 1;

        return cast(typeof(return)) getKernelByName(k.mangleof.ptr, numUAVs);
    }

    /// Load a DXIL blob from a file path.
    static Program fromFile(string path)
    {
        Program ret;
        import std.file : read;
        auto data = cast(const(ubyte)[]) read(path);
        ret.dxilBlob = data;
        return ret;
    }

    /// Load a DXIL blob from a byte array (for embedded blobs).
    static Program fromBytes(const(ubyte)[] blob)
    {
        Program ret;
        ret.dxilBlob = blob;
        return ret;
    }

    /// LDC embeds DXIL blobs as __dcompute_dxil_* globals.
    /// Similar to CUDA's __dcompute_ptx_* mechanism.
    static if (__VERSION__ >= 2113)
    static Program fromModule(string moduleName)()
    {
        version      (DComputeDirectX_660) enum _arch = "directx660";
        else version (DComputeDirectX_680) enum _arch = "directx680";
        else static assert(false,
            "Add a DComputeDirectX_XXX version to your dub config " ~
            "matching your --mdcompute-targets=directx-XXX dflag. " ~
            "Example: \"versions\": [\"DComputeDirectX_660\"]");

        import std.array : replace;
        enum mangledName = moduleName.replace(".", "_");
        enum symbolName  = "__dcompute_dxil_" ~ _arch ~ "_" ~ mangledName;

        mixin("pragma(mangle, \"" ~ symbolName ~ "\") extern(C) extern __gshared const ubyte " ~ symbolName ~ ";");

        Program ret;
        // The embedded blob starts at the symbol address; length is baked
        // into the DXBC container header (bytes 24-27, little-endian).
        mixin("const(ubyte)* base = &" ~ symbolName ~ ";");
        // Read DXBC container size from header
        uint containerSize = *cast(const(uint)*)(base + 24);
        ret.dxilBlob = base[0 .. containerSize];
        return ret;
    }

    __gshared static Program globalProgram;

    void unload()
    {
        dxilBlob = null;
    }
}

// Forward-declare Runtime so program.d can reference it
import dcompute.driver.d3d12.runtime;
alias Runtime = dcompute.driver.d3d12.runtime.Runtime;
