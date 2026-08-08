module dcompute.driver.d3d12.device;

// Import bindings
import dcompute.driver.d3d12.bindings;

import core.stdc.stdio : printf;

/// Represents a DirectX 12 compute device.
struct Device
{
    ID3D12Device* device;
    IDXGIAdapter1* adapter;
    
    // Command structures
    ID3D12CommandQueue* commandQueue;
    ID3D12CommandAllocator* commandAllocator;
    ID3D12GraphicsCommandList* commandList;

    @disable this();

    /// Initialize a new D3D12 device using the first hardware adapter.
    this(size_t adapterIndex)
    {
        IDXGIFactory4* factory;
        uint dxgiFactoryFlags = 0;

        version(assert) 
        {
            // Enable the D3D12 debug layer.
            ID3D12Debug* debugController;
            if (SUCCEEDED(D3D12GetDebugInterface(IID_ID3D12Debug, cast(void**)&debugController)))
            {
                debugController.EnableDebugLayer();
                debugController.Release();
                dxgiFactoryFlags |= DXGI_CREATE_FACTORY_DEBUG;
            }
        }

        if (FAILED(CreateDXGIFactory2(dxgiFactoryFlags, IID_IDXGIFactory4, cast(void**)&factory)))
        {
            assert(0, "Failed to create DXGI Factory");
        }

        // Enumerate adapters
        IDXGIAdapter1* hardwareAdapter;
        for (uint i = 0; factory.EnumAdapters1(i, &hardwareAdapter) != DXGI_ERROR_NOT_FOUND; ++i)
        {
            DXGI_ADAPTER_DESC1 desc;
            hardwareAdapter.GetDesc1(&desc);

            if (desc.Flags & DXGI_ADAPTER_FLAG_SOFTWARE)
            {
                hardwareAdapter.Release();
                continue;
            }

            if (i == adapterIndex)
            {
                adapter = hardwareAdapter;
                break;
            }
            hardwareAdapter.Release();
        }

        if (!adapter)
        {
            assert(0, "Failed to find a suitable hardware adapter.");
        }

        if (FAILED(D3D12CreateDevice(cast(IUnknown*)adapter, D3D_FEATURE_LEVEL_11_0, IID_ID3D12Device, cast(void**)&device)))
        {
            assert(0, "Failed to create D3D12 device.");
        }
        
        factory.Release();
    }
    
    ~this()
    {
        if (commandList) commandList.Release();
        if (commandAllocator) commandAllocator.Release();
        if (commandQueue) commandQueue.Release();
        if (device) device.Release();
        if (adapter) adapter.Release();
    }
}
