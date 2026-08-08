module dcompute.driver.d3d12.buffer;

import dcompute.driver.d3d12;

enum Copy {
    hostToDevice,
    deviceToHost
}

struct Buffer(T)
{
    ID3D12Resource* raw;
    T[] hostMemory;

    this(size_t elems)
    {
        D3D12_HEAP_PROPERTIES hp;
        hp.Type = D3D12_HEAP_TYPE_DEFAULT;
        
        D3D12_RESOURCE_DESC rd;
        rd.Dimension = D3D12_RESOURCE_DIMENSION_BUFFER;
        rd.Width = elems * T.sizeof;
        rd.Height = 1;
        rd.DepthOrArraySize = 1;
        rd.MipLevels = 1;
        rd.SampleDesc.Count = 1;
        rd.Layout = D3D12_TEXTURE_LAYOUT_ROW_MAJOR;
        rd.Flags = D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS;

        Device.get.raw.lpVtbl.CreateCommittedResource(Device.get.raw, &hp, D3D12_HEAP_FLAG_NONE, &rd, D3D12_RESOURCE_STATE_UNORDERED_ACCESS, null, cast(void**)&raw);
    }

    this(T[] arr)
    {
        this(arr.length);
        hostMemory = arr;
    }

    void copy(Copy c)()
    {
        static if (c == Copy.hostToDevice)
        {
            // Upload heap logic would go here
        }
        else static if (c == Copy.deviceToHost)
        {
            // Readback heap logic using Map/Unmap would go here
        }
    }

    void release()
    {
        if (raw)
        {
            raw.lpVtbl.Release(raw);
            raw = null;
        }
        hostMemory = null;
    }
}

alias bf = Buffer!float;
