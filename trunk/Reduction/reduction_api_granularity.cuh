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
 *  Reduction Granularity Configuration
 ******************************************************************************/

#pragma once

#include "b40c_cuda_properties.cuh"
#include "b40c_kernel_data_movement.cuh"
#include "reduction_kernel.cuh"

namespace b40c {
namespace reduction {


/**
 * Unified granularity configuration type for both kernels in a reduction pass
 * (upsweep and spine).
 *
 * This type encapsulates both sets of kernel-tuning parameters (they
 * are reflected via the static fields). By deriving from the three granularity
 * types, we assure operational consistency over an entire reduction pass.
 */
template <
	// Problem type
	typename T,
	T BinaryOp(const T&, const T&),
	T Identity(),

	// Common
	typename SizeT,
	CacheModifier CACHE_MODIFIER,
	bool WORK_STEALING,
	bool _UNIFORM_SMEM_ALLOCATION,
	bool _UNIFORM_GRID_SIZE,

	// Upsweep
	int UPSWEEP_CTA_OCCUPANCY,
	int UPSWEEP_LOG_THREADS,
	int UPSWEEP_LOG_LOAD_VEC_SIZE,
	int UPSWEEP_LOG_LOADS_PER_TILE,
	int UPSWEEP_LOG_RAKING_THREADS,
	int UPSWEEP_LOG_SCHEDULE_GRANULARITY,

	// Spine
	int SPINE_LOG_THREADS,
	int SPINE_LOG_LOAD_VEC_SIZE,
	int SPINE_LOG_LOADS_PER_TILE,
	int SPINE_LOG_RAKING_THREADS>
struct ReductionConfig
{
	static const bool UNIFORM_SMEM_ALLOCATION 	= _UNIFORM_SMEM_ALLOCATION;
	static const bool UNIFORM_GRID_SIZE 		= _UNIFORM_GRID_SIZE;

	// Kernel config for the upsweep reduction kernel
	typedef ReductionKernelConfig <
		T,
		BinaryOp,
		Identity,
		SizeT,
		UPSWEEP_CTA_OCCUPANCY,
		UPSWEEP_LOG_THREADS,
		UPSWEEP_LOG_LOAD_VEC_SIZE,
		UPSWEEP_LOG_LOADS_PER_TILE,
		UPSWEEP_LOG_RAKING_THREADS,
		CACHE_MODIFIER,
		WORK_STEALING,
		UPSWEEP_LOG_SCHEDULE_GRANULARITY>
			Upsweep;

	// Kernel config for the spine reduction kernel
	typedef ReductionKernelConfig <
		T,
		BinaryOp,
		Identity,
		int,
		1,
		SPINE_LOG_THREADS,
		SPINE_LOG_LOAD_VEC_SIZE,
		SPINE_LOG_LOADS_PER_TILE,
		SPINE_LOG_RAKING_THREADS,
		CACHE_MODIFIER,
		false,
		SPINE_LOG_LOADS_PER_TILE + SPINE_LOG_LOAD_VEC_SIZE + SPINE_LOG_THREADS>
			Spine;
};
		

}// namespace reduction
}// namespace b40c

