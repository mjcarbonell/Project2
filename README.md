## Generation of files: Generation.rsc 
To begin creating a dataset, one can utilize the main function within Generation.rsc to generate a specified file by name(via the name variable) and by the amount of methods (via the methods variable) they would like in that file. 


Each run of main will place the generated file into the CustomDataSet\default folder. 

## Mutation and Clone Injection Type1Mutator.rsc
Once placed there, the user can use the main function in Type1Mutator.rsc to randomly pick a given file A, a method within file A, and a given file B to inject a mutated version of that method. 

Alternatively, the user can also specify explictly which file should be assigned to file A and file B as well as the method to be mutated (from file A). 

Once main() is ran within Type1Mutator.rsc, file A will be outputted to customDataSet_T1/{class_ID}/default to create a collection of type 1 clones of the same "funcitonality" (functinoalityID). 