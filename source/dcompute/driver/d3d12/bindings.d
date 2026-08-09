module dcompute.driver.d3d12.bindings;

// Minimal, dependency-free D3D12/DXGI COM bindings for dcompute.
// Uses C-style vtable structs to avoid massive COM inheritance chains.
// Each struct wraps a raw COM pointer; helper methods forward through lpVtbl.

// ── Fundamental Windows types ──────────────────────────────────────────────
alias HRESULT = int;
alias UINT   = uint;
alias UINT64 = ulong;
alias BOOL   = int;
alias HANDLE = void*;
alias LPCWSTR = const(wchar)*;
alias SIZE_T = size_t;

struct GUID {
    uint   Data1;
    ushort Data2;
    ushort Data3;
    ubyte[8] Data4;
}

enum S_OK = 0;
bool SUCCEEDED(HRESULT hr) { return hr >= 0; }
bool FAILED(HRESULT hr)    { return hr < 0; }

enum INFINITE = 0xFFFFFFFF;

// ── DXGI enums ─────────────────────────────────────────────────────────────
enum DXGI_ERROR_NOT_FOUND    = cast(HRESULT)0x887A0002;
enum DXGI_ADAPTER_FLAG_SOFTWARE = 2;

// ── D3D12 enums ────────────────────────────────────────────────────────────
enum D3D_FEATURE_LEVEL : int {
    _11_0 = 0xb000,
    _12_0 = 0xc000,
    _12_1 = 0xc100,
}

enum D3D12_COMMAND_LIST_TYPE : int {
    DIRECT  = 0,
    BUNDLE  = 1,
    COMPUTE = 2,
    COPY    = 3,
}

enum D3D12_DESCRIPTOR_HEAP_TYPE : int {
    CBV_SRV_UAV = 0,
    SAMPLER     = 1,
    RTV         = 2,
    DSV         = 3,
}

enum D3D12_DESCRIPTOR_HEAP_FLAGS : int {
    NONE           = 0,
    SHADER_VISIBLE = 1,
}

enum D3D12_HEAP_TYPE : int {
    DEFAULT  = 1,
    UPLOAD   = 2,
    READBACK = 3,
    CUSTOM   = 4,
}

enum D3D12_HEAP_FLAGS : int {
    NONE = 0,
}

enum D3D12_RESOURCE_DIMENSION : int {
    UNKNOWN   = 0,
    BUFFER    = 1,
    TEXTURE1D = 2,
    TEXTURE2D = 3,
    TEXTURE3D = 4,
}

enum D3D12_TEXTURE_LAYOUT : int {
    UNKNOWN            = 0,
    ROW_MAJOR          = 1,
    _64KB_UNDEFINED_SWIZZLE = 2,
    _64KB_STANDARD_SWIZZLE  = 3,
}

enum D3D12_RESOURCE_FLAGS : int {
    NONE                          = 0,
    ALLOW_RENDER_TARGET           = 1,
    ALLOW_DEPTH_STENCIL           = 2,
    ALLOW_UNORDERED_ACCESS        = 4,
    DENY_SHADER_RESOURCE          = 8,
    ALLOW_CROSS_ADAPTER            = 16,
    ALLOW_SIMULTANEOUS_ACCESS      = 32,
}

enum D3D12_RESOURCE_STATES : int {
    COMMON                       = 0,
    VERTEX_AND_CONSTANT_BUFFER   = 1,
    INDEX_BUFFER                 = 2,
    RENDER_TARGET                = 4,
    UNORDERED_ACCESS             = 8,
    DEPTH_WRITE                  = 16,
    DEPTH_READ                   = 32,
    NON_PIXEL_SHADER_RESOURCE    = 64,
    PIXEL_SHADER_RESOURCE        = 128,
    STREAM_OUT                   = 256,
    INDIRECT_ARGUMENT            = 512,
    COPY_DEST                    = 1024,
    COPY_SOURCE                  = 2048,
    RESOLVE_DEST                 = 4096,
    RESOLVE_SOURCE               = 8192,
    GENERIC_READ                 = 0xAC3, // combination of read states
}

enum D3D12_RESOURCE_BARRIER_TYPE : int {
    TRANSITION = 0,
    ALIASING   = 1,
    UAV        = 2,
}

enum D3D12_RESOURCE_BARRIER_FLAGS : int {
    NONE       = 0,
    BEGIN_ONLY = 1,
    END_ONLY   = 2,
}

enum D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES = 0xffffffff;

enum D3D12_FENCE_FLAGS : int {
    NONE   = 0,
    SHARED = 1,
}

enum D3D_ROOT_SIGNATURE_VERSION : int {
    _1_0 = 1,
    _1_1 = 2,
}

enum D3D12_DESCRIPTOR_RANGE_TYPE : int {
    SRV     = 0,
    UAV     = 1,
    CBV     = 2,
    SAMPLER = 3,
}

enum D3D12_DESCRIPTOR_RANGE_FLAGS : int {
    NONE                          = 0,
    DESCRIPTORS_VOLATILE          = 1,
    DATA_VOLATILE                 = 2,
    DATA_STATIC_WHILE_SET_AT_EXECUTE = 4,
    DATA_STATIC                   = 8,
    DESCRIPTORS_STATIC_KEEPING_BUFFER_BOUNDS_CHECKS = 0x10000,
}

enum D3D12_ROOT_PARAMETER_TYPE : int {
    DESCRIPTOR_TABLE = 0,
    _32BIT_CONSTANTS = 1,
    CBV              = 2,
    SRV              = 3,
    UAV              = 4,
}

enum D3D12_SHADER_VISIBILITY : int {
    ALL      = 0,
    VERTEX   = 1,
    HULL     = 2,
    DOMAIN   = 3,
    GEOMETRY = 4,
    PIXEL    = 5,
    AMPLIFICATION = 6,
    MESH     = 7,
}

enum D3D12_ROOT_SIGNATURE_FLAGS : int {
    NONE = 0,
    ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT = 1,
    DENY_VERTEX_SHADER_ROOT_ACCESS     = 2,
    DENY_HULL_SHADER_ROOT_ACCESS       = 4,
    DENY_DOMAIN_SHADER_ROOT_ACCESS     = 8,
    DENY_GEOMETRY_SHADER_ROOT_ACCESS   = 16,
    DENY_PIXEL_SHADER_ROOT_ACCESS      = 32,
    ALLOW_STREAM_OUTPUT                = 64,
}

enum DXGI_FORMAT : int {
    UNKNOWN         = 0,
    R32_TYPELESS    = 39,
    R32_FLOAT       = 41,
    R32_UINT        = 42,
    R32G32_FLOAT    = 16,
    R32G32B32_FLOAT = 6,
    R32G32B32A32_FLOAT = 2,
}

enum D3D12_UAV_DIMENSION : int {
    UNKNOWN = 0,
    BUFFER  = 1,
    TEXTURE1D = 2,
    TEXTURE2D = 4,
    TEXTURE3D = 8,
}

enum D3D12_BUFFER_UAV_FLAGS : int {
    NONE = 0,
    RAW  = 1,
}

// ── D3D12 structs ──────────────────────────────────────────────────────────

struct DXGI_ADAPTER_DESC1 {
    wchar[128] Description;
    uint VendorId;
    uint DeviceId;
    uint SubSysId;
    uint Revision;
    size_t DedicatedVideoMemory;
    size_t DedicatedSystemMemory;
    size_t SharedSystemMemory;
    long AdapterLuid;
    uint Flags;
}

struct DXGI_SAMPLE_DESC {
    uint Count  = 1;
    uint Quality = 0;
}

struct D3D12_COMMAND_QUEUE_DESC {
    D3D12_COMMAND_LIST_TYPE Type;
    int Priority;
    int Flags;
    uint NodeMask;
}

struct D3D12_HEAP_PROPERTIES {
    D3D12_HEAP_TYPE Type;
    int CPUPageProperty;
    int MemoryPoolPreference;
    uint CreationNodeMask;
    uint VisibleNodeMask;
}

struct D3D12_RESOURCE_DESC {
    D3D12_RESOURCE_DIMENSION Dimension;
    ulong Alignment;
    ulong Width;
    uint Height          = 1;
    ushort DepthOrArraySize = 1;
    ushort MipLevels      = 1;
    DXGI_FORMAT Format    = DXGI_FORMAT.UNKNOWN;
    DXGI_SAMPLE_DESC SampleDesc;
    D3D12_TEXTURE_LAYOUT Layout;
    D3D12_RESOURCE_FLAGS Flags;
}

struct D3D12_DESCRIPTOR_HEAP_DESC {
    D3D12_DESCRIPTOR_HEAP_TYPE Type;
    uint NumDescriptors;
    D3D12_DESCRIPTOR_HEAP_FLAGS Flags;
    uint NodeMask;
}

struct D3D12_CPU_DESCRIPTOR_HANDLE {
    size_t ptr;
}

struct D3D12_GPU_DESCRIPTOR_HANDLE {
    ulong ptr;
}

struct D3D12_RESOURCE_TRANSITION_BARRIER {
    void* pResource;        // ID3D12Resource*
    uint Subresource;
    D3D12_RESOURCE_STATES StateBefore;
    D3D12_RESOURCE_STATES StateAfter;
}

struct D3D12_RESOURCE_BARRIER {
    D3D12_RESOURCE_BARRIER_TYPE Type;
    D3D12_RESOURCE_BARRIER_FLAGS Flags;
    D3D12_RESOURCE_TRANSITION_BARRIER Transition;
}

struct D3D12_RANGE {
    size_t Begin;
    size_t End;
}

struct D3D12_SHADER_BYTECODE {
    const(void)* pShaderBytecode;
    size_t BytecodeLength;
}

struct D3D12_DESCRIPTOR_RANGE1 {
    D3D12_DESCRIPTOR_RANGE_TYPE RangeType;
    uint NumDescriptors;
    uint BaseShaderRegister;
    uint RegisterSpace;
    D3D12_DESCRIPTOR_RANGE_FLAGS Flags;
    uint OffsetInDescriptorsFromTableStart = 0xffffffff; // D3D12_DESCRIPTOR_RANGE_OFFSET_APPEND
}

struct D3D12_ROOT_DESCRIPTOR_TABLE1 {
    uint NumDescriptorRanges;
    const(D3D12_DESCRIPTOR_RANGE1)* pDescriptorRanges;
}

struct D3D12_ROOT_PARAMETER1 {
    D3D12_ROOT_PARAMETER_TYPE ParameterType;
    D3D12_ROOT_DESCRIPTOR_TABLE1 DescriptorTable;
    D3D12_SHADER_VISIBILITY ShaderVisibility;
}

struct D3D12_ROOT_SIGNATURE_DESC1 {
    uint NumParameters;
    const(D3D12_ROOT_PARAMETER1)* pParameters;
    uint NumStaticSamplers;
    const(void)* pStaticSamplers;
    D3D12_ROOT_SIGNATURE_FLAGS Flags;
}

struct D3D12_VERSIONED_ROOT_SIGNATURE_DESC {
    D3D_ROOT_SIGNATURE_VERSION Version;
    D3D12_ROOT_SIGNATURE_DESC1 Desc_1_1;
}

struct D3D12_COMPUTE_PIPELINE_STATE_DESC {
    void* pRootSignature;   // ID3D12RootSignature*
    D3D12_SHADER_BYTECODE CS;
    uint NodeMask;
    D3D12_SHADER_BYTECODE CachedPSO;
    int Flags;
}

struct D3D12_BUFFER_UAV {
    ulong FirstElement;
    uint  NumElements;
    uint  StructureByteStride;
    ulong CounterOffsetInBytes;
    D3D12_BUFFER_UAV_FLAGS Flags;
}

struct D3D12_CONSTANT_BUFFER_VIEW_DESC {
    ulong BufferLocation;
    uint SizeInBytes;
}

struct D3D12_UNORDERED_ACCESS_VIEW_DESC {
    DXGI_FORMAT Format;
    D3D12_UAV_DIMENSION ViewDimension;
    D3D12_BUFFER_UAV Buffer;
}

// ── GUIDs ──────────────────────────────────────────────────────────────────

immutable GUID IID_IDXGIFactory4 = {
    0x1bc6ea02, 0xef36, 0x464f, [0xbf, 0x0c, 0x21, 0xca, 0x39, 0xe5, 0x16, 0x8a]
};
immutable GUID IID_ID3D12Device = {
    0x189819f1, 0x1db6, 0x4b57, [0xbe, 0x54, 0x18, 0x21, 0x33, 0x9b, 0x85, 0xf7]
};
immutable GUID IID_ID3D12CommandQueue = {
    0x0ec870a6, 0x5d7e, 0x4c22, [0x8c, 0xfc, 0x5b, 0xaa, 0xe0, 0x76, 0x16, 0xed]
};
immutable GUID IID_ID3D12CommandAllocator = {
    0x6102dee4, 0xaf59, 0x4b09, [0xb9, 0x99, 0xb4, 0x4d, 0x73, 0xf0, 0x9b, 0x24]
};
immutable GUID IID_ID3D12GraphicsCommandList = {
    0x5b160d0f, 0xac1b, 0x4185, [0x8b, 0xa8, 0xb3, 0xae, 0x42, 0xa5, 0xa4, 0x55]
};
immutable GUID IID_ID3D12Fence = {
    0x0a753dcf, 0xc4d8, 0x4b91, [0xad, 0xf6, 0xbe, 0x5a, 0x60, 0xd9, 0x5a, 0x76]
};
immutable GUID IID_ID3D12PipelineState = {
    0x765a30f3, 0xf624, 0x4c6f, [0xa8, 0x28, 0xac, 0xe9, 0x48, 0x62, 0x24, 0x45]
};
immutable GUID IID_ID3D12RootSignature = {
    0xc54a6b66, 0x72df, 0x4ee8, [0x8b, 0xe5, 0xa9, 0x46, 0xa1, 0x42, 0x92, 0x14]
};
immutable GUID IID_ID3D12DescriptorHeap = {
    0x8efb471d, 0x616c, 0x4f49, [0x90, 0xf7, 0x12, 0x7b, 0xb7, 0x63, 0xfa, 0x51]
};
immutable GUID IID_ID3D12Resource = {
    0x696442be, 0xa72e, 0x4059, [0xbc, 0x79, 0x5b, 0x5c, 0x98, 0x04, 0x0f, 0xad]
};

// ── COM vtable wrappers ────────────────────────────────────────────────────
// These mirror the exact COM vtable layout. Each function pointer takes a
// raw void* self as the first argument, matching the C ABI for COM methods.

// ── IDXGIFactory4 ──────────────────────────────────────────────────────────
// Vtable slots: IUnknown(3) + IDXGIObject(4) + IDXGIFactory(6) +
//               IDXGIFactory1(2) + IDXGIFactory2(5) + IDXGIFactory3(1) +
//               IDXGIFactory4(2)
// We only need: EnumAdapters1 (slot 12), EnumWarpAdapter (slot ~25)
struct IDXGIFactory4Vtbl {
    // IUnknown (0-2)
    extern(Windows) HRESULT function(void*, const(GUID)*, void**) QueryInterface;
    extern(Windows) uint function(void*) AddRef;
    extern(Windows) uint function(void*) Release;
    // IDXGIObject (3-6)
    void*[4] _dxgiObject;
    // IDXGIFactory (7-12)
    void*[5] _dxgiFactory;
    extern(Windows) HRESULT function(void*, uint, IDXGIAdapter1**) EnumAdapters1;  // slot 12
    // IDXGIFactory1 (13)
    void*  _isCurrent;
    // IDXGIFactory2 (14-18)
    void*[5] _dxgiFactory2;
    // IDXGIFactory3 (19)
    void*  _getCreationFlags;
    // IDXGIFactory4 (20-21)
    void*  _enumAdapterByLuid;
    extern(Windows) HRESULT function(void*, const(GUID)*, void**) EnumWarpAdapter; // slot 21
}

struct IDXGIAdapter1Vtbl {
    // IUnknown (0-2)
    extern(Windows) HRESULT function(void*, const(GUID)*, void**) QueryInterface;
    extern(Windows) uint function(void*) AddRef;
    extern(Windows) uint function(void*) Release;
    // IDXGIObject (3-6)
    void*[4] _dxgiObject;
    // IDXGIAdapter (7-8)
    void*  _enumOutputs;
    extern(Windows) HRESULT function(void*, DXGI_ADAPTER_DESC1*) GetDesc1; // slot 8 for IDXGIAdapter1
}

// ── ID3DBlob ───────────────────────────────────────────────────────────────
struct ID3DBlobVtbl {
    extern(Windows) HRESULT function(void*, const(GUID)*, void**) QueryInterface;
    extern(Windows) uint function(void*) AddRef;
    extern(Windows) uint function(void*) Release;
    extern(Windows) void* function(void*) GetBufferPointer;
    extern(Windows) size_t function(void*) GetBufferSize;
}

// ── ID3D12Device ───────────────────────────────────────────────────────────
// Full vtable: IUnknown(3) + ID3D12Object(4) + ID3D12Device(41 methods)
// We bind only the slots we actually call; everything else is void*.
struct ID3D12DeviceVtbl {
    // IUnknown (0-2)
    extern(Windows) HRESULT function(void*, const(GUID)*, void**) QueryInterface;
    extern(Windows) uint function(void*) AddRef;
    extern(Windows) uint function(void*) Release;
    // ID3D12Object (3-6)
    void*[4] _d3d12Object;
    // ID3D12Device methods begin at slot 7
    void*  _GetNodeCount;                                                  // 7
    extern(Windows) HRESULT function(void*, const(D3D12_COMMAND_QUEUE_DESC)*, const(GUID)*, void**) CreateCommandQueue;  // 8
    extern(Windows) HRESULT function(void*, D3D12_COMMAND_LIST_TYPE, const(GUID)*, void**) CreateCommandAllocator;       // 9
    void*  _CreateGraphicsPipelineState;                                   // 10
    extern(Windows) HRESULT function(void*, const(D3D12_COMPUTE_PIPELINE_STATE_DESC)*, const(GUID)*, void**) CreateComputePipelineState; // 11
    extern(Windows) HRESULT function(void*, uint, D3D12_COMMAND_LIST_TYPE, ID3D12CommandAllocator*, ID3D12PipelineState*, const(GUID)*, void**) CreateCommandList; // 12
    void*  _CheckFeatureSupport;                                           // 13
    extern(Windows) HRESULT function(void*, const(D3D12_DESCRIPTOR_HEAP_DESC)*, const(GUID)*, void**) CreateDescriptorHeap; // 14
    extern(Windows) uint function(void*, D3D12_DESCRIPTOR_HEAP_TYPE) GetDescriptorHandleIncrementSize; // 15
    extern(Windows) HRESULT function(void*, uint, const(void)*, size_t, const(GUID)*, void**) CreateRootSignature; // 16
    extern(Windows) void function(void*, const(D3D12_CONSTANT_BUFFER_VIEW_DESC)*, D3D12_CPU_DESCRIPTOR_HANDLE) CreateConstantBufferView; // 17
    void*  _CreateShaderResourceView;                                      // 18
    extern(Windows) void function(void*, ID3D12Resource*, ID3D12Resource*, const(D3D12_UNORDERED_ACCESS_VIEW_DESC)*, D3D12_CPU_DESCRIPTOR_HANDLE) CreateUnorderedAccessView; // 19
    void*[4] _renderAndDepthViews;                                         // 20-23
    void*[2] _copyDescriptors;                                             // 24-25 (CopyDescriptors, CopyDescriptorsSimple)
    void*  _GetResourceAllocationInfo;                                     // 26
    void*  _GetCustomHeapProperties;                                       // 27
    extern(Windows) HRESULT function(void*, const(D3D12_HEAP_PROPERTIES)*, D3D12_HEAP_FLAGS, const(D3D12_RESOURCE_DESC)*, D3D12_RESOURCE_STATES, const(void)*, const(GUID)*, void**) CreateCommittedResource; // 28
    void*[4] _heapAndPlacedResource;                                       // 29-32
    void*[3] _sharedHandles;                                               // 33-35
    void*[2] _residentEvict;                                               // 36-37
    extern(Windows) HRESULT function(void*, ulong, D3D12_FENCE_FLAGS, const(GUID)*, void**) CreateFence; // 38
    void*  _GetDeviceRemovedReason;                                        // 39
    void*  _GetCopyableFootprints;                                         // 40
    void*  _CreateQueryHeap;                                               // 41
    void*  _SetStablePowerState;                                           // 42
    void*  _CreateCommandSignature;                                        // 43
    void*  _GetResourceTiling;                                             // 44
    void*  _GetAdapterLuid;                                                // 45
}

// ── ID3D12CommandQueue ─────────────────────────────────────────────────────
struct ID3D12CommandQueueVtbl {
    extern(Windows) HRESULT function(void*, const(GUID)*, void**) QueryInterface;
    extern(Windows) uint function(void*) AddRef;
    extern(Windows) uint function(void*) Release;
    void*[4] _d3d12Object;                 // ID3D12Object (3-6)
    void*  _UpdateTileMappings;            // 7
    void*  _CopyTileMappings;              // 8
    extern(Windows) void function(void*, uint, ID3D12CommandList**) ExecuteCommandLists; // 9
    void*  _SetMarker;                     // 10
    void*  _BeginEvent;                    // 11
    void*  _EndEvent;                      // 12
    extern(Windows) HRESULT function(void*, ID3D12Fence*, ulong) Signal; // 13
    void*  _Wait;                          // 14
    void*  _GetTimestampFrequency;         // 15
    void*  _GetClockCalibration;           // 16
    void*  _GetDesc;                       // 17
}

// We need an ID3D12CommandList to pass to ExecuteCommandLists, which
// expects ID3D12CommandList** (base type). We define a minimal one.
struct ID3D12CommandList;

// ── ID3D12CommandAllocator ─────────────────────────────────────────────────
struct ID3D12CommandAllocatorVtbl {
    extern(Windows) HRESULT function(void*, const(GUID)*, void**) QueryInterface;
    extern(Windows) uint function(void*) AddRef;
    extern(Windows) uint function(void*) Release;
    void*[4] _d3d12Object;
    extern(Windows) HRESULT function(void*) Reset; // 7
}

// ── ID3D12GraphicsCommandList ──────────────────────────────────────────────
// Full vtable is massive (60+ methods). We bind only what we use.
struct ID3D12GraphicsCommandListVtbl {
    extern(Windows) HRESULT function(void*, const(GUID)*, void**) QueryInterface;
    extern(Windows) uint function(void*) AddRef;
    extern(Windows) uint function(void*) Release;
    void*[4] _d3d12Object;                // ID3D12Object (3-6)
    // ID3D12CommandList
    void*  _GetType;                       // 7
    // ID3D12GraphicsCommandList
    extern(Windows) HRESULT function(void*) Close;                         // 8
    extern(Windows) HRESULT function(void*, ID3D12CommandAllocator*, ID3D12PipelineState*) Reset; // 9
    void*  _ClearState;                    // 10
    void*  _DrawInstanced;                 // 11
    void*  _DrawIndexedInstanced;          // 12
    extern(Windows) void function(void*, uint, uint, uint) Dispatch;       // 13
    void*  _CopyBufferRegion;              // 14
    void*  _CopyTextureRegion;             // 15
    extern(Windows) void function(void*, ID3D12Resource*, ID3D12Resource*) CopyResource; // 16
    void*[5] _misc1;                       // 17-21 (CopyTiles..OMSetStencilRef)
    extern(Windows) void function(void*, ID3D12PipelineState*) SetPipelineState; // 22
    extern(Windows) void function(void*, uint, const(D3D12_RESOURCE_BARRIER)*) ResourceBarrier; // 23
    void*  _ExecuteBundle;                 // 24
    extern(Windows) void function(void*, uint, ID3D12DescriptorHeap**) SetDescriptorHeaps; // 25
    extern(Windows) void function(void*, ID3D12RootSignature*) SetComputeRootSignature; // 26
    void*  _SetGraphicsRootSignature;      // 27
    extern(Windows) void function(void*, uint, D3D12_GPU_DESCRIPTOR_HANDLE) SetComputeRootDescriptorTable; // 28
}

// ── ID3D12PipelineState ────────────────────────────────────────────────────
struct ID3D12PipelineStateVtbl {
    extern(Windows) HRESULT function(void*, const(GUID)*, void**) QueryInterface;
    extern(Windows) uint function(void*) AddRef;
    extern(Windows) uint function(void*) Release;
    void*[4] _d3d12Object;
    void*  _GetCachedBlob;
}

// ── ID3D12RootSignature ────────────────────────────────────────────────────
struct ID3D12RootSignatureVtbl {
    extern(Windows) HRESULT function(void*, const(GUID)*, void**) QueryInterface;
    extern(Windows) uint function(void*) AddRef;
    extern(Windows) uint function(void*) Release;
    void*[4] _d3d12Object;
}

// ── ID3D12DescriptorHeap ───────────────────────────────────────────────────
struct ID3D12DescriptorHeapVtbl {
    extern(Windows) HRESULT function(void*, const(GUID)*, void**) QueryInterface;
    extern(Windows) uint function(void*) AddRef;
    extern(Windows) uint function(void*) Release;
    void*[4] _d3d12Object;
    void*  _GetDesc;                       // 7
    extern(Windows) D3D12_CPU_DESCRIPTOR_HANDLE function(void*) GetCPUDescriptorHandleForHeapStart; // 8
    extern(Windows) D3D12_GPU_DESCRIPTOR_HANDLE function(void*) GetGPUDescriptorHandleForHeapStart; // 9
}

// ── ID3D12Resource ─────────────────────────────────────────────────────────
struct ID3D12ResourceVtbl {
    extern(Windows) HRESULT function(void*, const(GUID)*, void**) QueryInterface;
    extern(Windows) uint function(void*) AddRef;
    extern(Windows) uint function(void*) Release;
    void*[4] _d3d12Object;
    extern(Windows) HRESULT function(void*, uint, const(D3D12_RANGE)*, void**) Map;    // 7
    extern(Windows) void function(void*, uint, const(D3D12_RANGE)*) Unmap;             // 8
    void*  _GetDesc;                       // 9
    extern(Windows) ulong function(void*) GetGPUVirtualAddress;          // 10
    void*  _WriteToSubresource;            // 11
    void*  _ReadFromSubresource;           // 12
    void*  _GetHeapProperties;             // 13
}

// ── ID3D12Fence ────────────────────────────────────────────────────────────
struct ID3D12FenceVtbl {
    extern(Windows) HRESULT function(void*, const(GUID)*, void**) QueryInterface;
    extern(Windows) uint function(void*) AddRef;
    extern(Windows) uint function(void*) Release;
    void*[4] _d3d12Object;
    extern(Windows) ulong function(void*) GetCompletedValue;               // 7
    extern(Windows) HRESULT function(void*, ulong, HANDLE) SetEventOnCompletion; // 8
    extern(Windows) HRESULT function(void*, ulong) Signal;                 // 9
}

// ── Wrapper structs ────────────────────────────────────────────────────────
// Each wraps a pointer to a vtable pointer (standard COM layout).

struct IDXGIFactory4  { IDXGIFactory4Vtbl**  lpVtbl; }
struct IDXGIAdapter1  { IDXGIAdapter1Vtbl**  lpVtbl; }
struct ID3DBlob       { ID3DBlobVtbl**       lpVtbl; }
struct ID3D12Device   { ID3D12DeviceVtbl**   lpVtbl; }
struct ID3D12CommandQueue { ID3D12CommandQueueVtbl** lpVtbl; }
struct ID3D12CommandAllocator { ID3D12CommandAllocatorVtbl** lpVtbl; }
struct ID3D12GraphicsCommandList { ID3D12GraphicsCommandListVtbl** lpVtbl; }
struct ID3D12PipelineState { ID3D12PipelineStateVtbl** lpVtbl; }
struct ID3D12RootSignature { ID3D12RootSignatureVtbl** lpVtbl; }
struct ID3D12DescriptorHeap { ID3D12DescriptorHeapVtbl** lpVtbl; }
struct ID3D12Resource { ID3D12ResourceVtbl** lpVtbl; }
struct ID3D12Fence    { ID3D12FenceVtbl**    lpVtbl; }

// ── Win32 / D3D12 functions (loaded at link time via .lib) ─────────────────

extern(Windows):

HRESULT CreateDXGIFactory1(const(GUID)* riid, void** ppFactory);
HRESULT CreateDXGIFactory2(uint Flags, const(GUID)* riid, void** ppFactory);
HRESULT D3D12CreateDevice(void* pAdapter, D3D_FEATURE_LEVEL MinimumFeatureLevel, const(GUID)* riid, void** ppDevice);
HRESULT D3D12SerializeVersionedRootSignature(const(D3D12_VERSIONED_ROOT_SIGNATURE_DESC)* pRootSignature, ID3DBlob** ppBlob, ID3DBlob** ppErrorBlob);
HANDLE  CreateEventW(void* lpEventAttributes, BOOL bManualReset, BOOL bInitialState, LPCWSTR lpName);
BOOL    CloseHandle(HANDLE hObject);
uint    WaitForSingleObject(HANDLE hHandle, uint dwMilliseconds);
HRESULT CoInitializeEx(void* pvReserved, uint dwCoInit);

enum COINIT_MULTITHREADED = 0;
