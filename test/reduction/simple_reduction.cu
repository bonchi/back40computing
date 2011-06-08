/******************************************************************************
 * 
 * Reductionright 2010-2011 Duane Merrill
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a reduction of the License at
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
 * Simple test driver program for reduction.
 ******************************************************************************/

#include <stdio.h> 
#include <b40c/reduction/enactor.cuh>

// Test utils
#include "b40c_test_util.h"

using namespace b40c;


/******************************************************************************
 * Utility Routines
 ******************************************************************************/


/**
 * Max binary associative operator
 */
template <typename T>
__host__ __device__ __forceinline__ T Max(const T &a, const T &b)
{
	return (a > b) ? a : b;
}


/**
 * Example showing syntax for invoking templated member functions from 
 * a templated function
 */
template <
	typename T,
	T BinaryOp(const T&, const T&)>
void TemplatedSubroutineReduction(
	b40c::reduction::Enactor &reduction_enactor,
	T *d_dest, 
	T *d_src,
	int num_elements)
{
	reduction_enactor.template Reduce<T, BinaryOp>(d_dest, d_src, num_elements);
}


/******************************************************************************
 * Main
 ******************************************************************************/

int main(int argc, char** argv)
{
	CommandLineArgs args(argc, argv);

	// Usage/help
    if (args.CheckCmdLineFlag("help") || args.CheckCmdLineFlag("h")) {
    	printf("\nsimple_reduction [--device=<device index>]\n");
    	return 0;
    }

    DeviceInit(args);

	typedef unsigned int T;
	const int NUM_ELEMENTS = 10;

	// Allocate and initialize host problem data and host reference solution
	T h_data[NUM_ELEMENTS];
	T h_reference[1];
	for (int i = 0; i < NUM_ELEMENTS; i++) {
		h_data[i] = i;
		h_reference[0] = (i == 0) ?
			h_data[i] :
			Max(h_reference[0], h_data[i]);
	}
	
	// Allocate and initialize device data
	T *d_src, *d_dest;
	cudaMalloc((void**) &d_src, sizeof(T) * NUM_ELEMENTS);
	cudaMalloc((void**) &d_dest, sizeof(T) * NUM_ELEMENTS);
	cudaMemcpy(d_src, h_data, sizeof(T) * NUM_ELEMENTS, cudaMemcpyHostToDevice);
	
	// Create a reduction enactor
	b40c::reduction::Enactor reduction_enactor;
	

	//
	// Example 1: Enact simple reduction using internal tuning heuristics
	//
	reduction_enactor.Reduce<T, Max>(d_dest, d_src, NUM_ELEMENTS);
	
	printf("Simple reduction: "); CompareDeviceResults(h_reference, d_dest, 1); printf("\n");
	
	
	//
	// Example 2: Enact simple reduction using "large problem" tuning configuration
	//
	reduction_enactor.Reduce<T, Max, b40c::reduction::LARGE_SIZE>(
		d_dest, d_src, NUM_ELEMENTS);

	printf("Large-tuned reduction: "); CompareDeviceResults(h_reference, d_dest, 1); printf("\n");

	
	//
	// Example 3: Enact simple reduction using "small problem" tuning configuration
	//
	reduction_enactor.Reduce<T, Max, b40c::reduction::SMALL_SIZE>(
		d_dest, d_src, NUM_ELEMENTS);
	
	printf("Small-tuned reduction: "); CompareDeviceResults(h_reference, d_dest, 1); printf("\n");


	//
	// Example 4: Enact simple reduction using a templated subroutine function
	//
	TemplatedSubroutineReduction<T, Max>(reduction_enactor, d_dest, d_src, NUM_ELEMENTS);
	
	printf("Templated subroutine reduction: "); CompareDeviceResults(h_reference, d_dest, 1); printf("\n");


	//
	// Example 5: Enact simple reduction using custom tuning configuration (base reduction enactor)
	//

	typedef b40c::reduction::ProblemType<T, size_t, Max> ProblemType;
	typedef b40c::reduction::Policy<
		ProblemType,
		b40c::reduction::SM20,
		b40c::util::io::ld::cg,
		b40c::util::io::st::cg,
		true,
		false,
		true, 
		false, 
		8, 7, 1, 2, 9,
		8, 1, 1> CustomPolicy;
	
	reduction_enactor.Reduce<CustomPolicy>(d_dest, d_src, NUM_ELEMENTS);

	printf("Custom reduction: "); CompareDeviceResults(h_reference, d_dest, 1); printf("\n");

	return 0;
}

