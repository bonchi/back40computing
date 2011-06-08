/******************************************************************************
 * 
 * Copyright 2010-2011 Duane Merrill
 * 
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * 
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License. 
 * 
 * For more information, see our Google Code project site: 
 * http://code.google.com/p/back40computing/
 * 
 ******************************************************************************/

/******************************************************************************
 * BFS compaction downsweep kernel
 ******************************************************************************/

#pragma once

#include <b40c/util/cta_work_distribution.cuh>
#include <b40c/util/cta_work_progress.cuh>
#include <b40c/util/kernel_runtime_stats.cuh>

#include <b40c/bfs/deprecated/compact/downsweep_cta.cuh>

namespace b40c {
namespace bfs {
namespace compact {


/**
 * Downsweep BFS Compaction pass
 */
template <typename KernelPolicy, typename SmemStorage>
__device__ __forceinline__ void DownsweepPass(
	int 										&iteration,
	typename KernelPolicy::VertexId 			* &d_in,
	typename KernelPolicy::VertexId 			* &d_parent_in,
	typename KernelPolicy::ValidFlag			* &d_flags_in,
	typename KernelPolicy::VertexId 			* &d_out,
	typename KernelPolicy::VertexId 			* &d_parent_out,
	typename KernelPolicy::SizeT 				* &d_spine,
	util::CtaWorkProgress 						&work_progress,
	util::CtaWorkDistribution<typename KernelPolicy::SizeT> &work_decomposition,
	SmemStorage									&smem_storage)
{
	typedef DownsweepCta<KernelPolicy> 			DownsweepCta;
	typedef typename KernelPolicy::SizeT 		SizeT;

	// Determine our threadblock's work range
	util::CtaWorkLimits<SizeT> work_limits;
	work_decomposition.template GetCtaWorkLimits<
		KernelPolicy::LOG_TILE_ELEMENTS,
		KernelPolicy::LOG_SCHEDULE_GRANULARITY>(work_limits);

	// Return if we have no work to do
	if (!work_limits.elements) {
		return;
	}

	// We need the exclusive partial from our spine
	SizeT spine_partial;
	util::io::ModifiedLoad<KernelPolicy::READ_MODIFIER>::Ld(
		spine_partial, d_spine + blockIdx.x);

	// CTA processing abstraction
	DownsweepCta cta(
		smem_storage,
		d_in,
		d_parent_in,
		d_flags_in,
		d_out,
		d_parent_out,
		spine_partial);

	// Process full tiles
	while (work_limits.offset < work_limits.guarded_offset) {
		cta.ProcessTile(work_limits.offset);
		work_limits.offset += KernelPolicy::TILE_ELEMENTS;
	}

	// Clean up last partial tile with guarded-io (not first tile)
	if (work_limits.guarded_elements) {
		cta.ProcessTile(
			work_limits.offset,
			work_limits.guarded_elements);
	}

	// Last block with work writes out compacted length
	if (work_limits.last_block && (threadIdx.x == 0)) {
		work_progress.StoreQueueLength(cta.carry, iteration);
	}
}


/******************************************************************************
 * Downsweep BFS Compaction Kernel Entrypoint
 ******************************************************************************/

/**
 * Downsweep BFS Compaction kernel entry point
 */
template <typename KernelPolicy, bool INSTRUMENT>
__launch_bounds__ (KernelPolicy::THREADS, KernelPolicy::CTA_OCCUPANCY)
__global__
void Kernel(
	typename KernelPolicy::VertexId			iteration,
	typename KernelPolicy::VertexId 		* d_in,
	typename KernelPolicy::VertexId 		* d_parent_in,
	typename KernelPolicy::ValidFlag		* d_flags_in,
	typename KernelPolicy::VertexId 		* d_out,
	typename KernelPolicy::VertexId 		* d_parent_out,
	typename KernelPolicy::SizeT			* d_spine,
	util::CtaWorkProgress 					work_progress,
	util::KernelRuntimeStats				kernel_stats)
{
	typedef typename KernelPolicy::SizeT SizeT;

	// Shared storage for CTA processing
	__shared__ typename KernelPolicy::SmemStorage smem_storage;

	if (INSTRUMENT) {
		if (threadIdx.x == 0) {
			kernel_stats.MarkStart();
		}
	}

	// Determine work decomposition
	if (threadIdx.x == 0) {

		// Obtain problem size
		SizeT num_elements = work_progress.template LoadQueueLength<SizeT>(iteration);

		// Initialize work decomposition in smem
		smem_storage.work_decomposition.template Init<KernelPolicy::LOG_SCHEDULE_GRANULARITY>(
			num_elements, gridDim.x);
	}

	// Barrier to protect work decomposition
	__syncthreads();

	DownsweepPass<KernelPolicy>(
		iteration,
		d_in,
		d_parent_in,
		d_flags_in,
		d_out,
		d_parent_out,
		d_spine,
		work_progress,
		smem_storage.work_decomposition,
		smem_storage);

	if (INSTRUMENT) {
		if (threadIdx.x == 0) {
			kernel_stats.MarkStop();
		}
	}
}


} // namespace compact
} // namespace bfs
} // namespace b40c

