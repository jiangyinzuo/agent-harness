```cuda
  // Deterministic == pivot collection via ballot-prefix-sum.
  // Scans the full row in original index order, selecting the first eq_needed
  // elements whose ordered representation matches full_pivot.
  auto collect_eq_pivot_det = [&](OrderedType full_pivot, int eq_needed) {
    constexpr int NUM_WARPS_EQ = BLOCK_SIZE / 32;
    int* warp_eq_counts = s_histogram_buf[1];
    int lane_id = tx & 31;
    int warp_id = tx >> 5;
    int running_eq = 0;
    int num_iters = (length + static_cast<int>(BLOCK_SIZE) - 1) / static_cast<int>(BLOCK_SIZE);
#pragma unroll 1
    for (int it = 0; it < num_iters; it++) {
      int idx = it * static_cast<int>(BLOCK_SIZE) + tx;
      bool valid = (idx < length);
      bool pred = valid && (Traits::ToOrdered(score[idx]) == full_pivot);

      uint32_t ballot = __ballot_sync(0xFFFFFFFF, pred);
      int warp_prefix = __popc(ballot & ((1u << lane_id) - 1));
      int warp_total = __popc(ballot);

      if (lane_id == 0) warp_eq_counts[warp_id] = warp_total;
      __syncthreads();

      int warp_base = running_eq;
      for (int w = 0; w < warp_id; w++) warp_base += warp_eq_counts[w];
      int iter_total = warp_base;
      for (int w = warp_id; w < NUM_WARPS_EQ; w++) iter_total += warp_eq_counts[w];

      if (pred) {
        int pos = warp_base + warp_prefix;
        if (pos < eq_needed) {
          s_indices[static_cast<int>(top_k) - eq_needed + pos] = idx;
        }
      }

      running_eq = iter_total;
      if (running_eq >= eq_needed) break;
      __syncthreads();
    }
    __syncthreads();
  };
```

你可以参考这个实现，临时写一份DeterministicLowerIndexFirstCollect函数，然后在现有的几个调用点中和
DeterministicThreadStridedCollect进行性能对比，

- 使用bench-topk.sh测试。你可以拷贝一份bench-topk.sh脚本，按照你自己的想法，修改其中的变量来运行性能测试
  - 运行AUTO
- 新建一个文件夹，保存实验结果
  - 保存原始数据
  - 修改的代码保存为patch
  - 记录性能对比结果、给出实验结论、分析性能高低背后的原因
