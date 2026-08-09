module dcompute.driver.d3d12.queue;

import dcompute.driver.d3d12.bindings;
import dcompute.driver.d3d12.device;
import dcompute.driver.d3d12.program;
import dcompute.driver.d3d12.runtime;
import dcompute.driver.d3d12.buffer;

/// A command queue in D3D12. Mirrors dcompute.driver.cuda.queue.
///
/// Handles command list recording, descriptor heap allocation for kernel arguments,
/// and dispatching compute workloads.
struct Queue
{
    ID3D12CommandQueue        raw;
    ID3D12CommandAllocator    allocator;
    ID3D12GraphicsCommandList commandList;
    ID3D12Fence               fence;
    ulong                     fenceValue;
    HANDLE                    fenceEvent;
    ID3D12Device              device; // cached

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
        if (FAILED(hr)) return;

        // 2. Create Command Allocator
        hr = device.CreateCommandAllocator(
            D3D12_COMMAND_LIST_TYPE.DIRECT, &IID_ID3D12CommandAllocator, cast(void**)&allocator
        );
        if (FAILED(hr)) return;

        // 3. Create Command List
        hr = device.CreateCommandList(
            0, D3D12_COMMAND_LIST_TYPE.DIRECT, allocator, null, &IID_ID3D12GraphicsCommandList, cast(void**)&commandList
        );
        if (FAILED(hr)) return;

        // Command lists are created in the recording state, but our pattern
        // opens/closes around dispatches. We close it immediately here.
        commandList.Close();

        // 4. Create Sync Fence
        hr = device.CreateFence(
            0, D3D12_FENCE_FLAGS.NONE, &IID_ID3D12Fence, cast(void**)&fence
        );
        if (FAILED(hr)) return;
        
        fenceValue = 1;
        fenceEvent = CreateEventW(null, 0 /*FALSE*/, 0 /*FALSE*/, null);
    }

    @property bool async()
    {
        return false;
    }

    /// Wait for all submitted work to complete on the GPU.
    void wait()
    {
        if (raw is null || fence is null) return;

        // Signal the fence from the GPU
        ulong fenceToWaitFor = fenceValue;
        raw.Signal(fence, fenceToWaitFor);
        fenceValue++;

        // Wait on CPU
        if (fence.GetCompletedValue() < fenceToWaitFor)
        {
            fence.SetEventOnCompletion(fenceToWaitFor, fenceEvent);
            WaitForSingleObject(fenceEvent, INFINITE);
        }
    }

    /// Internal helper: Execute a copy between resources (e.g. upload to default)
    void executeCopy(ID3D12Resource dst, ID3D12Resource src)
    {
        if (commandList is null) return;
        
        allocator.Reset();
        commandList.Reset(allocator, null);

        commandList.CopyResource(dst, src);

        commandList.Close();

        auto ppCommandLists = cast(ID3D12CommandList)commandList;
        raw.ExecuteCommandLists(1, &ppCommandLists);
        
        wait();
    }

    /// The core dispatch function. Maps D arguments to D3D12 Descriptors dynamically.
    auto enqueue(alias k)(uint[3] _grid, uint[3] _block, uint _sharedMem = 0)
    {
        static struct Call
        {
            Queue q;
            uint[3] grid, block;
            uint sharedMem;
            
            this(Queue _q, uint[3] _grid, uint[3] _block, uint _sharedMem)
            {
                q = _q;
                grid = _grid;
                block = _block;
                sharedMem = _sharedMem;
            }

            // This is the metaprogramming magic.
            // HostArgsOf gets the host-side types for the kernel (e.g. Buffer!float).
            void opCall(HostArgsOf!(typeof(k)) args)
            {
                if (q.commandList is null) return;

                auto kernel = Program.globalProgram.getKernel!k();
                if (!kernel.isValid()) return;

                import dcompute.driver.d3d12.traits : isBufferArg, countUAVs, countScalars, scalarSize;

                enum numUAVs   = countUAVs!k;
                enum numScalars= countScalars!k;
                enum totalDescriptors = (numUAVs > 0 ? numUAVs : 1) + (numScalars > 0 ? 1 : 0);

                // 1. Allocate a Shader-Visible Descriptor Heap for this dispatch.
                D3D12_DESCRIPTOR_HEAP_DESC heapDesc;
                heapDesc.NumDescriptors = totalDescriptors;
                heapDesc.Type = D3D12_DESCRIPTOR_HEAP_TYPE.CBV_SRV_UAV;
                heapDesc.Flags = D3D12_DESCRIPTOR_HEAP_FLAGS.SHADER_VISIBLE;
                heapDesc.NodeMask = 0;

                ID3D12DescriptorHeap descHeap;
                q.device.CreateDescriptorHeap(
                    &heapDesc, &IID_ID3D12DescriptorHeap, cast(void**)&descHeap
                );

                if (descHeap is null) return;

                uint descriptorSize = q.device.GetDescriptorHandleIncrementSize(
                    D3D12_DESCRIPTOR_HEAP_TYPE.CBV_SRV_UAV
                );
                
                D3D12_CPU_DESCRIPTOR_HANDLE cpuHandle = descHeap.GetCPUDescriptorHandleForHeapStart();
                D3D12_GPU_DESCRIPTOR_HANDLE gpuHandle = descHeap.GetGPUDescriptorHandleForHeapStart();

                // 2. Map Buffer arguments to UAV views dynamically
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
                        currentHandle.ptr += uavSlot * descriptorSize;

                        q.device.CreateUnorderedAccessView(
                            arg.gpuResource, null, &uavDesc, currentHandle
                        );
                        uavSlot++;
                    }
                }

                // 3. Map scalar arguments to a Constant Buffer View (CBV c0) if present
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

                    q.device.CreateCommittedResource(
                        &hp,
                        D3D12_HEAP_FLAGS.NONE,
                        &rd,
                        D3D12_RESOURCE_STATES.GENERIC_READ,
                        null,
                        &IID_ID3D12Resource,
                        cast(void**)&cbResource
                    );

                    if (cbResource !is null)
                    {
                        void* mapped;
                        D3D12_RANGE readRange = D3D12_RANGE(0, 0);
                        cbResource.Map(0, &readRange, &mapped);
                        if (mapped !is null)
                        {
                            size_t offset = 0;
                            static foreach (i, arg; args)
                            {
                                static if (!isBufferArg!(typeof(arg)))
                                {
                                    import core.stdc.string : memcpy;
                                    memcpy(mapped + offset, &arg, arg.sizeof);
                                    offset += arg.sizeof;
                                }
                            }
                            D3D12_RANGE writeRange = D3D12_RANGE(0, alignedCBSize);
                            cbResource.Unmap(0, &writeRange);
                        }

                        D3D12_CONSTANT_BUFFER_VIEW_DESC cbvDesc;
                        cbvDesc.BufferLocation = cbResource.GetGPUVirtualAddress();
                        cbvDesc.SizeInBytes    = cast(uint)alignedCBSize;

                        D3D12_CPU_DESCRIPTOR_HANDLE cbvHandle = cpuHandle;
                        cbvHandle.ptr += uavSlot * descriptorSize;

                        q.device.CreateConstantBufferView(
                            &cbvDesc, cbvHandle
                        );
                    }
                }

                // 4. Record command list
                q.allocator.Reset();
                q.commandList.Reset(q.allocator, kernel.pipelineState);

                q.commandList.SetComputeRootSignature(kernel.rootSignature);
                
                auto ppHeaps = cast(ID3D12DescriptorHeap)descHeap;
                q.commandList.SetDescriptorHeaps(1, &ppHeaps);

                q.commandList.SetComputeRootDescriptorTable(0, gpuHandle);

                // 5. Dispatch
                // DCompute kernel blocks map directly to Dispatch thread groups.
                q.commandList.Dispatch(grid[0], grid[1], grid[2]);

                q.commandList.Close();

                // 6. Execute
                auto ppCommandLists = cast(ID3D12CommandList)q.commandList;
                q.raw.ExecuteCommandLists(1, &ppCommandLists);

                // Wait immediately to keep memory safe (simplification)
                q.wait();

                // Cleanup temporary heaps and resources
                descHeap.Release();
                static if (numScalars > 0)
                {
                    if (cbResource !is null)
                        cbResource.Release();
                }
            }
        }
        
        return Call(this, _grid, _block, _sharedMem);
    }
}

// Forward import for HostArgsOf
import dcompute.driver.d3d12.traits : HostArgsOf;
