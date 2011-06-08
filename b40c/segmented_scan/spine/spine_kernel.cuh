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
 * Segmented scan spine kernel
 ******************************************************************************/

#pragma once

#include <b40c/segmented_scan/downsweep_cta.cuh>

namespace b40c {
namespace segmented_scan {


/**
 * Segmented scan spine pass
 */
template <typename KernelConfig, typename SmemStorage>
__device__ __forceinline__ void SpinePass(
	typename KernelConfig::T 		*&d_partials_in,
	typename KernelConfig::Flag		*&d_flags_in,
	typename KernelConfig::T 		*&d_partials_out,
	typename KernelConfig::SizeT 	&spine_elements,
	SmemStorage						&smem_storage)
{
	typedef DownsweepCta<KernelConfig> DownsweepCta;
	typedef typename KernelConfig::SizeT SizeT;
	typedef typename KernelConfig::SrtsSoaDetails SrtsSoaDetails;

	// Exit if we're not the first CTA
	if (blockIdx.x > 0) return;

	// CTA processing abstraction
	DownsweepCta cta(
		smem_storage,
		d_partials_in,
		d_flags_in,
		d_partials_out);

	// Number of elements in (the last) partially-full tile (requires guarded loads)
	SizeT cta_guarded_elements = spine_elements & (KernelConfig::TILE_ELEMENTS - 1);

	// Offset of final, partially-full tile (requires guarded loads)
	SizeT cta_guarded_offset = spine_elements - cta_guarded_elements;

	// Process full tiles of tile_elements
	SizeT cta_offset = 0;
	while (cta_offset < cta_guarded_offset) {

		cta.template ProcessTile<true>(cta_offset);
		cta_offset += KernelConfig::TILE_ELEMENTS;
	}

	// Clean up last partial tile with guarded-io
	if (cta_guarded_elements) {
		cta.template ProcessTile<false>(
			cta_offset,
			spine_elements);
	}
}


/******************************************************************************
 * Spine Scan Kernel Entry-point
 ******************************************************************************/

/**
 * Spine scan kernel entry point
 */
template <typename KernelConfig>
__launch_bounds__ (KernelConfig::THREADS, KernelConfig::CTA_OCCUPANCY)
__global__ 
void SpineKernel(
	typename KernelConfig::T 		*d_partials_in,
	typename KernelConfig::Flag		*d_flags_in,
	typename KernelConfig::T 		*d_partials_out,
	typename KernelConfig::SizeT 	spine_elements)
{
	// Shared storage for the kernel
	__shared__ typename KernelConfig::SmemStorage smem_storage;

	SpinePass<KernelConfig>(
		d_partials_in,
		d_flags_in,
		d_partials_out,
		spine_elements,
		smem_storage);
}


} // namespace segmented_scan
} // namespace b40c

