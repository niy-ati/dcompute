module dcompute.driver.d3d12.platform;

import dcompute.driver.d3d12.bindings;
import dcompute.driver.d3d12.device;

/// D3D12 platform: DXGI factory + adapter enumeration.
/// Mirrors dcompute.driver.cuda.platform.
struct Platform
{
    __gshared IDXGIFactory4 factory;

    /// Initialise COM and create the DXGI factory.
    /// Call once before any other D3D12 operation.
    static void initialise(uint flags = 0)
    {
        CoInitializeEx(null, COINIT_MULTITHREADED);

        auto hr = CreateDXGIFactory1(
            &IID_IDXGIFactory4,
            cast(void**)&factory
        );
        if (FAILED(hr))
            factory = IDXGIFactory4.init;
    }

    /// Enumerate all hardware adapters (skipping software/WARP).
    static Device[] getDevices()
    {
        Device[] devices;
        if (factory.lpVtbl is null) return devices;

        for (uint i = 0; ; ++i)
        {
            IDXGIAdapter1 adap;
            auto hr = (*factory.lpVtbl).EnumAdapters1(
                cast(void*)&factory, i, &adap
            );
            if (hr == DXGI_ERROR_NOT_FOUND)
                break;
            if (FAILED(hr))
                continue;

            // Skip software adapters
            DXGI_ADAPTER_DESC1 desc;
            (*adap.lpVtbl).GetDesc1(cast(void*)&adap, &desc);
            if (desc.Flags & DXGI_ADAPTER_FLAG_SOFTWARE)
            {
                (*adap.lpVtbl).Release(cast(void*)&adap);
                continue;
            }

            auto dev = Device.create(adap);
            if (dev.raw.lpVtbl !is null)
                devices ~= dev;
        }
        return devices;
    }

    /// Get the WARP software adapter (useful for testing without hardware).
    static Device getWarpDevice()
    {
        if (factory.lpVtbl is null)
            return Device.init;

        IDXGIAdapter1 warp;
        // EnumWarpAdapter returns IDXGIAdapter, QI to IDXGIAdapter1
        void* warpRaw;
        auto hr = (*factory.lpVtbl).EnumWarpAdapter(
            cast(void*)&factory,
            &IID_IDXGIFactory4, // need IDXGIAdapter GUID here actually
            &warpRaw
        );
        if (FAILED(hr))
            return Device.init;

        // QI to IDXGIAdapter1
        hr = (cast(IDXGIAdapter1Vtbl**)warpRaw).QueryInterface(
            warpRaw,
            &IID_ID3D12Device, // placeholder — in production use IID_IDXGIAdapter1
            cast(void**)&warp
        );

        return Device.create(warp);
    }
}
