#GPU.cu 
SOURCES = main.cu mm_cpu.cpp mm_gpu.cu mm_cpu.h mm_gpu.h mm_utility.h
OBJECTS = mm_cpu.o mm_utility.o
CUDAOBJECTS = mm_gpu.o main.o 
CC = nvcc
EXECUTABLE = main



#fpermissive because of tbb library on UHHPC
FLAGS =  -std=c++11 -O3 -Xcompiler -fopenmp -arch=compute_60 -code=sm_60 -lcuda -lineinfo -Xcompiler -fpermissive
# FLAGS =  -std=c++11 -O3 -Xcompiler -fopenmp -Xcompiler -fpermissive -ltbb -arch=compute_60 -code=sm_60 -lcuda -lineinfo
NTHREADS = -DNTHREADS=16 
CFLAGS = -c 


PARAMS= -DNUM_TRIALS=1 -DBLOCKSIZE=256 -DNUMGPU=1 -DCPUFRAC=1.0 -DPINNEDBUFFER=1000000 -DSTREAMSPERGPU=8 -DBLOCKING=0 

all: $(EXECUTABLE)

# merge.o:
# 	$(CC) -c -std=c++11 -O3 -fopenmp -fpermissive -ltbb merge.cpp

# import_dataset.o:
# 	$(CC) -c -std=c++11 -O3 -fopenmp -fpermissive -ltbb import_dataset.cpp	

.cpp.o:
	$(CC) $(CFLAGS) $(FLAGS) $(NTHREADS) $(PARAMS) $<

main.o: main.cu
	$(CC) $(FLAGS) $(CFLAGS) $(NTHREADS) $(PARAMS) main.cu 
mm_gpu.o: mm_gpu.cu mm_gpu.h
	$(CC) $(FLAGS) $(CFLAGS) $(NTHREADS) $(PARAMS) mm_gpu.cu

$(EXECUTABLE): $(OBJECTS) $(CUDAOBJECTS)
	$(CC) $(FLAGS) $^ -o $@



.PHONY: debug clean 
debug: clean
debug: FLAGS =-std=c++11 -O0 -g -G -Xcompiler -fopenmp -arch=compute_60 -code=sm_60 -lcuda -lineinfo -Xcompiler -fpermissive
debug: main

clean:
	rm -f $(OBJECTS)
	rm -f $(CUDAOBJECTS)
	rm -f main



# all:
# 	$(CC) $(FLAGS) -c $(NTHREADS) $(SEARCHMODE) $(PARAMS) import_dataset.cpp globals.cpp GPU.cu kernel.cu cluster.cpp qsort.cpp
# 	$(CC) $(FLAGS) -c $(NTHREADS) $(SEARCHMODE) $(PARAMS) main.cu 
# 	$(CC) $(FLAGS) $(OBJECTS) $(CUDAOBJECTS) -o main 
