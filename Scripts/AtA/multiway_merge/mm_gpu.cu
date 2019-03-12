#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <random>
#include <algorithm> 
#include <string.h>
#include <fstream>
#include <iostream>
#include <string>
#include <math.h>
#include <queue>
#include <iomanip>
#include <set>
#include <algorithm>
#include <thread>
#include <cstdint>
#include <utility>


// thrust inclusions
#include <thrust/host_vector.h>
#include <thrust/device_vector.h>
#include <thrust/sort.h>
#include <thrust/device_ptr.h>
#include <thrust/system/cuda/execution_policy.h> //for streams for thrust (added with Thrust v1.8)
#include <thrust/binary_search.h>
#include <thrust/execution_policy.h>


#include "mm_gpu.h"
#include "omp.h"

void warm_up_gpu( int device )
{
    cudaSetDevice( device ); 		
    // initialize all ten integers of a device_vector to 1 
    thrust::device_vector<int> D(10, 1); 
    // set the first seven elements of a vector to 9 
    thrust::fill(D.begin(), D.begin() + 7, 9); 
    // initialize a host_vector with the first five elements of D 
    thrust::host_vector<int> H(D.begin(), D.begin() + 5); 
    // set the elements of H to 0, 1, 2, 3, ... 
    thrust::sequence(H.begin(), H.end()); // copy all of H back to the beginning of D 
    thrust::copy(H.begin(), H.end(), D.begin()); 
    // print D 

    printf("\nDevice: %d\n",device);

    for(int i = 0; i < D.size(); i++) 
        std::cout << " D[" << i << "] = " << D[i]; 


    // empty the vector
    D.clear();

    // deallocate any capacity which may currently be associated with vec
    D.shrink_to_fit();

    printf("\n");

    return;
}

cudaError_t create_streams( cudaStream_t *streams, const int num_streams )
{
    int index = 0;
    cudaError_t error_code = cudaSuccess;
    cudaError_t result     = cudaSuccess;


    for( index = 0; index < num_streams; ++index )
        {
            error_code = cudaStreamCreate( &streams[ index ] );
            if(  error_code != cudaSuccess )
                {
                    result = error_code;
                }
        }
    return result;
}


void copy_to_device_buffer( uint64_t *input, uint64_t *pinned_host,
                            uint64_t *device_ptr, cudaStream_t stream,
                            uint64_t start_index,
                            uint64_t end_index, uint64_t BATCH_SIZE,
                            int thread_id, int stream_id
                          )
{
    uint64_t copy_index        = 0;
    uint64_t end_index_actual  = 0;
    uint64_t data_copied       = 0;
    uint64_t left_to_copy      = BATCH_SIZE;
    uint64_t data_copied_prev  = 0;
    uint64_t data_copied_total = 0;
    uint64_t write_index       = 0;


    for( copy_index = start_index; left_to_copy > 0; copy_index += BATCH_SIZE )
        {
            // want to make sure that we don't copy extra data
            end_index_actual = std::min( left_to_copy,
                                         BATCH_SIZE 
                                       ) + start_index;
            data_copied        = end_index_actual - start_index;
            data_copied_total += data_copied;

            std::memcpy( pinned_host + ( thread_id * data_copied_total ),
                         input + copy_index,
                         data_copied * sizeof( uint64_t )
                       );

            cudaMemcpyAsync( device_ptr  + ( stream_id * BATCH_SIZE ) + ( write_index * data_copied_prev ),
                             pinned_host + ( thread_id * data_copied_total ),
                             data_copied * sizeof( uint64_t ),
                             cudaMemcpyHostToDevice, stream
                           );

            data_copied_prev = data_copied;
            left_to_copy -= data_copied;

            cudaStreamSynchronize( stream );
        }
}

uint64_t get_gpu_output_index( const std::vector<std::vector<uint64_t>> *end_vectors,
                               const uint64_t numCPUBatches, const int num_threads
                             )
{

    uint64_t index       = 0;
    uint64_t out_val     = 0;

    uint64_t prev_val    = 0;
    uint64_t inner_index = 0;
    for( index = 0; index < end_vectors->size(); ++index )
        {

            for( inner_index = 0; inner_index < numCPUBatches; ++inner_index )
                {
                    prev_val = out_val;
                    
                    // get the difference between this val and the previous
                    // because indices are based from the start of output array
                    out_val += (*end_vectors)[ index ][ inner_index ] - prev_val;

                }
        }
    // out_val now contains the location of the last CPU item,
    // incrementing it puts us at GPU start
    return out_val + 1;

}
void copy_from_device_buffer( uint64_t *output_buffer,
                              uint64_t *pinned_buff, 
                              uint64_t *dev_ptr,
                              cudaStream_t stream,
                              uint64_t BATCH_SIZE,
                              int thread_id, int stream_id,
                              std::vector<uint64_t> *start_ptrs,
                              std::vector<uint64_t> *end_ptrs
                              )
{


    uint64_t start_index = (*start_ptrs)[ thread_id ];
    uint64_t end_index   = (*end_ptrs)[ thread_id ];
    uint64_t to_transfer = 0;
    uint64_t offset      = 0;
    uint64_t transferred = 0;
    uint64_t offset_index = thread_id;

    while( offset_index > 0 )
        {
            offset += (*end_ptrs)[ offset_index ];
            offset_index--;
        }
    
    for( ; start_index < end_index; start_index += BATCH_SIZE )
        {

            to_transfer = std::min( BATCH_SIZE, end_index - start_index + 1 );

            cudaMemcpyAsync(  pinned_buff + ( thread_id * BATCH_SIZE ), dev_ptr + to_transfer, to_transfer * sizeof( uint64_t ), cudaMemcpyDeviceToHost, stream );

            cudaStreamSynchronize( stream );

            std::memcpy( output_buffer + offset_index + transferred, pinned_buff + ( thread_id * BATCH_SIZE ), to_transfer * sizeof( uint64_t ) );

            transferred += to_transfer;
        }
}
