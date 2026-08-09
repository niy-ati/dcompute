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
        if (device.lpVtbl is null) return;

        // 1. Create Command Queue
        D3D12_COMMAND_QUEUE_DESC qDesc;
        qDesc.Type = D3D12_COMMAND_LIST_TYPE.DIRECT; // Or COMPUTE
        qDesc.Flags = 0;
        
        auto hr = (*device.lpVtbl).CreateCommandQueue(
            cast(void*)&device, &qDesc, &IID_ID3D12CommandQueue, cast(void**)&raw
        );
        if (FAILED(hr)) return;

        // 2. Create Command Allocator
        hr = (*device.lpVtbl).CreateCommandAllocator(
            cast(void*)&device, D3D12_COMMAND_LIST_TYPE.DIRECT, &IID_ID3D12CommandAllocator, cast(void**)&allocator
        );
        if (FAILED(hr)) return;

        // 3. Create Command List
        hr = (*device.lpVtbl).CreateCommandList(
            cast(void*)&device, 0, D3D12_COMMAND_LIST_TYPE.DIRECT, allocator, null, &IID_ID3D12GraphicsCommandList, cast(void**)&commandList
        );
        if (FAILED(hr)) return;

        // Command lists are created in the recording state, but our pattern
        // opens/closes around dispatches. We close it immediately here.
        (*commandList.lpVtbl).Close(cast(void*)&commandList);

        // 4. Create Sync Fence
        hr = (*device.lpVtbl).CreateFence(
            cast(void*)&device, 0, D3D12_FENCE_FLAGS.NONE, &IID_ID3D12Fence, cast(void**)&fence
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
        if (raw.lpVtbl is null || fence.lpVtbl is null) return;

        // Signal the fence from the GPU
        ulong fenceToWaitFor = fenceValue;
        (*raw.lpVtbl).Signal(cast(void*)&raw, fence, fenceToWaitFor);
        fenceValue++;

        // Wait on CPU
        if ((*fence.lpVtbl).GetCompletedValue(cast(void*)&fence) < fenceToWaitFor)
        {
            (*fence.lpVtbl).SetEventOnCompletion(cast(void*)&fence, fenceToWaitFor, fenceEvent);
            WaitForSingleObject(fenceEvent, INFINITE);
        }
    }

    /// Internal helper: Execute a copy between resources (e.g. upload to default)
    void executeCopy(ID3D12Resource dst, ID3D12Resource src)
    {
        if (commandList.lpVtbl is null) return;
        
        (*allocator.lpVtbl).Reset(cast(void*)&allocator);
        (*commandList.lpVtbl).Reset(cast(void*)&commandList, allocator, null);

        (*commandList.lpVtbl).CopyResource(cast(void*)&commandList, dst, src);

        (*commandList.lpVtbl).Close(cast(void*)&commandList);

        ID3D12CommandList* ppCommandLists = cast(ID3D12CommandList*)commandList;
        (*raw.lpVtbl).ExecuteCommandLists(cast(void*)&raw, 1, &ppCommandLists);
        
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
                if (q.commandList.lpVtbl is null) return;

                auto kernel = Program.globalProgram.getKernel!k();
                if (!kernel.isValid()) return;

                enum numArgs = args.length;

                // 1. Allocate a Shader-Visible Descriptor Heap for this dispatch.
                // In a real driver, this would be a ring buffer or pool, but for now
                // we allocate one per dispatch.
                D3D12_DESCRIPTOR_HEAP_DESC heapDesc;
                heapDesc.NumDescriptors = numArgs > 0 ? numArgs : 1;
                heapDesc.Type = D3D12_DESCRIPTOR_HEAP_TYPE.CBV_SRV_UAV;
                heapDesc.Flags = D3D12_DESCRIPTOR_HEAP_FLAGS.SHADER_VISIBLE;
                heapDesc.NodeMask = 0;

                ID3D12DescriptorHeap descHeap;
                (*q.device.lpVtbl).CreateDescriptorHeap(
                    cast(void*)&q.device, &heapDesc, &IID_ID3D12DescriptorHeap, cast(void**)&descHeap
                );

                if (descHeap.lpVtbl is null) return;

                uint descriptorSize = (*q.device.lpVtbl).GetDescriptorHandleIncrementSize(
                    cast(void*)&q.device, D3D12_DESCRIPTOR_HEAP_TYPE.CBV_SRV_UAV
                );
                
                D3D12_CPU_DESCRIPTOR_HANDLE cpuHandle = (*descHeap.lpVtbl).GetCPUDescriptorHandleForHeapStart(cast(void*)&descHeap);
                D3D12_GPU_DESCRIPTOR_HANDLE gpuHandle = (*descHeap.lpVtbl).GetGPUDescriptorHandleForHeapStart(cast(void*)&descHeap);

                // 2. Iterate arguments and map them to UAV views dynamically
                static foreach (i, arg; args)
                {
                    // arg is a Buffer!T (since it was a GlobalPointer!T in the kernel)
                    // We need to create a UAV for its gpuResource
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
                        currentHandle.ptr += i * descriptorSize;

                        (*q.device.lpVtbl).CreateUnorderedAccessView(
                            cast(void*)&q.device, arg.gpuResource, null, &uavDesc, currentHandle
                        );
                    }
                }

                // 3. Record command list
                (*q.allocator.lpVtbl).Reset(cast(void*)&q.allocator);
                (*q.commandList.lpVtbl).Reset(cast(void*)&q.commandList, q.allocator, kernel.pipelineState);

                (*q.commandList.lpVtbl).SetComputeRootSignature(cast(void*)&q.commandList, kernel.rootSignature);
                
                ID3D12DescriptorHeap* ppHeaps = cast(ID3D12DescriptorHeap*)descHeap;
                (*q.commandList.lpVtbl).SetDescriptorHeaps(cast(void*)&q.commandList, 1, &ppHeaps);

                (*q.commandList.lpVtbl).SetComputeRootDescriptorTable(cast(void*)&q.commandList, 0, gpuHandle);

                // 4. Dispatch
                // DCompute kernel blocks map directly to Dispatch thread groups.
                (*q.commandList.lpVtbl).Dispatch(cast(void*)&q.commandList, grid[0], grid[1], grid[2]);

                (*q.commandList.lpVtbl).Close(cast(void*)&q.commandList);

                // 5. Execute
                ID3D12CommandList* ppCommandLists = cast(ID3D12CommandList*)q.commandList;
                (*q.raw.lpVtbl).ExecuteCommandLists(cast(void*)&q.raw, 1, &ppCommandLists);

                // Wait immediately to keep memory safe (simplification)
                q.wait();

                // Cleanup temporary heap
                (*descHeap.lpVtbl).Release(cast(void*)&descHeap);
            }
        }
        
        return Call(this, _grid, _block, _sharedMem);
    }
}

// Forward import for HostArgsOf
import dcompute.driver.d3d12.traits : HostArgsOf;
