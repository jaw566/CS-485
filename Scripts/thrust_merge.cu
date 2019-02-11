#include <stdio.h>
#include <stdlib.h>
#include <omp.h>
#include <inttypes.h>
#include <vector>
#include <stdbool.h>
#include <algorithm>
#include <thrust/host_vector.h>
#include <thrust/device_vector.h>
#include <thrust/generate.h>
#include <thrust/copy.h>
#include <thrust/merge.h>

using namespace std;

const unsigned int DEVICE_CAPACITY_GB = 16;
const unsigned int DEFAULT_NUM_ARGS   = 3; // 2 + 1, first is prog name
const unsigned int SEED_RAND          = 42;

typedef struct command_args
{
    unsigned int total_data_size;
    unsigned int block_size;
} command_args_t;


bool parse_args( int argc, char **argv, command_args_t *dest );
int compare_ints( const void *a, const void *b );
uint64_t calc_num_items( unsigned int max_size_gb );
void report_time( double start_time, double end_time, const char *description );
std::vector<unsigned int> create_sorted_data( uint64_t num_items );
uint64_t num_items_in_gb( size_t item_size );
std::vector<unsigned int> merge_data( std::vector<unsigned int> data,
                 unsigned int size_in_gb, unsigned int block_size
               );

void verify_data_sorted( std::vector<unsigned int> data );

int main( int argc, char **argv )
{
    bool correct_args = false;
    command_args_t args;
    srand( SEED_RAND );
    double start_time = 0;
    double end_time   = 0;

    uint64_t num_items = 0;

    correct_args = parse_args( argc, argv, &args );

    if( !correct_args )
        {
            printf( "USAGE: thrust_merge total_size block_size\n"
                    "total_size and block_size are in GB\n"
                  );
            return EXIT_FAILURE;
        }

    // determine the number of 4 byte unsigned integers that can be used
    num_items = calc_num_items( args.total_data_size );
    printf( "Num of items: %" PRIu64 "\n", num_items );

    // create the data, time how long it takes to create
    start_time = omp_get_wtime();
    std::vector<unsigned int> data = create_sorted_data( num_items );
    end_time   = omp_get_wtime();

    // report time taken to sort data
    report_time( start_time, end_time, "Time taken to sort data" );

    // time how long it takes to merge the data
    start_time = omp_get_wtime();
    merge_data( data, args.total_data_size, args.block_size );
    end_time   = omp_get_wtime();

    report_time( start_time, end_time, "Time taken to merge all data on GPU" );
    // verify that the data is still sorted
    verify_data_sorted( data );


    return EXIT_SUCCESS;
}

bool parse_args( int argc, char **argv, command_args_t *dest )
{
    if( (unsigned int) argc != DEFAULT_NUM_ARGS )
        {
            return false;
        }
    dest->total_data_size = (unsigned int) atoll( argv[ 1 ] );
    dest->block_size      = atoi( argv[ 2 ] );

    return true;
}

uint64_t calc_num_items( unsigned int max_size_gb )
{
    uint64_t out_items = 0;

    out_items = num_items_in_gb( sizeof( unsigned int ) ) * max_size_gb;

    return out_items;
}


std::vector<unsigned int> create_sorted_data( uint64_t num_items )
{
    uint64_t index = 0;

    std::vector<unsigned int> data_ptr( num_items );

    for( index = 0; index < num_items; index++ )
        {
            data_ptr[ index ] = (unsigned int) rand();
        }

    std::sort( data_ptr.begin(), data_ptr.end() );
    return data_ptr;
}

int compare_ints( const void *a, const void *b )
{
    return *(int*)a - *(int*)b;
}
void report_time( double start_time, double end_time, const char *description )
{
    printf( "%s: %f\n", description, end_time - start_time );
}
std::vector<unsigned int> merge_data( std::vector<unsigned int> data,
                 unsigned int size_in_gb, unsigned int block_size )
{
    uint64_t items_in_one_gb    = num_items_in_gb( sizeof( unsigned int ) );
    uint64_t num_elements_trans = 0;
    uint64_t start_index        = 0;
    uint64_t end_index          = 0;
    unsigned int gb_left_to_transfer = size_in_gb;
    unsigned int gb_on_device   = 0;

    std::vector<unsigned int> merged_data( data.size() );

    while( gb_left_to_transfer > 0 )
        {
            while( gb_on_device < DEVICE_CAPACITY_GB / 2 )
                {
                    num_elements_trans = items_in_one_gb * min( gb_left_to_transfer, block_size ); 

                    gb_on_device += num_elements_trans;
                }

            gb_left_to_transfer -= gb_on_device;
            gb_on_device = 0;
        }

    return merged_data;

}

void verify_data_sorted( std::vector<unsigned int> data )
{
    uint64_t index = 0;

    for( index = 0; index < data.size() - 1; index++ )
        {
            if( data[ index ] > data[ index + 1 ] )
                {
                    printf( "Bad jujumagumbo\n" );
                }
        }
}

uint64_t num_items_in_gb( size_t item_size )
{
    const uint64_t GIGABYTE_EXPONENT = 30;
    return ( ( 1LLU << GIGABYTE_EXPONENT ) ) / item_size;
}