module dcompute.driver.d3d12.device;

import dcompute.driver.d3d12.bindings;

/// D3D12 device: wraps adapter enumeration and ID3D12Device creation.
/// Mirrors dcompute.driver.cuda.device — one Device per physical adapter.
struct Device
{
    ID3D12Device    raw;
    IDXGIAdapter1   adapter;

    /// Device capability information (D3D12 equivalent of CUDA Device.Info).
    static struct Info
    {
        wchar[128] description;
        uint vendorId;
        uint deviceId;
        size_t dedicatedVideoMemory;
        size_t dedicatedSystemMemory;
        size_t sharedSystemMemory;
        bool isSoftware;
    }

    /// Retrieve adapter metadata.
    @property Info info()
    {
        Info ret;
        if (adapter.lpVtbl is null) return ret;

        DXGI_ADAPTER_DESC1 desc;
        (*adapter.lpVtbl).GetDesc1(cast(void*)&adapter, &desc);

        ret.description           = desc.Description;
        ret.vendorId              = desc.VendorId;
        ret.deviceId              = desc.DeviceId;
        ret.dedicatedVideoMemory  = desc.DedicatedVideoMemory;
        ret.dedicatedSystemMemory = desc.DedicatedSystemMemory;
        ret.sharedSystemMemory    = desc.SharedSystemMemory;
        ret.isSoftware            = (desc.Flags & DXGI_ADAPTER_FLAG_SOFTWARE) != 0;
        return ret;
    }

    @property size_t totalMemory()
    {
        auto i = info;
        return i.dedicatedVideoMemory;
    }

    /// Create a D3D12 device on a specific adapter.
    static Device create(IDXGIAdapter1 adap, D3D_FEATURE_LEVEL level = D3D_FEATURE_LEVEL._11_0)
    {
        Device ret;
        ret.adapter = adap;
        auto hr = D3D12CreateDevice(
            cast(void*)&adap,
            level,
            &IID_ID3D12Device,
            cast(void**)&ret.raw
        );
        if (FAILED(hr))
            ret.raw = ID3D12Device.init;
        return ret;
    }

    void release()
    {
        if (raw.lpVtbl !is null)
        {
            (*raw.lpVtbl).Release(cast(void*)&raw);
            raw = ID3D12Device.init;
        }
        if (adapter.lpVtbl !is null)
        {
            (*adapter.lpVtbl).Release(cast(void*)&adapter);
            adapter = IDXGIAdapter1.init;
        }
    }
}
