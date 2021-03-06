#include <parallel/algorithm>
#include <stdlib.h>
#include <stdint.h>
#include <stdio.h>
#include <random>
#include <algorithm> 
#include <string.h>
#include <fstream>
#include <iostream>
#include <string>
#include <cmath>
#include <queue>
#include <iomanip>
#include <set>
#include <thread>
#include <utility>

// // thrust inclusions
#include <thrust/host_vector.h>
#include <thrust/device_vector.h>
#include <thrust/sort.h>
#include <thrust/device_ptr.h>
#include <thrust/system/cuda/execution_policy.h> //for streams for thrust (added with Thrust v1.8)
#include <thrust/binary_search.h>
#include <thrust/execution_policy.h>

#include "omp.h"
#include "ls_utility.h"

const int NUM_ARGS = 5;

int parse_args( args *dest, int argc, char ***argv )
{
    char **local_argv    = *argv;

    if( argc != NUM_ARGS )
        {
            return 0;
        }

    dest->N          = strtoull( local_argv[ 2 ], NULL, 0 );
    dest->batch_size = strtoull( local_argv[ 3 ], NULL, 0 );
    dest->cpu_frac   = atof( local_argv[ 4 ] );
    dest->seed       = atoi( local_argv[ 1 ] );

    return 1;
}

void report_args_failure( void )
{
    printf( "Incorrect args, must include seed for random number generation, "
            "N, the number of elements to scan, batch_size, the number of elements "
            "per batch, and cpu_frac, the fraction of batches to send to the CPU.\n"
          );
}

void generate_dataset( uint64_t *data, uint64_t num_items, int seed )
{
    uint64_t index = 0;
	//rng for the keys
	std::mt19937 gen( seed ); 
	//transform the randomly generated numbers into uniform distribution of ints
	std::uniform_int_distribution<uint64_t> dis( 0, num_items );

	for( index = 0; index < num_items; ++index )
	{
        data[ index ] = dis( gen );
    }
}

void compute_batches( std::vector<uint64_t> *vector_ptr, uint64_t n, uint64_t batch_size )
{
    uint64_t index = 0;

    for( index = 0 ; index < n / batch_size; ++index )
        {
            vector_ptr->push_back(  ( ( index + 1 ) * batch_size ) - 1 );
        }
}

double get_elapsed( time_data *data )
{
    return data->end - data->start;
}
