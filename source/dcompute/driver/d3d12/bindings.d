module dcompute.driver.d3d12.bindings;

import core.sys.windows.com;
import core.sys.windows.windows;

extern(Windows):

alias HRESULT = int;
alias UINT = uint;
alias UINT64 = ulong;

// Add some missing DXGI and D3D12 enums/structs not in core.sys.windows
enum DXGI_ERROR_NOT_FOUND = 0x887A0002;
enum DXGI_ADAPTER_FLAG_SOFTWARE = 2;
enum D3D_FEATURE_LEVEL_11_0 = 0xb000;
enum D3D12_COMMAND_LIST_TYPE_DIRECT = 0;
enum D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV = 0;
enum D3D12_DESCRIPTOR_HEAP_FLAG_SHADER_VISIBLE = 1;
enum D3D12_HEAP_TYPE_DEFAULT = 1;
enum D3D12_HEAP_TYPE_READBACK = 3;
enum D3D12_HEAP_FLAG_NONE = 0;
enum D3D12_RESOURCE_DIMENSION_BUFFER = 1;
enum D3D12_TEXTURE_LAYOUT_ROW_MAJOR = 1;
enum D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS = 4;
enum D3D12_RESOURCE_STATE_COPY_DEST = 1024;
enum D3D12_RESOURCE_STATE_COPY_SOURCE = 1;
enum D3D12_RESOURCE_STATE_UNORDERED_ACCESS = 8;
enum DXGI_FORMAT_R32_TYPELESS = 39;
enum D3D12_UAV_DIMENSION_BUFFER = 1;
enum D3D12_BUFFER_UAV_FLAG_RAW = 1;
enum D3D12_RESOURCE_BARRIER_TYPE_TRANSITION = 0;
enum D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES = 0xffffffff;
enum D3D12_FENCE_FLAG_NONE = 0;
enum D3D_ROOT_SIGNATURE_VERSION_1_1 = 2;
enum D3D12_DESCRIPTOR_RANGE_TYPE_UAV = 1;
enum D3D12_DESCRIPTOR_RANGE_FLAG_DESCRIPTORS_VOLATILE = 2;
enum D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE = 0;
enum D3D12_SHADER_VISIBILITY_ALL = 0;

struct DXGI_ADAPTER_DESC1 {
    wchar[128] Description;
    uint VendorId;
    uint DeviceId;
    uint SubSysId;
    uint Revision;
    size_t DedicatedVideoMemory;
    size_t DedicatedSystemMemory;
    size_t SharedSystemMemory;
    ulong AdapterLuid;
    uint Flags;
}

interface IDXGIAdapter1 : IUnknown {
    HRESULT GetDesc1(DXGI_ADAPTER_DESC1* pDesc);
    // Real vtable is much larger, but we only need these for now. 
    // Wait, D interfaces MUST define all methods in order. 
    // Since IUnknown has 3 methods, the 4th method here would map to the 4th method of IDXGIAdapter1? No, IDXGIAdapter1 inherits IDXGIAdapter which inherits IDXGIObject.
    // It's much safer to use C-style vtables if we don't define the full interface hierarchy.
}

// C-style vtable approach for minimal bindings (avoids massive inheritance chains):
struct IDXGIFactory4Vtbl {
    HRESULT function(void*, const GUID*, void**) QueryInterface;
    uint function(void*) AddRef;
    uint function(void*) Release;
    void* SetPrivateData;
    void* SetPrivateDataInterface;
    void* GetPrivateData;
    void* GetParent;
    void* EnumAdapters;
    void* MakeWindowAssociation;
    void* GetWindowAssociation;
    void* CreateSwapChain;
    void* CreateSoftwareAdapter;
    HRESULT function(void*, uint, void**) EnumAdapters1;
}

struct IDXGIFactory4 { IDXGIFactory4Vtbl* lpVtbl; }

struct IDXGIAdapter1Vtbl {
    HRESULT function(void*, const GUID*, void**) QueryInterface;
    uint function(void*) AddRef;
    uint function(void*) Release;
    void* SetPrivateData;
    void* SetPrivateDataInterface;
    void* GetPrivateData;
    void* GetParent;
    void* EnumOutputs;
    HRESULT function(void*, DXGI_ADAPTER_DESC1*) GetDesc1;
}

struct IDXGIAdapter1 { IDXGIAdapter1Vtbl* lpVtbl; }

// ID3D12Device is huge. We just define the slots we need.
struct ID3D12DeviceVtbl {
    HRESULT function(void*, const GUID*, void**) QueryInterface;
    uint function(void*) AddRef;
    uint function(void*) Release;
    void* GetNodeCount;
    HRESULT function(void*, int, void**) CreateCommandQueue;
    HRESULT function(void*, int, void**) CreateCommandAllocator;
    void* CreateGraphicsPipelineState;
    HRESULT function(void*, void*, void**) CreateComputePipelineState;
    HRESULT function(void*, uint, int, void*, void*, void**) CreateCommandList;
    void* CheckFeatureSupport;
    void* CreateDescriptorHeap;
    void* GetDescriptorHandleIncrementSize;
    HRESULT function(void*, uint, const void*, size_t, void**) CreateRootSignature;
    void* CreateConstantBufferView;
    void* CreateShaderResourceView;
    void* CreateUnorderedAccessView; // Slot 15
    void* CreateRenderTargetView;
    void* CreateDepthStencilView;
    void* CreateSampler;
    void* CopyDescriptors;
    void* CopyDescriptorsSimple;
    void* GetResourceAllocationInfo;
    void* GetCustomHeapProperties;
    HRESULT function(void*, void*, int, void*, int, void*, void**) CreateCommittedResource; // Slot 23
    void* CreateHeap;
    void* CreatePlacedResource;
    void* CreateReservedResource;
    void* CreateSharedHandle;
    void* OpenSharedHandle;
    void* OpenSharedHandleByName;
    void* MakeResident;
    void* Evict;
    HRESULT function(void*, ulong, int, void**) CreateFence;
}

struct ID3D12Device { ID3D12DeviceVtbl* lpVtbl; }

struct ID3D12CommandQueueVtbl {
    HRESULT function(void*, const GUID*, void**) QueryInterface;
    uint function(void*) AddRef;
    uint function(void*) Release;
    void* UpdateTileMappings;
    void* CopyTileMappings;
    void function(void*, uint, void**) ExecuteCommandLists;
    void* SetMarker;
    void* BeginEvent;
    void* EndEvent;
    HRESULT function(void*, void*, ulong) Signal;
    void* Wait;
    void* GetTimestampFrequency;
    void* GetClockCalibration;
    void* GetDesc;
}
struct ID3D12CommandQueue { ID3D12CommandQueueVtbl* lpVtbl; }

struct ID3D12CommandAllocatorVtbl {
    HRESULT function(void*, const GUID*, void**) QueryInterface;
    uint function(void*) AddRef;
    uint function(void*) Release;
    void* Reset;
}
struct ID3D12CommandAllocator { ID3D12CommandAllocatorVtbl* lpVtbl; }

struct ID3D12GraphicsCommandListVtbl {
    HRESULT function(void*, const GUID*, void**) QueryInterface;
    uint function(void*) AddRef;
    uint function(void*) Release;
    void* GetDevice;
    void* GetType;
    HRESULT function(void*) Close;
    void* Reset;
    void* ClearState;
    void* DrawInstanced;
    void* DrawIndexedInstanced;
    void function(void*, uint, uint, uint) Dispatch;
    void function(void*, void*, void*) CopyResource;
    void* CopyTextureRegion;
    void* CopyBufferRegion;
    void* CopyTiles;
    void* ResolveSubresource;
    void* IASetPrimitiveTopology;
    void* RSSetViewports;
    void* RSSetScissorRects;
    void* OMSetBlendFactor;
    void* OMSetStencilRef;
    void function(void*, void*) SetPipelineState;
    void function(void*, uint, void*) ResourceBarrier;
    void* ExecuteBundle;
    void* SetDescriptorHeaps; // slot 24
    void function(void*, void*) SetComputeRootSignature; // slot 25
    void* SetGraphicsRootSignature;
    void* SetComputeRootDescriptorTable; // slot 27
    // We can add more if needed
}
struct ID3D12GraphicsCommandList { ID3D12GraphicsCommandListVtbl* lpVtbl; }

// Needed structs
struct D3D12_COMMAND_QUEUE_DESC {
    int Type; int Priority; int Flags; uint NodeMask;
}
struct DXGI_SAMPLE_DESC { uint Count; uint Quality; }
struct D3D12_RESOURCE_DESC {
    int Dimension; ulong Alignment; ulong Width; uint Height; ushort DepthOrArraySize; ushort MipLevels;
    DXGI_SAMPLE_DESC SampleDesc; int Layout; int Flags;
}
struct D3D12_HEAP_PROPERTIES {
    int Type; int CPUPageProperty; int MemoryPoolPreference; uint CreationNodeMask; uint VisibleNodeMask;
}
struct D3D12_SHADER_BYTECODE {
    const(void)* pShaderBytecode; size_t BytecodeLength;
}
struct D3D12_COMPUTE_PIPELINE_STATE_DESC {
    void* pRootSignature; D3D12_SHADER_BYTECODE CS; uint NodeMask; D3D12_SHADER_BYTECODE CachedPSO; int Flags;
}
struct D3D12_DESCRIPTOR_RANGE1 {
    int RangeType; uint NumDescriptors; uint BaseShaderRegister; uint RegisterSpace; int Flags; uint OffsetInDescriptorsFromTableStart;
}
struct D3D12_ROOT_DESCRIPTOR_TABLE1 {
    uint NumDescriptorRanges; const(D3D12_DESCRIPTOR_RANGE1)* pDescriptorRanges;
}
struct D3D12_ROOT_PARAMETER1 {
    int ParameterType; D3D12_ROOT_DESCRIPTOR_TABLE1 DescriptorTable; int ShaderVisibility;
}
struct D3D12_ROOT_SIGNATURE_DESC1 {
    uint NumParameters; const(D3D12_ROOT_PARAMETER1)* pParameters; uint NumStaticSamplers; const(void)* pStaticSamplers; int Flags;
}
struct D3D12_VERSIONED_ROOT_SIGNATURE_DESC {
    int Version; D3D12_ROOT_SIGNATURE_DESC1 Desc_1_1;
}

extern(Windows) HRESULT CreateDXGIFactory1(const GUID* riid, void** ppFactory);
extern(Windows) HRESULT D3D12CreateDevice(void* pAdapter, int MinimumFeatureLevel, const GUID* riid, void** ppDevice);
extern(Windows) HRESULT D3D12SerializeVersionedRootSignature(const D3D12_VERSIONED_ROOT_SIGNATURE_DESC* pRootSignature, void** ppBlob, void** ppErrorBlob);
