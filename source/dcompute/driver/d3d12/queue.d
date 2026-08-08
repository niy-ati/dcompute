module dcompute.driver.d3d12.queue;

import dcompute.driver.d3d12;

struct Queue
{
    ID3D12CommandQueue* raw;
    ID3D12CommandAllocator* allocator;
    ID3D12GraphicsCommandList* commandList;

    this(bool async)
    {
        D3D12_COMMAND_QUEUE_DESC qDesc;
        qDesc.Type = D3D12_COMMAND_LIST_TYPE_DIRECT;
        
        Device.get.raw.lpVtbl.CreateCommandQueue(Device.get.raw, qDesc.Type, cast(void**)&raw);
        Device.get.raw.lpVtbl.CreateCommandAllocator(Device.get.raw, D3D12_COMMAND_LIST_TYPE_DIRECT, cast(void**)&allocator);
        Device.get.raw.lpVtbl.CreateCommandList(Device.get.raw, 0, D3D12_COMMAND_LIST_TYPE_DIRECT, allocator, null, cast(void**)&commandList);
    }

    @property bool async()
    {
        return false;
    }

    void wait()
    {
        // Fence synchronization
    }

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

            // void opCall(HostArgsOf!(typeof(k)) args)
            // {
            //     auto k_inst = Program.globalProgram.getKernel!k();
            //     q.commandList.lpVtbl.SetPipelineState(q.commandList, k_inst.pipelineState);
            //     q.commandList.lpVtbl.SetComputeRootSignature(q.commandList, k_inst.rootSignature);
            //     // Bind args here
            //     q.commandList.lpVtbl.Dispatch(q.commandList, grid[0], grid[1], grid[2]);
            // }
        }
        
        return Call(this, _grid, _block, _sharedMem);
    }
}
