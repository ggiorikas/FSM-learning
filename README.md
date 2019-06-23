
# FSM Learning

This repository hosts code accompanying [Learning Moore Machines from Input-Output Traces](https://arxiv.org/abs/1605.07805) and related publications.


## Prerequisites

In order to run the random and benchmark Moore machine learning experiments presented in the paper, you will need a [D compiler](https://dlang.org/download.html) (dmd or ldc should be fine), as well as a Python 2.7 interpreter (this is temporary though -- we are in the process of porting all Python code to D). In order to run the performance comparison experiments you will also need [LearnLib](https://github.com/LearnLib/learnlib), [flexfringe](https://bitbucket.org/chrshmmmr/dfasat) and their dependencies.

We ran all experiments on 64 bit Windows (it is possible to compile flexfringe under Cygwin with very little effort), but it should be possible to run everything on Linux or OS X without much modification. We used dmd 2.086.0 for the random and benchmark learning experiments and ldc 1.15.0 for the performance comparison experiments.

## How to...

### Run the random Moore machine learning experiments

```shell
$ dmd -m64 -i -O -release -inline -boundscheck=off generate.d

$ dmd -m64 -i -O -release -inline -boundscheck=off run_rand_fsm_experiments.d

$ run_rand_fsm_experiments.exe
```

Results will be stored in o/all-results.txt. Note that the process stops when detecting high memory usage and you have to restart it (all results are cached -- no experiment is repeated).


### Run the benchmark Moore machine learning experiments

```shell
$ dmd -m64 -i -O -release -inline -boundscheck=off generate.d

$ dmd -m64 -i -O -release -inline -boundscheck=off run_real_fsm_experiments.d

$ run_real_fsm_experiments.exe
```
Results will be stored in o2/all-results.txt    


### Run the performance comparison experiments

#### MealyMI

```shell
$ ldmd2 -m64 -i -O -release -inline -boundscheck=off mealy_learn_opt.d

$ mealy_learn_opt.exe perfcomp/train30ff.txt 3 ff
```

#### LearnLib

- Set up a new maven project following the instructions [here](https://github.com/LearnLib/learnlib/wiki).
For convenience we provide a pom file which also includes the shade plugin, 
required to bundle everything into a single jar (see `perfcomp/pom.xml`).

- As the source code for the project use the provided `perfcomp/ExampleMealy.java`
(edit to make sure the correct path is used for the training set).

- Build and run the project:
    
```shell
$ mvn package

$ java -cp path/to/project.jar org.example.learnlib.ExampleMealy
```

#### flexfringe

- Checkout commit b44cfadf0a28530dd8da72cef439a8fe0f96b462 from [here](https://bitbucket.org/chrshmmmr/dfasat)

- Before building you may want to... 

    - comment out print statements inside
    `random_greedy_bounded_run` (random_greedy.cpp) and
    `get_possible_refinements` (state_merger.cpp)

    - measure execution time of
    `id.read_abbadingo_file(input_stream);` (main.cpp),
    `id.add_data_to_apta(the_apta);` (main.cpp), and
    `random_greedy_bounded_run(&merger);` (dfasat.cpp)
    using e.g. [this](https://stackoverflow.com/a/22387757)

- Build it following the instructions in the repository

    - Note that to build on Windows under Cygwin, you may 
    need to change `-std=c++11` to `-std=gnu++11` in the makefile.

- Run it using the `perfcomp/batch-mealy.ini` file we provide:

```shell
$ ./start.sh batch-mealy.ini path/to/train30ff
```    


## More examples & documentation

Coming soon, stay tuned...


