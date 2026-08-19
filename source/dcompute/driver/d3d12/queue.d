module dcompute.driver.d3d12.queue;

import dcompute.driver.d3d12.bindings;
import dcompute.driver.d3d12.device;
import dcompute.driver.d3d12.program;
import dcompute.driver.d3d12.runtime;
import dcompute.driver.d3d12.buffer;
import dcompute.driver.d3d12.event;
import dcompute.driver.d3d12.error;

/// Structure to hold resources that are currently executing on the GPU.
/// D3D12 forbids resetting an allocator that is still in-flight.
struct InFlightResource {
    ID3D12CommandAllocator    allocator;
    ID3D12GraphicsCommandList commandList;
    ulong                     targetFence; // The fence value when this will be free
    ID3D12Resource[]          pendingReleases; // Resources to release when this fence passes
}

/// A command queue in D3D12. Mirrors dcompute.driver.cuda.queue.
///
/// Handles command list recording, descriptor heap allocation for kernel arguments,
/// and dispatching compute workloads asynchronously.
struct Queue
{
    ID3D12CommandQueue        raw;
    ID3D12Fence               fence;
    ulong                     fenceValue;
    HANDLE                    fenceEvent;
    ID3D12Device              device; // cached

    // Ring-buffer for true async execution
    InFlightResource[]        inFlightPool;
    
    // Bump-allocator Descriptor Heap (Shader Visible)
    ID3D12DescriptorHeap      globalDescriptorHeap;
    uint                      descriptorIncrementSize;
    uint                      currentDescriptorOffset;
    enum                      MAX_DESCRIPTORS = 65536;

    this(bool async)
    {
        device = Runtime.defaultDevice.raw;
        if (device is null) return;

        // 1. Create Command Queue
        D3D12_COMMAND_QUEUE_DESC qDesc;
        qDesc.Type = D3D12_COMMAND_LIST_TYPE.DIRECT; // Or COMPUTE
        qDesc.Flags = 0;
        
        auto hr = device.CreateCommandQueue(
            &qDesc, &IID_ID3D12CommandQueue, cast(void**)&raw
        );
        checkErrors(hr);

        // 2. Create Sync Fence
        hr = device.CreateFence(
            0, D3D12_FENCE_FLAGS.NONE, &IID_ID3D12Fence, cast(void**)&fence
        );
        checkErrors(hr);
        
        fenceValue = 1;
        fenceEvent = CreateEventW(null, 0 /*FALSE*/, 0 /*FALSE*/, null);

        // 3. Create a single large Shader Visible Descriptor Heap
        D3D12_DESCRIPTOR_HEAP_DESC heapDesc;
        heapDesc.NumDescriptors = MAX_DESCRIPTORS;
        heapDesc.Type = D3D12_DESCRIPTOR_HEAP_TYPE.CBV_SRV_UAV;
        heapDesc.Flags = D3D12_DESCRIPTOR_HEAP_FLAGS.SHADER_VISIBLE;
        heapDesc.NodeMask = 0;

        hr = device.CreateDescriptorHeap(
            &heapDesc, &IID_ID3D12DescriptorHeap, cast(void**)&globalDescriptorHeap
        );
        checkErrors(hr);

        descriptorIncrementSize = device.GetDescriptorHandleIncrementSize(
            D3D12_DESCRIPTOR_HEAP_TYPE.CBV_SRV_UAV
        );
        currentDescriptorOffset = 0;
    }

    @property bool async()
    {
        return true; // We are now truly async!
    }

    /// Instructs the GPU command queue to wait for the given event (fence)
    /// to reach its target value, without blocking the CPU.
    /// Mirrors dcompute.driver.cuda.queue.wait(Event)
    void wait(Event e)
    {
        if (raw is null || e.q is null || e.q.fence is null) return;
        
        auto hr = raw.Wait(e.q.fence, e.targetValue);
        checkErrors(hr);
    }

    /// Retrieve an available command allocator/list from the pool,
    /// or create a new one if all are currently executing.
    private InFlightResource getAvailableResource()
    {
        ulong completed = fence.GetCompletedValue();

        // Search for an allocator the GPU has finished using
        foreach (ref res; inFlightPool)
        {
            if (res.targetFence <= completed)
            {
                // GPU is done with this! We can safely reset it.
                res.allocator.Reset();
                res.commandList.Reset(res.allocator, null);
                
                foreach (r; res.pendingReleases)
                {
                    if (r !is null) r.Release();
                }
                res.pendingReleases.length = 0;
                
                return res;
            }
        }

        // None available, create a new one (expands the pool)
        InFlightResource newRes;
        auto hr = device.CreateCommandAllocator(
            D3D12_COMMAND_LIST_TYPE.DIRECT, &IID_ID3D12CommandAllocator, cast(void**)&newRes.allocator
        );
        checkErrors(hr);
        hr = device.CreateCommandList(
            0, D3D12_COMMAND_LIST_TYPE.DIRECT, newRes.allocator, null, &IID_ID3D12GraphicsCommandList, cast(void**)&newRes.commandList
        );
        checkErrors(hr);

        // Store in pool
        newRes.targetFence = 0; // Available immediately
        inFlightPool ~= newRes;
        return newRes;
    }

    /// Internal helper: Execute a copy between resources.
    /// CRITICAL: D3D12 requires explicit resource state transitions (barriers)
    /// before and after CopyResource. Without them, GPU caches are incoherent
    /// and the copy produces undefined results or validation layer crashes.
    void executeCopy(ID3D12Resource dst, ID3D12Resource src,
                     D3D12_RESOURCE_STATES srcStateBefore = D3D12_RESOURCE_STATES.UNORDERED_ACCESS,
                     D3D12_RESOURCE_STATES dstStateBefore = D3D12_RESOURCE_STATES.COMMON)
    {
        if (raw is null) return;
        
        auto res = getAvailableResource();

        // 1. Transition barriers: move resources into COPY states
        D3D12_RESOURCE_BARRIER[2] barriers;
        uint numBarriers = 0;

        // Source: current state → COPY_SOURCE
        if (srcStateBefore != D3D12_RESOURCE_STATES.COPY_SOURCE)
        {
            barriers[numBarriers].Type = D3D12_RESOURCE_BARRIER_TYPE.TRANSITION;
            barriers[numBarriers].Flags = D3D12_RESOURCE_BARRIER_FLAGS.NONE;
            barriers[numBarriers].Transition.pResource = cast(void*)src;
            barriers[numBarriers].Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
            barriers[numBarriers].Transition.StateBefore = srcStateBefore;
            barriers[numBarriers].Transition.StateAfter = D3D12_RESOURCE_STATES.COPY_SOURCE;
            numBarriers++;
        }

        // Destination: current state → COPY_DEST
        if (dstStateBefore != D3D12_RESOURCE_STATES.COPY_DEST)
        {
            barriers[numBarriers].Type = D3D12_RESOURCE_BARRIER_TYPE.TRANSITION;
            barriers[numBarriers].Flags = D3D12_RESOURCE_BARRIER_FLAGS.NONE;
            barriers[numBarriers].Transition.pResource = cast(void*)dst;
            barriers[numBarriers].Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
            barriers[numBarriers].Transition.StateBefore = dstStateBefore;
            barriers[numBarriers].Transition.StateAfter = D3D12_RESOURCE_STATES.COPY_DEST;
            numBarriers++;
        }

        if (numBarriers > 0)
            res.commandList.ResourceBarrier(numBarriers, barriers.ptr);

        // 2. Execute the copy
        res.commandList.CopyResource(dst, src);

        // 3. Transition barriers: restore original states
        numBarriers = 0;
        if (srcStateBefore != D3D12_RESOURCE_STATES.COPY_SOURCE)
        {
            barriers[numBarriers].Type = D3D12_RESOURCE_BARRIER_TYPE.TRANSITION;
            barriers[numBarriers].Flags = D3D12_RESOURCE_BARRIER_FLAGS.NONE;
            barriers[numBarriers].Transition.pResource = cast(void*)src;
            barriers[numBarriers].Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
            barriers[numBarriers].Transition.StateBefore = D3D12_RESOURCE_STATES.COPY_SOURCE;
            barriers[numBarriers].Transition.StateAfter = srcStateBefore;
            numBarriers++;
        }

        if (dstStateBefore != D3D12_RESOURCE_STATES.COPY_DEST)
        {
            barriers[numBarriers].Type = D3D12_RESOURCE_BARRIER_TYPE.TRANSITION;
            barriers[numBarriers].Flags = D3D12_RESOURCE_BARRIER_FLAGS.NONE;
            barriers[numBarriers].Transition.pResource = cast(void*)dst;
            barriers[numBarriers].Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
            barriers[numBarriers].Transition.StateBefore = D3D12_RESOURCE_STATES.COPY_DEST;
            barriers[numBarriers].Transition.StateAfter = dstStateBefore;
            numBarriers++;
        }

        if (numBarriers > 0)
            res.commandList.ResourceBarrier(numBarriers, barriers.ptr);

        res.commandList.Close();

        auto ppCommandLists = cast(ID3D12CommandList)res.commandList;
        raw.ExecuteCommandLists(1, &ppCommandLists);
        
        // Signal fence
        ulong fenceToWaitFor = fenceValue;
        raw.Signal(fence, fenceToWaitFor);
        fenceValue++;
        
        // Update the resource in the pool so it knows when it's free
        res.targetFence = fenceToWaitFor;

        // Synchronous wait for copies
        if (fence.GetCompletedValue() < fenceToWaitFor)
        {
            fence.SetEventOnCompletion(fenceToWaitFor, fenceEvent);
            WaitForSingleObject(fenceEvent, INFINITE);
        }
    }

    /// Drain all pending GPU work on this queue.
    /// Mirrors OpenCL's clFinish() — blocks the CPU until every
    /// command list submitted to this queue has completed execution.
    void finish()
    {
        if (raw is null || fence is null) return;

        ulong waitVal = fenceValue;
        raw.Signal(fence, waitVal);
        fenceValue++;

        if (fence.GetCompletedValue() < waitVal)
        {
            fence.SetEventOnCompletion(waitVal, fenceEvent);
            WaitForSingleObject(fenceEvent, INFINITE);
        }
    }

    /// The core dispatch function. Returns an Event for async synchronization!
    auto enqueue(alias k)(uint[3] _grid, uint[3] _block, uint _sharedMem = 0)
    {
        static struct Call
        {
            Queue* q;
            uint[3] grid, block;
            uint sharedMem;
            
            this(Queue* _q, uint[3] _grid, uint[3] _block, uint _sharedMem)
            {
                q = _q;
                grid = _grid;
                block = _block;
                sharedMem = _sharedMem;
            }

            // Returns an Event instead of blocking!
            Event opCall(HostArgsOf!(typeof(k)) args)
            {
                if (q.raw is null) return Event(q, 0);

                auto kernel = Program.globalProgram.getKernel!k();
                if (!kernel.isValid()) return Event(q, 0);

                import dcompute.driver.d3d12.traits : isBufferArg, countUAVs, countScalars, scalarSize, checkKernelABI;

                // 0. Enforce DCompute Driver ABI at compile-time
                checkKernelABI!k;

                enum numUAVs   = countUAVs!k;
                enum numScalars= countScalars!k;
                enum totalDescriptors = (numUAVs > 0 ? numUAVs : 1) + (numScalars > 0 ? 1 : 0);

                // 1. Grab sub-allocation from global descriptor heap
                if (q.currentDescriptorOffset + totalDescriptors >= q.MAX_DESCRIPTORS)
                {
                    // Ring buffer wrap-around: wait for everything to finish, then reset offset
                    ulong waitVal = q.fenceValue - 1;
                    if (q.fence.GetCompletedValue() < waitVal)
                    {
                        q.fence.SetEventOnCompletion(waitVal, q.fenceEvent);
                        WaitForSingleObject(q.fenceEvent, INFINITE);
                    }
                    q.currentDescriptorOffset = 0;
                }

                uint offset = q.currentDescriptorOffset;
                q.currentDescriptorOffset += totalDescriptors;

                D3D12_CPU_DESCRIPTOR_HANDLE cpuHandle = q.globalDescriptorHeap.GetCPUDescriptorHandleForHeapStart();
                D3D12_GPU_DESCRIPTOR_HANDLE gpuHandle = q.globalDescriptorHeap.GetGPUDescriptorHandleForHeapStart();
                
                cpuHandle.ptr += offset * q.descriptorIncrementSize;
                gpuHandle.ptr += offset * q.descriptorIncrementSize;

                // DCompute ABI Rule 1: Map Buffer arguments to UAV views dynamically
                // Vulkan equivalent: vkUpdateDescriptorSets for descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER
                size_t uavSlot = 0;
                static foreach (i, arg; args)
                {
                    static if (isBufferArg!(typeof(arg)))
                    {
                        D3D12_UNORDERED_ACCESS_VIEW_DESC uavDesc;
                        uavDesc.Format = DXGI_FORMAT.UNKNOWN;
                        uavDesc.ViewDimension = D3D12_UAV_DIMENSION.BUFFER;
                        uavDesc.Buffer.FirstElement = 0;
                        uavDesc.Buffer.NumElements = cast(uint)arg.numElements;
                        uavDesc.Buffer.StructureByteStride = typeof(arg.hostMemory[0]).sizeof;
                        uavDesc.Buffer.CounterOffsetInBytes = 0;
                        uavDesc.Buffer.Flags = D3D12_BUFFER_UAV_FLAGS.NONE;

                        D3D12_CPU_DESCRIPTOR_HANDLE currentHandle = cpuHandle;
                        currentHandle.ptr += uavSlot * q.descriptorIncrementSize;

                        q.device.CreateUnorderedAccessView(
                            arg.gpuResource, null, &uavDesc, currentHandle
                        );
                        uavSlot++;
                    }
                }

                // DCompute ABI Rule 2: Map scalar arguments to a Constant Buffer View (CBV c0) if present
                // Vulkan equivalent: vkUpdateDescriptorSets for descriptorType = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER
                ID3D12Resource cbResource;
                static if (numScalars > 0)
                {
                    enum rawSize = scalarSize!k;
                    enum alignedCBSize = (rawSize + 255) & ~255; // 256-byte alignment rule for D3D12 CBVs

                    D3D12_HEAP_PROPERTIES hp;
                    hp.Type = D3D12_HEAP_TYPE.UPLOAD;

                    D3D12_RESOURCE_DESC rd;
                    rd.Dimension        = D3D12_RESOURCE_DIMENSION.BUFFER;
                    rd.Width            = alignedCBSize;
                    rd.Height           = 1;
                    rd.DepthOrArraySize = 1;
                    rd.MipLevels        = 1;
                    rd.SampleDesc.Count = 1;
                    rd.Layout           = D3D12_TEXTURE_LAYOUT.ROW_MAJOR;
                    rd.Flags            = D3D12_RESOURCE_FLAGS.NONE;

                    auto hr = q.device.CreateCommittedResource(
                        &hp,
                        D3D12_HEAP_FLAGS.NONE,
                        &rd,
                        D3D12_RESOURCE_STATES.GENERIC_READ,
                        null,
                        &IID_ID3D12Resource,
                        cast(void**)&cbResource
                    );
                    checkErrors(hr);

                    if (cbResource !is null)
                    {
                        void* mapped;
                        D3D12_RANGE readRange = D3D12_RANGE(0, 0);
                        cbResource.Map(0, &readRange, &mapped);
                        if (mapped !is null)
                        {
                            size_t byteOffset = 0;
                            static foreach (i, arg; args)
                            {
                                static if (!isBufferArg!(typeof(arg)))
                                {
                                    import core.stdc.string : memcpy;
                                    memcpy(mapped + byteOffset, &arg, arg.sizeof);
                                    byteOffset += arg.sizeof;
                                }
                            }
                            D3D12_RANGE writeRange = D3D12_RANGE(0, alignedCBSize);
                            cbResource.Unmap(0, &writeRange);
                        }

                        D3D12_CONSTANT_BUFFER_VIEW_DESC cbvDesc;
                        cbvDesc.BufferLocation = cbResource.GetGPUVirtualAddress();
                        cbvDesc.SizeInBytes    = cast(uint)alignedCBSize;

                        D3D12_CPU_DESCRIPTOR_HANDLE cbvHandle = cpuHandle;
                        cbvHandle.ptr += uavSlot * q.descriptorIncrementSize;

                        q.device.CreateConstantBufferView(
                            &cbvDesc, cbvHandle
                        );
                        
                        // Schedule it for release once this dispatch's fence is passed
                        foreach(ref poolRes; q.inFlightPool) {
                            if (poolRes.allocator == res.allocator) {
                                poolRes.pendingReleases ~= cbResource;
                                break;
                            }
                        }
                    }
                }

                // 4. Record command list using an available allocator pool resource
                auto res = q.getAvailableResource();

                // PSO might be different, so we set it
                res.commandList.SetPipelineState(kernel.pipelineState);
                res.commandList.SetComputeRootSignature(kernel.rootSignature);
                
                auto ppHeaps = cast(ID3D12DescriptorHeap)q.globalDescriptorHeap;
                res.commandList.SetDescriptorHeaps(1, &ppHeaps);

                res.commandList.SetComputeRootDescriptorTable(0, gpuHandle);

                // 5. Dispatch
                res.commandList.Dispatch(grid[0], grid[1], grid[2]);
                res.commandList.Close();

                // 6. Execute Async!
                auto ppCommandLists = cast(ID3D12CommandList)res.commandList;
                q.raw.ExecuteCommandLists(1, &ppCommandLists);

                // Signal fence
                ulong targetFence = q.fenceValue;
                q.raw.Signal(q.fence, targetFence);
                q.fenceValue++;

                // Update the resource pool with the fence value so we know when it's free
                // Note: since we copied by value, we must update the actual array element
                foreach (ref poolRes; q.inFlightPool)
                {
                    if (poolRes.allocator == res.allocator)
                    {
                        poolRes.targetFence = targetFence;
                        break;
                    }
                }

                // Return the event immediately instead of blocking!
                return Event(q, targetFence);
            }
        }
        
        return Call(&this, _grid, _block, _sharedMem);
    }
}

// Forward import for HostArgsOf
import dcompute.driver.d3d12.traits : HostArgsOf;
