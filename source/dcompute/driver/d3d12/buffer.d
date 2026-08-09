module dcompute.driver.d3d12.buffer;

import dcompute.driver.d3d12.bindings;
import dcompute.driver.d3d12.device;

/// Copy direction for host ↔ device transfers.
enum Copy {
    hostToDevice,
    deviceToHost,
}

/// D3D12 buffer: wraps a committed GPU resource with host memory shadow.
/// Mirrors dcompute.driver.cuda.buffer.
///
/// D3D12 memory model:
///   - DEFAULT heap  = GPU-local VRAM (fast compute access, no CPU mapping)
///   - UPLOAD heap   = CPU-writable, GPU-readable (for hostToDevice)
///   - READBACK heap = GPU-writable, CPU-readable (for deviceToHost)
///
/// This struct manages all three heaps transparently. The user sees a simple
/// `copy!(Copy.hostToDevice)` / `copy!(Copy.deviceToHost)` interface.
struct Buffer(T)
{
    ID3D12Resource  gpuResource;     // DEFAULT heap — UAV target
    ID3D12Resource  stagingResource; // UPLOAD or READBACK heap for transfers
    T[]             hostMemory;      // Host-side shadow
    size_t          numElements;
    ID3D12Device    device;          // cached reference

    this(size_t elems)
    {
        import dcompute.driver.d3d12.runtime : Runtime;
        device = Runtime.defaultDevice.raw;
        numElements = elems;

        if (device.lpVtbl is null) return;

        // Create DEFAULT heap resource (GPU-local, UAV-capable)
        D3D12_HEAP_PROPERTIES hp;
        hp.Type = D3D12_HEAP_TYPE.DEFAULT;

        D3D12_RESOURCE_DESC rd;
        rd.Dimension        = D3D12_RESOURCE_DIMENSION.BUFFER;
        rd.Width            = elems * T.sizeof;
        rd.Height           = 1;
        rd.DepthOrArraySize = 1;
        rd.MipLevels        = 1;
        rd.SampleDesc.Count = 1;
        rd.Layout           = D3D12_TEXTURE_LAYOUT.ROW_MAJOR;
        rd.Flags            = D3D12_RESOURCE_FLAGS.ALLOW_UNORDERED_ACCESS;

        (*device.lpVtbl).CreateCommittedResource(
            cast(void*)&device,
            &hp,
            D3D12_HEAP_FLAGS.NONE,
            &rd,
            D3D12_RESOURCE_STATES.UNORDERED_ACCESS,
            null, // no clear value for buffers
            &IID_ID3D12Resource,
            cast(void**)&gpuResource
        );
    }

    this(T[] arr)
    {
        this(arr.length);
        hostMemory = arr;
    }

    /// Transfer data between host and device.
    /// In a full implementation this requires a command list to execute
    /// CopyResource between the staging and GPU resources.
    void copy(Copy c)()
    {
        if (device.lpVtbl is null || gpuResource.lpVtbl is null) return;

        static if (c == Copy.hostToDevice)
        {
            // 1. Create upload heap staging buffer
            auto staging = createStagingBuffer(D3D12_HEAP_TYPE.UPLOAD, D3D12_RESOURCE_STATES.GENERIC_READ);
            if (staging.lpVtbl is null) return;

            // 2. Map upload buffer, copy host data in
            void* mapped;
            D3D12_RANGE readRange = D3D12_RANGE(0, 0); // we won't read
            (*staging.lpVtbl).Map(cast(void*)&staging, 0, &readRange, &mapped);
            if (mapped !is null)
            {
                import core.stdc.string : memcpy;
                memcpy(mapped, hostMemory.ptr, hostMemory.length * T.sizeof);
                D3D12_RANGE writeRange = D3D12_RANGE(0, hostMemory.length * T.sizeof);
                (*staging.lpVtbl).Unmap(cast(void*)&staging, 0, &writeRange);
            }

            // 3. Execute GPU copy (staging → gpuResource) via command list
            // This requires a command queue — done in Queue.executeCopy()

            stagingResource = staging;
        }
        else static if (c == Copy.deviceToHost)
        {
            // 1. Create readback heap staging buffer
            auto staging = createStagingBuffer(D3D12_HEAP_TYPE.READBACK, D3D12_RESOURCE_STATES.COPY_DEST);
            if (staging.lpVtbl is null) return;

            stagingResource = staging;

            // After GPU copy completes (via Queue), map and read back:
            // readBack() should be called after Queue.wait()
        }
    }

    /// After a deviceToHost copy + queue wait, map the readback buffer
    /// and copy data into hostMemory.
    void readBack()
    {
        if (stagingResource.lpVtbl is null || hostMemory is null) return;

        void* mapped;
        D3D12_RANGE readRange = D3D12_RANGE(0, numElements * T.sizeof);
        auto hr = (*stagingResource.lpVtbl).Map(
            cast(void*)&stagingResource, 0, &readRange, &mapped
        );
        if (SUCCEEDED(hr) && mapped !is null)
        {
            import core.stdc.string : memcpy;
            memcpy(hostMemory.ptr, mapped, numElements * T.sizeof);
            (*stagingResource.lpVtbl).Unmap(cast(void*)&stagingResource, 0, null);
        }
    }

    /// Create a staging buffer (upload or readback).
    private ID3D12Resource createStagingBuffer(D3D12_HEAP_TYPE heapType, D3D12_RESOURCE_STATES initialState)
    {
        D3D12_HEAP_PROPERTIES hp;
        hp.Type = heapType;

        D3D12_RESOURCE_DESC rd;
        rd.Dimension        = D3D12_RESOURCE_DIMENSION.BUFFER;
        rd.Width            = numElements * T.sizeof;
        rd.Height           = 1;
        rd.DepthOrArraySize = 1;
        rd.MipLevels        = 1;
        rd.SampleDesc.Count = 1;
        rd.Layout           = D3D12_TEXTURE_LAYOUT.ROW_MAJOR;
        rd.Flags            = D3D12_RESOURCE_FLAGS.NONE;

        ID3D12Resource res;
        (*device.lpVtbl).CreateCommittedResource(
            cast(void*)&device,
            &hp,
            D3D12_HEAP_FLAGS.NONE,
            &rd,
            initialState,
            null,
            &IID_ID3D12Resource,
            cast(void**)&res
        );
        return res;
    }

    /// Map kernel GlobalPointer argument to the underlying GPU resource.
    /// This is the bridge between dcompute's type system and D3D12.
    alias hostArgOf(U : GlobalPointer!T) = gpuResource;

    void release()
    {
        if (gpuResource.lpVtbl !is null)
        {
            (*gpuResource.lpVtbl).Release(cast(void*)&gpuResource);
            gpuResource = ID3D12Resource.init;
        }
        if (stagingResource.lpVtbl !is null)
        {
            (*stagingResource.lpVtbl).Release(cast(void*)&stagingResource);
            stagingResource = ID3D12Resource.init;
        }
        hostMemory = null;
    }
}

// Forward import for GlobalPointer
import ldc.dcompute : GlobalPointer;

alias bf = Buffer!float;
