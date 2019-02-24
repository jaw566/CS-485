#include "tbb/concurrent_queue.h"

void testMultiwayMerge();

void multiwayMergeBatches(uint64_t BATCHSIZE, int NUMBATCHES, double ** resultsFromBatches, double ** tmpBuffer);
void mergeConsumerMultiwayWithRanges(double ** resultsFromBatches, uint64_t lower1, uint64_t upper1, uint64_t lower2, uint64_t upper2);
void multiwayMergeBatchesAfterPipeline(uint64_t N, tbb::concurrent_queue<struct rangeorder> * rangeQueue, double ** resultsFromBatches, double ** tmpBuffer);