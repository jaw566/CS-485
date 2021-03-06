#include <stdio.h>
#include <omp.h>
#include <stdlib.h>
#include <string.h>
#include <iostream>
#include <stdint.h>

using namespace std;

void warmUpGPU();

int main( int argc, char **argv )
{
	cudaError_t error_code;
	unsigned long long num_items = atoll( argv[ 1 ] );
	unsigned long long upper_bound = atoll( argv[ 2 ] );

	warmUpGPU();
	const int num_trials = 3;
	const int STEP_SIZE = 125000000;
	int outer_index = 0;

		while( num_items < upper_bound )
		{

			for( outer_index = 0; outer_index < num_trials; outer_index++ )
			{
				char *dev_A = NULL;
				char *host_A = (char*) malloc( sizeof( char ) * num_items );

				int index = 0;
				for( index = 0; index < num_items - 1; index++ )
				{
					host_A[ index ] = 'A';
				}

				host_A[ num_items - 1 ] = '\0';

				error_code = cudaMalloc( (char **) &dev_A, sizeof( char ) * num_items );
				cudaDeviceSynchronize();

				if( error_code != cudaSuccess )
				{
					cout << "Error allocating on device" << endl;
				}

				error_code = cudaMemcpy( dev_A, host_A, sizeof( char ) * num_items, cudaMemcpyHostToDevice );

				cudaDeviceSynchronize();


				free( host_A );
				cudaFree( dev_A );
				cudaDeviceSynchronize();
			}

			num_items += STEP_SIZE;
			printf( "Doing a thing\n" );

		}


	return EXIT_SUCCESS;
}

__global__ void warmup( unsigned int *tmp )
{
    if( threadIdx.x == 0 )
        {
            *tmp = 555;
        }
    return;
}

void warmUpGPU()
{
    printf( "Warming up GPU for time trialing...\n" );

    unsigned int *dev_tmp;
    unsigned int *tmp;

    cudaError_t errCode = cudaSuccess;


    tmp = (unsigned int *) malloc( sizeof( unsigned int ) );
    errCode = cudaMalloc( (unsigned int **) &dev_tmp, sizeof( unsigned int ) );

    if( errCode != cudaSuccess )
        {
            cout << "Error: dev_tmp error with code " << errCode << endl;
        }

    warmup<<<1,256>>>(dev_tmp);

    //copy data from device to host 
	errCode=cudaMemcpy( tmp, dev_tmp, sizeof(unsigned int), cudaMemcpyDeviceToHost);
	if(errCode != cudaSuccess)
    {
        cout << "Error: getting tmp result form GPU error with code " << errCode << endl; 
	}

	cudaDeviceSynchronize();

	printf("tmp (changed to 555 on GPU): %d\n",*tmp);

    cudaFree(dev_tmp);

    return;

}
